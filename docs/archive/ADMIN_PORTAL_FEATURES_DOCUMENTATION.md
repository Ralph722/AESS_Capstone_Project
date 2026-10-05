# Admin Portal - Complete Features & Functionalities Documentation

## 📋 Table of Contents
1. [Overview](#overview)
2. [Navigation System](#navigation-system)
3. [Dashboard](#dashboard)
4. [Events Management](#events-management)
5. [Alumni Members Management](#alumni-members-management)
6. [Job Postings Management](#job-postings-management)
7. [Messages/Communication](#messagescommunication)
8. [Activity Logs](#activity-logs)
9. [ID Tracer (Employment Records)](#id-tracer-employment-records)
10. [Archives Management](#archives-management)
11. [Authentication & Security](#authentication--security)
12. [Export & Reporting](#export--reporting)

---

## Overview

The Admin Portal is a comprehensive web-based management interface designed for administrators to:
- Manage alumni events and activities
- Oversee alumni member database
- Handle job postings and applications
- Communicate with users via messaging
- Track employment records and verification
- Monitor system activity and audit logs
- Export data for reporting

**Platform**: Flutter Web  
**Backend**: Firebase (Firestore, Authentication, Storage)  
**Status**: ~70% Complete

---

## Navigation System

### Sidebar Navigation
The admin dashboard features a fixed sidebar with the following menu items:

1. **Dashboard** (Menu Item 0) - Overview and statistics
2. **Events** (Menu Item 1) - Event management
3. **Alumni Members** (Menu Item 2) - Member database
4. **Job Postings** (Menu Item 5) - Job management
5. **Messages** (Menu Item 6) - Communication hub
6. **Activity Logs** (Menu Item 7) - Audit trail
7. **ID Tracer** (Menu Item 8) - Employment tracking
8. **Archives** (Menu Item 4) - Archived content

### Top Header
- **Page Title**: Dynamic title based on current section
- **Admin Badge**: Shows admin email and role
- **Responsive Design**: Adapts to screen size

---

## Dashboard

### Overview Statistics Cards
Displays key metrics at a glance:

1. **Total Events**
   - Count of all events in the system
   - Icon: Event icon
   - Color: Primary blue

2. **Active Events**
   - Currently active events
   - Icon: Check circle
   - Color: Green

3. **Expiring Soon**
   - Events expiring within 7 days
   - Icon: Schedule
   - Color: Orange

4. **Archived Events**
   - Count of archived events
   - Icon: Archive
   - Color: Gray

5. **Total Users**
   - Registered alumni members
   - Icon: People
   - Color: Blue

6. **Total Jobs**
   - Active job postings
   - Icon: Work
   - Color: Purple

7. **Unread Messages**
   - Messages from users to admin
   - Badge indicator
   - Color: Red accent

### Quick Actions Section
Provides quick navigation to common tasks:

1. **Add New Event** - Opens event creation form
2. **View Members** - Navigate to Alumni Members
3. **View Comments** - Access event comments
4. **Manage Jobs** - Navigate to Job Postings
5. **Activity Logs** - View audit trail
6. **Archived Events** - View archived content

### Recent Activity Feed
- Shows last 5 system activities
- Displays action, user, timestamp
- Color-coded by status (Success/Failed)
- Quick access to full activity logs

---

## Events Management

### Add New Event Form
Comprehensive form for creating alumni events:

**Form Fields:**
- **Event Theme** (Required)
  - Text input
  - Event title/name
  
- **Batch Year** (Required)
  - Text input
  - Format: e.g., "2022-2023"
  
- **Event Date** (Required)
  - Date picker
  - Format: MM/DD/YYYY
  - Calendar UI
  
- **Venue** (Required)
  - Text input
  - Event location
  
- **Start Time** (Required)
  - Time picker
  - Format: HH:mm (24-hour)
  
- **End Time** (Required)
  - Time picker
  - Format: HH:mm (24-hour)
  
- **Description** (Optional)
  - Multiline text area
  - Rich text support
  - Fixed-width container (600px)

**Actions:**
- **Submit**: Creates event and sends notification to all users
- **Cancel**: Clears form without saving

### Events List Display
Table view showing all active events:

**Columns:**
- Theme (Event name)
- Batch Year
- Date (Formatted: MMM d, yyyy)
- Venue
- Time (Start - End)
- Status (Active/Archived)
- Comments Count
- Actions

**Per-Event Actions:**
1. **Edit** (Pencil icon)
   - Opens edit dialog with pre-filled data
   - Fixed-width container (600px)
   - Updates event details
   - Saves changes to Firestore

2. **View Comments** (Comment icon)
   - Opens comments dialog
   - Shows all comments for the event
   - Real-time updates via stream
   - Delete comment option

3. **Archive** (Archive icon)
   - Moves event to archived status
   - Confirmation dialog
   - Removes from active list

4. **Delete** (Trash icon)
   - Permanently deletes event
   - Confirmation dialog required
   - Cannot be undone

### Event Filtering & Search
- **Search Bar**: Search by theme, batch year, or venue
- **Batch Year Filter**: Dropdown filter by batch
- **Date Range Filter**: Filter by start/end date
- **Venue Filter**: Filter by venue location
- **Real-time Filtering**: Updates as you type

### Event Comments Management
- View all comments for an event
- Real-time comment stream
- Delete inappropriate comments
- Comment count display
- User information (name, timestamp)

---

## Alumni Members Management

### Add Member Form
Two-column layout with form on left, list on right:

**Required Fields:**
- **Full Name**
- **Batch Year** (e.g., 2022-2023)
- **Course**
- **Contact Number**
- **Email Address**

**Optional Fields:**
- **Current Position**
- **Current Company**
- **Address** (Multiline)
- **LinkedIn URL**

**Actions:**
- **Add Member**: Creates new member record
- **Clear Form**: Resets all fields

### Members List Display
Organized by batch year with statistics:

**Statistics Cards:**
- Total Members count
- All Batches count

**Search & Filter:**
- **Search Bar**: Search by name, email, course, or batch
- **Batch Filter**: Dropdown to filter by specific batch
- **Real-time Search**: Instant filtering

**Member Display:**
- Grouped by batch year
- Batch header with member count
- Member cards showing:
  - Avatar (Initial letter)
  - Full Name
  - Course
  - Email
  - Current Position/Company (if available)

**Per-Member Actions:**
1. **View Details** (Eye icon)
   - Modal dialog with full member information
   - All fields displayed
   - Join date shown

2. **Edit** (Edit icon)
   - Edit dialog with pre-filled data
   - Update any field
   - Save changes

3. **Delete** (Delete icon)
   - Confirmation dialog
   - Permanently removes member
   - Audit log entry created

### Export Functionality
- **Export to Excel**: Downloads member data as .xlsx file
- Includes all member fields
- Date format: yyyy-MM-dd
- Filename includes current date

---

## Job Postings Management

### Job Management Interface
Comprehensive job posting management system:

**Header Section:**
- Title: "Job Postings Management"
- **Post New Job** button
- Statistics cards

**Statistics Cards:**
1. **Total Jobs** - All job postings
2. **Active** - Currently active jobs
3. **Drafts** - Draft job postings
4. **Expired** - Expired job postings
5. **Applications** - Total application count

### Job Tabs
Three-tab system for organizing jobs:

1. **Active Tab**
   - Currently active job postings
   - Visible to users
   - Can be archived or deleted

2. **Drafts Tab**
   - Unpublished job postings
   - Can be edited and activated
   - Not visible to users

3. **Expired Tab**
   - Past deadline jobs
   - Can be reactivated or deleted

### Add/Edit Job Dialog
Comprehensive job posting form:

**Job Details:**
- **Company Name** (Required)
- **Job Title** (Required)
- **Job Type** (Required)
  - Full-time, Part-time, Contract, Internship
- **Location** (Required)
- **Remote Work** (Checkbox)
- **Experience Level** (Required)
  - Entry, Mid, Senior, Executive
- **Salary Range** (Optional)
- **Application Deadline** (Required)
  - Date picker
- **Contact Email** (Required)

**Job Description:**
- **Job Description** (Multiline, Required)
- **Requirements** (Multiline, Required)
- **Benefits** (Multiline, Optional)

**Actions:**
- **Save**: Creates or updates job posting
- **Cancel**: Closes dialog without saving

### Job Card Display
Each job displayed as a card with:

**Information:**
- Status indicator (colored bar)
- Job Title (Bold)
- Company Name
- Job Type badge
- Location badge
- Remote indicator (if applicable)
- Experience Level badge
- Posted date
- Application count
- View count

**Status Colors:**
- Active: Green
- Draft: Orange
- Expired: Red
- Archived: Gray

**Per-Job Actions:**
1. **Edit** (Edit icon)
   - Opens edit dialog
   - Pre-filled with current data
   - Update any field

2. **Archive/Activate** (Archive icon)
   - Toggles between active and archived
   - Confirmation for status change

3. **Delete** (Delete icon)
   - Permanently removes job
   - Confirmation dialog required

### Search Functionality
- **Search Bar**: Search by job title or company name
- **Real-time Filtering**: Updates as you type
- **Tab-specific Search**: Filters within selected tab

---

## Messages/Communication

### Messenger Interface
Real-time messaging system between admin and users:

**Layout:**
- Two-panel design
- Left: Conversation list
- Right: Chat area

### Conversation List (Left Panel)
**Header:**
- Admin avatar and name
- "Messenger" title

**Search Bar:**
- Search conversations by user name
- Real-time filtering

**Conversation Items:**
- User avatar (Initial letter)
- User name
- Last message preview
- Last message time (Relative: "Now", "5m", "2h", "3d", or date)
- Unread indicator (Blue dot)
- Selected state highlighting

**Features:**
- Sorted by most recent message
- Unread count badge
- Click to open conversation

### Chat Area (Right Panel)
**Chat Header:**
- User avatar and name
- "Last active recently" status

**Messages Display:**
- Scrollable message list
- Auto-scroll to bottom on new messages
- Image loading detection and auto-scroll
- Messages aligned by sender:
  - Admin messages: Right-aligned, blue background
  - User messages: Left-aligned, white background

**Message Features:**
1. **Text Messages**
   - Multiline support
   - Timestamp display
   - Relative time formatting

2. **Image Messages**
   - Image upload support
   - Base64 encoding (stored in Firestore)
   - Image compression (max 700KB)
   - Click to view full screen
   - Zoomable image viewer

3. **Message Reactions**
   - Emoji reactions (👍, ❤️, 😂, 😮, 😢, 🙏)
   - Multiple users can react
   - Reaction count display
   - Toggle reaction on click
   - Double-tap for quick 👍 reaction

4. **Message Actions** (Long press)
   - **Add Reaction**: Opens reaction picker
   - **Edit Message** (Admin only): Edit text content
   - **Delete Message** (Admin only): Remove message

**Message Input:**
- Text input field
- Multiline support
- Image attachment button
- Send button (enabled when text or image present)
- Image preview before sending
- Remove image option

**Image Upload:**
- Choose from gallery or camera
- Automatic compression
- Progress indicator
- Base64 encoding for Firestore storage
- Error handling for large images

### Message Features
- **Real-time Updates**: Stream-based message loading
- **Read Status**: Marks messages as read when viewed
- **Auto-scroll**: Automatically scrolls to latest message
- **Image Handling**: Full-screen image viewer with zoom
- **Reaction System**: Emoji reactions with user tracking
- **Message Editing**: Admin can edit sent messages
- **Message Deletion**: Admin can delete messages

---

## Activity Logs

### Comprehensive Audit Trail
Complete system activity monitoring:

**Statistics Cards:**
1. **Total Logs** - All activity records
2. **Failed Actions** - Failed operations count
3. **Successful** - Successful operations count

### Filtering System
Advanced filtering capabilities:

**Action Filter:**
- All
- LOGIN
- LOGOUT
- CREATE_EVENT
- UPDATE_EVENT
- DELETE_EVENT
- CREATE_MEMBER
- UPDATE_MEMBER
- DELETE_MEMBER
- CREATE_JOB
- UPDATE_JOB
- DELETE_JOB
- And more...

**Resource Filter:**
- All
- Event
- Job
- User
- Comment
- AlumniMember
- JobPosting
- And more...

**Status Filter:**
- All
- SUCCESS
- FAILED

**Date Range Filter:**
- Start Date picker
- End Date picker
- Clear date filters

**Search Bar:**
- Search by description, user name, or action
- Real-time filtering

### Activity Log Display
Each log entry shows:

**Information:**
- Status icon (Success: Green check, Failed: Red error)
- Action type (Bold, primary color)
- Status badge (SUCCESS/FAILED)
- Description (Full action description)
- User information:
  - Avatar (Initial letter)
  - Role badge (Admin: Gold, User: Blue)
  - User name
  - User email
- Resource type badge
- Timestamp (Formatted: MMM d, yyyy HH:mm)

**Color Coding:**
- Success: Green border and icon
- Failed: Red border and icon
- Admin: Gold badge
- User: Blue badge

### Log Management
- **View Logs**: Scrollable list (up to 100 displayed)
- **Delete Logs**: Delete logs before a specific date
- **Export**: Future enhancement
- **Pagination**: Shows "Showing first 100 of X records"

---

## ID Tracer (Employment Records)

### Employment Records Management
Track and verify alumni employment status:

**Header Actions:**
- **Export**: Export records to Excel
- **Batch Actions**: Perform bulk operations
- **Refresh**: Reload records

### Statistics Cards
1. **Total Records** - All employment records
2. **Employed** - Currently employed alumni
3. **Unemployed** - Unemployed alumni
4. **Pending Verification** - Records awaiting verification

### Search & Filter System
**Search Bar:**
- Search by name, email, school ID, or company
- Real-time filtering

**Filters:**
1. **Employment Status Filter**
   - All
   - Employed
   - Unemployed

2. **Verification Status Filter**
   - All
   - Pending
   - Verified
   - Rejected

**Clear Filters Button:**
- Resets all filters and search

### Records Table Display
Comprehensive table showing:

**Columns:**
1. **Checkbox** - Select for batch operations
2. **Name** - Alumni full name
3. **Email** - Contact email
4. **School ID** - Student ID number
5. **Batch Year** - Graduation batch
6. **Employment Status** - Employed/Unemployed
7. **Company** - Current employer (if employed)
8. **Position** - Job title (if employed)
9. **Months Unemployed** - Duration (if unemployed)
10. **Verification Status** - Pending/Verified/Rejected
11. **Submitted Date** - Record submission date
12. **Actions** - Edit, Verify, Reject, Delete

**Table Features:**
- Scrollable (horizontal and vertical)
- Responsive column widths
- Alternating row colors
- Status color coding
- Sortable columns (future enhancement)

### Per-Record Actions
1. **Edit** (Edit icon)
   - Modify record details
   - Update employment information

2. **Verify** (Check icon)
   - Mark record as verified
   - Changes status to "Verified"
   - Audit log entry

3. **Reject** (X icon)
   - Mark record as rejected
   - Changes status to "Rejected"
   - Requires reason (optional)

4. **Delete** (Delete icon)
   - Permanently remove record
   - Confirmation dialog

### Batch Operations
- **Select All**: Select all visible records
- **Deselect All**: Clear all selections
- **Batch Verify**: Verify multiple records at once
- **Batch Reject**: Reject multiple records at once
- **Batch Delete**: Delete multiple records at once

### Export Functionality
- **Export to Excel**: Download all records as .xlsx
- Includes all columns
- Formatted dates
- Filename includes export date

---

## Archives Management

### Two-Tab System
1. **Archived Events Tab**
2. **Archived Jobs Tab**

### Archived Events
**Display:**
- All archived events in card format
- Same information as active events
- "Archived" status badge

**Per-Event Actions:**
1. **Restore** (Restore icon)
   - Moves event back to active status
   - Confirmation dialog
   - Updates status to "Active"

2. **Delete** (Delete icon)
   - Permanently removes archived event
   - Confirmation dialog required

### Archived Jobs
**Display:**
- All archived job postings
- Job details (title, company, location)
- "Archived" status badge
- View and application counts

**Per-Job Actions:**
1. **Restore** (Restore icon)
   - Reactivates job posting
   - Changes status to "active"
   - Becomes visible to users

2. **Delete** (Delete icon)
   - Permanently removes job
   - Confirmation required

---

## Authentication & Security

### Admin Access
- **Role-based Access**: Only admin users can access dashboard
- **Firebase Authentication**: Secure login system
- **Session Management**: Automatic logout on token expiry

### User Profile Section
**Sidebar Profile:**
- Admin avatar (Icon)
- Display name
- Email address
- Logout button

**Top Header Badge:**
- Admin role indicator
- Email display
- Styled badge with gradient

### Security Features
- **Audit Logging**: All actions logged
- **Role Tracking**: Admin vs User actions tracked
- **Confirmation Dialogs**: Required for destructive actions
- **Error Handling**: Comprehensive error messages

---

## Export & Reporting

### Available Exports

1. **Alumni Members Export**
   - Format: Excel (.xlsx)
   - Includes: All member fields
   - Date format: yyyy-MM-dd
   - Filename: `alumni_members_YYYYMMDD.xlsx`

2. **Employment Records Export**
   - Format: Excel (.xlsx)
   - Includes: All record fields
   - Filtered data (respects current filters)
   - Filename: `employment_records_YYYYMMDD.xlsx`

3. **Activity Logs Export** (Future)
   - Format: CSV/Excel
   - Filtered by current filters
   - Date range support

### Export Features
- **One-click Export**: Button triggers download
- **Filtered Exports**: Respects current search/filter settings
- **Date Stamping**: Filename includes export date
- **Complete Data**: All relevant fields included

---

## Additional Features

### Real-time Updates
- **Stream-based Data**: Real-time updates via Firestore streams
- **Auto-refresh**: Data updates automatically
- **Notification System**: New event notifications to users

### Responsive Design
- **Desktop Optimized**: Full-width layout
- **Mobile Support**: Responsive tables and cards
- **Adaptive Layout**: Adjusts to screen size

### User Experience
- **Loading States**: Spinners during data fetch
- **Empty States**: Helpful messages when no data
- **Error Handling**: User-friendly error messages
- **Success Notifications**: Confirmation for successful actions
- **Confirmation Dialogs**: Prevent accidental deletions

### Data Management
- **Pagination**: Large lists paginated (100 items)
- **Caching**: Pre-loaded data for faster access
- **Optimistic Updates**: UI updates before server confirmation
- **Batch Operations**: Multiple record operations

---

## Technical Details

### Backend Services
- **Firebase Firestore**: Database
- **Firebase Authentication**: User management
- **Firebase Storage**: File storage (future)
- **Cloud Functions**: Server-side logic (future)

### Data Models
- **AlumniEvent**: Event information
- **AlumniMember**: Member database
- **JobPosting**: Job listings
- **EmploymentRecord**: Employment tracking
- **AuditLog**: Activity tracking
- **Message**: Communication records

### State Management
- **StatefulWidget**: Component-level state
- **StreamBuilder**: Real-time data streams
- **FutureBuilder**: Async data loading

---

## Future Enhancements

### Planned Features
1. **Advanced Analytics Dashboard**
   - Charts and graphs
   - Trend analysis
   - Export reports

2. **Bulk Import**
   - CSV/Excel import for members
   - Batch job creation

3. **Email Notifications**
   - Automated email alerts
   - Customizable templates

4. **Role Management**
   - Multiple admin roles
   - Permission system

5. **Advanced Search**
   - Full-text search
   - Saved searches

6. **Mobile App**
   - Native mobile admin app
   - Push notifications

---

## Notes

- All timestamps use "MMM d, yyyy HH:mm" format
- Date pickers use calendar UI
- All destructive actions require confirmation
- Activity logs are automatically created
- Admin role required for all dashboard access
- Real-time updates via Firestore streams
- Export files are downloaded automatically
- Image uploads are compressed to save storage

---

## Related Files

- `lib/screens/admin_dashboard_web.dart` - Main dashboard implementation
- `lib/screens/admin_alumni_members_screen.dart` - Members management
- `lib/screens/admin_job_management.dart` - Job management
- `lib/screens/admin_messages_screen.dart` - Messaging system
- `lib/screens/audit_logs_screen.dart` - Activity logs
- `lib/services/` - Backend service layer
- `lib/models/` - Data models

---

**Document Version**: 1.0  
**Last Updated**: December 2024  
**Status**: Active Development (~70% Complete)

