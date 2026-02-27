import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing user data in Firestore.
class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user data by UID.
  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// Get user data stream (real-time updates).
  static Stream<DocumentSnapshot> getUserDataStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Update user information.
  static Future<void> updateUser({
    required String uid,
    String? name,
    String? phone,
    int? age,
    String? gender,
    String? bloodGroup,
    String? address,
    String? location,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;
      if (age != null) updateData['age'] = age;
      if (gender != null) updateData['gender'] = gender;
      if (bloodGroup != null) updateData['blood_grp'] = bloodGroup;
      if (address != null) updateData['address'] = address;
      if (location != null) updateData['location'] = location;

      await _firestore.collection('users').doc(uid).update(updateData);
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  /// Add guardian to user's guardians list.
  static Future<void> addGuardian({
    required String uid,
    required String guardianName,
    required String guardianPhone,
    required String guardianEmail,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'guardians': FieldValue.arrayUnion([
          {
            'name': guardianName,
            'phone': guardianPhone,
            'email': guardianEmail,
          }
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding guardian: $e');
      rethrow;
    }
  }

  /// Remove guardian from user's guardians list.
  static Future<void> removeGuardian({
    required String uid,
    required Map<String, dynamic> guardian,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'guardians': FieldValue.arrayRemove([guardian]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error removing guardian: $e');
      rethrow;
    }
  }

  /// Delete user account and data.
  static Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }
}
