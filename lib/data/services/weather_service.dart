import 'dart:convert';

import 'package:http/http.dart' as http;

import 'location_service.dart';
import 'storage_service.dart';

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.precipitationChance,
    required this.windKmh,
    required this.weatherCode,
    required this.isDay,
    required this.tempMax,
    required this.tempMin,
    required this.place,
    required this.fetchedAtMs,
  });

  final double temperature;
  final double feelsLike;
  final int humidity;

  /// Highest rain probability today, 0-100.
  final int precipitationChance;
  final double windKmh;
  final int weatherCode;
  final bool isDay;
  final double tempMax;
  final double tempMin;
  final String place;
  final int fetchedAtMs;

  DateTime get fetchedAt => DateTime.fromMillisecondsSinceEpoch(fetchedAtMs);

  String get description {
    switch (weatherCode) {
      case 0:
        return isDay ? 'Clear sky' : 'Clear night';
      case 1:
        return 'Mostly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
        return 'Rain';
      case 71:
      case 73:
      case 75:
      case 77:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Unknown';
    }
  }

  Map<String, dynamic> toMap() => {
    'temperature': temperature,
    'feelsLike': feelsLike,
    'humidity': humidity,
    'precipitationChance': precipitationChance,
    'windKmh': windKmh,
    'weatherCode': weatherCode,
    'isDay': isDay,
    'tempMax': tempMax,
    'tempMin': tempMin,
    'place': place,
    'fetchedAtMs': fetchedAtMs,
  };

  static WeatherSnapshot? fromMap(Map<String, dynamic> m) {
    try {
      return WeatherSnapshot(
        temperature: (m['temperature'] as num).toDouble(),
        feelsLike: (m['feelsLike'] as num).toDouble(),
        humidity: (m['humidity'] as num).toInt(),
        precipitationChance: (m['precipitationChance'] as num).toInt(),
        windKmh: (m['windKmh'] as num).toDouble(),
        weatherCode: (m['weatherCode'] as num).toInt(),
        isDay: m['isDay'] == true,
        tempMax: (m['tempMax'] as num).toDouble(),
        tempMin: (m['tempMin'] as num).toDouble(),
        place: (m['place'] as String?) ?? '',
        fetchedAtMs: (m['fetchedAtMs'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Current weather from Open-Meteo (free, no API key). The last result is
/// cached so the home page still shows something while offline.
class WeatherService {
  WeatherService._();

  static const String _cacheKey = 'weather_cache_v1';
  static const Duration freshFor = Duration(minutes: 30);

  static WeatherSnapshot? get cached {
    final raw = StorageService.getString(_cacheKey);
    if (raw.isEmpty) return null;
    try {
      return WeatherSnapshot.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static bool isFresh(WeatherSnapshot? s) =>
      s != null && DateTime.now().difference(s.fetchedAt) < freshFor;

  static Future<void> clearCache() => StorageService.remove(_cacheKey);

  /// Fresh weather, or the cached copy when offline. Null when there is
  /// nothing to show.
  static Future<WeatherSnapshot?> load({bool force = false}) async {
    final existing = cached;
    if (!force && isFresh(existing)) return existing;

    try {
      final location = await LocationService.refresh();
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': location.latitude.toStringAsFixed(4),
        'longitude': location.longitude.toStringAsFixed(4),
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,is_day',
        'daily':
            'precipitation_probability_max,temperature_2m_max,temperature_2m_min',
        'timezone': 'auto',
        'forecast_days': '1',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return existing;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>;
      num first(String key) => ((daily[key] as List).first as num?) ?? 0;

      var place = LocationService.placeName;
      if (location.isReal) {
        final resolved = await _reverseGeocode(
          location.latitude,
          location.longitude,
        );
        if (resolved.isNotEmpty) {
          place = resolved;
          await LocationService.setPlaceName(resolved);
        }
      } else {
        place = 'Dhaka';
      }

      final snapshot = WeatherSnapshot(
        temperature: (current['temperature_2m'] as num).toDouble(),
        feelsLike: (current['apparent_temperature'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).round(),
        precipitationChance: first('precipitation_probability_max').round(),
        windKmh: (current['wind_speed_10m'] as num).toDouble(),
        weatherCode: (current['weather_code'] as num).toInt(),
        isDay: (current['is_day'] as num) == 1,
        tempMax: first('temperature_2m_max').toDouble(),
        tempMin: first('temperature_2m_min').toDouble(),
        place: place,
        fetchedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await StorageService.setString(_cacheKey, jsonEncode(snapshot.toMap()));
      return snapshot;
    } catch (_) {
      return existing;
    }
  }

  static Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.https(
        'api.bigdatacloud.net',
        '/data/reverse-geocode-client',
        {
          'latitude': lat.toStringAsFixed(4),
          'longitude': lon.toStringAsFixed(4),
          'localityLanguage': 'en',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return '';
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final city = (json['city'] as String?)?.trim() ?? '';
      final locality = (json['locality'] as String?)?.trim() ?? '';
      return city.isNotEmpty ? city : locality;
    } catch (_) {
      return '';
    }
  }
}
