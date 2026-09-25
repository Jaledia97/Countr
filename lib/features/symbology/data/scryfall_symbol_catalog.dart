// Generated MTG Scryfall Symbol Catalog for Countr.
// Source: https://api.scryfall.com/symbology
// Exactly 84 official canonical symbols + comprehensive transposable alias map.

/// Represents an official MTG card symbol from Scryfall's Symbology API.
class ScryfallSymbol {
  /// The canonical bracketed symbol notation (e.g. `{W/U}`, `{P/B}`, `{2}`).
  final String symbol;

  /// The SVG asset filename (e.g. `WU.svg`, `BP.svg`).
  final String filename;

  /// Human-readable English description (e.g. `one white or blue mana`).
  final String english;

  /// The converted mana value / CMC. `null` for `{∞}`.
  final double? manaValue;

  /// Whether the symbol represents hybrid mana.
  final bool isHybrid;

  /// Whether the symbol is Phyrexian mana (payable with life).
  final bool isPhyrexian;

  /// MTG color codes represented by this symbol.
  final List<String> colors;

  /// Whether this symbol represents mana (false for `{T}`, `{Q}`, `{E}`, `{P}`, etc.).
  final bool representsMana;

  /// Whether this symbol appears in standard mana costs.
  final bool appearsInManaCosts;

  /// Whether this symbol belongs to Un-sets, playtest cards, or joke mechanics.
  final bool isFunny;

  /// Whether components can appear in transposed order (e.g. `{W/U}` vs `{U/W}`).
  final bool isTransposable;

  const ScryfallSymbol({
    required this.symbol,
    required this.filename,
    required this.english,
    this.manaValue,
    this.isHybrid = false,
    this.isPhyrexian = false,
    this.colors = const [],
    this.representsMana = true,
    this.appearsInManaCosts = true,
    this.isFunny = false,
    this.isTransposable = false,
  });

  /// Flutter asset bundle path for this symbol.
  String get assetPath => 'assets/symbology/$filename';

  /// The unbracketed code (e.g. `W/U`, `2`, `BP`).
  String get cleanCode => symbol.replaceAll('{', '').replaceAll('}', '');

  /// Whether this symbol represents colorless mana.
  bool get isColorless => colors.isEmpty && representsMana;

  /// Whether this symbol represents exactly one color.
  bool get isMonoColored => colors.length == 1;

  /// Whether this symbol represents multiple colors.
  bool get isMultiColored => colors.length > 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScryfallSymbol &&
          runtimeType == other.runtimeType &&
          symbol == other.symbol;

  @override
  int get hashCode => symbol.hashCode;

  @override
  String toString() => 'ScryfallSymbol($symbol -> $filename)';
}

/// Static catalog providing compile-time lookup and resolution for MTG symbols.
abstract final class ScryfallSymbolCatalog {
  /// Base directory for local vector symbology assets.
  static const String assetDirectory = 'assets/symbology';
  static const String assetPrefix = 'assets/symbology/';

  /// Regex pattern matching any bracketed symbol expression (e.g. `{2}`, `{W/U}`).
  static final RegExp _bracketPattern = RegExp(r'\{([^\{}]+)\}');

  /// All 84 canonical symbols indexed by their official bracketed representation (e.g. `{W/U}`).
  static const Map<String, ScryfallSymbol> symbols = {
    '{T}': ScryfallSymbol(
      symbol: '{T}',
      filename: 'T.svg',
      english: 'tap this permanent',
      manaValue: 0.0,
      representsMana: false,
      appearsInManaCosts: false,
    ),
    '{Q}': ScryfallSymbol(
      symbol: '{Q}',
      filename: 'Q.svg',
      english: 'untap this permanent',
      manaValue: 0.0,
      representsMana: false,
      appearsInManaCosts: false,
    ),
    '{E}': ScryfallSymbol(
      symbol: '{E}',
      filename: 'E.svg',
      english: 'an energy counter',
      manaValue: 0.0,
      representsMana: false,
      appearsInManaCosts: false,
    ),
    '{P}': ScryfallSymbol(
      symbol: '{P}',
      filename: 'P.svg',
      english: 'modal budget pawprint',
      manaValue: 0.0,
      representsMana: false,
      appearsInManaCosts: false,
    ),
    '{PW}': ScryfallSymbol(
      symbol: '{PW}',
      filename: 'PW.svg',
      english: 'planeswalker',
      manaValue: 0.0,
      representsMana: false,
      appearsInManaCosts: false,
    ),
    '{CHAOS}': ScryfallSymbol(
      symbol: '{CHAOS}',
      filename: 'CHAOS.svg',
      english: 'chaos',
      manaValue: 0.0,
      representsMana: false,
      appearsInManaCosts: false,
    ),
    '{A}': ScryfallSymbol(
      symbol: '{A}',
      filename: 'A.svg',
      english: 'an acorn counter',
      manaValue: 0.0,
      representsMana: false,
      appearsInManaCosts: false,
      isFunny: true,
    ),
    '{TK}': ScryfallSymbol(
      symbol: '{TK}',
      filename: 'TK.svg',
      english: 'a ticket counter',
      manaValue: 0.0,
      representsMana: false,
      appearsInManaCosts: false,
    ),
    '{X}': ScryfallSymbol(
      symbol: '{X}',
      filename: 'X.svg',
      english: 'X generic mana',
      manaValue: 0.0,
    ),
    '{Y}': ScryfallSymbol(
      symbol: '{Y}',
      filename: 'Y.svg',
      english: 'Y generic mana',
      manaValue: 0.0,
      isFunny: true,
    ),
    '{Z}': ScryfallSymbol(
      symbol: '{Z}',
      filename: 'Z.svg',
      english: 'Z generic mana',
      manaValue: 0.0,
      isFunny: true,
    ),
    '{0}': ScryfallSymbol(
      symbol: '{0}',
      filename: '0.svg',
      english: 'zero mana',
      manaValue: 0.0,
    ),
    '{½}': ScryfallSymbol(
      symbol: '{½}',
      filename: 'HALF.svg',
      english: 'one-half generic mana',
      manaValue: 0.5,
      appearsInManaCosts: false,
      isFunny: true,
    ),
    '{1}': ScryfallSymbol(
      symbol: '{1}',
      filename: '1.svg',
      english: 'one generic mana',
      manaValue: 1.0,
    ),
    '{2}': ScryfallSymbol(
      symbol: '{2}',
      filename: '2.svg',
      english: 'two generic mana',
      manaValue: 2.0,
    ),
    '{3}': ScryfallSymbol(
      symbol: '{3}',
      filename: '3.svg',
      english: 'three generic mana',
      manaValue: 3.0,
    ),
    '{4}': ScryfallSymbol(
      symbol: '{4}',
      filename: '4.svg',
      english: 'four generic mana',
      manaValue: 4.0,
    ),
    '{5}': ScryfallSymbol(
      symbol: '{5}',
      filename: '5.svg',
      english: 'five generic mana',
      manaValue: 5.0,
    ),
    '{6}': ScryfallSymbol(
      symbol: '{6}',
      filename: '6.svg',
      english: 'six generic mana',
      manaValue: 6.0,
    ),
    '{7}': ScryfallSymbol(
      symbol: '{7}',
      filename: '7.svg',
      english: 'seven generic mana',
      manaValue: 7.0,
    ),
    '{8}': ScryfallSymbol(
      symbol: '{8}',
      filename: '8.svg',
      english: 'eight generic mana',
      manaValue: 8.0,
    ),
    '{9}': ScryfallSymbol(
      symbol: '{9}',
      filename: '9.svg',
      english: 'nine generic mana',
      manaValue: 9.0,
    ),
    '{10}': ScryfallSymbol(
      symbol: '{10}',
      filename: '10.svg',
      english: 'ten generic mana',
      manaValue: 10.0,
    ),
    '{11}': ScryfallSymbol(
      symbol: '{11}',
      filename: '11.svg',
      english: 'eleven generic mana',
      manaValue: 11.0,
    ),
    '{12}': ScryfallSymbol(
      symbol: '{12}',
      filename: '12.svg',
      english: 'twelve generic mana',
      manaValue: 12.0,
    ),
    '{13}': ScryfallSymbol(
      symbol: '{13}',
      filename: '13.svg',
      english: 'thirteen generic mana',
      manaValue: 13.0,
    ),
    '{14}': ScryfallSymbol(
      symbol: '{14}',
      filename: '14.svg',
      english: 'fourteen generic mana',
      manaValue: 14.0,
    ),
    '{15}': ScryfallSymbol(
      symbol: '{15}',
      filename: '15.svg',
      english: 'fifteen generic mana',
      manaValue: 15.0,
    ),
    '{16}': ScryfallSymbol(
      symbol: '{16}',
      filename: '16.svg',
      english: 'sixteen generic mana',
      manaValue: 16.0,
    ),
    '{17}': ScryfallSymbol(
      symbol: '{17}',
      filename: '17.svg',
      english: 'seventeen generic mana',
      manaValue: 17.0,
      appearsInManaCosts: false,
    ),
    '{18}': ScryfallSymbol(
      symbol: '{18}',
      filename: '18.svg',
      english: 'eighteen generic mana',
      manaValue: 18.0,
      appearsInManaCosts: false,
    ),
    '{19}': ScryfallSymbol(
      symbol: '{19}',
      filename: '19.svg',
      english: 'nineteen generic mana',
      manaValue: 19.0,
      appearsInManaCosts: false,
    ),
    '{20}': ScryfallSymbol(
      symbol: '{20}',
      filename: '20.svg',
      english: 'twenty generic mana',
      manaValue: 20.0,
      appearsInManaCosts: false,
    ),
    '{100}': ScryfallSymbol(
      symbol: '{100}',
      filename: '100.svg',
      english: 'one hundred generic mana',
      manaValue: 100.0,
      appearsInManaCosts: false,
      isFunny: true,
    ),
    '{1000000}': ScryfallSymbol(
      symbol: '{1000000}',
      filename: '1000000.svg',
      english: 'one million generic mana',
      manaValue: 1000000.0,
      isFunny: true,
    ),
    '{∞}': ScryfallSymbol(
      symbol: '{∞}',
      filename: 'INFINITY.svg',
      english: 'infinite generic mana',
      appearsInManaCosts: false,
      isFunny: true,
    ),
    '{W/U}': ScryfallSymbol(
      symbol: '{W/U}',
      filename: 'WU.svg',
      english: 'one white or blue mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['W', 'U'],
      isTransposable: true,
    ),
    '{W/B}': ScryfallSymbol(
      symbol: '{W/B}',
      filename: 'WB.svg',
      english: 'one white or black mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['W', 'B'],
      isTransposable: true,
    ),
    '{B/R}': ScryfallSymbol(
      symbol: '{B/R}',
      filename: 'BR.svg',
      english: 'one black or red mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['B', 'R'],
      isTransposable: true,
    ),
    '{B/G}': ScryfallSymbol(
      symbol: '{B/G}',
      filename: 'BG.svg',
      english: 'one black or green mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['B', 'G'],
      isTransposable: true,
    ),
    '{U/B}': ScryfallSymbol(
      symbol: '{U/B}',
      filename: 'UB.svg',
      english: 'one blue or black mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['U', 'B'],
      isTransposable: true,
    ),
    '{U/R}': ScryfallSymbol(
      symbol: '{U/R}',
      filename: 'UR.svg',
      english: 'one blue or red mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['U', 'R'],
      isTransposable: true,
    ),
    '{R/G}': ScryfallSymbol(
      symbol: '{R/G}',
      filename: 'RG.svg',
      english: 'one red or green mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['R', 'G'],
      isTransposable: true,
    ),
    '{R/W}': ScryfallSymbol(
      symbol: '{R/W}',
      filename: 'RW.svg',
      english: 'one red or white mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['W', 'R'],
      isTransposable: true,
    ),
    '{G/W}': ScryfallSymbol(
      symbol: '{G/W}',
      filename: 'GW.svg',
      english: 'one green or white mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['W', 'G'],
      isTransposable: true,
    ),
    '{G/U}': ScryfallSymbol(
      symbol: '{G/U}',
      filename: 'GU.svg',
      english: 'one green or blue mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['U', 'G'],
      isTransposable: true,
    ),
    '{B/G/P}': ScryfallSymbol(
      symbol: '{B/G/P}',
      filename: 'BGP.svg',
      english: 'one black mana, one green mana, or 2 life',
      manaValue: 1.0,
      isHybrid: true,
      isPhyrexian: true,
      colors: ['B', 'G'],
      appearsInManaCosts: false,
      isTransposable: true,
    ),
    '{B/R/P}': ScryfallSymbol(
      symbol: '{B/R/P}',
      filename: 'BRP.svg',
      english: 'one black mana, one red mana, or 2 life',
      manaValue: 1.0,
      isHybrid: true,
      isPhyrexian: true,
      colors: ['B', 'R'],
      appearsInManaCosts: false,
      isTransposable: true,
    ),
    '{G/U/P}': ScryfallSymbol(
      symbol: '{G/U/P}',
      filename: 'GUP.svg',
      english: 'one green mana, one blue mana, or 2 life',
      manaValue: 1.0,
      isHybrid: true,
      isPhyrexian: true,
      colors: ['U', 'G'],
      isTransposable: true,
    ),
    '{G/W/P}': ScryfallSymbol(
      symbol: '{G/W/P}',
      filename: 'GWP.svg',
      english: 'one green mana, one white mana, or 2 life',
      manaValue: 1.0,
      isHybrid: true,
      isPhyrexian: true,
      colors: ['W', 'G'],
      isTransposable: true,
    ),
    '{R/G/P}': ScryfallSymbol(
      symbol: '{R/G/P}',
      filename: 'RGP.svg',
      english: 'one red mana, one green mana, or 2 life',
      manaValue: 1.0,
      isHybrid: true,
      isPhyrexian: true,
      colors: ['R', 'G'],
      appearsInManaCosts: false,
      isTransposable: true,
    ),
    '{R/W/P}': ScryfallSymbol(
      symbol: '{R/W/P}',
      filename: 'RWP.svg',
      english: 'one red mana, one white mana, or 2 life',
      manaValue: 1.0,
      isHybrid: true,
      isPhyrexian: true,
      colors: ['W', 'R'],
      appearsInManaCosts: false,
      isTransposable: true,
    ),
    '{U/B/P}': ScryfallSymbol(
      symbol: '{U/B/P}',
      filename: 'UBP.svg',
      english: 'one blue mana, one black mana, or 2 life',
      manaValue: 1.0,
      isHybrid: true,
      isPhyrexian: true,
      colors: ['U', 'B'],
      appearsInManaCosts: false,
      isTransposable: true,
    ),
    '{U/R/P}': ScryfallSymbol(
      symbol: '{U/R/P}',
      filename: 'URP.svg',
      english: 'one blue mana, one red mana, or 2 life',
      manaValue: 1.0,
      isHybrid: true,
      isPhyrexian: true,
      colors: ['U', 'R'],
      appearsInManaCosts: false,
      isTransposable: true,
    ),
    '{W/B/P}': ScryfallSymbol(
      symbol: '{W/B/P}',
      filename: 'WBP.svg',
      english: 'one white mana, one black mana, or 2 life',
      manaValue: 1.0,
      isHybrid: true,
      isPhyrexian: true,
      colors: ['W', 'B'],
      appearsInManaCosts: false,
      isTransposable: true,
    ),
    '{W/U/P}': ScryfallSymbol(
      symbol: '{W/U/P}',
      filename: 'WUP.svg',
      english: 'one white mana, one blue mana, or 2 life',
      manaValue: 1.0,
      isHybrid: true,
      isPhyrexian: true,
      colors: ['W', 'U'],
      appearsInManaCosts: false,
      isTransposable: true,
    ),
    '{C/W}': ScryfallSymbol(
      symbol: '{C/W}',
      filename: 'CW.svg',
      english: 'one colorless mana or one white mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['W'],
      isTransposable: true,
    ),
    '{C/U}': ScryfallSymbol(
      symbol: '{C/U}',
      filename: 'CU.svg',
      english: 'one colorless mana or one blue mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['U'],
      isTransposable: true,
    ),
    '{C/B}': ScryfallSymbol(
      symbol: '{C/B}',
      filename: 'CB.svg',
      english: 'one colorless mana or one black mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['B'],
      isTransposable: true,
    ),
    '{C/R}': ScryfallSymbol(
      symbol: '{C/R}',
      filename: 'CR.svg',
      english: 'one colorless mana or one red mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['R'],
      isTransposable: true,
    ),
    '{C/G}': ScryfallSymbol(
      symbol: '{C/G}',
      filename: 'CG.svg',
      english: 'one colorless mana or one green mana',
      manaValue: 1.0,
      isHybrid: true,
      colors: ['G'],
      isTransposable: true,
    ),
    '{2/W}': ScryfallSymbol(
      symbol: '{2/W}',
      filename: '2W.svg',
      english: 'two generic mana or one white mana',
      manaValue: 2.0,
      isHybrid: true,
      colors: ['W'],
      isTransposable: true,
    ),
    '{2/U}': ScryfallSymbol(
      symbol: '{2/U}',
      filename: '2U.svg',
      english: 'two generic mana or one blue mana',
      manaValue: 2.0,
      isHybrid: true,
      colors: ['U'],
      isTransposable: true,
    ),
    '{2/B}': ScryfallSymbol(
      symbol: '{2/B}',
      filename: '2B.svg',
      english: 'two generic mana or one black mana',
      manaValue: 2.0,
      isHybrid: true,
      colors: ['B'],
      isTransposable: true,
    ),
    '{2/R}': ScryfallSymbol(
      symbol: '{2/R}',
      filename: '2R.svg',
      english: 'two generic mana or one red mana',
      manaValue: 2.0,
      isHybrid: true,
      colors: ['R'],
      isTransposable: true,
    ),
    '{2/G}': ScryfallSymbol(
      symbol: '{2/G}',
      filename: '2G.svg',
      english: 'two generic mana or one green mana',
      manaValue: 2.0,
      isHybrid: true,
      colors: ['G'],
      isTransposable: true,
    ),
    '{H}': ScryfallSymbol(
      symbol: '{H}',
      filename: 'H.svg',
      english: 'one colored mana or two life',
      manaValue: 1.0,
      isPhyrexian: true,
      appearsInManaCosts: false,
    ),
    '{W/P}': ScryfallSymbol(
      symbol: '{W/P}',
      filename: 'WP.svg',
      english: 'one white mana or two life',
      manaValue: 1.0,
      isPhyrexian: true,
      colors: ['W'],
      isTransposable: true,
    ),
    '{U/P}': ScryfallSymbol(
      symbol: '{U/P}',
      filename: 'UP.svg',
      english: 'one blue mana or two life',
      manaValue: 1.0,
      isPhyrexian: true,
      colors: ['U'],
      isTransposable: true,
    ),
    '{B/P}': ScryfallSymbol(
      symbol: '{B/P}',
      filename: 'BP.svg',
      english: 'one black mana or two life',
      manaValue: 1.0,
      isPhyrexian: true,
      colors: ['B'],
      isTransposable: true,
    ),
    '{R/P}': ScryfallSymbol(
      symbol: '{R/P}',
      filename: 'RP.svg',
      english: 'one red mana or two life',
      manaValue: 1.0,
      isPhyrexian: true,
      colors: ['R'],
      isTransposable: true,
    ),
    '{G/P}': ScryfallSymbol(
      symbol: '{G/P}',
      filename: 'GP.svg',
      english: 'one green mana or two life',
      manaValue: 1.0,
      isPhyrexian: true,
      colors: ['G'],
      isTransposable: true,
    ),
    '{C/P}': ScryfallSymbol(
      symbol: '{C/P}',
      filename: 'CP.svg',
      english: 'one colorless mana or two life',
      manaValue: 1.0,
      isPhyrexian: true,
      isFunny: true,
      isTransposable: true,
    ),
    '{HW}': ScryfallSymbol(
      symbol: '{HW}',
      filename: 'HW.svg',
      english: 'one-half white mana',
      manaValue: 0.5,
      colors: ['W'],
      isFunny: true,
      isTransposable: true,
    ),
    '{HR}': ScryfallSymbol(
      symbol: '{HR}',
      filename: 'HR.svg',
      english: 'one-half red mana',
      manaValue: 0.5,
      colors: ['R'],
      appearsInManaCosts: false,
      isFunny: true,
      isTransposable: true,
    ),
    '{W}': ScryfallSymbol(
      symbol: '{W}',
      filename: 'W.svg',
      english: 'one white mana',
      manaValue: 1.0,
      colors: ['W'],
    ),
    '{U}': ScryfallSymbol(
      symbol: '{U}',
      filename: 'U.svg',
      english: 'one blue mana',
      manaValue: 1.0,
      colors: ['U'],
    ),
    '{B}': ScryfallSymbol(
      symbol: '{B}',
      filename: 'B.svg',
      english: 'one black mana',
      manaValue: 1.0,
      colors: ['B'],
    ),
    '{R}': ScryfallSymbol(
      symbol: '{R}',
      filename: 'R.svg',
      english: 'one red mana',
      manaValue: 1.0,
      colors: ['R'],
    ),
    '{G}': ScryfallSymbol(
      symbol: '{G}',
      filename: 'G.svg',
      english: 'one green mana',
      manaValue: 1.0,
      colors: ['G'],
    ),
    '{C}': ScryfallSymbol(
      symbol: '{C}',
      filename: 'C.svg',
      english: 'one colorless mana',
      manaValue: 1.0,
    ),
    '{S}': ScryfallSymbol(
      symbol: '{S}',
      filename: 'S.svg',
      english: 'one snow mana',
      manaValue: 1.0,
    ),
    '{L}': ScryfallSymbol(
      symbol: '{L}',
      filename: 'L.svg',
      english: 'one mana from a legendary source',
      manaValue: 1.0,
      isFunny: true,
    ),
    '{D}': ScryfallSymbol(
      symbol: '{D}',
      filename: 'D.svg',
      english: 'one potential land drop',
      manaValue: 0.0,
      representsMana: false,
      isFunny: true,
    ),
  };

  /// Alias for [symbols] to provide compatibility across modules and tests.
  static const Map<String, ScryfallSymbol> allSymbols = symbols;

  /// Comprehensive compile-time alias lookup map linking transposed notations,
  /// filename stems, and text variations to their canonical bracketed key in [symbols].
  static const Map<String, String> _aliases = {
    '2B': '{2/B}',
    '2G': '{2/G}',
    '2R': '{2/R}',
    '2U': '{2/U}',
    '2W': '{2/W}',
    'B/2': '{2/B}',
    'B/C': '{C/B}',
    'B/P/G': '{B/G/P}',
    'B/P/R': '{B/R/P}',
    'B/P/U': '{U/B/P}',
    'B/P/W': '{W/B/P}',
    'B/U': '{U/B}',
    'B/U/P': '{U/B/P}',
    'B/W': '{W/B}',
    'B/W/P': '{W/B/P}',
    'BG': '{B/G}',
    'BGP': '{B/G/P}',
    'BP': '{B/P}',
    'BR': '{B/R}',
    'BRP': '{B/R/P}',
    'CB': '{C/B}',
    'CG': '{C/G}',
    'CP': '{C/P}',
    'CR': '{C/R}',
    'CU': '{C/U}',
    'CW': '{C/W}',
    'G/2': '{2/G}',
    'G/B': '{B/G}',
    'G/B/P': '{B/G/P}',
    'G/C': '{C/G}',
    'G/P/B': '{B/G/P}',
    'G/P/R': '{R/G/P}',
    'G/P/U': '{G/U/P}',
    'G/P/W': '{G/W/P}',
    'G/R': '{R/G}',
    'G/R/P': '{R/G/P}',
    'GP': '{G/P}',
    'GU': '{G/U}',
    'GUP': '{G/U/P}',
    'GW': '{G/W}',
    'GWP': '{G/W/P}',
    'HALF': '{½}',
    'INFINITY': '{∞}',
    'P/B': '{B/P}',
    'P/B/G': '{B/G/P}',
    'P/B/R': '{B/R/P}',
    'P/B/U': '{U/B/P}',
    'P/B/W': '{W/B/P}',
    'P/C': '{C/P}',
    'P/G': '{G/P}',
    'P/G/B': '{B/G/P}',
    'P/G/R': '{R/G/P}',
    'P/G/U': '{G/U/P}',
    'P/G/W': '{G/W/P}',
    'P/R': '{R/P}',
    'P/R/B': '{B/R/P}',
    'P/R/G': '{R/G/P}',
    'P/R/U': '{U/R/P}',
    'P/R/W': '{R/W/P}',
    'P/U': '{U/P}',
    'P/U/B': '{U/B/P}',
    'P/U/G': '{G/U/P}',
    'P/U/R': '{U/R/P}',
    'P/U/W': '{W/U/P}',
    'P/W': '{W/P}',
    'P/W/B': '{W/B/P}',
    'P/W/G': '{G/W/P}',
    'P/W/R': '{R/W/P}',
    'P/W/U': '{W/U/P}',
    'R/2': '{2/R}',
    'R/B': '{B/R}',
    'R/B/P': '{B/R/P}',
    'R/C': '{C/R}',
    'R/P/B': '{B/R/P}',
    'R/P/G': '{R/G/P}',
    'R/P/U': '{U/R/P}',
    'R/P/W': '{R/W/P}',
    'R/U': '{U/R}',
    'R/U/P': '{U/R/P}',
    'RG': '{R/G}',
    'RGP': '{R/G/P}',
    'RP': '{R/P}',
    'RW': '{R/W}',
    'RWP': '{R/W/P}',
    'U/2': '{2/U}',
    'U/C': '{C/U}',
    'U/G': '{G/U}',
    'U/G/P': '{G/U/P}',
    'U/P/B': '{U/B/P}',
    'U/P/G': '{G/U/P}',
    'U/P/R': '{U/R/P}',
    'U/P/W': '{W/U/P}',
    'U/W': '{W/U}',
    'U/W/P': '{W/U/P}',
    'UB': '{U/B}',
    'UBP': '{U/B/P}',
    'UP': '{U/P}',
    'UR': '{U/R}',
    'URP': '{U/R/P}',
    'W/2': '{2/W}',
    'W/C': '{C/W}',
    'W/G': '{G/W}',
    'W/G/P': '{G/W/P}',
    'W/P/B': '{W/B/P}',
    'W/P/G': '{G/W/P}',
    'W/P/R': '{R/W/P}',
    'W/P/U': '{W/U/P}',
    'W/R': '{R/W}',
    'W/R/P': '{R/W/P}',
    'WB': '{W/B}',
    'WBP': '{W/B/P}',
    'WP': '{W/P}',
    'WU': '{W/U}',
    'WUP': '{W/U/P}',
  };

  /// Normalizes a raw symbol input string:
  /// - Trims leading and trailing whitespace
  /// - Strips file extensions like `.SVG` or `.svg`
  /// - Strips surrounding `{` and `}` braces if both are present
  /// - Converts to uppercase
  static String _normalize(String rawCode) {
    if (rawCode.isEmpty) return '';
    var code = rawCode.trim().toUpperCase();
    if (code.endsWith('.SVG')) {
      code = code.substring(0, code.length - 4);
    }
    if (code.startsWith('{') && code.endsWith('}') && code.length >= 2) {
      code = code.substring(1, code.length - 1).trim();
    }
    return code;
  }

  /// Finds the [ScryfallSymbol] model matching [rawCode].
  ///
  /// Accepts bracketed (`{W/U}`), unbracketed (`W/U`), transposed (`{P/B}`),
  /// lowercase (`w/u`), or filename (`WU.svg`) representations.
  ///
  /// Returns `null` if the token is not a recognized MTG symbol (never throws).
  static ScryfallSymbol? findBySymbol(String rawCode) {
    final clean = _normalize(rawCode);
    if (clean.isEmpty) return null;

    // 1. Direct canonical lookup
    final bracketed = '{$clean}';
    final canonical = symbols[bracketed];
    if (canonical != null) return canonical;

    // 2. Transposed alias or filename stem lookup
    final targetKey = _aliases[clean];
    if (targetKey != null) {
      return symbols[targetKey];
    }

    return null;
  }

  /// Checks if [rawCode] corresponds to a valid recognized symbol or alias.
  static bool isValidSymbol(String rawCode) {
    return findBySymbol(rawCode) != null;
  }

  /// Resolves the Flutter asset bundle path for [rawCode] (e.g. `assets/symbology/WU.svg`).
  ///
  /// Returns `null` if [rawCode] is unrecognized or empty. Never throws.
  static String? resolveAssetPath(String rawCode) {
    return findBySymbol(rawCode)?.assetPath;
  }

  /// Resolves the SVG filename for [rawCode] (e.g. `WU.svg`).
  ///
  /// Returns `null` if [rawCode] is unrecognized or empty. Never throws.
  static String? resolveFilename(String rawCode) {
    return findBySymbol(rawCode)?.filename;
  }

  /// Extracts individual symbol codes from a mana cost string.
  ///
  /// Example:
  /// ```dart
  /// extractSymbols("{2}{U}{B}") // => ["2", "U", "B"]
  /// extractSymbols("{W/U}{G}")   // => ["W/U", "G"]
  /// extractSymbols("{P/B}")       // => ["P/B"]
  /// ```
  ///
  /// If [validate] is true (default), unrecognized tokens (e.g. `{NotASymbol}`)
  /// are filtered out. If false, all bracketed contents are returned.
  ///
  /// Also safely handles single unbracketed symbols (e.g. `W` -> `["W"]`).
  static List<String> extractSymbols(String manaCost, {bool validate = true}) {
    if (manaCost.isEmpty) return const [];

    // Handle single unbracketed valid symbol input
    if (!manaCost.contains('{')) {
      final trimmed = manaCost.trim();
      if (!validate || isValidSymbol(trimmed)) {
        return [trimmed];
      }
      return const [];
    }

    final matches = _bracketPattern.allMatches(manaCost);
    final results = <String>[];
    for (final match in matches) {
      final token = match.group(1);
      if (token != null && token.isNotEmpty) {
        if (!validate || isValidSymbol(token)) {
          results.add(token);
        }
      }
    }
    return results;
  }

  /// Calculates the total converted mana value (CMC) of a mana cost string.
  ///
  /// Example:
  /// ```dart
  /// calculateManaValue("{2}{U}{B}") // => 4.0
  /// calculateManaValue("{W/U}{G}")   // => 2.0
  /// ```
  /// Returns `null` if any symbol has null mana value (e.g. `{∞}`) or if cost is invalid.
  static double? calculateManaValue(String manaCost) {
    final tokens = extractSymbols(manaCost, validate: false);
    if (tokens.isEmpty) return 0.0;

    double total = 0.0;
    for (final token in tokens) {
      final symbol = findBySymbol(token);
      if (symbol == null || symbol.manaValue == null) {
        return null;
      }
      total += symbol.manaValue!;
    }
    return total;
  }
}
