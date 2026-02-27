import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:safety_pal/screens/map/navigation_screen.dart';
// import 'package:url_launcher/url_launcher.dart';

class SafeZoneListScreen extends StatefulWidget {
  const SafeZoneListScreen({Key? key}) : super(key: key);

  @override
  _SafeZoneListScreenState createState() => _SafeZoneListScreenState();
}

class _SafeZoneListScreenState extends State<SafeZoneListScreen> {
  List<Map<String, dynamic>> safeZones = [];
  bool isLoading = false;
  String errorMessage = "";
  Position? userLocation;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        isLoading = false;
        errorMessage = "Location services are disabled.";
      });
      return;
    }

    // Check location permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          isLoading = false;
          errorMessage = "Location permission is denied.";
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        isLoading = false;
        errorMessage =
            "Location permissions are permanently denied. Please enable them in settings.";
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        userLocation = position;
      });

      _fetchSafeZones(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error fetching location: $e";
      });
    }
  }

  Future<void> _fetchSafeZones(double lat, double lng) async {
    setState(() {
      isLoading = true;
    });

    String query = """
      [out:json];
      (
        node["amenity"="hospital"](around:5000,$lat,$lng);
        node["amenity"="police"](around:5000,$lat,$lng);
        node["shop"="mall"](around:5000,$lat,$lng);
      );
      out;
    """;

    String url =
        "https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('elements') && data['elements'].isNotEmpty) {
          List elements = data['elements'];

          List<Map<String, dynamic>> places =
              elements.where((place) => place.containsKey("tags")).map((place) {
            double placeLat = place['lat'];
            double placeLng = place['lon'];
            double distance = _calculateDistance(lat, lng, placeLat, placeLng);
            return {
              "name": place['tags']['name'] ?? "Unknown",
              "lat": placeLat,
              "lng": placeLng,
              "type": place['tags'].containsKey("amenity")
                  ? place['tags']['amenity']
                  : "mall",
              "distance": distance,
            };
          }).toList();

          // Sort places by distance (ascending order)
          places.sort((a, b) => a['distance'].compareTo(b['distance']));

          setState(() {
            safeZones = places.take(5).toList(); // Get top 5 closest places
            isLoading = false;
          });
        } else {
          setState(() {
            safeZones = [];
            isLoading = false;
            errorMessage = "No Safe Zones found nearby.";
          });
        }
      } else {
        throw "Failed to fetch data from Overpass API.";
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error fetching safe zones: $e";
      });
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0; // Radius of the Earth in km
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c; // Distance in km
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  void _navigateTo(double lat, double lng, String placeName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          destinationLat: lat,
          destinationLng: lng,
          placeName: placeName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Top 5 Closest Safe Zones")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Text(errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 16)))
              : safeZones.isEmpty
                  ? const Center(
                      child: Text("No Safe Zones found.",
                          style: TextStyle(fontSize: 18)))
                  : ListView.builder(
                      itemCount: safeZones.length,
                      itemBuilder: (context, index) {
                        final zone = safeZones[index];
                        return ListTile(
                          leading: Icon(
                            zone['type'] == "hospital"
                                ? Icons.local_hospital
                                : zone['type'] == "police"
                                    ? Icons.local_police
                                    : Icons.shopping_bag,
                            color: Colors.blue,
                          ),
                          title: Text(zone['name']),
                          subtitle: Text(
                              "Type: ${zone['type']} • ${zone['distance'].toStringAsFixed(2)} km away"),
                          onTap: () => _navigateTo(
                              zone['lat'], zone['lng'], zone['name']),
                        );
                      },
                    ),
    );
  }
}
