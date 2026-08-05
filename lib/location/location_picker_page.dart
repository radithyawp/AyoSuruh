import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../jobs/job_helpers.dart';
import 'location_service.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    this.initialPoint,
    this.addressLabel,
  });

  final LatLng? initialPoint;
  final String? addressLabel;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const LatLng _bandungCenter = LatLng(-6.9175, 107.6191);

  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();

  LatLng? _selectedPoint;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final position = await _locationService.determineCurrentPosition();
      final LatLng point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _selectedPoint = point);
      _mapController.move(point, 17);
    } catch (error) {
      if (!mounted) return;
      final String message = error.toString().replaceFirst('Bad state: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          action: SnackBarAction(
            label: 'Pengaturan',
            textColor: Colors.white,
            onPressed: _locationService.openAppLocationSettings,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _confirmPoint() {
    final LatLng? point = _selectedPoint;
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ketuk peta atau gunakan lokasi saat ini terlebih dahulu.'),
          backgroundColor: jobBrownColor,
        ),
      );
      return;
    }
    Navigator.pop<LatLng>(context, point);
  }

  @override
  Widget build(BuildContext context) {
    final LatLng center = _selectedPoint ?? _bandungCenter;
    return Scaffold(
      backgroundColor: jobBackgroundColor,
      appBar: AppBar(
        backgroundColor: jobBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: jobBrownColor),
        ),
        title: const Text(
          'Pilih Titik Lokasi',
          style: TextStyle(
            color: jobBrownColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          if ((widget.addressLabel ?? '').trim().isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: jobBorderColor),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.location_on_outlined,
                    color: jobBrownColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.addressLabel!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: <Widget>[
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _selectedPoint == null ? 12.5 : 16,
                    minZoom: 4,
                    maxZoom: 19,
                    onTap: (_, LatLng point) {
                      setState(() => _selectedPoint = point);
                    },
                  ),
                  children: <Widget>[
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ayosuruh',
                      maxNativeZoom: 19,
                    ),
                    if (_selectedPoint != null)
                      MarkerLayer(
                        markers: <Marker>[
                          Marker(
                            point: _selectedPoint!,
                            width: 54,
                            height: 54,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_pin,
                              size: 50,
                              color: jobOrangeColor,
                              shadows: <Shadow>[
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  right: 14,
                  top: 14,
                  child: FloatingActionButton.small(
                    heroTag: 'currentLocationButton',
                    onPressed: _isLocating ? null : _useCurrentLocation,
                    backgroundColor: Colors.white,
                    foregroundColor: jobBrownColor,
                    child: _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: jobBrownColor,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded),
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 9, color: Color(0xFF625750)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            decoration: const BoxDecoration(
              color: jobBackgroundColor,
              border: Border(top: BorderSide(color: jobBorderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _selectedPoint == null
                      ? 'Belum ada titik dipilih'
                      : 'Koordinat: ${_selectedPoint!.latitude.toStringAsFixed(6)}, ${_selectedPoint!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: Color(0xFF625750),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Geser peta lalu ketuk lokasi yang tepat. Titik ini akan membantu mitra menemukan tujuan pekerjaan.',
                  style: TextStyle(
                    color: Color(0xFF7B7069),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _confirmPoint,
                    style: FilledButton.styleFrom(
                      backgroundColor: jobOrangeColor,
                      foregroundColor: const Color(0xFF5E3B00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text(
                      'Gunakan Titik Ini',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
