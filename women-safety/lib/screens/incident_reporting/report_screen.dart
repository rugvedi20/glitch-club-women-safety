import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'package:safety_pal/theme/app_theme.dart';
import 'package:safety_pal/widgets/shared_components.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  String selectedIncident = "Harassment";
  double severity = 3;
  bool isSafeNow = true;
  bool submitAnonymously = true;
  bool isSubmitting = false;
  bool _showSuccess = false;

  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController otherIncidentController = TextEditingController();

  double? latitude;
  double? longitude;
  String? locationName;
  bool isLoadingLocation = false;

  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedImages = [];
  final MapController _mapController = MapController();

  late AnimationController _fadeController;

  final List<Map<String, dynamic>> incidentTypes = [
    {"label": "Harassment", "icon": Icons.report_problem_rounded},
    {"label": "Stalking", "icon": Icons.visibility_rounded},
    {"label": "Assault", "icon": Icons.warning_rounded},
    {"label": "Domestic Abuse", "icon": Icons.home_rounded},
    {"label": "Other", "icon": Icons.more_horiz_rounded},
  ];

  final List<String> severityEmojis = ['😌', '😐', '😟', '😰', '🚨'];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeController.forward();
    fetchLocation();
  }

  @override
  void dispose() {
    descriptionController.dispose();
    otherIncidentController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> fetchLocation() async {
    setState(() => isLoadingLocation = true);

    try {
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
      } catch (_) {
        locationName = "Location unavailable";
      }

      setState(() => isLoadingLocation = false);
      _mapController.move(LatLng(latitude!, longitude!), 15);
    } catch (_) {
      setState(() => isLoadingLocation = false);
    }
  }

  Future<void> pickImages() async {
    final List<XFile>? images = await _picker.pickMultiImage(imageQuality: 80);
    if (images == null) return;
    setState(() {
      _selectedImages.addAll(images.map((e) => File(e.path)));
    });
  }

  Future<void> captureImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (image == null) return;
    setState(() => _selectedImages.add(File(image.path)));
  }

  Future<List<String>> uploadImages() async {
    List<String> urls = [];
    const String cloudName = 'dph8dkvr3';
    const String uploadPreset = 'incident-reports';

    for (final image in _selectedImages) {
      try {
        final uri = Uri.parse(
            'https://api.cloudinary.com/v1_1/$cloudName/image/upload');
        final request = http.MultipartRequest('POST', uri);
        request.fields['upload_preset'] = uploadPreset;
        request.fields['folder'] = 'incident-reports';
        request.files
            .add(await http.MultipartFile.fromPath('file', image.path));

        final streamedResponse = await request.send().timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException(
                  'Upload timed out', const Duration(seconds: 30)),
            );

        final response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          urls.add(jsonResponse['secure_url']);
        }
      } catch (_) {
        rethrow;
      }
    }
    return urls;
  }

  Future<void> submitReport() async {
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Location not available. Please wait."),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      String finalIncidentType = selectedIncident == "Other"
          ? otherIncidentController.text.trim()
          : selectedIncident;

      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await uploadImages();
      }

      await FirebaseFirestore.instance.collection('incident_reports').add({
        "incidentType": finalIncidentType,
        "dateTime": DateTime.now().toIso8601String(),
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

      if (mounted) {
        setState(() {
          isSubmitting = false;
          _showSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: $e"),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _showSuccess = false;
      selectedIncident = "Harassment";
      severity = 3;
      isSafeNow = true;
      submitAnonymously = true;
      descriptionController.clear();
      otherIncidentController.clear();
      _selectedImages.clear();
    });
    fetchLocation();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) return _buildSuccessScreen();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildIntroCard()),
                  SliverToBoxAdapter(child: _buildIncidentTypes()),
                  SliverToBoxAdapter(child: _buildDescription()),
                  SliverToBoxAdapter(child: _buildLocationPreview()),
                  SliverToBoxAdapter(child: _buildPhotoUpload()),
                  SliverToBoxAdapter(child: _buildSeveritySlider()),
                  SliverToBoxAdapter(child: _buildSafeToggle()),
                  SliverToBoxAdapter(child: _buildAnonymousToggle()),
                  SliverToBoxAdapter(child: _buildSubmitButton()),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
              if (isSubmitting) _buildLoadingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report an Incident', style: AppTheme.displayMedium),
          const SizedBox(height: 4),
          Text(
            'Help keep someone safe.',
            style: AppTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.coralLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(color: AppTheme.coral.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: const Icon(Icons.favorite_rounded,
                  color: AppTheme.primaryRed, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("You're helping protect someone.",
                      style: AppTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    "Your report will be reviewed securely.",
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentTypes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Incident Type', style: AppTheme.headlineMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: incidentTypes.map((item) {
              final bool isSelected = selectedIncident == item["label"];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => selectedIncident = item["label"]);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryRed.withOpacity(0.1)
                        : AppTheme.cardWhite,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryRed
                          : AppTheme.divider,
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected ? AppTheme.cardShadow : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item["icon"],
                        size: 16,
                        color: isSelected
                            ? AppTheme.primaryRed
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item["label"],
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppTheme.primaryRed
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
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
                fillColor: AppTheme.cardWhite,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What happened?', style: AppTheme.headlineMedium),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText:
                  "Describe what you observed. Share only what you're comfortable with.",
              filled: true,
              fillColor: AppTheme.cardWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                borderSide: const BorderSide(color: AppTheme.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                borderSide: const BorderSide(color: AppTheme.divider),
              ),
              counterStyle: AppTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPreview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location', style: AppTheme.headlineMedium),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryRed.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSM),
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            color: AppTheme.primaryRed, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: isLoadingLocation
                            ? Text("Fetching location...",
                                style: AppTheme.bodyMedium)
                            : Text(
                                locationName ?? "Location not available",
                                style: AppTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded,
                            color: AppTheme.textTertiary, size: 20),
                        onPressed: fetchLocation,
                      ),
                    ],
                  ),
                ),
                if (latitude != null && longitude != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppTheme.radiusLG),
                      bottomRight: Radius.circular(AppTheme.radiusLG),
                    ),
                    child: SizedBox(
                      height: 180,
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
                            urlTemplate:
                                "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
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
                                  color: AppTheme.primaryRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoUpload() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Photos (Optional)', style: AppTheme.headlineMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: pickImages,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.photo_library_rounded,
                            color: AppTheme.textSecondary, size: 20),
                        const SizedBox(width: 8),
                        Text('Gallery',
                            style: AppTheme.labelLarge.copyWith(
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: captureImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_rounded,
                            color: AppTheme.textSecondary, size: 20),
                        const SizedBox(width: 8),
                        Text('Camera',
                            style: AppTheme.labelLarge.copyWith(
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
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
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSM),
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
                          setState(
                              () => _selectedImages.removeAt(index));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeveritySlider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Severity Level', style: AppTheme.headlineMedium),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (index) {
                    final isActive = (index + 1) <= severity.round();
                    return Column(
                      children: [
                        Text(
                          severityEmojis[index],
                          style: TextStyle(
                            fontSize: isActive ? 28 : 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w400,
                            color: isActive
                                ? AppTheme.primaryRed
                                : AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.primaryRed,
                    inactiveTrackColor: AppTheme.divider,
                    thumbColor: AppTheme.primaryRed,
                    overlayColor: AppTheme.primaryRed.withOpacity(0.12),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: severity,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() => severity = value);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Low Concern', style: AppTheme.bodySmall),
                    Text('Very Serious', style: AppTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Are they safe right now?',
                      style: AppTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('This helps assess urgency.',
                      style: AppTheme.bodySmall),
                ],
              ),
            ),
            Switch(
              value: isSafeNow,
              onChanged: (value) => setState(() => isSafeNow = value),
              activeColor: AppTheme.primaryRed,
              activeTrackColor: AppTheme.coralLight,
              inactiveThumbColor: AppTheme.iconGrey,
              inactiveTrackColor: AppTheme.divider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnonymousToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Submit Anonymously',
                      style: AppTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('Your identity will not be shared.',
                      style: AppTheme.bodySmall),
                ],
              ),
            ),
            Switch(
              value: submitAnonymously,
              onChanged: (value) =>
                  setState(() => submitAnonymously = value),
              activeColor: AppTheme.primaryRed,
              activeTrackColor: AppTheme.coralLight,
              inactiveThumbColor: AppTheme.iconGrey,
              inactiveTrackColor: AppTheme.divider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: SPPrimaryButton(
        text: isLoadingLocation
            ? 'Getting Location...'
            : latitude == null
                ? 'Waiting for Location...'
                : 'Submit Report',
        onPressed: (isSubmitting || isLoadingLocation || latitude == null)
            ? null
            : submitReport,
        isLoading: isSubmitting,
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            boxShadow: AppTheme.elevatedShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
                ),
              ),
              const SizedBox(height: 20),
              Text('Submitting your report...',
                  style: AppTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.successLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppTheme.success,
                    size: 56,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Report Submitted\nSuccessfully',
                style: AppTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Thank you for helping keep someone safe.\nYour report will be reviewed securely.',
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SPPrimaryButton(
                text: 'Back to Home',
                onPressed: _resetForm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
