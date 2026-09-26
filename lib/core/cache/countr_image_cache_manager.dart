import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom [CacheManager] tailored for MTG and collectible card imagery.
/// Enforces a 35+ day retention policy and 5,000 maximum cached objects on disk
/// to ensure complete offline resilience.
class CountrImageCacheManager extends CacheManager with ImageCacheManager {
  static const String key = 'countr_card_images';
  static const Duration stalePeriod = Duration(days: 35);
  static const int maxNrOfCacheObjects = 5000;

  static final CountrImageCacheManager _instance = CountrImageCacheManager._();
  static CountrImageCacheManager get instance => _instance;
  factory CountrImageCacheManager() => _instance;

  CountrImageCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: stalePeriod,
            maxNrOfCacheObjects: maxNrOfCacheObjects,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: HttpFileService(),
          ),
        );
}
