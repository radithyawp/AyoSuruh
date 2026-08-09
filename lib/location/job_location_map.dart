import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../jobs/job_helpers.dart';
import '../widgets/ayo_snackbar.dart';
import 'location_service.dart';

LatLng? jobLatLng(Map<String, dynamic> job) {
  double? parseCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  double? latitude = parseCoordinate(job['latitude']);
  double? longitude = parseCoordinate(job['longitude']);

  final dynamic address = job['addresses'];
  if ((latitude == null || longitude == null) && address is Map) {
    latitude ??= parseCoordinate(address['latitude']);
    longitude ??= parseCoordinate(address['longitude']);
  }

  if (latitude == null || longitude == null) return null;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return null;
  }
  return LatLng(latitude, longitude);
}

class JobLocationMapCard extends StatefulWidget {
  const JobLocationMapCard({
    super.key,
    required this.job,
    this.title = 'Lokasi Pekerjaan',
    this.enableOpenMap = true,
  });

  final Map<String, dynamic> job;
  final String title;
  final bool enableOpenMap;

  @override
  State<JobLocationMapCard> createState() => _JobLocationMapCardState();
}

class _JobLocationMapCardState extends State<JobLocationMapCard> {
  final LocationService _locationService = LocationService();
  bool _isOpeningMap = false;

  Future<void> _openMap(LatLng point) async {
    if (_isOpeningMap) return;
    setState(() => _isOpeningMap = true);
    try {
      await _locationService.openOpenStreetMap(
        latitude: point.latitude,
        longitude: point.longitude,
      );
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Peta belum dapat dibuka: $error');
    } finally {
      if (mounted) setState(() => _isOpeningMap = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? point = jobLatLng(widget.job);
    if (point == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: jobBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.map_outlined,
                color: jobBrownColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 180,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 16,
                  minZoom: 16,
                  maxZoom: 16,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.ayosuruh',
                    maxNativeZoom: 19,
                  ),
                  MarkerLayer(
                    markers: <Marker>[
                      Marker(
                        point: point,
                        width: 50,
                        height: 50,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_pin,
                          color: jobOrangeColor,
                          size: 46,
                          shadows: <Shadow>[
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Positioned(
                    left: 7,
                    bottom: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xE6FFFFFF),
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(fontSize: 8, color: Color(0xFF625750)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.location_on_outlined,
                color: jobBrownColor,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  jobAddress(widget.job),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF625750),
                  ),
                ),
              ),
            ],
          ),
          if (widget.enableOpenMap) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _isOpeningMap ? null : () => _openMap(point),
                style: OutlinedButton.styleFrom(
                  foregroundColor: jobBrownColor,
                  side: const BorderSide(color: jobOrangeColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                icon: _isOpeningMap
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: jobBrownColor,
                        ),
                      )
                    : const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text(
                  'Buka di OpenStreetMap',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
