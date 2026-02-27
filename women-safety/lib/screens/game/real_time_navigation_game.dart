import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RealTimeNavigationGame extends StatefulWidget {
  final Function(int) onScoreUpdate;

  const RealTimeNavigationGame({
    Key? key,
    required this.onScoreUpdate,
  }) : super(key: key);

  @override
  State<RealTimeNavigationGame> createState() => _RealTimeNavigationGameState();
}

class _RealTimeNavigationGameState extends State<RealTimeNavigationGame> {
  LatLng playerPosition = LatLng(0, 0);
  LatLng safeZoneLocation = LatLng(0, 0);
  List<LatLng> safeRoute = [];
  List<PowerUpMarker> powerUps = [];
  final mapController = MapController();
  bool isLoading = true;
  String errorMessage = "";
  StreamSubscription<Position>? positionStream;
  int score = 0;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initializeGame() async {
    await _requestLocationPermission();
    await _getUserLocation();
    _trackUserMovement();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        errorMessage = "Location services are disabled.";
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          errorMessage = "Location permissions are denied.";
        });
        return;
      }
    }
  }

  Future<void> _getUserLocation() async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        playerPosition = LatLng(position.latitude, position.longitude);
        _fetchSafeZones(position.latitude, position.longitude);
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error fetching location: $e";
      });
    }
  }

  void _trackUserMovement() {
    positionStream = Geolocator.getPositionStream(
      locationSettings:
          LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((Position position) {
      setState(() {
        playerPosition = LatLng(position.latitude, position.longitude);
        _fetchRoute();
        _checkPowerUpCollection();
        _checkIfReachedSafeZone();
      });
    });
  }

  Future<void> _fetchSafeZones(double lat, double lng) async {
    setState(() {
      isLoading = true;
    });

    String query = """
      [out:json];
      (
        node["amenity"="hospital"](around:500,$lat,$lng);
        node["amenity"="police"](around:500,$lat,$lng);
        node["shop"="mall"](around:500,$lat,$lng);
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
            return {
              "lat": placeLat,
              "lng": placeLng,
            };
          }).toList();

          setState(() {
            if (places.isNotEmpty) {
              safeZoneLocation = LatLng(places[0]["lat"], places[0]["lng"]);
              _fetchRoute();
            }
            isLoading = false;
          });
        } else {
          setState(() {
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

  Future<void> _fetchRoute() async {
    String url = "https://router.project-osrm.org/route/v1/driving/"
        "${playerPosition.longitude},${playerPosition.latitude};"
        "${safeZoneLocation.longitude},${safeZoneLocation.latitude}?overview=full&geometries=geojson";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        List coordinates = data["routes"][0]["geometry"]["coordinates"];
        safeRoute =
            coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();

        _generatePowerUps();
      } else {
        print("Failed to fetch route. Response: ${response.body}");
      }
    } catch (e) {
      print("Error fetching route: $e");
    }
  }

  void _generatePowerUps() {
    powerUps.clear();
    for (int i = 1; i < safeRoute.length - 1; i += 2) {
      powerUps.add(PowerUpMarker(
        position: safeRoute[i],
        type: PowerUpType.points,
        id: i.toString(),
      ));
    }
  }

  void _checkPowerUpCollection() {
    powerUps.removeWhere((powerUp) {
      double distance = Geolocator.distanceBetween(
        playerPosition.latitude,
        playerPosition.longitude,
        powerUp.position.latitude,
        powerUp.position.longitude,
      );

      if (distance < 10) {
        score += 10;
        widget.onScoreUpdate(score);
        return true;
      }
      return false;
    });
  }

  void _checkIfReachedSafeZone() {
    double distance = Geolocator.distanceBetween(
      playerPosition.latitude,
      playerPosition.longitude,
      safeZoneLocation.latitude,
      safeZoneLocation.longitude,
    );

    if (distance < 20) {
      setState(() {
        score += 50;
        widget.onScoreUpdate(score);
        errorMessage = "You reached the Safe Zone!";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Center(child: CircularProgressIndicator())
        : errorMessage.isNotEmpty
            ? Center(
                child: Text(errorMessage,
                    style: TextStyle(color: Colors.red, fontSize: 16)))
            : FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  center: playerPosition,
                  zoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: safeRoute,
                        strokeWidth: 5.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: playerPosition,
                        child: Icon(Icons.person_pin_circle,
                            color: Colors.blue, size: 40),
                      ),
                      Marker(
                        point: safeZoneLocation,
                        child:
                            Icon(Icons.security, color: Colors.green, size: 40),
                      ),
                      ...powerUps.map((powerUp) => Marker(
                            point: powerUp.position,
                            child: Icon(
                              Icons.star,
                              color: Colors.yellow,
                              size: 30,
                            ),
                          )),
                    ],
                  ),
                ],
              );
  }
}

enum PowerUpType { points, speedBoost, shield }

class PowerUpMarker {
  final LatLng position;
  final PowerUpType type;
  final String id;

  PowerUpMarker({required this.position, required this.type, required this.id});
}
