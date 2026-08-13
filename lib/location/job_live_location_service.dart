import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JobLiveLocationPoint {
  const JobLiveLocationPoint({
    required this.id,
    required this.point,
    required this.recordedAt,
    this.accuracyM,
    this.headingDeg,
    this.speedMps,
  });

  final int id;
  final LatLng point;
  final DateTime recordedAt;
  final double? accuracyM;
  final double? headingDeg;
  final double? speedMps;

  factory JobLiveLocationPoint.fromMap(Map<String, dynamic> map) {
    double? parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    return JobLiveLocationPoint(
      id: map['id'] is num
          ? (map['id'] as num).toInt()
          : int.tryParse(map['id']?.toString() ?? '') ?? 0,
      point: LatLng(
        parseDouble(map['latitude']) ?? 0,
        parseDouble(map['longitude']) ?? 0,
      ),
      recordedAt: DateTime.tryParse(map['recorded_at']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      accuracyM: parseDouble(map['accuracy_m']),
      headingDeg: parseDouble(map['heading_deg']),
      speedMps: parseDouble(map['speed_mps']),
    );
  }
}

class JobLiveLocationService {
  JobLiveLocationService._();

  static final JobLiveLocationService instance = JobLiveLocationService._();

  final SupabaseClient _client = Supabase.instance.client;
  StreamSubscription<Position>? _positionSubscription;
  String? _activeJobId;
  DateTime? _lastSentAt;
  Position? _lastSentPosition;

  String? get activeJobId => _activeJobId;
  bool get isSharing => _positionSubscription != null && _activeJobId != null;

  Stream<List<JobLiveLocationPoint>> watchTrail(String jobId) {
    return _client
        .from('job_live_location_points')
        .stream(primaryKey: <String>['id'])
        .eq('job_id', jobId)
        .order('recorded_at', ascending: true)
        .limit(250)
        .map((List<Map<String, dynamic>> rows) {
          return rows
              .map(JobLiveLocationPoint.fromMap)
              .where((JobLiveLocationPoint point) {
                return point.point.latitude.abs() <= 90 &&
                    point.point.longitude.abs() <= 180;
              })
              .toList(growable: false);
        });
  }

  Future<void> startSharing(String jobId) async {
    if (_activeJobId == jobId && _positionSubscription != null) return;
    await stopSharing();

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('GPS sedang nonaktif. Aktifkan lokasi untuk membagikan posisi.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Izin lokasi diperlukan untuk live tracking.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Izin lokasi ditolak permanen. Aktifkan izin lokasi dari pengaturan aplikasi.',
      );
    }

    _activeJobId = jobId;
    _lastSentAt = null;
    _lastSentPosition = null;

    // Publish one position immediately so Customer does not see an empty map.
    // If acquiring/publishing the first point fails, reset sharing state instead
    // of leaving a phantom active job behind.
    try {
      final Position initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final bool published = await _publish(jobId, initial, force: true);
      if (!published) {
        throw StateError(
          'Lokasi pertama belum dapat dikirim. Periksa koneksi lalu coba lagi.',
        );
      }
    } catch (_) {
      await stopSharing();
      rethrow;
    }

    final LocationSettings settings;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 8),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Ayo Suruh · Live Tracking Aktif',
          notificationText:
              'Lokasi dibagikan ke Customer selama pekerjaan mobilitas berjalan.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 12,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 12,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (Position position) {
        final String? active = _activeJobId;
        if (active == null) return;
        unawaited(_publish(active, position));
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Live location stream error: $error');
      },
      cancelOnError: false,
    );
  }

  Future<void> stopSharing() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _activeJobId = null;
    _lastSentAt = null;
    _lastSentPosition = null;
  }

  Future<bool> _publish(
    String jobId,
    Position position, {
    bool force = false,
  }) async {
    final DateTime now = DateTime.now();
    if (!force && _lastSentAt != null) {
      final Duration elapsed = now.difference(_lastSentAt!);
      final Position? last = _lastSentPosition;
      final double distance = last == null
          ? double.infinity
          : Geolocator.distanceBetween(
              last.latitude,
              last.longitude,
              position.latitude,
              position.longitude,
            );
      if (elapsed < const Duration(seconds: 6)) return true;
      if (elapsed < const Duration(seconds: 20) && distance < 4) return true;
    }

    try {
      await _client.rpc(
        'append_job_live_location',
        params: <String, dynamic>{
          'p_job_id': jobId,
          'p_latitude': position.latitude,
          'p_longitude': position.longitude,
          'p_accuracy_m': position.accuracy,
          'p_heading_deg': position.heading,
          'p_speed_mps': position.speed,
        },
      );
      _lastSentAt = now;
      _lastSentPosition = position;
      return true;
    } on PostgrestException catch (error) {
      // If backend closes tracking because job is completed/submitted, stop the
      // stream instead of repeatedly sending rejected points.
      final String message = error.message.toLowerCase();
      if (message.contains('live tracking hanya aktif') ||
          message.contains('bukan milik mitra') ||
          message.contains('hanya dapat dibagikan')) {
        await stopSharing();
      }
      debugPrint('Live location publish failed: $error');
      return false;
    } catch (error) {
      debugPrint('Live location publish failed: $error');
      return false;
    }
  }
}
