import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scalable Riverpod StateProvider for the Active Game Context.
/// Defaults to 'Magic: The Gathering'.
final activeGameContextProvider = StateProvider<String>((ref) {
  return 'Magic: The Gathering';
});

/// Global user persona viewing mode for Countr.
/// - [investor]: Prioritizes live market valuation, acquisition cost basis, and financial deltas.
/// - [player]: Prioritizes in-game utility mechanics (Mana Value/Cost, P/T, Keyword badges).
enum UserPersona {
  investor,
  player,
}

/// Global Riverpod StateProvider for active user persona.
/// Defaults to [UserPersona.investor].
final userPersonaProvider = StateProvider<UserPersona>((ref) {
  return UserPersona.investor;
});

/// Global Riverpod StateProvider tracking user authentication status.
/// Defaults to false.
final isUserLoggedInProvider = StateProvider<bool>((ref) {
  return false;
});
