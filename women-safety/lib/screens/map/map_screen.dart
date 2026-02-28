import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:safety_pal/theme/app_theme.dart';
import 'package:safety_pal/widgets/shared_components.dart';
import 'package:safety_pal/screens/map/navigation_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 0;

  // Safe zones
  List<Map<String, dynamic>> safeZones = [];
  bool isLoadingSafeZones = false;

  // Risky areas
  List<WeightedLatLng> heatmapPoints = [];
  bool isLoadingRisky = false;
  bool _inRiskyZone = false;

  Position? userLocation;
  final MapController _mapController = MapController();
  String? selectedFilter; // null = all

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _activeTab = _tabController.index);
    });
    _getUserLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => userLocation = position);

      _fetchSafeZones(position.latitude, position.longitude);
      _fetchHeatmapData();
    } catch (_) {}
  }

  Future<void> _fetchSafeZones(double lat, double lng) async {
    setState(() => isLoadingSafeZones = true);

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
          List<Map<String, dynamic>> places = elements
              .where((place) => place.containsKey("tags"))
              .map((place) {
            double placeLat = place['lat'];
            double placeLng = place['lon'];
            double distance =
                _calculateDistance(lat, lng, placeLat, placeLng);
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
          places.sort((a, b) => a['distance'].compareTo(b['distance']));
          setState(() {
            safeZones = places;
            isLoadingSafeZones = false;
          });
        } else {
          setState(() {
            safeZones = [];
            isLoadingSafeZones = false;
          });
        }
      }
    } catch (_) {
      setState(() => isLoadingSafeZones = false);
    }
  }

  Future<void> _fetchHeatmapData() async {
    setState(() => isLoadingRisky = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('incident_reports')
          .where('status', isEqualTo: 'validated')
          // .where('active', isEqualTo: true)
          .get();

      print('Fetched ${snapshot.docs.length} validated incidents from Firestore');

      List<WeightedLatLng> points = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final location = data['location'];
        if (location == null) continue;

        final double lat = location.latitude;
        final double lng = location.longitude;
        final double intensity = 1.0;

        points.add(WeightedLatLng(LatLng(lat, lng), intensity));
      }

      setState(() {
        heatmapPoints = points;
        isLoadingRisky = false;
      });
      print('Total heatmap points: ${points.length}');
    } catch (e) {
      print('Error fetching heatmap data: $e');
      setState(() => isLoadingRisky = false);
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0;
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLon = (lon2 - lon1) * (pi / 180);
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            (sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'police':
        return Icons.local_police_rounded;
      default:
        return Icons.shopping_bag_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'hospital':
        return AppTheme.danger;
      case 'police':
        return AppTheme.info;
      default:
        return AppTheme.warning;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'hospital':
        return 'Hospital';
      case 'police':
        return 'Police Station';
      default:
        return 'Shopping Mall';
    }
  }

  List<Map<String, dynamic>> get filteredZones {
    if (selectedFilter == null) return safeZones;
    return safeZones.where((z) => z['type'] == selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildToggleTabs(),
            if (_inRiskyZone && _activeTab == 1) _buildRiskyAlert(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildSafeZonesView(),
                  _buildRiskyAreasView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text('Map', style: AppTheme.displayMedium),
          ),
          if (_activeTab == 0)
            PopupMenuButton<String?>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: const Icon(Icons.filter_list_rounded,
                    color: AppTheme.textSecondary, size: 20),
              ),
              onSelected: (value) {
                setState(() => selectedFilter = value);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: null,
                  child: Text('All Types'),
                ),
                const PopupMenuItem(
                  value: 'hospital',
                  child: Text('Hospitals'),
                ),
                const PopupMenuItem(
                  value: 'police',
                  child: Text('Police Stations'),
                ),
                const PopupMenuItem(
                  value: 'mall',
                  child: Text('Malls'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildToggleTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            boxShadow: AppTheme.cardShadow,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textTertiary,
          labelStyle: AppTheme.labelLarge,
          unselectedLabelStyle: AppTheme.labelMedium,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_rounded,
                      size: 18,
                      color: _activeTab == 0
                          ? AppTheme.safeGreen
                          : AppTheme.textTertiary),
                  const SizedBox(width: 6),
                  const Text('Safe Zones'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_rounded,
                      size: 18,
                      color: _activeTab == 1
                          ? AppTheme.riskyRed
                          : AppTheme.textTertiary),
                  const SizedBox(width: 6),
                  const Text('Risky Areas'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskyAlert() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.dangerLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded,
              color: AppTheme.danger, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'You are entering a high-risk area.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.danger,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              _tabController.animateTo(0);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.danger,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: const Text(
                'Find Safe Zone',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _inRiskyZone = false),
            child: const Icon(Icons.close, size: 18, color: AppTheme.danger),
          ),
        ],
      ),
    );
  }

  // ── SAFE ZONES VIEW ──────────────────────────────────────────────────────
  Widget _buildSafeZonesView() {
    if (isLoadingSafeZones) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRed),
      );
    }

    if (filteredZones.isEmpty) {
      return SPEmptyState(
        icon: Icons.shield_outlined,
        title: 'No Safe Zones nearby',
        subtitle:
            'We couldn\'t find safe zones in your area. Try refreshing.',
        buttonText: 'Refresh',
        onButtonTap: () {
          if (userLocation != null) {
            _fetchSafeZones(
                userLocation!.latitude, userLocation!.longitude);
          }
        },
      );
    }

    return Column(
      children: [
        // Map view
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: userLocation != null
                      ? LatLng(userLocation!.latitude,
                          userLocation!.longitude)
                      : const LatLng(18.5018, 73.8636),
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    userAgentPackageName: 'com.safetypal.app',
                  ),
                  if (userLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(userLocation!.latitude,
                              userLocation!.longitude),
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.info.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.my_location,
                                color: AppTheme.info, size: 22),
                          ),
                        ),
                        ...filteredZones.map(
                          (zone) => Marker(
                            point: LatLng(zone['lat'], zone['lng']),
                            width: 36,
                            height: 36,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.safeGreen,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.safeGreen
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _getTypeIcon(zone['type']),
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        // Safe zone list
        Expanded(
          flex: 2,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            itemCount: filteredZones.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final zone = filteredZones[index];
              final typeColor = _getTypeColor(zone['type']);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusLG),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: Icon(_getTypeIcon(zone['type']),
                          color: typeColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone['name'],
                            style: AppTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getTypeLabel(zone['type']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${zone['distance'].toStringAsFixed(1)} km',
                                style: AppTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NavigationScreen(
                              destinationLat: zone['lat'],
                              destinationLng: zone['lng'],
                              placeName: zone['name'],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull),
                        ),
                        child: const Text(
                          'Navigate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── RISKY AREAS VIEW ─────────────────────────────────────────────────────
  Widget _buildRiskyAreasView() {
    if (isLoadingRisky && heatmapPoints.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRed),
      );
    }

    if (heatmapPoints.isEmpty) {
      return SPEmptyState(
        icon: Icons.map_outlined,
        title: 'No Risky Areas data',
        subtitle:
            'Risk data is not available for your area at the moment.',
        buttonText: 'Refresh',
        onButtonTap: _fetchHeatmapData,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: userLocation != null
                ? LatLng(
                    userLocation!.latitude, userLocation!.longitude)
                : const LatLng(18.5018, 73.8636),
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              userAgentPackageName: 'com.safetypal.app',
            ),
            if (heatmapPoints.isNotEmpty)
              HeatMapLayer(
                heatMapDataSource:
                    InMemoryHeatMapDataSource(data: heatmapPoints),
                heatMapOptions: HeatMapOptions(
                  radius: 100,
                  minOpacity: 0.6,
                  gradient: {
                    0.3: const MaterialColor(0xFFFF9800, <int, Color>{}) ,
                    0.6: const MaterialColor(0xFFFF5722, <int, Color>{}),
                    1.0: const MaterialColor(0xFFD32F2F, <int, Color>{}),
                  },
                ),
              ),
            if (userLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                        userLocation!.latitude, userLocation!.longitude),
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.info.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.my_location,
                          color: AppTheme.info, size: 22),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
