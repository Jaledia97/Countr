# Project: Countr Multi-Epic Production Overhaul (R1–R8)

## Architecture
Countr is an offline-first Flutter TCG mobile application featuring:
- **Presentation Layer**: Flutter widgets with Riverpod StateNotifier / AsyncNotifier / StreamProvider state management, dark-slate & neon theme.
- **Domain Layer**: Models, DTOs, `FeedPost`, `PostComment`, `AuthUser`, `TradeProposal`, `GuestMigrationService`, `CardImageAndDataCacheResolver`.
- **Data Layer**: Drift SQLite relational database (`AppDatabase` v16) with SQLite expression indexes, reactive DAOs (`FeedDao`, `InboxDao`, `UserProfileDao`, `VaultDao`, `FriendsDao`), and background Isolates.
- **Cache & Hydration Layer**: `CardImageAndDataCacheResolver` (2-step local catalog repair -> Scryfall HTTP fallback), `CountrCachedImage`.
- **Routing & Shell**: `GoRouter` declarative router managing app shells, `/welcome` onboarding route, and deep links.

## Feature Inventory
Every feature from the Survey phase is mapped to an assigned milestone:

| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Database Schema v16 | Add tables `post_votes`, `post_reactions`, `comment_reactions`, `saved_posts`, add `parent_comment_id` to `post_comments`, and `is_wishlisted` to `vault_items` | M1 | Survey R1-R3 |
| 2 | Reactive Profile Sync in Feed & Comments | `FeedDao.watchComments` LEFT JOIN `user_profiles` on author_id; reactive refresh when user updates display name, avatar, or @username | M1 | Survey R3 |
| 3 | Atomic Notification & Friendship Sync | `InboxDao` & `FriendsDao` atomically update status to "Accepted" or "Declined", completely removing "@Request removed" | M1 | Survey R6 |
| 4 | Trade Lifecycle DAO Methods | `InboxDao.cancelTradeProposal` and `counterTradeProposal` with atomic status updates | M1 | Survey R7 |
| 5 | Unsegregated Post Creation Workflow | Post creator starts as text post, removing segregated post-type menus; action buttons `[+ Add Card]` and `[+ Add Image]` | M2 | Survey R1 |
| 6 | Automatic Dynamic Post Transformation | Post editor preview and published layout adapt automatically to single-card, multi-card grid, image, or mixed media, reverting to text when empty | M2 | Survey R1 |
| 7 | Card Details Share Sheet (`As Link` & `As Post`) | Share button opens sheet: `As Link` (via `share_plus` + Countr message targets) and `As Post` (opens Post Editor pre-attached) | M2 | Survey R1 |
| 8 | Home Page Card Click Lightbox Overlay | Tapping any card in a post opens Expanded Card View lightbox with high-res art, swipe navigation, and `[See Details]` button navigating to details | M2 | Survey R1 |
| 9 | Icons-Only Post Interaction Bar | Strip all text labels off interaction bar; icons accompanied only by compact numeric counters | M3 | Survey R2 |
| 10 | Reddit-Style Upvote/Downvote Pill | Replace Hype with `[ ↑ \| Net Score \| ↓ ]` pill; +1 neon/orange, -1 blue/purple; persistent votes in SQLite and sync | M3 | Survey R2 |
| 11 | Emoji Reactions on Posts | React Emoji icon; tap or long-press opens 5 MRU suggestions (`🔥`, `❤️`, `😂`, `🤯`, `💎`) + `+` full picker; active reaction pills above bar | M3 | Survey R2 |
| 12 | Relocate Wishlist/Save to Header Menu | Single-card: Wishlist Card (Add to Looking For); Multi-card: Wishlist Cards (multi-select drawer); Text/image: Save Post bookmark | M3 | Survey R2 |
| 13 | Command Center Saved Posts Dropdown | Top My Profile tile chevron expands downward to reveal `Saved Posts` row with count badge opening saved posts screen | M3 | Survey R2 |
| 14 | Deep Nested Reply Threads | Multi-level comments tree with vertical thread guide lines, `Reply` button, and `"Replying to @username [X]"` banner | M3 | Survey R3 |
| 15 | True Total Comment Count | Post card and comments header display true total count across all nesting depths | M3 | Survey R3 |
| 16 | Comment Emoji Reactions | React to individual comments with 5 MRU emoji bar and compact reaction pills beneath comments | M3 | Survey R3 |
| 17 | Log Out Feature | High-visibility Log Out button at bottom of Command Center and Settings, showing confirmation prompt, signOut, and routing to `/welcome` | M4 | Survey R4 |
| 18 | Complete 3-Step Onboarding Workflow | Step 1 Account Type; Step 2 Individual (Discord primary CTA + Profile Setup) vs Business (Places + 6-digit OTP); Step 3 Shell + Guest Merge | M4 | Survey R4 |
| 19 | Unified Card Details Resolution | Handle any identifier (`cards.id`, `scryfall_id`, `collection_items.id`, legacy slug `item-mtg-...`), repairing FKs/backfill with zero blank screens | M5 | Survey R5 |
| 20 | Vault Singles Header Spacing Fix | Remove hardcoded height/padding/empty SizedBox when Estimated Vault Value hidden, making search bar flush with zero dead space | M5 | Survey R5 |
| 21 | Vault Singles Live Search | Live typing executes SQLite query matching `name`, `type_line`, and `oracle_text` | M5 | Survey R5 |
| 22 | Vault Collections Set Completion Ratio | Calculate `COUNT(DISTINCT owned.card_id)` divided by master catalog total `COUNT(DISTINCT catalog.id) WHERE catalog.set_code = ?` | M5 | Survey R5 |
| 23 | 3x3 Master Set View | Display all cards from master catalog in 3x3 grid; owned in full color with quantity badge (`x2`), unowned in true grayscale with dimmed opacity | M5 | Survey R5 |
| 24 | Wishlist Badge & Filter in Vault/Binders | Cards with `isWishlisted: true` display Wishlist Badge in Vault / Binders and filter via `Wishlisted` filter pill | M5 | Survey R2/R5 |
| 25 | Friends & Groups 2-Tab Restructure | Strictly two tabs (`Friends` and `Groups`), completely removing `"Requests & Find"` tab | M6 | Survey R6 |
| 26 | Friends Tab 3-Section Layout | Top: Friend Requests (inline + See More); Middle: Searchable Friends List; Bottom: Sent Requests (inline + See More + Cancel) | M6 | Survey R6 |
| 27 | Inbox Messages Draft Compose Button | Prominent Draft New Message button on `Messages` tab opening searchable friend/user picker for 1 or up to 2 recipients | M6 | Survey R7 |
| 28 | Reactive Trade Proposal Status & Unpinning | Pinned trade banner and chat card bind directly to `trade_proposals.status`; unpin on decline/cancel/counter and display status badge | M6 | Survey R7 |
| 29 | Trade Card Plain English Name Resolution | Join trade items against `cards`/vault items to display plain English names (never raw IDs or `item-mtg-...`) | M6 | Survey R7 |
| 30 | Full Trade Negotiation Lifecycle | Cancel Trade (Proposer), Edit Trade (Proposer), Counter Trade (Recipient) with pre-loaded Trade Builder and live Trade Value Meter | M6 | Survey R7 |
| 31 | Architectural Zero-Duplicate Mandate & Clean Quality | Zero duplicate widgets, zero conflicting providers, `dart analyze` 0 issues, `flutter test` 100% passing across repository | M7 | Survey R8 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Database Schema v16 & Reactive DAOs | Features 1–4 (Tables `post_votes`, `post_reactions`, `comment_reactions`, `saved_posts`, `parent_comment_id`, `is_wishlisted`, DAO queries, atomic notifications, trade DAO methods) | None | DONE |
| 2 | M2: Unified Post Creation, Share Sheet & Card Lightbox | Features 5–8 (Text-first composer, `[+ Add Card]`, `[+ Add Image]`, dynamic transform, `share_plus` share sheet `As Link` & `As Post`, expanded card lightbox with `[See Details]`) | M1 | DONE |
| 3 | M3: Post UI Rework, Voting, Emoji Reactions & Nested Comments Tree | Features 9–16 (Icons-only interaction bar, Reddit voting pill, 5 MRU post reactions, `'⋮'` Wishlist/Save menu, Command Center Saved Posts dropdown, deep nested comments tree with thread guides, true total comment count, comment reactions, live profile sync) | M1, M2 | DONE |
| 4 | M4: Authentication, Logout & Complete Onboarding Workflow | Features 17–18 (Command Center & Settings Log Out button, confirmation dialog, session reset, 3-step onboarding wizard with Discord primary CTA, Profile Setup, Business Places + OTP, Guest Data Merge) | M1 | PLANNED |
| 5 | M5: Unified Card Details Resolution & Vault Overhaul | Features 19–24 (Identifier resolution & slug de-hyphenation, Vault Singles flush header spacing, SQLite live search on name/type/oracle, Collections set completion ratio, 3x3 Master Set grid with color/grayscale, Wishlist badge & filter) | M1 | PLANNED |
| 6 | M6: Friends & Groups Restructure, Inbox Compose & Trade Negotiation | Features 25–30 (Friends & Groups 2 tabs, Friends tab 3 sections, cross-app notification sync to "Accepted"/"Declined", Inbox compose button & user picker, reactive pinned banner unpinning, plain English card names, Cancel/Edit/Counter trade negotiation lifecycle) | M1 | PLANNED |
| 7 | M7: Full Repository Verification, Dual-Track E2E & Forensic Audit | Feature 31 (Dual-track test suite publication, `dart analyze` 0 issues, full `flutter test` 100% pass rate, Forensic Integrity Audit CLEAN verdict) | M1, M2, M3, M4, M5, M6 | PLANNED |

## Interface Contracts

### M1 Contract: Schema v16, Reactive Feeds & Inbox DAOs
- `AppDatabase.schemaVersion => 16`.
- Tables added:
  - `PostVotesTable`: `postId`, `userId`, `vote` (+1, -1, 0), timestamps.
  - `PostReactionsTable`: `postId`, `userId`, `emoji`, timestamps.
  - `CommentReactionsTable`: `commentId`, `userId`, `emoji`, timestamps.
  - `SavedPostsTable`: `postId`, `userId`, timestamps.
- Table columns added:
  - `PostCommentsTable.parentCommentId`: `TextColumn get parentCommentId => text().named('parent_comment_id').nullable()();`
  - `VaultItemsTable.isWishlisted`: `BoolColumn get isWishlisted => boolean().named('is_wishlisted').withDefault(const Constant(false))();`
- `FeedDao`:
  - `watchComments(String postId)`: `LEFT JOIN user_profiles ON post_comments.author_id = user_profiles.id`.
  - `watchCommentCount(String postId)`: counts all comments where `post_id = ?` and `is_deleted = 0`.
  - `votePost(String postId, String userId, int vote)`: upserts row in `post_votes`.
- `InboxDao`:
  - `cancelTradeProposal(String proposalId, {required String currentUserId})`: status -> `'cancelled'`.
  - `counterTradeProposal(String priorProposalId, {required String proposerId, required String receiverId, ...})`: status -> `'countered'`, creates counter-proposal.
  - `respondToFriendRequest`: updates `notifications` to `'Accepted'` or `'Declined'`.

### M2 Contract: Post Creation, Share Sheet & Card Lightbox
- `PostComposerModal`:
  - Starts as Text Post.
  - Attachment buttons: `Key('post_add_card_button')` and `Key('post_add_image_button')`.
  - Dynamic transform to single-card, multi-card, image, or mixed media.
- `CardDetailSheet` Share Sheet:
  - `As Link`: invokes `Share.share` with deep link + displays internal Countr message targets.
  - `As Post`: opens `PostComposerModal` with card pre-attached.
- `ExpandedCardViewModal`:
  - Opened on card tap in Feed. Displays high-res art, PageView for multi-card posts, and `[See Details]` (`Key('expanded_card_see_details_button')`).

### M3 Contract: Post UI, Voting, Reactions, Menu & Comments Tree
- `PostActionBar`:
  - Icons-only, no string labels.
  - Reddit voting pill: `[ ↑ | Net Score | ↓ ]` (`Key('post_upvote_button')`, `Key('post_net_score_text')`, `Key('post_downvote_button')`).
  - React Emoji icon: `Key('post_action_react_button')`. 5 MRU suggestions floating bar + pills above bar.
- `PostHeader` Menu:
  - `Key('post_header_overflow_menu')`:
    - Single card: `Wishlist Card (Add to Looking For)`.
    - Multi-card: `Wishlist Cards` opening slide-up drawer.
    - Text/image: `Save Post`.
- `MorphingCommandCenter`:
  - Downward chevron on top My Profile tile expands `Saved Posts` row (`Key('command_center_saved_posts_tile')`).
- `PostCommentsSheet`:
  - Tree rendering with indentation and thread guides.
  - `Reply` button on each comment item (`Key('comment_reply_button_$id')`).
  - Input header banner: `"Replying to @username [X]"`.
  - 5 MRU comment reactions bar & pills.

### M4 Contract: Auth, Logout & Onboarding
- `Log Out` button: `Key('command_center_logout_button')` and `Key('app_settings_logout_button')`.
- `LogoutConfirmationDialog`: options to keep local guest data vs dev/test reset, executes `authRepository.signOut()`, routes to `/welcome`.
- `/welcome` route: `OnboardingWelcomeScreen` 3-step wizard:
  - Step 1: Account Type selection.
  - Step 2: Individual Auth (Discord primary CTA `#5865F2` + Profile Setup) vs Business (Places + OTP).
  - Step 3: Shell transition + `GuestMigrationService.migrateGuestData()`.

### M5 Contract: Card Details Resolution & Vault Overhaul
- `CardImageAndDataCacheResolver` & `VaultDao.findCatalogCard`:
  - Resolves any ID (`cards.id`, `scryfall_id`, `collection_items.id`, legacy slug `item-mtg-...` stripped to title case).
  - Zero blank screens on card details.
- `VaultScreen`:
  - When Estimated Vault Value is hidden, collapse header delegate to 0dp extent and set flush padding (zero dead space).
  - Live typing in search filters `name`, `type_line`, and `oracle_text`.
  - Wishlisted cards display Wishlist Badge and filter via `Wishlisted` filter pill.
- `VaultDao.watchSetCollectionsFull`:
  - Completion ratio = unique owned cards / master catalog set total.
- `MasterSetScreen`:
  - 3x3 grid (`crossAxisCount: 3`). Owned cards in full color with `'x$quantity'` badge. Unowned cards in true grayscale with dimmed opacity.

### M6 Contract: Friends & Groups, Notifications & Trade Negotiation
- `FriendsHubScreen`: strictly 2 tabs (`Friends` and `Groups`).
  - `Friends` tab: Top (Friend Requests 2-3 inline + See More), Middle (Searchable Friends List), Bottom (Sent Requests 2-3 inline + See More + Cancel).
- Notification status text: strictly `"Accepted"` or `"Declined"` (zero occurrences of `"Request removed"`).
- `InboxHubScreen`: Draft New Message button (`Key('inbox_compose_button')`) opening searchable user picker.
- `ChatConversationScreen`:
  - `_ActiveTradeProposalBanner` unpins immediately when status is `'declined'`, `'cancelled'`, or `'countered'`.
  - Displays plain English card names.
  - Proposer buttons: `[Cancel Trade]` and `[Edit Trade]`.
  - Recipient button: `[Counter Trade]`.
- `TradeScreen`: preloads existing proposal in Counter/Edit mode with live Trade Value Meter.

## Code Layout
- `lib/core/database/`:
  - `app_database.dart`: schema version 16, migrations.
  - `tables/social/`: `post_votes_table.dart`, `post_reactions_table.dart`, `comment_reactions_table.dart`, `saved_posts_table.dart`, `post_comments_table.dart`.
  - `tables/vault/`: `vault_items_table.dart` (`isWishlisted`).
- `lib/features/feed/`:
  - `data/daos/feed_dao.dart`: joined comments query, total comment count, voting, reactions, saving.
  - `data/daos/inbox_dao.dart`: trade proposal lifecycle, atomic notification updates.
  - `presentation/widgets/post_composer_modal.dart`: unified post creation.
  - `presentation/widgets/post_card.dart`, `post_header.dart`, `post_action_bar.dart`: icons-only bar, Reddit pill, reactions, wishlist menu.
  - `presentation/widgets/post_comments_sheet.dart`: nested comments tree, reply banner, reactions.
  - `presentation/screens/friends_hub_screen.dart`: 2-tab restructure, 3-section layout.
  - `presentation/screens/inbox_hub_screen.dart`: compose button, notifications without "Request removed".
  - `presentation/screens/chat_conversation_screen.dart`: reactive trade banner unpinning, plain English names, cancel/edit/counter buttons.
- `lib/features/vault/`:
  - `presentation/widgets/card_detail_sheet.dart`: share sheet `As Link` & `As Post`, identifier normalization.
  - `presentation/widgets/expanded_card_view_modal.dart`: feed card lightbox overlay.
  - `presentation/screens/vault_screen.dart`: zero dead space header, live SQLite search on name/type/oracle.
  - `presentation/screens/master_set_screen.dart`: 3x3 grid, color vs grayscale.
- `lib/features/auth/`:
  - `presentation/screens/onboarding_welcome_screen.dart`: 3-step onboarding wizard.
  - `presentation/widgets/logout_confirmation_dialog.dart`: logout prompt with guest data options.
- `lib/features/command_center/`:
  - `presentation/widgets/morphing_command_center.dart`: logout button, saved posts dropdown.
- `lib/features/trades/`:
  - `presentation/screens/trade_screen.dart`: preloaded counter/edit offer with Trade Value Meter.
- `test/`:
  - Comprehensive unit, widget, and E2E test suites for all 8 requirements.
