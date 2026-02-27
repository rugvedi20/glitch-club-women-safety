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
          setState(() {
            heatmapPoints = data.map((point) {
              double lat = double.tryParse(point['Latitude'].toString()) ?? 0.0;
              double lon =
                  double.tryParse(point['Longitude'].toString()) ?? 0.0;
              double riskWeight = getRiskWeight(point['Risk Level'].toString());

              return WeightedLatLng(LatLng(lat, lon), riskWeight);
            }).toList();
          });
          print("Heatmap data updated!");
        } else {
          print("No data received from API");
        }
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Risky Zones")),
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(18.5018, 73.8636),
          zoom: 12.0,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          ),
          if (heatmapPoints.isNotEmpty)
            HeatMapLayer(
              heatMapDataSource: InMemoryHeatMapDataSource(data: heatmapPoints),
              heatMapOptions: HeatMapOptions(
                radius: 100,
                minOpacity: 0.9,
                gradient: {
                  0.5: Colors.yellow, // Low Risk
                  0.75: Colors.orange, // Medium Risk
                  1.0: Colors.purple, // High Risk
                },
              ),
            ),
        ],
      ),
    );
  }
}
