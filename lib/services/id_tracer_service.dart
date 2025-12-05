import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alumni_system/models/id_tracer_model.dart';

class IdTracerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit employment record
  Future<void> submitEmploymentRecord(EmploymentRecord record) async {
    try {
      // Check if user already has a record
      final existingRecord = await getEmploymentRecordByUserId(record.userId);
      
      if (existingRecord != null) {
        // Update existing record
        await _firestore
            .collection('employment_records')
            .doc(existingRecord.id)
            .update(record.copyWith(lastUpdated: DateTime.now()).toFirestore());
      } else {
        // Create new record
        await _firestore
            .collection('employment_records')
            .doc(record.id)
            .set(record.toFirestore());
      }
    } catch (e) {
      throw Exception('Error submitting employment record: $e');
    }
  }

  /// Get employment record by user ID
  Future<EmploymentRecord?> getEmploymentRecordByUserId(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('employment_records')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return EmploymentRecord.fromFirestore(snapshot.docs.first);
    } catch (e) {
      throw Exception('Error fetching employment record: $e');
    }
  }

  /// Get current user's employment record
  Future<EmploymentRecord?> getCurrentUserRecord() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return getEmploymentRecordByUserId(user.uid);
  }

  /// Get all employment records (for admin)
  Future<List<EmploymentRecord>> getAllEmploymentRecords({int limit = 100}) async {
    try {
      final snapshot = await _firestore
          .collection('employment_records')
          .orderBy('submittedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => EmploymentRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error fetching all employment records: $e');
    }
  }

  /// Get employment records by status
  Future<List<EmploymentRecord>> getRecordsByStatus(String status) async {
    try {
      final snapshot = await _firestore
          .collection('employment_records')
          .where('employmentStatus', isEqualTo: status)
          .orderBy('submittedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => EmploymentRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error fetching records by status: $e');
    }
  }

  /// Search employment records (for admin)
  Future<List<EmploymentRecord>> searchRecords(String query) async {
    try {
      // Get all records first (Firestore doesn't support full-text search easily)
      final allRecords = await getAllEmploymentRecords(limit: 500);
      
      // Filter in memory
      final lowerQuery = query.toLowerCase();
      return allRecords.where((record) {
        return record.userName.toLowerCase().contains(lowerQuery) ||
            record.userEmail.toLowerCase().contains(lowerQuery) ||
            record.schoolId.toLowerCase().contains(lowerQuery) ||
            (record.companyName?.toLowerCase().contains(lowerQuery) ?? false) ||
            (record.position?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    } catch (e) {
      throw Exception('Error searching records: $e');
    }
  }

  /// Filter records by multiple criteria
  Future<List<EmploymentRecord>> filterRecords({
    String? employmentStatus,
    String? industry,
    String? employmentType,
    String? province,
    String? verificationStatus,
  }) async {
    try {
      Query query = _firestore.collection('employment_records');

      if (employmentStatus != null && employmentStatus.isNotEmpty) {
        query = query.where('employmentStatus', isEqualTo: employmentStatus);
      }

      if (verificationStatus != null && verificationStatus.isNotEmpty) {
        query = query.where('verificationStatus', isEqualTo: verificationStatus);
      }

      final snapshot = await query.orderBy('submittedAt', descending: true).get();
      var records = snapshot.docs
          .map((doc) => EmploymentRecord.fromFirestore(doc))
          .toList();

      // Filter in memory for fields that might not have indexes
      if (industry != null && industry.isNotEmpty) {
        records = records.where((r) => r.industry == industry).toList();
      }

      if (employmentType != null && employmentType.isNotEmpty) {
        records = records.where((r) => r.employmentType == employmentType).toList();
      }

      if (province != null && province.isNotEmpty) {
        records = records.where((r) => r.province == province).toList();
      }

      return records;
    } catch (e) {
      throw Exception('Error filtering records: $e');
    }
  }

  /// Verify employment record (admin only)
  Future<void> verifyRecord(String recordId, String adminId, {String? notes}) async {
    try {
      await _firestore.collection('employment_records').doc(recordId).update({
        'verificationStatus': 'Verified',
        'verifiedBy': adminId,
        'verifiedAt': FieldValue.serverTimestamp(),
        'notes': notes,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error verifying record: $e');
    }
  }

  /// Reject employment record (admin only)
  Future<void> rejectRecord(String recordId, String adminId, {String? notes}) async {
    try {
      await _firestore.collection('employment_records').doc(recordId).update({
        'verificationStatus': 'Rejected',
        'verifiedBy': adminId,
        'verifiedAt': FieldValue.serverTimestamp(),
        'notes': notes,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error rejecting record: $e');
    }
  }

  /// Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final allRecords = await getAllEmploymentRecords(limit: 1000);
      
      final total = allRecords.length;
      final employed = allRecords.where((r) => r.employmentStatus == 'Employed').length;
      final unemployed = allRecords.where((r) => r.employmentStatus == 'Unemployed').length;
      final verified = allRecords.where((r) => r.verificationStatus == 'Verified').length;
      final pending = allRecords.where((r) => r.verificationStatus == 'Pending').length;

      return {
        'total': total,
        'employed': employed,
        'unemployed': unemployed,
        'employmentRate': total > 0 ? (employed / total * 100).toStringAsFixed(1) : '0.0',
        'verified': verified,
        'pending': pending,
      };
    } catch (e) {
      throw Exception('Error getting statistics: $e');
    }
  }

  /// Get total count
  Future<int> getTotalRecordsCount() async {
    try {
      final snapshot = await _firestore
          .collection('employment_records')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Error getting total count: $e');
    }
  }
}


