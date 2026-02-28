import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({Key? key}) : super(key: key);

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  String selectedIncident = "Harassment";
  DateTime selectedDateTime = DateTime.now();
  double severity = 3;
  bool isSafeNow = true;
  bool submitAnonymously = true;
  bool isSubmitting = false; // Track submission state

  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController otherIncidentController = TextEditingController();

  double? latitude;
  double? longitude;
  String? locationName; // 👈 Human-readable location
  bool isLoadingLocation = false;

  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];

  final MapController _mapController = MapController();

  final List<Map<String, dynamic>> incidentTypes = [
    {"label": "Harassment", "icon": Icons.report_problem},
    {"label": "Stalking", "icon": Icons.visibility},
    {"label": "Assault", "icon": Icons.warning},
    {"label": "Domestic Abuse", "icon": Icons.home_filled},
    {"label": "Other", "icon": Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    fetchLocation();
  }

  Future<void> fetchLocation() async {
    setState(() {
      isLoadingLocation = true;
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => isLoadingLocation = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => isLoadingLocation = false);
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    latitude = position.latitude;
    longitude = position.longitude;

    // 🔁 Reverse geocoding: lat/lng -> place name
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude!, longitude!);

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        locationName =
            "${p.locality ?? ''}, ${p.administrativeArea ?? ''}, ${p.country ?? ''}";
      } else {
        locationName = "Unknown location";
      }
    } catch (e) {
      locationName = "Location unavailable";
    }

    setState(() {
      isLoadingLocation = false;
    });

    // Move map to new location
    _mapController.move(LatLng(latitude!, longitude!), 15);
  }

  Future<void> pickImages() async {
    final List<XFile>? images = await _picker.pickMultiImage(imageQuality: 80);
    if (images == null) return;

    setState(() {
      _selectedImages.addAll(images.map((e) => File(e.path)));
    });
  }

  Future<List<String>> uploadImages() async {
    List<String> urls = [];
    
    // Cloudinary credentials (get from cloudinary.com)
    const String cloudName = 'dph8dkvr3'; // Replace with your cloud name
    const String uploadPreset = 'incident-reports'; // Create unsigned preset in Cloudinary

    for (final image in _selectedImages) {
      try {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';

        print("⬆️ Uploading to Cloudinary: $fileName");
  
        // Create multipart request
        final uri = Uri.parse(
            'https://api.cloudinary.com/v1_1/$cloudName/image/upload');
        
        final request = http.MultipartRequest('POST', uri);
        request.fields['upload_preset'] = uploadPreset;
        request.fields['folder'] = 'incident-reports';
        request.fields['public_id'] = fileName.replaceAll('.', '_');
        
        // Add image file
        request.files.add(
          await http.MultipartFile.fromPath('file', image.path),
        );

        print("📤 Sending request to Cloudinary...");
        
        // Send request with timeout
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException(
                'Image upload timed out after 30 seconds',
                const Duration(seconds: 30));
          },
        );

        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          final downloadUrl = jsonResponse['secure_url'];
          urls.add(downloadUrl);
          print("✅ Upload successful: $fileName");
          print("🔗 URL: $downloadUrl");
        } else {
          throw Exception(
              'Cloudinary upload failed: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print("❌ Upload failed for image ${image.path}: $e");
        rethrow;
      }
    }

    return urls;
}

  Future<void> captureImage() async {
  final XFile? image = await _picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 80,
  );

  if (image == null) return;

  setState(() {
    _selectedImages.add(File(image.path));
  });
}



   Future<void> submitReport() async {
  print("📤 submitReport() called");
  
  if (latitude == null || longitude == null) {
    print("❌ Location not available: lat=$latitude, lng=$longitude");
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("❌ Location not available. Please wait for location to load."),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    return;
  }

  print("✅ Location available: lat=$latitude, lng=$longitude");

  try {
    String finalIncidentType = selectedIncident == "Other"
        ? otherIncidentController.text.trim()
        : selectedIncident;

    List<String> imageUrls = [];

    // ⚠️ If user selected images, MUST upload them successfully
    if (_selectedImages.isNotEmpty) {
      try {
        print("📸 Uploading ${_selectedImages.length} image(s)...");
        imageUrls = await uploadImages();
        print("✅ All images uploaded successfully");
      } catch (e) {
        print("❌ Image upload failed: $e");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Image upload failed: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        // ⛔ STOP submission if images fail
        return;
      }
    }

    print("📤 Submitting report to Firestore...");
    print("📝 Report details: type=$finalIncidentType, hasImages=${imageUrls.isNotEmpty}");
    
    final docRef = await FirebaseFirestore.instance
        .collection('incident_reports')
        .add({
      "incidentType": finalIncidentType,
      "dateTime": selectedDateTime.toIso8601String(),
      "description": descriptionController.text.trim(),
      "severity": severity,
      "isSafeNow": isSafeNow,
      "submitAnonymously": submitAnonymously,
      "location": GeoPoint(latitude!, longitude!),
      "locationName": locationName,
      "reportedBy": "third_person",
      "images": imageUrls,
      "status": "pending",
      "submittedAt": FieldValue.serverTimestamp(),
    });
    
    print("✅ Report saved with ID: ${docRef.id}");

    if (!mounted) return;

    print("✅ Report submitted successfully");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Report submitted successfully"),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);

    } catch (e) {
      print("❌ Submit report failed: $e");
  
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to submit report: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  
  } // end of submitReport
  
    @override
    Widget build(BuildContext context) {
  final themeColor = const Color(0xFF6A5ACD);

  return Scaffold(
    appBar: AppBar(
      title: const Text("Incident Report (3rd Person)"),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF6F7FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "You’re helping keep someone safe ",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Report what you know. Your information is handled with care and privacy.",
              style: TextStyle(color: Colors.black54),
            ),

            const SizedBox(height: 20),

            const Text("Incident Type", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: incidentTypes.map((item) {
                final bool isSelected = selectedIncident == item["label"];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item["icon"], size: 18),
                      const SizedBox(width: 6),
                      Text(item["label"]),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: themeColor.withOpacity(0.2),
                  onSelected: (_) {
                    setState(() {
                      selectedIncident = item["label"];
                    });
                  },
                );
              }).toList(),
            ),

            if (selectedIncident == "Other") ...[
              const SizedBox(height: 12),
              TextField(
                controller: otherIncidentController,
                decoration: InputDecoration(
                  labelText: "Please specify the incident type",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            const SizedBox(height: 20),

            const Text("What happened?", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Describe what you observed. Share only what you’re comfortable with.",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            // 🗺️ MAP PREVIEW
            const SizedBox(height: 20),
            const Text("Location Preview", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: isLoadingLocation
                        ? const Text("Fetching location...")
                        : Text(
                            locationName ?? "Location not available",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: fetchLocation,
                    ),
                  ),
                  if (latitude != null && longitude != null)
                    SizedBox(
                      height: 220,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(latitude!, longitude!),
                          initialZoom: 15,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                            userAgentPackageName: "com.example.safety_pal",
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(latitude!, longitude!),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_pin,
                                  size: 40,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text("Add Photos (Optional)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Gallery"),
                    onPressed: pickImages,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Camera"),
                    onPressed: captureImage,
                  ),
                ),
              ],
            ),

            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedImages.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImages[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                            });
                          },
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],

            const SizedBox(height: 20),

            const Text("Severity Level", style: TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: severity,
              min: 1,
              max: 5,
              divisions: 4,
              label: severity.round().toString(),
              onChanged: (value) {
                setState(() {
                  severity = value;
                });
              },
            ),
            const Text("1 = Low concern, 5 = Very serious", style: TextStyle(color: Colors.black54)),

            const SizedBox(height: 20),

            SwitchListTile(
              title: const Text("Are they safe right now?"),
              subtitle: Text(
                isSafeNow
                    ? "Good. You can continue calmly."
                    : "If not, we recommend using SOS immediately.",
              ),
              value: isSafeNow,
              onChanged: (value) {
                setState(() {
                  isSafeNow = value;
                });
              },
            ),

            const SizedBox(height: 20),

            SwitchListTile(
              title: const Text("Submit Anonymously"),
              subtitle: const Text("Your identity will not be shared."),
              value: submitAnonymously,
              onChanged: (value) {
                setState(() {
                  submitAnonymously = value;
                });
              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: themeColor.withOpacity(0.5),
                ),
                onPressed: (isSubmitting || isLoadingLocation || latitude == null)
                    ? null
                    : () async {
                        setState(() => isSubmitting = true);
                        print("🔴 Submit button pressed");
                        await submitReport();
                        if (mounted) {
                          setState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : isLoadingLocation
                        ? const Text(
                            "Getting Location...",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          )
                        : latitude == null
                            ? const Text(
                                "Waiting for Location...",
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              )
                            : const Text(
                                "Submit Report",
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}