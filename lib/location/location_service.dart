import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  Future<Position> determineCurrentPosition() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError(
        'GPS sedang nonaktif. Aktifkan layanan lokasi, lalu coba lagi.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw StateError(
        'Izin lokasi ditolak. Kamu tetap bisa memilih titik secara manual pada peta.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengaktifkannya.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<void> openAppLocationSettings() async {
    if (kIsWeb) return;
    await Geolocator.openAppSettings();
  }

  Future<void> openDeviceLocationSettings() async {
    if (kIsWeb) return;
    await Geolocator.openLocationSettings();
  }

  Future<void> openOpenStreetMap({
    required double latitude,
    required double longitude,
  }) async {
    final Uri uri = Uri.parse(
      'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=18/$latitude/$longitude',
    );
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
    );
    if (!launched) {
      throw StateError('OpenStreetMap tidak dapat dibuka pada perangkat ini.');
    }
  }
}
