/// Filter mode for cards displayed in the Trade Proposal Builder card selection sheet.
enum TradeCardSourceFilter {
  /// Strictly cards assigned to the user's active system trade binder.
  tradeBinder,

  /// Owned inventory cards not assigned to the system trade binder.
  collection,

  /// All owned cards (trade binder + general collection).
  both,
}
