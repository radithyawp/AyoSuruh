import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OsmGeocodingResult {
  const OsmGeocodingResult({
    required this.displayName,
    required this.point,
  });

  final String displayName;
  final LatLng point;
}

class OsmGeocodingService {
  OsmGeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static DateTime? _lastRequestAt;

  Future<List<OsmGeocodingResult>> search(String query) async {
    final String normalized = query.trim();
    if (normalized.length < 3) return const <OsmGeocodingResult>[];

    // Public Nominatim dipakai hanya ketika user menekan cari/submit, bukan
    // autocomplete tiap ketikan. Jaga jarak request minimal satu detik.
    final DateTime now = DateTime.now();
    final DateTime? previous = _lastRequestAt;
    if (previous != null) {
      final Duration elapsed = now.difference(previous);
      if (elapsed < const Duration(seconds: 1)) {
        await Future<void>.delayed(const Duration(seconds: 1) - elapsed);
      }
    }
    _lastRequestAt = DateTime.now();

    final Uri uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      <String, String>{
        'q': normalized,
        'format': 'jsonv2',
        'limit': '5',
        'countrycodes': 'id',
        'addressdetails': '1',
      },
    );

    final http.Response response = await _client.get(
      uri,
      headers: const <String, String>{
        'User-Agent': 'AyoSuruh/1.0 (academic MVP; UPI Cibiru)',
        'Accept-Language': 'id,en;q=0.8',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw StateError('Pencarian lokasi gagal (${response.statusCode}).');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! List) return const <OsmGeocodingResult>[];

    final List<OsmGeocodingResult> results = <OsmGeocodingResult>[];
    for (final dynamic item in decoded) {
      if (item is! Map) continue;
      final double? lat = double.tryParse(item['lat']?.toString() ?? '');
      final double? lon = double.tryParse(item['lon']?.toString() ?? '');
      final String label = item['display_name']?.toString().trim() ?? '';
      if (lat == null || lon == null || label.isEmpty) continue;
      results.add(
        OsmGeocodingResult(
          displayName: label,
          point: LatLng(lat, lon),
        ),
      );
    }
    return results;
  }

  void dispose() => _client.close();
}
