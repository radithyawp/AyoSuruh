import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../jobs/job_helpers.dart';
import 'location_service.dart';
import 'osm_geocoding_service.dart';
import '../widgets/home_shortcut_button.dart';

class PickedLocation {
  const PickedLocation({
    required this.point,
    required this.addressLabel,
  });

  final LatLng point;
  final String addressLabel;
}

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
  final OsmGeocodingService _geocodingService = OsmGeocodingService();
  late final TextEditingController _searchController;

  LatLng? _selectedPoint;
  String _selectedAddressLabel = '';
  bool _isLocating = false;
  bool _isSearching = false;
  bool _isResolvingPoint = false;
  bool _pointNeedsReverse = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
    _selectedAddressLabel = (widget.addressLabel ?? '').trim();
    _searchController = TextEditingController(text: _selectedAddressLabel);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _geocodingService.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final position = await _locationService.determineCurrentPosition();
      final LatLng point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _selectedPoint = point;
        _selectedAddressLabel = '';
        _pointNeedsReverse = true;
      });
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

  Future<void> _searchAddress() async {
    final String query = _searchController.text.trim();
    if (query.length < 3 || _isSearching) {
      if (query.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ketik minimal 3 karakter alamat.')),
        );
      }
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);
    try {
      final List<OsmGeocodingResult> results =
          await _geocodingService.search(query);
      if (!mounted) return;
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alamat belum ditemukan. Coba tambah nama kota/kecamatan.'),
            backgroundColor: jobBrownColor,
          ),
        );
        return;
      }

      OsmGeocodingResult? selected;
      if (results.length == 1) {
        selected = results.first;
      } else {
        selected = await showModalBottomSheet<OsmGeocodingResult>(
          context: context,
          showDragHandle: true,
          builder: (BuildContext sheetContext) {
            return SafeArea(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
                itemCount: results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final OsmGeocodingResult result = results[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: jobOrangeColor,
                    ),
                    title: Text(
                      result.displayName,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, height: 1.3),
                    ),
                    onTap: () => Navigator.pop(sheetContext, result),
                  );
                },
              ),
            );
          },
        );
      }

      if (selected == null || !mounted) return;
      setState(() {
        _selectedPoint = selected!.point;
        _selectedAddressLabel = selected.displayName;
        _searchController.text = selected.displayName;
        _pointNeedsReverse = false;
      });
      _mapController.move(selected.point, 17);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pencarian alamat gagal: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _confirmPoint() async {
    final LatLng? point = _selectedPoint;
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cari alamat, ketuk peta, atau gunakan lokasi saat ini.'),
          backgroundColor: jobBrownColor,
        ),
      );
      return;
    }
    if (_isResolvingPoint) return;

    String address = _selectedAddressLabel.trim();
    if (_pointNeedsReverse || address.length < 8) {
      setState(() => _isResolvingPoint = true);
      try {
        final OsmGeocodingResult? resolved =
            await _geocodingService.reverse(point);
        if (!mounted) return;
        if (resolved != null) {
          address = resolved.displayName.trim();
          setState(() {
            _selectedAddressLabel = address;
            _searchController.text = address;
            _pointNeedsReverse = false;
          });
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alamat titik belum dapat dibaca otomatis: $error'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      } finally {
        if (mounted) setState(() => _isResolvingPoint = false);
      }
    }

    if (!mounted) return;
    if (address.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Alamat titik belum terbaca. Cari alamat terlebih dahulu atau ketik alamat yang lebih lengkap.',
          ),
          backgroundColor: jobBrownColor,
        ),
      );
      return;
    }

    Navigator.pop<PickedLocation>(
      context,
      PickedLocation(point: point, addressLabel: address),
    );
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

        actions: const <Widget>[HomeShortcutButton()],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchAddress(),
              decoration: InputDecoration(
                hintText: 'Cari alamat, contoh: UPI Kampus Cibiru',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Cari alamat',
                  onPressed: _isSearching ? null : _searchAddress,
                  icon: _isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: jobOrangeColor,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: jobBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: jobOrangeColor, width: 1.4),
                ),
              ),
            ),
          ),
          if (_selectedAddressLabel.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2DE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.pin_drop_outlined,
                    color: jobBrownColor,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _selectedAddressLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, height: 1.3),
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
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _selectedPoint = point;
                        _selectedAddressLabel = '';
                        _pointNeedsReverse = true;
                      });
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
                  'Cari alamat atau ketuk peta untuk mengoreksi titik. Pencarian menggunakan data OpenStreetMap.',
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
                    onPressed: _isResolvingPoint ? null : _confirmPoint,
                    style: FilledButton.styleFrom(
                      backgroundColor: jobOrangeColor,
                      foregroundColor: const Color(0xFF5E3B00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: _isResolvingPoint
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF5E3B00),
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      _isResolvingPoint
                          ? 'Membaca Alamat Titik...'
                          : 'Gunakan Titik Ini',
                      style: const TextStyle(fontWeight: FontWeight.w800),
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
