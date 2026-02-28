// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
// import 'package:http/http.dart' as http;

// class HeatMapScreen extends StatefulWidget {
//   @override
//   _HeatMapScreenState createState() => _HeatMapScreenState();
// }

// class _HeatMapScreenState extends State<HeatMapScreen> {
//   List<WeightedLatLng> heatmapPoints = [];

//   @override
//   void initState() {
//     super.initState();
//     fetchHeatmapData();
//   }

//   Future<void> fetchHeatmapData() async {
//     try {
//       final response = await http.get(Uri.parse('http://10.20.1.190:5000/area-risk'));

//       if (response.statusCode == 200) {
//         List<dynamic> data = json.decode(response.body);

//         if (data.isNotEmpty) {
//           setState(() {
//             heatmapPoints = data.map((point) {
//               double lat = double.tryParse(point['Latitude'].toString()) ?? 0.0;
//               double lon = double.tryParse(point['Longitude'].toString()) ?? 0.0;
//               double riskWeight = getRiskWeight(point['Risk Level'].toString());

//               return WeightedLatLng(LatLng(lat, lon), riskWeight);
//             }).toList();
//           });
//           print("Heatmap data updated!");
//         } else {
//           print("No data received from API");
//         }
//       } else {
//         print("Error: ${response.statusCode}");
//       }
//     } catch (e) {
//       print("Error fetching data: $e");
//     }
//   }

//   double getRiskWeight(String riskLevel) {
//     switch (riskLevel.toLowerCase().trim()) {
//       case 'low':
//         return 0.3;
//       case 'medium':
//         return 0.6;
//       case 'high':
//         return 1.0;
//       default:
//         return 0.0;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Risky Zones")),
//       body: FlutterMap(
//         options: MapOptions(
//           center: LatLng(18.559, 73.7898),
//           zoom: 12.0,
//         ),
//         children: [
//           TileLayer(
//             urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
//           ),
//           if (heatmapPoints.isNotEmpty)
//             HeatMapLayer(
//               heatMapDataSource: InMemoryHeatMapDataSource(data: heatmapPoints),
//               heatMapOptions: HeatMapOptions(
//                 radius: 50,
//                 minOpacity: 20,
//                 gradient: {
//                   0.3: Colors.purple,  // Low Risk
//                   0.6: Colors.purple, // Medium Risk
//                   1.0: Colors.purple,    // High Risk
//                 },
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:http/http.dart' as http;

// entry point is handled by main.dart; no standalone runApp here

class RiskyAreasMapScreen extends StatefulWidget {
  const RiskyAreasMapScreen({super.key});

  @override
  _RiskyAreasMapScreenState createState() => _RiskyAreasMapScreenState();
}

class _RiskyAreasMapScreenState extends State<RiskyAreasMapScreen> {
  List<WeightedLatLng> heatmapPoints = [];
  List<Marker> validatedMarkers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchHeatmapData();
  }

  Future<void> fetchHeatmapData() async {
    try {
      final response =
          await http.get(Uri.parse('http://10.183.90.99:5000/area-risk'));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);

        if (data.isNotEmpty) {
          final List<WeightedLatLng> points = [];
          final List<Marker> markers = [];

          for (final point in data) {
            double lat = double.tryParse(point['Latitude'].toString()) ?? 0.0;
            double lon = double.tryParse(point['Longitude'].toString()) ?? 0.0;
            String riskLevel = (point['Risk Level'] ?? '').toString();
            String status = (point['Status'] ?? '').toString().toLowerCase().trim();

            double riskWeight = getRiskWeight(riskLevel);
            print('[HEATMAP] Point: lat=$lat, lon=$lon, risk=$riskLevel, status=$status, weight=$riskWeight');
            points.add(WeightedLatLng(LatLng(lat, lon), riskWeight));

            // Add a pin marker for ALL points (debug)
            markers.add(
              Marker(
                point: LatLng(lat, lon),
                width: 40,
                height: 40,
                child: Icon(
                  Icons.location_on,
                  color: _getRiskColor(riskLevel),
                  size: 36,
                ),
              ),
            );
          }

          setState(() {
            heatmapPoints = points;
            validatedMarkers = markers;
            _isLoading = false;
          });
          print('[HEATMAP] Total points: ${points.length}, validated markers: ${markers.length}');
          // Log bounding box to verify spread
          if (points.isNotEmpty) {
            final lats = data.map((p) => double.tryParse(p['Latitude'].toString()) ?? 0.0).toList();
            final lons = data.map((p) => double.tryParse(p['Longitude'].toString()) ?? 0.0).toList();
            lats.sort();
            lons.sort();
            print('[HEATMAP] Lat range: ${lats.first} → ${lats.last}');
            print('[HEATMAP] Lon range: ${lons.first} → ${lons.last}');
          }
        } else {
          setState(() => _isLoading = false);
          print("No data received from API");
        }
      } else {
        setState(() => _isLoading = false);
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error fetching data: $e");
    }
  }

  double getRiskWeight(String riskLevel) {
    switch (riskLevel.toLowerCase().trim()) {
      case 'low':
        return 0.3;
      case 'medium':
        return 0.6;
      case 'high':
        return 1.0;
      default:
        return 0.0;
    }
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase().trim()) {
      case 'low':
        return Colors.yellow.shade700;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Risky Zones")),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(18.5018, 73.8636),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              ),
              // if (heatmapPoints.isNotEmpty)
              //   HeatMapLayer(
              //     heatMapDataSource:
              //         InMemoryHeatMapDataSource(data: heatmapPoints),
              //     heatMapOptions: HeatMapOptions(
              //       radius: 30,
              //       minOpacity: 0.5,
              //       gradient: {
              //         0.5: Colors.yellow, // Low Risk
              //         0.75: Colors.orange, // Medium Risk
              //         1.0: Colors.purple, // High Risk
              //       },
              //     ),
              //   ),
              if (validatedMarkers.isNotEmpty)
                MarkerLayer(markers: validatedMarkers),
            ],
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
