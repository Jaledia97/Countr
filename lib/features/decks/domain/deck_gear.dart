import 'package:flutter/foundation.dart';

@immutable
class DeckGear {
  final String sleeveBrand;
  final String sleeveColor;
  final String deckBoxModel;

  const DeckGear({
    this.sleeveBrand = 'Dragon Shield',
    this.sleeveColor = 'Matte Slate',
    this.deckBoxModel = 'Ultimate Guard Boulder 100+',
  });

  DeckGear copyWith({
    String? sleeveBrand,
    String? sleeveColor,
    String? deckBoxModel,
  }) {
    return DeckGear(
      sleeveBrand: sleeveBrand ?? this.sleeveBrand,
      sleeveColor: sleeveColor ?? this.sleeveColor,
      deckBoxModel: deckBoxModel ?? this.deckBoxModel,
    );
  }

  Map<String, dynamic> toJson() => {
    'sleeve_brand': sleeveBrand,
    'sleeve_color': sleeveColor,
    'deck_box_model': deckBoxModel,
  };

  factory DeckGear.fromJson(Map<String, dynamic> json) {
    return DeckGear(
      sleeveBrand: json['sleeve_brand'] as String? ?? 'Dragon Shield',
      sleeveColor: json['sleeve_color'] as String? ?? 'Matte Slate',
      deckBoxModel: json['deck_box_model'] as String? ?? 'Ultimate Guard Boulder 100+',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeckGear &&
          runtimeType == other.runtimeType &&
          sleeveBrand == other.sleeveBrand &&
          sleeveColor == other.sleeveColor &&
          deckBoxModel == other.deckBoxModel;

  @override
  int get hashCode =>
      sleeveBrand.hashCode ^ sleeveColor.hashCode ^ deckBoxModel.hashCode;
}
