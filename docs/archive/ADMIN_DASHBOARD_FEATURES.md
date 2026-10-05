# Admin Dashboard Features Documentation

## Overview
The Alumni System Admin Dashboard is a comprehensive management interface for administrators to oversee all system operations, including events, members, comments, jobs, and activity tracking.

---

## 📊 Dashboard Menu Items

### 1. **Dashboard** (Menu Item 0)
**Icon:** Dashboard  
**Description:** Main overview of the system with key statistics and quick actions.

#### Features:
- **Statistics Cards:**
  - Total Events: Shows count of all events in the system
  - Active Events: Shows count of currently active events
  - Expiring Soon: Shows count of events expiring within 7 days
  - Archived Events: Shows count of archived events

- **Quick Actions Section:**
  - Add New Event
  - View Members
  - View Comments
  - Manage Jobs
  - Activity Logs
  - Archived Events

---

### 2. **Events Management** (Menu Item 1)
**Icon:** Event  
**Description:** Create, view, edit, and manage alumni events.

#### Features:
- **Add New Alumni Event Form:**
  - Event Theme (text input)
  - Batch Year (text input)
  - Event Date (date picker - MM/DD/YYYY format)
  - Venue (text input)
  - Start Time (time picker)
  - End Time (time picker)
  - Description (multiline text)
  - Submit button to create event

- **Events List Display:**
  - Shows all active events in a table format
  - Displays: Theme, Batch Year, Date, Venue, Time, Status
  - Action buttons for each event:
    - **Edit:** Modify event details
    - **Archive:** Move event to archived
    - **Delete:** Permanently remove event

- **Event Management Actions:**
  - Real-time event creation
  - Edit event details in modal dialog
  - Archive events (changes status to Archived)
  - Delete events permanently
  - Event count display

---

### 3. **Alumni Members** (Menu Item 2)
**Icon:** People  
**Description:** View and manage registered alumni members.

#### Features:
- Members list display
- Member information view
- Search/filter capabilities
- Member management options

---

### 4. **Comments** (Menu Item 3)
**Icon:** Comment  
**Description:** Monitor and manage comments on events.

#### Features:
- Comments list display
- Comment moderation
- Delete inappropriate comments
- Comment statistics

---

### 5. **Archived Events** (Menu Item 4)
**Icon:** Archive  
**Description:** View and manage archived events.

#### Features:
- **Archived Events Table:**
  - Shows all archived events
  - Displays: Theme, Batch Year, Date, Venue, Time
  - Action buttons for each archived event:
    - **Restore:** Move event back to Active status
    - **Delete:** Permanently remove archived event

- **Archive Management:**
  - View archived event count
  - Restore archived events
  - Permanently delete archived events

---

### 6. **Job Postings** (Menu Item 5)
**Icon:** Work  
**Description:** Create and manage job postings for alumni.

#### Features:
- **Job Management Interface:**
  - Add new job postings
  - View all job listings
  - Edit job details
  - Delete job postings
  - Track job applications
  - View job statistics

- **Job Posting Form:**
  - Company name
  - Job title
  - Job type (Full-time, Part-time, etc.)
  - Location
  - Salary range
  - Job description
  - Requirements
  - Benefits
  - Application deadline
  - Contact email

- **Job Listing Display:**
  - Active jobs table
  - Job details view
  - Application count tracking
  - Job status management

---

### 7. **Activity Logs** (Menu Item 6)
**Icon:** History  
**Description:** View comprehensive audit trail of all user activities in the system.

#### Features:

##### **Filtering System:**
- **Action Filter:** Filter by user actions
  - LOGIN, LOGOUT, CREATE, UPDATE, DELETE, etc.
  
- **Resource Filter:** Filter by resource type
  - Event, Job, User, Comment, etc.
  
- **Status Filter:** Filter by operation status
  - SUCCESS, FAILED
  
- **Date Range Filters:**
  - Start Date picker: Filter logs from a specific date onwards
  - End Date picker: Filter logs up to a specific date
  - Both filters work together for precise date range selection

- **Reset Filters Button:** Clears all filters including dates

##### **Activity Logs Table:**
Displays the following columns:
- **User:** Name and email of the user who performed the action
- **Role:** User role (ADMIN or USER)
  - ADMIN: Gold badge - indicates admin user
  - USER: Blue badge - indicates regular user
- **Action:** Type of action performed (with green badge)
- **Resource:** Type of resource affected
- **Description:** Details about what was done
- **Status:** Operation status
  - SUCCESS: Green badge
  - FAILED: Red badge
- **Timestamp:** Formatted as "MMM d, yyyy HH:mm"

##### **Log Management:**
- **Delete Logs Before Date Button:**
  - Opens dialog to delete old logs
  - Date selection for deletion cutoff
  - Preview showing count of logs to be deleted
  - Confirmation dialog before deletion
  - Success feedback with deletion count

- **Record Display:**
  - Total record count shown at bottom
  - Alternating row colors for readability
  - Empty state message when no logs match filters
  - Professional styling with shadows

##### **Tracked Activities:**
The system automatically logs:
- User login/logout
- Event creation, updates, and deletion
- Event archival and restoration
- Job posting creation and updates
- Comment creation and deletion
- Member profile updates
- Admin actions and changes

---

## 🎨 Dashboard Design Features

### Visual Design:
- **Color Scheme:**
  - Primary: Deep Blue (#090A4F)
  - Accent: Gold (#FFD700)
  - Secondary: Blue (#2196F3)
  - Success: Green (#4CAF50)
  - Warning: Orange (#FF9800)
  - Error: Red (#FF6B6B)
  - Archive: Gray (#607D8B)

- **Layout:**
  - Responsive sidebar navigation
  - Top header with page title and admin info
  - Main content area with scrollable content
  - Professional spacing and padding

### User Experience:
- Quick action cards for easy navigation
- Real-time data updates
- Confirmation dialogs for destructive actions
- Success/error notifications
- Loading states
- Empty state messages
- Professional table displays with alternating row colors

---

## 🔐 Security & Audit Trail

### User Role Identification:
- **Admin Users:** Identified with "ADMIN" badge in activity logs
- **Regular Users:** Identified with "USER" badge in activity logs
- Role information stored in Firestore for each audit log entry

### Activity Tracking:
- All user actions are automatically logged
- Timestamps recorded for each action
- User information (name, email) captured
- Action status (SUCCESS/FAILED) tracked
- Resource details recorded
- Changes documented for updates

### Log Management:
- Admins can view all activity logs
- Admins can filter logs by multiple criteria
- Admins can delete old logs before a specific date
- Logs are stored in Firestore for persistence
- Up to 200 recent logs loaded for display

---

## 📱 Responsive Features

- **Desktop Optimized:** Full-width layout with sidebar
- **Responsive Tables:** Scrollable on smaller screens
- **Mobile Friendly:** Collapsible navigation (future enhancement)
- **Touch Friendly:** Large buttons and interactive elements

---

## 🚀 Quick Start Guide

### Accessing the Dashboard:
1. Log in with admin credentials
2. You will be automatically redirected to the Admin Dashboard
3. Use the sidebar to navigate between different sections

### Common Tasks:

#### Adding an Event:
1. Click "Add New Event" quick action or go to Events menu
2. Fill in event details (theme, date, venue, etc.)
3. Click "Submit" to create the event

#### Managing Jobs:
1. Click "Manage Jobs" quick action or go to Job Postings menu
2. Add, edit, or delete job postings
3. Track applications and job statistics

#### Viewing Activity Logs:
1. Click "Activity Logs" quick action or go to Activity Logs menu
2. Use filters to narrow down logs (optional)
3. Select date range to view specific time periods
4. Click "Delete Logs Before Date" to clean up old logs

#### Archiving Events:
1. Go to Events menu
2. Click "Archive" button on any event
3. View archived events in Archived Events menu
4. Restore or permanently delete as needed

---

## 📊 Statistics & Monitoring

### Dashboard Statistics:
- Total Events: All events created in the system
- Active Events: Events with "Active" status
- Expiring Soon: Events expiring within 7 days
- Archived Events: Events moved to archive

### Activity Monitoring:
- View all user activities in real-time
- Filter by action type, resource, or status
- Track user logins and logouts
- Monitor data modifications
- Audit trail for compliance

---

## 🔄 Data Management

### Event Management:
- Create new events
- Edit event details
- Archive events for later reference
- Restore archived events
- Delete events permanently

### Job Management:
- Post new job opportunities
- Edit job listings
- Track applications
- Manage job status

### Activity Management:
- View complete audit trail
- Filter activities by multiple criteria
- Delete old logs to manage storage
- Export logs (future enhancement)

---

## 📝 Notes

- All timestamps are displayed in "MMM d, yyyy HH:mm" format
- Date pickers use calendar UI for easy selection
- All destructive actions (delete) require confirmation
- Activity logs are automatically created by the system
- Admin role is required to access the dashboard
- All changes are tracked in the activity logs

---

## 🔗 Related Files

- `lib/screens/admin_dashboard_web.dart` - Main dashboard implementation
- `lib/screens/admin_job_management.dart` - Job management interface
- `lib/services/audit_service.dart` - Activity logging service
- `lib/models/audit_log_model.dart` - Audit log data model
- `lib/services/event_service.dart` - Event management service

---

**Last Updated:** December 1, 2025  
**Version:** 2.0 (Enhanced with Activity Logs and Date Filtering)
