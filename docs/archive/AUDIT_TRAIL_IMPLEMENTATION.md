# Audit Trail Implementation - Alumni Portal

## Overview
A comprehensive audit trail system has been implemented to track all user actions and system events in the Alumni Portal. This provides administrators with detailed logs of who did what, when, and the status of each action.

## Files Created

### 1. **Audit Log Model** (`lib/models/audit_log_model.dart`)
Defines the structure for audit log entries with the following fields:
- `id` - Unique identifier for the audit log
- `userId` - ID of the user who performed the action
- `userName` - Display name of the user
- `userEmail` - Email of the user
- `action` - Type of action (LOGIN, LOGOUT, CREATE_EVENT, EDIT_EVENT, DELETE_EVENT, etc.)
- `resource` - Type of resource affected (User, Event, Post, Comment, etc.)
- `resourceId` - ID of the resource being acted upon
- `description` - Human-readable description of the action
- `changes` - Map of before/after values for update operations
- `timestamp` - When the action occurred
- `ipAddress` - IP address of the user (for future enhancement)
- `status` - SUCCESS or FAILED

### 2. **Audit Service** (`lib/services/audit_service.dart`)
Core service for logging and retrieving audit logs with the following methods:

#### Logging Actions
```dart
logAction({
  required String action,
  required String resource,
  required String resourceId,
  required String description,
  Map<String, dynamic>? changes,
  String status = 'SUCCESS',
})
```

#### Retrieving Logs
- `getAllAuditLogs(limit)` - Get all audit logs
- `getUserAuditLogs(userId, limit)` - Get logs for a specific user
- `getResourceAuditLogs(resource, resourceId)` - Get logs for a specific resource
- `getAuditLogsByAction(action, limit)` - Get logs by action type
- `getAuditLogsByDateRange(startDate, endDate, limit)` - Get logs within a date range
- `searchAuditLogs(query, limit)` - Search audit logs

#### Analytics
- `getAuditLogCount()` - Total number of audit logs
- `getFailedActionsCount()` - Count of failed actions
- `deleteOldAuditLogs(daysToKeep)` - Delete old logs (retention policy)

### 3. **Audit Logs Screen** (`lib/screens/audit_logs_screen.dart`)
Admin dashboard screen for viewing and analyzing audit logs with:
- **Statistics Cards**: Total logs, failed actions, successful actions
- **Search Functionality**: Search logs by description, user name, or action
- **Filter Buttons**: Filter by action type (LOGIN, LOGOUT, CREATE_EVENT, etc.)
- **Log Cards**: Display detailed information for each audit log
- **Status Indicators**: Visual indicators for success/failed actions
- **Timestamps**: Formatted date/time for each action

## Integration Points

### 1. **Login Screen** (`lib/screens/login_screen.dart`)
- Logs successful login with user email
- Logs failed login attempts
- Records timestamp and user information

```dart
await _auditService.logAction(
  action: 'LOGIN',
  resource: 'User',
  resourceId: user.uid,
  description: 'User logged in: ${user.email}',
  status: 'SUCCESS',
);
```

### 2. **Profile Screen** (`lib/screens/profile_screen.dart`)
- Logs user logout actions
- Records user email and timestamp

```dart
await auditService.logAction(
  action: 'LOGOUT',
  resource: 'User',
  resourceId: user.uid,
  description: 'User logged out: ${user.email}',
  status: 'SUCCESS',
);
```

### 3. **Admin Dashboard** (`lib/screens/admin_dashboard_web.dart`)
- Added "Audit Logs" menu item to sidebar
- Accessible via menu item index 5

## Firestore Collection Structure

### Collection: `audit_logs`
```
audit_logs/
├── {logId}
│   ├── id: string
│   ├── userId: string
│   ├── userName: string
│   ├── userEmail: string
│   ├── action: string
│   ├── resource: string
│   ├── resourceId: string
│   ├── description: string
│   ├── changes: map
│   ├── timestamp: timestamp
│   ├── ipAddress: string
│   └── status: string
```

## Action Types

Currently tracked actions:
- `LOGIN` - User login
- `LOGOUT` - User logout
- `CREATE_EVENT` - Event creation (ready for integration)
- `EDIT_EVENT` - Event modification (ready for integration)
- `DELETE_EVENT` - Event deletion (ready for integration)
- `UPDATE_PROFILE` - Profile update (ready for integration)
- `POST_COMMENT` - Comment posting (ready for integration)

## Usage Examples

### Log a Login
```dart
await auditService.logAction(
  action: 'LOGIN',
  resource: 'User',
  resourceId: user.uid,
  description: 'User logged in: ${user.email}',
  status: 'SUCCESS',
);
```

### Log an Event Creation
```dart
await auditService.logAction(
  action: 'CREATE_EVENT',
  resource: 'Event',
  resourceId: event.id,
  description: 'Event created: ${event.theme}',
  changes: {
    'theme': event.theme,
    'date': event.date.toString(),
    'venue': event.venue,
  },
  status: 'SUCCESS',
);
```

### Get All Logs
```dart
final logs = await auditService.getAllAuditLogs(limit: 100);
```

### Get User's Logs
```dart
final userLogs = await auditService.getUserAuditLogs(
  userId: userId,
  limit: 50,
);
```

### Search Logs
```dart
final results = await auditService.searchAuditLogs(
  query: 'login',
  limit: 50,
);
```

## Features

✅ **Comprehensive Logging**
- Tracks all user actions with timestamps
- Records user information (name, email, ID)
- Captures action status (success/failure)

✅ **Advanced Querying**
- Filter by action type
- Filter by user
- Filter by resource
- Filter by date range
- Full-text search

✅ **Analytics**
- Total log count
- Failed action count
- Success rate calculation

✅ **Data Retention**
- Automatic cleanup of old logs
- Configurable retention period (default: 90 days)

✅ **Admin Dashboard Integration**
- Dedicated audit logs screen
- Real-time statistics
- Search and filter capabilities
- User-friendly interface

## Future Enhancements

1. **IP Address Tracking** - Capture user's IP address for security
2. **Event Logging** - Log all event CRUD operations
3. **Post Logging** - Log community post actions
4. **Profile Logging** - Log profile update actions
5. **Export Functionality** - Export audit logs to CSV/PDF
6. **Advanced Analytics** - Charts and graphs for audit data
7. **Alerts** - Real-time alerts for suspicious activities
8. **Role-Based Access** - Restrict audit log viewing by role

## Security Considerations

1. **Immutable Logs** - Audit logs should not be editable
2. **Access Control** - Only admins should view audit logs
3. **Data Privacy** - Consider GDPR compliance for user data
4. **Encryption** - Consider encrypting sensitive data in logs
5. **Backup** - Regular backups of audit logs

## Performance Notes

- Audit logs are stored in Firestore
- Queries are optimized with proper indexing
- Old logs can be automatically deleted to manage storage
- Consider archiving old logs to a separate collection for long-term retention

## Testing

To test the audit trail system:

1. **Login** - Check that login action is logged
2. **Logout** - Check that logout action is logged
3. **View Logs** - Navigate to Audit Logs in admin dashboard
4. **Search** - Test search functionality
5. **Filter** - Test filter by action type
6. **Statistics** - Verify statistics are accurate

## Troubleshooting

### Logs Not Appearing
- Ensure Firestore `audit_logs` collection is created
- Check that user is authenticated
- Verify audit service is properly initialized

### Performance Issues
- Check Firestore query limits
- Consider archiving old logs
- Optimize query indexes in Firestore

### Missing Logs
- Verify action is being logged in the code
- Check Firestore permissions
- Ensure timestamp is correct

## Support

For questions or issues with the audit trail system, refer to:
- Firestore documentation: https://firebase.google.com/docs/firestore
- Flutter Firebase: https://firebase.flutter.dev/
