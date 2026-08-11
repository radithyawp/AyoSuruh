import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../jobs/job_helpers.dart';
import '../widgets/ayo_snackbar.dart';
import 'location_service.dart';
import 'osm_map_config.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

LatLng? _parseLatLng(dynamic latitudeValue, dynamic longitudeValue) {
  double? parseCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  final double? latitude = parseCoordinate(latitudeValue);
  final double? longitude = parseCoordinate(longitudeValue);
  if (latitude == null || longitude == null) return null;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return null;
  }
  return LatLng(latitude, longitude);
}

LatLng? jobLatLng(Map<String, dynamic> job) {
  LatLng? point = _parseLatLng(job['latitude'], job['longitude']);
  if (point != null) return point;

  final dynamic address = job['addresses'];
  if (address is Map) {
    point = _parseLatLng(address['latitude'], address['longitude']);
  }
  return point;
}

LatLng? jobDestinationLatLng(Map<String, dynamic> job) {
  LatLng? point = _parseLatLng(
    job['destination_latitude'],
    job['destination_longitude'],
  );
  if (point != null) return point;

  final dynamic address = job['destination_address'];
  if (address is Map) {
    point = _parseLatLng(address['latitude'], address['longitude']);
  }
  return point;
}

Widget _osmAttribution() {
  return const Positioned(
    left: 7,
    bottom: 5,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xEBFFFFFF),
        borderRadius: BorderRadius.all(Radius.circular(7)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: AyoText(
          '© OpenStreetMap contributors',
          style: TextStyle(fontSize: 8.5, color: Color(0xFF625750)),
        ),
      ),
    ),
  );
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

    return _MapShell(
      title: widget.title,
      child: Column(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 184,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 16,
                  minZoom: 15,
                  maxZoom: 18,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate: OsmMapConfig.tileUrl,
                    userAgentPackageName: OsmMapConfig.userAgentPackageName,
                    maxNativeZoom: 19,
                  ),
                  MarkerLayer(
                    markers: <Marker>[
                      Marker(
                        point: point,
                        width: 52,
                        height: 52,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_pin,
                          color: jobOrangeColor,
                          size: 48,
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
                  _osmAttribution(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AddressRow(
            icon: Icons.location_on_outlined,
            label: jobAddress(widget.job),
          ),
          if (widget.enableOpenMap) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isOpeningMap ? null : () => _openMap(point),
                icon: _isOpeningMap
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new_rounded, size: 18),
                label: const AyoText('Buka di OpenStreetMap'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class JobRouteMapCard extends StatefulWidget {
  const JobRouteMapCard({
    super.key,
    required this.job,
    this.enableOpenMap = true,
  });

  final Map<String, dynamic> job;
  final bool enableOpenMap;

  @override
  State<JobRouteMapCard> createState() => _JobRouteMapCardState();
}

class _JobRouteMapCardState extends State<JobRouteMapCard> {
  final LocationService _locationService = LocationService();
  bool _opening = false;

  Future<void> _open(LatLng point) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await _locationService.openOpenStreetMap(
        latitude: point.latitude,
        longitude: point.longitude,
      );
    } catch (error) {
      if (!mounted) return;
      AyoSnackBar.error(context, 'Peta belum dapat dibuka: $error');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? origin = jobLatLng(widget.job);
    final LatLng? destination = jobDestinationLatLng(widget.job);
    if (origin == null || destination == null) {
      return JobLocationMapCard(job: widget.job);
    }

    final LatLng center = LatLng(
      (origin.latitude + destination.latitude) / 2,
      (origin.longitude + destination.longitude) / 2,
    );
    final double distanceM = const Distance().as(
      LengthUnit.Meter,
      origin,
      destination,
    );
    final double zoom = distanceM < 1000
        ? 15.2
        : distanceM < 5000
            ? 13.4
            : distanceM < 15000
                ? 11.8
                : 10.3;

    return _MapShell(
      title: 'Rute Pekerjaan',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0DE),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AyoText(
          distanceM < 1000
              ? '${distanceM.round()} m'
              : '${(distanceM / 1000).toStringAsFixed(1)} km',
          style: TextStyle(
            color: jobBrownColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 210,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: zoom,
                  minZoom: 4,
                  maxZoom: 18,
                ),
                children: <Widget>[
                  TileLayer(
                    urlTemplate: OsmMapConfig.tileUrl,
                    userAgentPackageName: OsmMapConfig.userAgentPackageName,
                    maxNativeZoom: 19,
                  ),
                  PolylineLayer(
                    polylines: <Polyline>[
                      Polyline(
                        points: <LatLng>[origin, destination],
                        color: const Color(0x66F6990E),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: <Marker>[
                      _endpointMarker(
                        point: origin,
                        icon: Icons.inventory_2_rounded,
                        color: jobGreenColor,
                      ),
                      _endpointMarker(
                        point: destination,
                        icon: Icons.flag_rounded,
                        color: jobOrangeColor,
                      ),
                    ],
                  ),
                  _osmAttribution(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _RouteEndpointRow(
            badge: 'A',
            title: jobOriginLabel(widget.job),
            address: jobAddress(widget.job),
            color: jobGreenColor,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Container(
              width: 2,
              height: 14,
              color: jobBorderColor,
            ),
          ),
          _RouteEndpointRow(
            badge: 'B',
            title: jobDestinationLabel(widget.job),
            address: jobDestinationAddress(widget.job),
            color: jobOrangeColor,
          ),
          if (widget.enableOpenMap) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _opening ? null : () => _open(origin),
                    icon: const Icon(Icons.trip_origin_rounded, size: 17),
                    label: const AyoText('Titik A'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _opening ? null : () => _open(destination),
                    icon: const Icon(Icons.flag_outlined, size: 17),
                    label: const AyoText('Titik B'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const AyoText(
            'Garis pada peta menghubungkan dua titik dan bukan petunjuk navigasi jalan.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.35,
              color: Color(0xFF786B63),
            ),
          ),
        ],
      ),
    );
  }

  Marker _endpointMarker({
    required LatLng point,
    required IconData icon,
    required Color color,
  }) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2.5),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black12, blurRadius: 7, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: color, size: 23),
      ),
    );
  }
}

class _MapShell extends StatelessWidget {
  const _MapShell({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: jobBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.map_outlined, color: jobBrownColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: AyoText(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: jobBrownColor, size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: AyoText(
            label,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF625750),
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteEndpointRow extends StatelessWidget {
  const _RouteEndpointRow({
    required this.badge,
    required this.title,
    required this.address,
    required this.color,
  });

  final String badge;
  final String title;
  final String address;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: AyoText(
            badge,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AyoText(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: jobDarkBrownColor,
                ),
              ),
              const SizedBox(height: 2),
              AyoText(
                address,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Color(0xFF625750),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
