import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for SOS emergency record stored in Firestore
class SOSRecord {
  final String? id;
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final double? latitude;
  final double? longitude;
  final String triggerType; // 'shake', 'manual_button', 'api'
  final String status; // 'active', 'cancelled', 'resolved'
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? audioPath;
  final List<String> guardiansNotified;
  final bool adminAlertsent;
  final String? notes;

  SOSRecord({
    this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    this.latitude,
    this.longitude,
    required this.triggerType,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.audioPath,
    required this.guardiansNotified,
    required this.adminAlertsent,
    this.notes,
  });

  /// Convert SOSRecord to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'latitude': latitude,
      'longitude': longitude,
      'triggerType': triggerType,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'audioPath': audioPath,
      'guardiansNotified': guardiansNotified,
      'adminAlertSent': adminAlertsent,
      'notes': notes,
    };
  }

  /// Create SOSRecord from Firestore document
  factory SOSRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SOSRecord(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userPhone: data['userPhone'] ?? '',
      latitude: data['latitude'],
      longitude: data['longitude'],
      triggerType: data['triggerType'] ?? 'unknown',
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      audioPath: data['audioPath'],
      guardiansNotified: List<String>.from(data['guardiansNotified'] ?? []),
      adminAlertsent: data['adminAlertSent'] ?? false,
      notes: data['notes'],
    );
  }
}
