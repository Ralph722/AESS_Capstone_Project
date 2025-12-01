import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:alumni_system/models/audit_log_model.dart';

class AuditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Log an action
  Future<void> logAction({
    required String action,
    required String resource,
    required String resourceId,
    required String description,
    Map<String, dynamic>? changes,
    String status = 'SUCCESS',
    String userRole = 'user',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final auditLog = AuditLog(
        id: _firestore.collection('audit_logs').doc().id,
        userId: user.uid,
        userName: user.displayName ?? 'Unknown',
        userEmail: user.email ?? 'unknown@example.com',
        action: action,
        resource: resource,
        resourceId: resourceId,
        description: description,
        changes: changes,
        timestamp: DateTime.now(),
        ipAddress: null,
        status: status,
        userRole: userRole,
      );

      await _firestore
          .collection('audit_logs')
          .doc(auditLog.id)
          .set(auditLog.toFirestore());

      print('DEBUG: Audit log created - $action on $resource by $userRole');
    } catch (e) {
      print('ERROR: Failed to log action: $e');
    }
  }

  // Get all audit logs
  Future<List<AuditLog>> getAllAuditLogs({int limit = 100}) async {
    try {
      final snapshot = await _firestore
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => AuditLog.fromFirestore(doc)).toList();
    } catch (e) {
      print('ERROR: Failed to get audit logs: $e');
      return [];
    }
  }

  // Get audit logs for a specific user
  Future<List<AuditLog>> getUserAuditLogs(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('audit_logs')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => AuditLog.fromFirestore(doc)).toList();
    } catch (e) {
      print('ERROR: Failed to get user audit logs: $e');
      return [];
    }
  }

  // Get audit logs for a specific resource
  Future<List<AuditLog>> getResourceAuditLogs(
    String resource,
    String resourceId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('audit_logs')
          .where('resource', isEqualTo: resource)
          .where('resourceId', isEqualTo: resourceId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => AuditLog.fromFirestore(doc)).toList();
    } catch (e) {
      print('ERROR: Failed to get resource audit logs: $e');
      return [];
    }
  }

  // Get audit logs by action type
  Future<List<AuditLog>> getAuditLogsByAction(
    String action, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('audit_logs')
          .where('action', isEqualTo: action)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => AuditLog.fromFirestore(doc)).toList();
    } catch (e) {
      print('ERROR: Failed to get audit logs by action: $e');
      return [];
    }
  }

  // Get audit logs by date range
  Future<List<AuditLog>> getAuditLogsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    int limit = 100,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('audit_logs')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => AuditLog.fromFirestore(doc)).toList();
    } catch (e) {
      print('ERROR: Failed to get audit logs by date range: $e');
      return [];
    }
  }

  // Get total audit log count
  Future<int> getAuditLogCount() async {
    try {
      final snapshot = await _firestore.collection('audit_logs').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('ERROR: Failed to get audit log count: $e');
      return 0;
    }
  }

  // Get failed actions count
  Future<int> getFailedActionsCount() async {
    try {
      final snapshot = await _firestore
          .collection('audit_logs')
          .where('status', isEqualTo: 'FAILED')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('ERROR: Failed to get failed actions count: $e');
      return 0;
    }
  }

  // Delete old audit logs (retention policy)
  Future<void> deleteOldAuditLogs(int daysToKeep) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final snapshot = await _firestore
          .collection('audit_logs')
          .where('timestamp', isLessThan: cutoffDate)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      print('DEBUG: Deleted ${snapshot.docs.length} old audit logs');
    } catch (e) {
      print('ERROR: Failed to delete old audit logs: $e');
    }
  }

  // Search audit logs
  Future<List<AuditLog>> searchAuditLogs(
    String query, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit * 2)
          .get();

      final logs = snapshot.docs.map((doc) => AuditLog.fromFirestore(doc)).toList();

      // Client-side filtering
      return logs
          .where((log) =>
              log.description.toLowerCase().contains(query.toLowerCase()) ||
              log.userName.toLowerCase().contains(query.toLowerCase()) ||
              log.action.toLowerCase().contains(query.toLowerCase()))
          .take(limit)
          .toList();
    } catch (e) {
      print('ERROR: Failed to search audit logs: $e');
      return [];
    }
  }

  // Delete a single audit log
  Future<void> deleteAuditLog(String logId) async {
    try {
      await _firestore.collection('audit_logs').doc(logId).delete();
    } catch (e) {
      print('ERROR: Failed to delete audit log: $e');
      rethrow;
    }
  }

  // Delete all audit logs before a specific date
  Future<int> deleteAuditLogsBefore(DateTime beforeDate) async {
    try {
      final snapshot = await _firestore
          .collection('audit_logs')
          .where('timestamp', isLessThan: beforeDate)
          .get();

      int deletedCount = 0;
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        deletedCount++;
      }
      return deletedCount;
    } catch (e) {
      print('ERROR: Failed to delete audit logs before date: $e');
      rethrow;
    }
  }
}
