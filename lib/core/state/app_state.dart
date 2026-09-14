import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scalable Riverpod StateProvider for the Active Game Context.
/// Defaults to 'Magic: The Gathering'.
final activeGameContextProvider = StateProvider<String>((ref) {
  return 'Magic: The Gathering';
});
