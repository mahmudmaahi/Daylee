import 'package:geolocator/geolocator.dart';

import 'storage_service.dart';

class AppLocation {
  const AppLocation({
    required this.latitude,
    required this.longitude,
    required this.isReal,
  });

  final double latitude;
  final double longitude;

  /// False when this is the built-in default (Dhaka) rather than a real fix.
  final bool isReal;
}

enum LocationAccess { off, granted, denied, deniedForever, serviceDisabled }

/// Opt-in device location. Nothing is requested until the user enables it in
/// settings; the last fix is cached so weather and prayer times keep working
/// offline.
class LocationService {
  LocationService._();

  static const String enabledKey = 'location_enabled';
  static const String _latKey = 'location_lat';
  static const String _lonKey = 'location_lon';
  static const String _placeKey = 'location_place';
  static const String _fixAtKey = 'location_fix_ms';

  // Dhaka, Bangladesh.
  static const double defaultLat = 23.8103;
  static const double defaultLon = 90.4125;

  static bool get enabled => StorageService.getBool(enabledKey);

  static String get placeName => StorageService.getString(_placeKey);

  static Future<void> setPlaceName(String value) =>
      StorageService.setString(_placeKey, value);

  static AppLocation get cached {
    final lat = StorageService.getDouble(_latKey, fallback: double.nan);
    final lon = StorageService.getDouble(_lonKey, fallback: double.nan);
    if (lat.isNaN || lon.isNaN) {
      return const AppLocation(
        latitude: defaultLat,
        longitude: defaultLon,
        isReal: false,
      );
    }
    return AppLocation(latitude: lat, longitude: lon, isReal: true);
  }

  static DateTime? get lastFixAt {
    final ms = StorageService.getInt(_fixAtKey);
    return ms <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<LocationAccess> access() async {
    if (!enabled) return LocationAccess.off;
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    switch (await Geolocator.checkPermission()) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAccess.granted;
      case LocationPermission.deniedForever:
        return LocationAccess.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccess.denied;
    }
  }

  /// Turns the feature on and asks for permission. The preference is only
  /// kept when access was granted.
  static Future<LocationAccess> enable() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationAccess.deniedForever;
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      return LocationAccess.denied;
    }
    await StorageService.setBool(enabledKey, true);
    return LocationAccess.granted;
  }

  static Future<void> disable() => StorageService.setBool(enabledKey, false);

  static Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Gets a fresh fix (low accuracy is plenty for weather / prayer times).
  /// Falls back to the cached one when the fix fails.
  static Future<AppLocation> refresh() async {
    if (await access() != LocationAccess.granted) return cached;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await _store(position.latitude, position.longitude);
      return AppLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        isReal: true,
      );
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        await _store(last.latitude, last.longitude);
        return AppLocation(
          latitude: last.latitude,
          longitude: last.longitude,
          isReal: true,
        );
      }
      return cached;
    }
  }

  static Future<void> _store(double lat, double lon) async {
    await StorageService.setDouble(_latKey, lat);
    await StorageService.setDouble(_lonKey, lon);
    await StorageService.setInt(_fixAtKey, DateTime.now().millisecondsSinceEpoch);
  }
}
