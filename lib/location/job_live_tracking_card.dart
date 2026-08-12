import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../jobs/job_helpers.dart';
import '../widgets/ayo_snackbar.dart';
import 'job_live_location_service.dart';
import 'job_location_map.dart';
import 'osm_map_config.dart';
import 'package:ayosuruh/l10n/ayo_localization.dart';

class JobLiveTrackingCard extends StatefulWidget {
  const JobLiveTrackingCard({
    super.key,
    required this.job,
    required this.isMitra,
  });

  final Map<String, dynamic> job;
  final bool isMitra;

  @override
  State<JobLiveTrackingCard> createState() => _JobLiveTrackingCardState();
}

class _JobLiveTrackingCardState extends State<JobLiveTrackingCard> {
  final JobLiveLocationService _service = JobLiveLocationService.instance;
  Timer? _freshnessTimer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _freshnessTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    super.dispose();
  }

  bool get _canShare {
    return widget.isMitra &&
        jobWorkMode(widget.job) == jobWorkModeMobile &&
        (widget.job['status'] ?? '').toString() == 'on_progress' &&
        (widget.job['progress_stage'] ?? '').toString() != 'completion_submitted';
  }

  bool get _sharingThisJob =>
      _service.isSharing && _service.activeJobId == widget.job['id']?.toString();

  Future<void> _toggleSharing() async {
    if (_busy) return;

    if (_sharingThisJob) {
      setState(() => _busy = true);
      await _service.stopSharing();
      if (mounted) {
        setState(() => _busy = false);
        AyoSnackBar.info(context, 'Live tracking dihentikan.');
      }
      return;
    }

    final bool? consent = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Image.asset(
            'assets/images/Logo_Ayo_Suruh.png',
            width: 52,
            height: 52,
            fit: BoxFit.contain,
          ),
          title: const AyoText(
            'Bagikan Lokasi Langsung?',
            textAlign: TextAlign.center,
          ),
          content: const AyoText(
            'Selama live tracking aktif, lokasi perangkat Mitra dibagikan hanya kepada Customer pada pekerjaan ini. Gunakan fitur ini saat perjalanan berlangsung dan hentikan setelah selesai.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AyoText('Nanti'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.navigation_rounded),
              label: const AyoText('Mulai Tracking'),
            ),
          ],
        );
      },
    );

    if (consent != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.startSharing(widget.job['id'].toString());
      if (!mounted) return;
      setState(() => _busy = false);
      AyoSnackBar.success(
        context,
        'Live tracking aktif. Customer dapat melihat posisi perjalananmu.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      final String message = error.toString().replaceFirst('Bad state: ', '');
      AyoSnackBar.error(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (jobWorkMode(widget.job) != jobWorkModeMobile) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<JobLiveLocationPoint>>(
      stream: _service.watchTrail(widget.job['id'].toString()),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JobLiveLocationPoint>> snapshot,
      ) {
        final List<JobLiveLocationPoint> trail =
            snapshot.data ?? const <JobLiveLocationPoint>[];
        final JobLiveLocationPoint? latest = trail.isEmpty ? null : trail.last;
        final bool live = latest != null &&
            DateTime.now().difference(latest.recordedAt) <
                const Duration(seconds: 75);

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
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0DE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.near_me_rounded,
                      color: jobOrangeColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AyoText(
                          'Live Tracking',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        AyoText(
                          'Posisi Mitra pada pekerjaan mobilitas',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF786B63),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _LiveBadge(live: live),
                ],
              ),
              const SizedBox(height: 12),
              if (trail.isNotEmpty)
                _LiveTrailMap(job: widget.job, trail: trail)
              else
                _WaitingTrackingState(isMitra: widget.isMitra),
              if (latest != null) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Icon(
                      live ? Icons.sensors_rounded : Icons.history_rounded,
                      size: 16,
                      color: live ? jobGreenColor : const Color(0xFF7B7069),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: AyoText(
                        live
                            ? 'Diperbarui ${_relativeTime(latest.recordedAt)}'
                            : 'Lokasi terakhir ${_relativeTime(latest.recordedAt)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF6C6059),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (latest.accuracyM != null)
                      AyoText(
                        '±${latest.accuracyM!.round()} m',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF8B8079),
                        ),
                      ),
                  ],
                ),
              ],
              if (_canShare) ...<Widget>[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _sharingThisJob
                      ? OutlinedButton.icon(
                          onPressed: _busy ? null : _toggleSharing,
                          icon: _busy
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.location_off_rounded),
                          label: const AyoText('Hentikan Live Tracking'),
                        )
                      : FilledButton.icon(
                          onPressed: _busy ? null : _toggleSharing,
                          icon: _busy
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.navigation_rounded),
                          label: const AyoText('Mulai Live Tracking'),
                        ),
                ),
                const SizedBox(height: 7),
                const AyoText(
                  'Aktifkan saat mulai perjalanan. Android menampilkan notifikasi tetap selama lokasi dibagikan.',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.35,
                    color: Color(0xFF7B7069),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _relativeTime(DateTime value) {
    final Duration difference = DateTime.now().difference(value);
    if (difference.inSeconds < 10) return 'baru saja';
    if (difference.inMinutes < 1) return '${difference.inSeconds} detik lalu';
    if (difference.inHours < 1) return '${difference.inMinutes} menit lalu';
    return '${difference.inHours} jam lalu';
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: live ? const Color(0xFFE7F2DF) : const Color(0xFFF1ECE8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: live ? jobGreenColor : const Color(0xFF9A8E87),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          AyoText(
            live ? 'LIVE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w900,
              color: live ? jobGreenColor : const Color(0xFF746A64),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingTrackingState extends StatelessWidget {
  const _WaitingTrackingState({required this.isMitra});

  final bool isMitra;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: jobBorderColor),
      ),
      child: Row(
        children: <Widget>[
          Image.asset(
            'assets/images/ayos/ayos_live_tracking.png',
            width: 54,
            height: 54,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AyoText(
              isMitra
                  ? 'Mulai live tracking saat perjalanan dimulai agar Customer dapat mengikuti posisimu.'
                  : 'Menunggu Mitra mengaktifkan live tracking untuk perjalanan ini.',
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: Color(0xFF625750),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveTrailMap extends StatefulWidget {
  const _LiveTrailMap({required this.job, required this.trail});

  final Map<String, dynamic> job;
  final List<JobLiveLocationPoint> trail;

  @override
  State<_LiveTrailMap> createState() => _LiveTrailMapState();
}

class _LiveTrailMapState extends State<_LiveTrailMap> {
  final MapController _mapController = MapController();
  int? _lastPointId;

  @override
  void initState() {
    super.initState();
    if (widget.trail.isNotEmpty) {
      _lastPointId = widget.trail.last.id;
    }
  }

  @override
  void didUpdateWidget(covariant _LiveTrailMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trail.isEmpty) return;

    final JobLiveLocationPoint latest = widget.trail.last;
    if (latest.id == _lastPointId) return;
    _lastPointId = latest.id;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _followCurrentPosition();
    });
  }

  void _followCurrentPosition() {
    if (widget.trail.isEmpty) return;
    _mapController.move(widget.trail.last.point, 15.4);
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? origin = jobLatLng(widget.job);
    final LatLng? destination = jobDestinationLatLng(widget.job);
    final LatLng current = widget.trail.last.point;

    final List<LatLng> points = <LatLng>[
      ?origin,
      ?destination,
      ...widget.trail.map((JobLiveLocationPoint value) => value.point),
    ];
    final LatLng center = _center(points);
    final double zoom = _zoomFor(points);

    final List<Marker> trailDots = _trailMarkers(widget.trail);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 235,
        child: FlutterMap(
          mapController: _mapController,
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
            if (widget.trail.length > 1)
              PolylineLayer(
                polylines: <Polyline>[
                  Polyline(
                    points: widget.trail
                        .map((JobLiveLocationPoint value) => value.point)
                        .toList(growable: false),
                    color: jobOrangeColor.withValues(alpha: 0.82),
                    strokeWidth: 5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: <Marker>[
                if (origin != null)
                  _smallEndpoint(origin, 'A', jobGreenColor),
                if (destination != null)
                  _smallEndpoint(destination, 'B', jobOrangeColor),
                ...trailDots,
                Marker(
                  point: current,
                  width: 48,
                  height: 48,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: jobOrangeColor, width: 3),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/Logo_Ayo_Suruh.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Material(
                color: const Color(0xF5FFFFFF),
                shape: const CircleBorder(),
                elevation: 2,
                child: IconButton(
                  tooltip: AyoI18n.t('Ikuti posisi Mitra'),
                  onPressed: _followCurrentPosition,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.my_location_rounded,
                    size: 19,
                    color: jobBrownColor,
                  ),
                ),
              ),
            ),
            const Positioned(
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
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _trailMarkers(List<JobLiveLocationPoint> values) {
    if (values.length < 3) return const <Marker>[];
    final int step = (values.length / 10).ceil();
    final List<Marker> markers = <Marker>[];
    for (int i = 0; i < values.length - 1; i += step) {
      final double progress = (i + 1) / values.length;
      markers.add(
        Marker(
          point: values[i].point,
          width: 12,
          height: 12,
          child: Container(
            decoration: BoxDecoration(
              color: jobOrangeColor.withValues(alpha: 0.18 + (0.55 * progress)),
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  Marker _smallEndpoint(LatLng point, String label, Color color) {
    return Marker(
      point: point,
      width: 30,
      height: 30,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2.2),
        ),
        child: AyoText(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  LatLng _center(List<LatLng> values) {
    if (values.isEmpty) return const LatLng(-6.9175, 107.6191);
    double lat = 0;
    double lng = 0;
    for (final LatLng point in values) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / values.length, lng / values.length);
  }

  double _zoomFor(List<LatLng> values) {
    if (values.length < 2) return 16;
    double maxDistance = 0;
    const Distance calculator = Distance();
    for (final LatLng point in values) {
      final double distance = calculator.as(
        LengthUnit.Meter,
        values.first,
        point,
      );
      if (distance > maxDistance) maxDistance = distance;
    }
    if (maxDistance < 600) return 15.5;
    if (maxDistance < 2000) return 14.2;
    if (maxDistance < 6000) return 12.8;
    if (maxDistance < 15000) return 11.4;
    return 10.2;
  }
}
