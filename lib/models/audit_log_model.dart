import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLog {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String action;
  final String resource;
  final String resourceId;
  final String description;
  final Map<String, dynamic>? changes;
  final DateTime timestamp;
  final String? ipAddress;
  final String status;
  final String userRole; // 'admin' or 'user'

  AuditLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.action,
    required this.resource,
    required this.resourceId,
    required this.description,
    this.changes,
    required this.timestamp,
    this.ipAddress,
    required this.status,
    this.userRole = 'user',
  });

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'action': action,
      'resource': resource,
      'resourceId': resourceId,
      'description': description,
      'changes': changes,
      'timestamp': timestamp,
      'ipAddress': ipAddress,
      'status': status,
      'userRole': userRole,
    };
  }

  // Create from Firestore document
  factory AuditLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditLog(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      action: data['action'] ?? '',
      resource: data['resource'] ?? '',
      resourceId: data['resourceId'] ?? '',
      description: data['description'] ?? '',
      changes: data['changes'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ipAddress: data['ipAddress'],
      status: data['status'] ?? 'SUCCESS',
      userRole: data['userRole'] ?? 'user',
    );
  }

  // Copy with method
  AuditLog copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? action,
    String? resource,
    String? resourceId,
    String? description,
    Map<String, dynamic>? changes,
    DateTime? timestamp,
    String? ipAddress,
    String? status,
    String? userRole,
  }) {
    return AuditLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      action: action ?? this.action,
      resource: resource ?? this.resource,
      resourceId: resourceId ?? this.resourceId,
      description: description ?? this.description,
      changes: changes ?? this.changes,
      timestamp: timestamp ?? this.timestamp,
      ipAddress: ipAddress ?? this.ipAddress,
      status: status ?? this.status,
      userRole: userRole ?? this.userRole,
    );
  }
}
