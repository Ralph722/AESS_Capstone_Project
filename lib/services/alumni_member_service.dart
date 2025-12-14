import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alumni_system/models/alumni_member_model.dart';

class AlumniMemberService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'alumni_members';

  /// Create a new alumni member
  Future<AlumniMember> createMember(AlumniMember member) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final memberWithId = member.copyWith(id: docRef.id);
      
      await docRef.set(memberWithId.toFirestore());
      return memberWithId;
    } catch (e) {
      throw Exception('Error creating member: $e');
    }
  }

  /// Get all alumni members
  Future<List<AlumniMember>> getAllMembers() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => AlumniMember.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error fetching members: $e');
    }
  }

  /// Get members by batch year
  Future<List<AlumniMember>> getMembersByBatch(String batchYear) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('batchYear', isEqualTo: batchYear)
          .orderBy('fullName')
          .get();
      
      return snapshot.docs
          .map((doc) => AlumniMember.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error fetching members by batch: $e');
    }
  }

  /// Get a single member by ID
  Future<AlumniMember?> getMemberById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return AlumniMember.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching member: $e');
    }
  }

  /// Update an alumni member
  Future<void> updateMember(AlumniMember member) async {
    try {
      await _firestore.collection(_collection).doc(member.id).set(
        member.copyWith(updatedAt: DateTime.now()).toFirestore(),
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception('Error updating member: $e');
    }
  }

  /// Delete an alumni member
  Future<void> deleteMember(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Error deleting member: $e');
    }
  }

  /// Search members by name, email, course, or batch year
  Future<List<AlumniMember>> searchMembers(String query) async {
    try {
      final allMembers = await getAllMembers();
      final lowerQuery = query.toLowerCase();
      
      return allMembers.where((member) {
        return member.fullName.toLowerCase().contains(lowerQuery) ||
            member.emailAddress.toLowerCase().contains(lowerQuery) ||
            member.course.toLowerCase().contains(lowerQuery) ||
            member.batchYear.toLowerCase().contains(lowerQuery) ||
            member.contactNumber.contains(query);
      }).toList();
    } catch (e) {
      throw Exception('Error searching members: $e');
    }
  }

  /// Get all unique batch years
  Future<List<String>> getBatchYears() async {
    try {
      final members = await getAllMembers();
      final batchYears = members.map((m) => m.batchYear).toSet().toList();
      batchYears.sort();
      return batchYears;
    } catch (e) {
      throw Exception('Error fetching batch years: $e');
    }
  }

  /// Get total member count
  Future<int> getTotalMemberCount() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      return snapshot.docs.length;
    } catch (e) {
      throw Exception('Error getting member count: $e');
    }
  }

  /// Get member count by batch year
  Future<int> getMemberCountByBatch(String batchYear) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('batchYear', isEqualTo: batchYear)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      throw Exception('Error getting member count by batch: $e');
    }
  }

  /// Stream of all members (for real-time updates)
  Stream<List<AlumniMember>> getMembersStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AlumniMember.fromFirestore(doc))
            .toList());
  }
}

