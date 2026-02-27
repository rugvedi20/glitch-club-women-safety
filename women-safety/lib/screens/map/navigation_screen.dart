import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NavigationScreen extends StatefulWidget {
  final double destinationLat;
  final double destinationLng;
  final String placeName;

  const NavigationScreen({
    Key? key,
    required this.destinationLat,
    required this.destinationLng,
    required this.placeName,
  }) : super(key: key);

  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  Position? _userLocation;
  List<LatLng> routePoints = [];
  bool isLoading = true;
  bool isMapInitialized = false;
  String errorMessage = "";
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getUserLocation();
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
        _userLocation = position;
      });

      if (isMapInitialized) {
        _mapController.move(
            LatLng(position.latitude, position.longitude), 14.0);
      }

      _fetchRoute(position.latitude, position.longitude);
      _startLocationUpdates();
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error fetching location: $e";
      });
    }
  }

  void _startLocationUpdates() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((Position position) {
      setState(() {
        _userLocation = position;
      });

      if (isMapInitialized) {
        // Preserve the current zoom level
        double currentZoom = _mapController.camera.zoom;
        _mapController.move(
            LatLng(position.latitude, position.longitude), currentZoom);
      }

      _fetchRoute(position.latitude, position.longitude);
    });
  }

  Future<void> _fetchRoute(double userLat, double userLng) async {
    String url =
        "https://router.project-osrm.org/route/v1/driving/$userLng,$userLat;${widget.destinationLng},${widget.destinationLat}?overview=full&geometries=geojson";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey("routes") &&
            data["routes"].isNotEmpty &&
            data["routes"][0]["geometry"] != null) {
          List coordinates = data["routes"][0]["geometry"]["coordinates"];

          setState(() {
            routePoints =
                coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
            errorMessage = "No route found.";
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMessage = "Failed to fetch route (API Error).";
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Error fetching route: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Navigate to ${widget.placeName}")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Text(errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 16)),
                )
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _userLocation != null
                        ? LatLng(
                            _userLocation!.latitude, _userLocation!.longitude)
                        : const LatLng(
                            0.0, 0.0), // Default position to avoid errors
                    minZoom: 5.0,
                    onMapReady: () {
                      setState(() {
                        isMapInitialized = true;
                      });

                      if (_userLocation != null) {
                        // Use the initial zoom level instead of setting a fixed zoom
                        double initialZoom = _mapController.camera.zoom;
                        _mapController.move(
                            LatLng(_userLocation!.latitude,
                                _userLocation!.longitude),
                            initialZoom);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    ),
                    MarkerLayer(
                      markers: [
                        if (_userLocation != null)
                          Marker(
                            width: 50.0,
                            height: 50.0,
                            point: LatLng(_userLocation!.latitude,
                                _userLocation!.longitude),
                            child: Builder(
                              builder: (ctx) => const Icon(
                                  Icons.person_pin_circle,
                                  color: Colors.blue,
                                  size: 40),
                            ),
                          ),
                        Marker(
                          width: 50.0,
                          height: 50.0,
                          point: LatLng(
                              widget.destinationLat, widget.destinationLng),
                          child: Builder(
                            builder: (ctx) => const Icon(Icons.location_on,
                                color: Colors.red, size: 40),
                          ),
                        ),
                      ],
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          strokeWidth: 4.0,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
