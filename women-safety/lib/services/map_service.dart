import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

/// Lightweight wrapper around Overpass and OSRM API calls.
class MapService {
  static const _overpassBase = 'https://overpass-api.de/api/interpreter';
  static const _osrmBase = 'https://router.project-osrm.org';

  /// Returns a list of nearby places (hospital/police/mall) with distance.
  static Future<List<Map<String, dynamic>>> fetchSafeZones(
      double lat, double lng,
      {int radius = 5000}) async {
    final query = '''
[out:json];
(
  node["amenity"="hospital"](around:$radius,$lat,$lng);
  node["amenity"="police"](around:$radius,$lat,$lng);
  node["shop"="mall"](around:$radius,$lat,$lng);
);
out;
''';
    final url = '$_overpassBase?data=${Uri.encodeComponent(query)}';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('Overpass error');
    final data = json.decode(res.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>?;
    if (elements == null) return [];

    double distance(double lat1, double lon1, double lat2, double lon2) {
      return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // km
    }

    final places = elements.where((e) => e['tags'] != null).map((place) {
      final tags = place['tags'] as Map<String, dynamic>;
      final plLat = place['lat'] as double;
      final plLon = place['lon'] as double;
      return {
        'name': tags['name'] ?? 'Unknown',
        'lat': plLat,
        'lng': plLon,
        'type': tags.containsKey('amenity') ? tags['amenity'] : 'mall',
        'distance': distance(lat, lng, plLat, plLon),
      };
    }).toList();
    places.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    return places;
  }

  /// Fetches a list of LatLng points representing a driving route between two
  /// coordinates.
  static Future<List<LatLng>> fetchRoute(
      double fromLat, double fromLng, double toLat, double toLng) async {
    final url =
        '$_osrmBase/route/v1/driving/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('OSRM error');
    final data = json.decode(res.body) as Map<String, dynamic>;
    final coords =
        (data['routes'][0]['geometry']['coordinates'] as List<dynamic>?) ?? [];
    return coords
        .map((c) => LatLng((c as List)[1] as double, c[0] as double))
        .toList();
  }
}
