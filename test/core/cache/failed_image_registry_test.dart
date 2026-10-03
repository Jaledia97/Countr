import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/failed_image_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FailedImageRegistry registry;

  setUp(() {
    registry = FailedImageRegistry.instance;
    registry.clear();
    registry.maxAttempts = 3; // Enforce strict cap: max 2-3 attempts
  });

  tearDown(() {
    registry.clear();
  });

  group('FailedImageRegistry: Attempt Counting & Strict Capping', () {
    test('Initial state: Unrecorded URL has 0 attempts and is not failed', () {
      const url = 'https://example.com/card1.jpg';
      expect(registry.getAttempts(url), equals(0));
      expect(registry.isFailed(url), isFalse);
      expect(registry.isTerminal(url), isFalse);
    });

    test('Transient failures increment attempt count without immediately locking', () {
      const url = 'https://example.com/card_transient.jpg';

      // Attempt 1: 500 Server Error
      registry.recordAttempt(url, statusCode: 500, error: 'Internal Server Error');
      expect(registry.getAttempts(url), equals(1));
      expect(registry.isFailed(url), isFalse);
      expect(registry.isTerminal(url), isFalse);

      // Attempt 2: Connection Timeout
      registry.recordAttempt(url, error: 'SocketException: Connection timed out');
      expect(registry.getAttempts(url), equals(2));
      expect(registry.isFailed(url), isFalse);
      expect(registry.isTerminal(url), isFalse);
    });

    test('Strict attempt capping: Reaching maxAttempts (3) locks URL as terminal failure', () {
      const url = 'https://example.com/card_capped.jpg';

      registry.recordAttempt(url, statusCode: 503);
      registry.recordAttempt(url, statusCode: 503);
      expect(registry.isFailed(url), isFalse);

      // Attempt 3 reaches cap
      registry.recordAttempt(url, statusCode: 503);
      expect(registry.getAttempts(url), equals(3));
      expect(registry.isFailed(url), isTrue);
      expect(registry.isTerminal(url), isTrue);

      final record = registry.getRecord(url);
      expect(record, isNotNull);
      expect(record!.failureType, equals(ImageFailureType.exhaustedRetries));

      // Attempt 4 is rejected / does not destabilize count
      registry.recordAttempt(url, statusCode: 503);
      expect(registry.getAttempts(url), equals(3));
      expect(registry.isFailed(url), isTrue);
    });

    test('Configurable attempt cap: Cap of 2 locks on second attempt', () {
      registry.maxAttempts = 2;
      const url = 'https://example.com/card_cap2.jpg';

      registry.recordAttempt(url, statusCode: 502);
      expect(registry.isFailed(url), isFalse);

      registry.recordAttempt(url, statusCode: 502);
      expect(registry.getAttempts(url), equals(2));
      expect(registry.isFailed(url), isTrue);
      expect(registry.isTerminal(url), isTrue);
    });
  });

  group('FailedImageRegistry: Immediate Terminal Locking', () {
    test('HTTP 404 immediately marks record terminal on first attempt', () {
      const url = 'https://cards.scryfall.io/art_crop/missing_404.jpg';

      registry.recordAttempt(url, statusCode: 404, error: 'Not Found');
      expect(registry.getAttempts(url), greaterThanOrEqualTo(1));
      expect(registry.isFailed(url), isTrue);
      expect(registry.isTerminal(url), isTrue);

      final record = registry.getRecord(url);
      expect(record, isNotNull);
      expect(record!.failureType, equals(ImageFailureType.terminalNotFound));
      expect(record.httpStatusCode, equals(404));
    });

    test('HTTP 400, 403, 410, 422 Client Errors lock immediately as terminalClientError', () {
      final terminalCodes = [400, 403, 410, 422];

      for (final code in terminalCodes) {
        final url = 'https://example.com/error_$code.jpg';
        registry.recordAttempt(url, statusCode: code, error: 'Client Error $code');

        expect(registry.isFailed(url), isTrue, reason: 'Status $code must lock failure');
        expect(registry.isTerminal(url), isTrue, reason: 'Status $code must be terminal');
        expect(registry.getRecord(url)!.failureType, equals(ImageFailureType.terminalClientError));
      }
    });

    test('HTTP 429 (Too Many Requests) is treated as transient backoff, NOT terminal', () {
      const url = 'https://api.scryfall.com/rate_limit.jpg';

      registry.recordAttempt(url, statusCode: 429, error: 'Rate Limited');
      expect(registry.getAttempts(url), equals(1));
      expect(registry.isFailed(url), isFalse);
      expect(registry.isTerminal(url), isFalse);
      expect(registry.getRecord(url)!.failureType, equals(ImageFailureType.transientNetwork));
    });

    test('Invalid URI schemes (ftp, javascript, malformed) lock immediately as terminalInvalidUri', () {
      const invalidUrls = [
        'ftp://example.com/card.jpg',
        'javascript:void(0)',
        'data:image/bad;base64,invalid',
        'ht tp://broken-domain/art.jpg',
        '',
        '   ',
      ];

      for (final badUrl in invalidUrls) {
        registry.markTerminal(
          badUrl,
          type: ImageFailureType.terminalInvalidUri,
          reason: 'Unsupported URI scheme',
        );

        expect(registry.isFailed(badUrl), isTrue);
        expect(registry.isTerminal(badUrl), isTrue);
        expect(registry.getRecord(badUrl)!.failureType, equals(ImageFailureType.terminalInvalidUri));
      }
    });
  });

  group('FailedImageRegistry: Bidirectional Dual-Key Association', () {
    test('Linking URL and cacheKey propagates failure bidirectionally', () {
      const url = 'https://cards.scryfall.io/art/sol_ring.jpg';
      const cacheKey = 'card_art_sol-ring-001';

      registry.linkKeys(url, cacheKey);

      // Record terminal 404 against URL
      registry.recordAttempt(url, statusCode: 404);

      // Lookup by cacheKey must immediately reflect failure
      expect(registry.isFailed(cacheKey), isTrue);
      expect(registry.isTerminal(cacheKey), isTrue);
      expect(registry.getAttempts(cacheKey), equals(registry.getAttempts(url)));

      // Lookup with optional cacheKey argument must match
      expect(registry.isFailed(url, cacheKey: cacheKey), isTrue);
      expect(registry.isFailed(null, cacheKey: cacheKey), isTrue);
    });

    test('Recording attempt on cacheKey updates linked URL record', () {
      const url = 'https://cards.scryfall.io/art/edgar.jpg';
      const cacheKey = 'card_art_edgar-markov';

      registry.linkKeys(url, cacheKey);

      // Record transient failure against cacheKey
      registry.recordAttempt(cacheKey, statusCode: 500);

      // Lookup by URL reflects the attempt
      expect(registry.getAttempts(url), equals(1));
      expect(registry.getAttempts(cacheKey), equals(1));
    });

    test('Deck cover key association: deck_cover_\$deckId links with cover art URL', () {
      const url = 'https://cards.scryfall.io/art/commander.jpg';
      const deckKey = 'deck_cover_deck-vampires';

      registry.linkKeys(url, deckKey);
      registry.markTerminal(url, type: ImageFailureType.terminalNotFound, statusCode: 404);

      expect(registry.isFailed(deckKey), isTrue);
      expect(registry.isTerminal(deckKey), isTrue);
    });
  });

  group('FailedImageRegistry: Session Reset & Recovery', () {
    test('reset(url) clears failure record for both URL and linked cacheKey', () {
      const url = 'https://example.com/reset_test.jpg';
      const cacheKey = 'card_art_reset_1';

      registry.linkKeys(url, cacheKey);
      registry.recordAttempt(url, statusCode: 404);
      expect(registry.isFailed(url), isTrue);
      expect(registry.isFailed(cacheKey), isTrue);

      // User performs manual retry
      registry.reset(url, cacheKey: cacheKey);

      expect(registry.isFailed(url), isFalse);
      expect(registry.isFailed(cacheKey), isFalse);
      expect(registry.getAttempts(url), equals(0));
      expect(registry.getAttempts(cacheKey), equals(0));
    });

    test('clear() purges all records and links across application session', () {
      for (int i = 0; i < 5; i++) {
        registry.recordAttempt('https://example.com/card_$i.jpg', statusCode: 404);
      }
      expect(registry.isFailed('https://example.com/card_0.jpg'), isTrue);

      registry.clear();

      for (int i = 0; i < 5; i++) {
        expect(registry.isFailed('https://example.com/card_$i.jpg'), isFalse);
        expect(registry.getAttempts('https://example.com/card_$i.jpg'), equals(0));
      }
    });
  });
}
