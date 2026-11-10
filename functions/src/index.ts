import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import * as zlib from "zlib";
import * as crypto from "crypto";

// Initialize Firebase Admin SDK if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Structure of pricing data for a single card printing.
 */
export interface CardMarketPrices {
  usd: number | null;
  usd_foil: number | null;
  usd_etched: number | null;
  eur: number | null;
  eur_foil: number | null;
}

/**
 * Consolidated market price snapshot payload stored in Cloud Storage.
 */
export interface MarketPriceSnapshot {
  version: string;
  updatedAt: string;
  cardCount: number;
  prices: Record<string, CardMarketPrices>;
}

/**
 * Scheduled Cloud Function running daily at 3:00 AM Central (America/Chicago).
 * Fetches Scryfall daily bulk prices, compresses payload into gzip,
 * uploads to Firebase Storage (`market_prices/latest.json.gz`),
 * and atomically updates Firestore metadata document `system/market_sync`.
 */
export const syncDailyMarketPrices = onSchedule(
  {
    schedule: "0 3 * * *",
    timeZone: "America/Chicago",
    timeoutSeconds: 540,
    memory: "1GiB",
    retryCount: 3,
  },
  async (event) => {
    const jobStartTime = new Date().toISOString();
    console.log(`[syncDailyMarketPrices] Job started at ${jobStartTime} (scheduled time: ${event.scheduleTime})`);

    try {
      // Step 1: Query Scryfall bulk data endpoint
      console.log("[syncDailyMarketPrices] Fetching Scryfall bulk data index...");
      const bulkIndexResponse = await fetch("https://api.scryfall.com/bulk-data", {
        headers: {
          "User-Agent": "Countr-PriceSync/1.0.0 (https://countr.app; support@countr.app)",
          "Accept": "application/json",
        },
      });

      if (!bulkIndexResponse.ok) {
        throw new Error(
          `Failed to fetch Scryfall bulk data index: HTTP ${bulkIndexResponse.status} ${bulkIndexResponse.statusText}`
        );
      }

      const bulkIndex = (await bulkIndexResponse.json()) as {
        data?: Array<{ type: string; download_uri?: string }>;
      };
      const defaultCardsMeta = bulkIndex.data?.find(
        (entry) => entry.type === "default_cards"
      );

      if (!defaultCardsMeta?.download_uri) {
        throw new Error("Scryfall bulk data index did not contain a valid download_uri for default_cards");
      }

      // Step 2: Download default cards JSON feed
      console.log(`[syncDailyMarketPrices] Downloading card dataset from ${defaultCardsMeta.download_uri}...`);
      const cardsResponse = await fetch(defaultCardsMeta.download_uri, {
        headers: {
          "User-Agent": "Countr-PriceSync/1.0.0 (https://countr.app; support@countr.app)",
          "Accept": "application/json",
        },
      });

      if (!cardsResponse.ok) {
        throw new Error(`Failed to download cards feed: HTTP ${cardsResponse.status} ${cardsResponse.statusText}`);
      }

      const allCards = (await cardsResponse.json()) as Array<{
        id: string;
        prices?: Record<string, string | null>;
      }>;
      console.log(`[syncDailyMarketPrices] Successfully downloaded ${allCards.length} card objects.`);

      // Step 3: Extract and normalize prices into key-value map (Scryfall ID -> CardMarketPrices)
      const priceMap: Record<string, CardMarketPrices> = {};
      let validPriceCount = 0;

      for (const card of allCards) {
        if (!card.id || !card.prices) continue;

        const prices = card.prices;
        const usd = prices.usd != null ? parseFloat(prices.usd) : null;
        const usdFoil = prices.usd_foil != null ? parseFloat(prices.usd_foil) : null;
        const usdEtched = prices.usd_etched != null ? parseFloat(prices.usd_etched) : null;
        const eur = prices.eur != null ? parseFloat(prices.eur) : null;
        const eurFoil = prices.eur_foil != null ? parseFloat(prices.eur_foil) : null;

        const hasAnyPrice =
          (usd !== null && !isNaN(usd)) ||
          (usdFoil !== null && !isNaN(usdFoil)) ||
          (usdEtched !== null && !isNaN(usdEtched)) ||
          (eur !== null && !isNaN(eur)) ||
          (eurFoil !== null && !isNaN(eurFoil));

        if (hasAnyPrice) {
          priceMap[card.id] = {
            usd: usd !== null && !isNaN(usd) ? usd : null,
            usd_foil: usdFoil !== null && !isNaN(usdFoil) ? usdFoil : null,
            usd_etched: usdEtched !== null && !isNaN(usdEtched) ? usdEtched : null,
            eur: eur !== null && !isNaN(eur) ? eur : null,
            eur_foil: eurFoil !== null && !isNaN(eurFoil) ? eurFoil : null,
          };
          validPriceCount++;
        }
      }

      console.log(`[syncDailyMarketPrices] Extracted prices for ${validPriceCount} cards.`);

      // Step 4: Construct snapshot and compress payload with gzip
      const nowIso = new Date().toISOString();
      const snapshot: MarketPriceSnapshot = {
        version: "v1",
        updatedAt: nowIso,
        cardCount: validPriceCount,
        prices: priceMap,
      };

      const rawJson = JSON.stringify(snapshot);
      const rawBuffer = Buffer.from(rawJson, "utf-8");
      const compressedBuffer = zlib.gzipSync(rawBuffer, { level: 9 });
      const checksum = crypto.createHash("sha256").update(compressedBuffer).digest("hex");

      const rawSizeMb = (rawBuffer.length / (1024 * 1024)).toFixed(2);
      const gzippedSizeMb = (compressedBuffer.length / (1024 * 1024)).toFixed(2);
      console.log(
        `[syncDailyMarketPrices] Payload size: ${rawSizeMb} MB uncompressed -> ${gzippedSizeMb} MB gzipped. Checksum: ${checksum}`
      );

      // Step 5: Upload compressed file to Firebase Cloud Storage
      const bucket = admin.storage().bucket();
      const storageFilePath = "market_prices/latest.json.gz";
      const file = bucket.file(storageFilePath);

      await file.save(compressedBuffer, {
        contentType: "application/gzip",
        metadata: {
          contentEncoding: "gzip",
          contentType: "application/json",
          metadata: {
            checksum,
            cardCount: validPriceCount.toString(),
            version: "v1",
            updatedAt: snapshot.updatedAt,
          },
        },
        resumable: false,
      });

      console.log(`[syncDailyMarketPrices] Uploaded compressed market prices to gs://${bucket.name}/${storageFilePath}`);

      // Optional archive delta path: prices/deltas/YYYY-MM-DD.json.gz
      const dateStr = nowIso.slice(0, 10);
      const deltaFilePath = `market_prices/deltas/${dateStr}.json.gz`;
      await bucket.file(deltaFilePath).save(compressedBuffer, {
        contentType: "application/gzip",
        metadata: {
          contentEncoding: "gzip",
          contentType: "application/json",
          metadata: {
            checksum,
            cardCount: validPriceCount.toString(),
            version: "v1",
            updatedAt: snapshot.updatedAt,
          },
        },
        resumable: false,
      });

      // Step 6: Atomically update Firestore metadata document system/market_sync
      const db = admin.firestore();
      const syncDocRef = db.doc("system/market_sync");

      await syncDocRef.set({
        timestamp: admin.firestore.Timestamp.now(),
        version: "v1",
        checksum,
        cardCount: validPriceCount,
        storagePath: storageFilePath,
        fileSizeBytes: compressedBuffer.length,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log("[syncDailyMarketPrices] Successfully committed metadata to Firestore doc: system/market_sync.");
    } catch (error) {
      console.error("[syncDailyMarketPrices] Job failed with unhandled error:", error);
      throw error;
    }
  }
);
