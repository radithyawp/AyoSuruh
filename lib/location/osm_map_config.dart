import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class OsmMapConfig {
  static const String defaultTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String userAgentPackageName = 'com.ayosuruh.app';

  static String get tileUrl {
    final String? configured = dotenv.env['OSM_TILE_URL']?.trim();
    return configured == null || configured.isEmpty
        ? defaultTileUrl
        : configured;
  }
}
