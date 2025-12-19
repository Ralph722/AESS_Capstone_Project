# User Portal - Complete Features & Functionalities Documentation

## 📋 Table of Contents
1. [Overview](#overview)
2. [Navigation System](#navigation-system)
3. [Home Screen](#home-screen)
4. [Events Screen](#events-screen)
5. [Messages/Community Screen](#messagescommunity-screen)
6. [Job Postings Screen](#job-postings-screen)
7. [ID Tracer Screen](#id-tracer-screen)
8. [Profile Screen](#profile-screen)
9. [Authentication & Access](#authentication--access)

---

## Overview

The User Portal is a comprehensive mobile-friendly interface designed for alumni members to:
- View and interact with alumni events
- Communicate with administrators
- Browse and apply for job opportunities
- Track employment status
- Manage personal profile information

**Platform**: Flutter Web/Mobile  
**Backend**: Firebase (Firestore, Authentication, Storage)  
**Status**: ~70% Complete

---

## Navigation System

### Bottom Navigation Bar
The app features a persistent bottom navigation bar with 6 main sections:

1. **Home** (Index 0)
   - Icon: `home_outlined` / `home`
   - Default landing screen

2. **Events** (Index 1)
   - Icon: `event_outlined` / `event`
   - View and manage alumni events

3. **Messages** (Index 2)
   - Icon: `message_outlined` / `message`
   - Direct messaging with admin

4. **Jobs** (Index 3)
   - Icon: `work_outline` / `work`
   - Browse job opportunities

5. **ID Tracer** (Index 4)
   - Icon: `search`
   - Employment tracking system

6. **Profile** (Index 5)
   - Icon: `person_outline` / `person`
   - User profile and settings

### Navigation Features
- **Active State**: Selected tab highlighted with filled icon
- **Smooth Transitions**: Animated tab switching
- **State Persistence**: Maintains current screen on navigation

---

## Home Screen

### Welcome Section
- **Personalized Greeting**: "Welcome back, [First Name]"
- **User Badge**: "Alumni Member" badge display
- **Profile Picture**: Circular profile image (if uploaded)
- **Gradient Background**: Blue gradient header card

### Quick Stats Cards
Three interactive stat cards showing:
1. **Events Count**
   - Displays total upcoming events
   - Color: Green (#4CAF50)
   - Tap to navigate to Events screen

2. **Messages Count**
   - Shows unread messages from admin
   - Color: Purple (#9C27B0)
   - Tap to navigate to Messages screen
   - Real-time updates via stream

3. **Jobs Count**
   - Displays total active job postings
   - Color: Orange (#FF9800)
   - Tap to navigate to Jobs screen

### Upcoming Events Section
- **Display**: Top 3 upcoming events
- **Event Cards** show:
  - Event date (month and day)
  - Event theme/title
  - Time range (start - end)
  - Venue location
  - Time indicator (Today, Tomorrow, X days)
- **Visual Indicators**:
  - Today's events: Gold border highlight
  - Events within 7 days: Orange background
  - Other events: Green background
- **Action**: "View All" button navigates to Events screen

### Featured Job Opportunities Section
- **Display**: Horizontal scrolling list of 5 recent jobs
- **Job Cards** show:
  - Company name
  - Job title
  - Job type badge (Full-time, Part-time, etc.)
  - Remote indicator (if applicable)
  - "View Details" button
- **Action**: "View All" button navigates to Jobs screen

### Quick Links Grid
Four quick access cards:
1. **ID Tracer**
   - Icon: Search
   - Color: Blue (#2196F3)
   - Navigates to ID Tracer screen

2. **Profile**
   - Icon: Person
   - Color: Purple (#9C27B0)
   - Navigates to Profile screen

3. **Messages**
   - Icon: People
   - Color: Green (#4CAF50)
   - Navigates to Messages screen

4. **Help & Support**
   - Icon: Help outline
   - Color: Orange (#FF9800)
   - Navigates to Messages screen (for support)

### Calendar Widget
- **Monthly View**: Full calendar grid
- **Today Highlight**: Current date highlighted in blue
- **Weekend Styling**: Red text for Saturday/Sunday
- **Navigation**: Previous/Next month buttons
- **Current Time Display**: Shows full date and time at bottom
- **Format**: "EEEE, MMMM d, yyyy • hh:mm:ss a"
- **Real-time Updates**: Clock updates every second

### Notifications Panel
- **Access**: Bell icon in app bar (top right)
- **Badge**: Red notification count badge
- **Features**:
  - Real-time notification stream
  - Unread count display
  - "Mark all as read" button
  - Refresh button
  - Notification types:
    - Event notifications
    - Job notifications
    - Message notifications
    - Announcements
    - System notifications
- **Notification Items**:
  - Icon based on type
  - Title and message
  - Timestamp (relative or absolute)
  - Unread indicator (red dot)
  - Tap to navigate to related screen
  - Auto-mark as read on tap

### Data Loading
- **Real-time Updates**: Events, messages, and notifications via Firebase streams
- **Loading States**: Circular progress indicators during data fetch
- **Error Handling**: User-friendly error messages
- **Empty States**: Helpful messages when no data available

---

## Events Screen

### Header
- **Title**: "Alumni Events"
- **Gradient Background**: Blue gradient header
- **View Toggle**: Switch between List and Grid view
- **Icon**: `grid_view` / `view_list`

### Search Bar
- **Placeholder**: "Search events..."
- **Search Fields**: 
  - Event theme
  - Batch year
  - Venue
  - Description
- **Real-time Filtering**: Results update as you type
- **Clear Button**: X icon appears when search has text

### Filter Chips
Four filter options:
1. **All**: Shows all upcoming events
2. **This Week**: Events within 7 days
3. **This Month**: Events within current month
4. **Newest**: Sorted by creation date (newest first)

### Events Count Display
- Shows: "[X] events found"
- Updates based on active filters

### List View
**Event Cards Display**:
- **Date Header**:
  - Month abbreviation (e.g., "DEC")
  - Day number (large)
  - Gradient background (blue for future, gold for today, grey for past)
- **Event Information**:
  - Event theme (title)
  - Batch year badge
  - Time range (start - end)
  - Venue with location icon
  - Description (if available, max 3 lines with ellipsis)
- **Status Badge**: 
  - "Today" (gold) for today's events
  - "Tomorrow" for next day
  - "X days" for upcoming
  - "Past" for past events
- **Action Buttons**:
  - "View Details" (outlined button)
  - "Remind Me" (filled button)

### Grid View
- **Layout**: 2 columns grid
- **Compact Display**:
  - Date header (smaller)
  - Event theme (2 lines max)
  - Time and venue (condensed)
  - "View" button

### Event Details Modal
**Full-screen bottom sheet** showing:
- **Header**:
  - Event theme (large title)
  - Batch year badge
  - Close button
- **Details Cards**:
  - **Date**: Full formatted date (e.g., "Friday, December 20, 2025")
  - **Time**: Start - End time range
  - **Venue**: Location with icon
- **Description Section**:
  - Full description text
  - Styled container
- **Action Buttons**:
  - "Set Reminder" (outlined)
  - "Comments (X)" (filled, shows comment count)

### Event Comments System
**Features**:
- View all comments for an event
- Add new comments
- Edit own comments
- Delete own comments
- Reply to comments (admin replies shown with badge)
- Real-time comment stream
- User avatars (initials)
- Timestamp display (relative: "Just now", "5m ago", etc.)
- Empty state when no comments

**Comment Actions**:
- Long press on own comments for menu
- Edit: Opens text field
- Delete: Confirmation dialog

### Event Reminders
- **Set Reminder**: Creates local notification
- **Saves to Firestore**: Tracks reminder in database
- **Notification**: Success message with undo option
- **Cancel Reminder**: Remove from both local and Firestore

### Event Filtering Logic
- **Upcoming Events Only**: Users only see future events
- **Date Normalization**: Accurate day calculations
- **Smart Sorting**: By date, then by creation time

---

## Messages/Community Screen

### Header
- **Admin Avatar**: Yellow circle with admin icon
- **Admin Name**: Display name of admin
- **Status**: "Online" indicator (green)
- **Title**: Shows admin name and status

### Messages List
**Features**:
- **Real-time Updates**: Firebase stream listener
- **Auto-scroll**: Automatically scrolls to bottom on new messages
- **Image Support**: Handles image loading and auto-scroll
- **Empty State**: Helpful message when no conversations

**Message Display**:
- **User Messages** (Right-aligned):
  - Blue background (#090A4F)
  - White text
  - User avatar (initials)
  - Timestamp

- **Admin Messages** (Left-aligned):
  - White background
  - Black text
  - Admin icon avatar
  - Timestamp

**Message Content**:
- **Text Messages**: Standard text display
- **Image Messages**: 
  - Thumbnail preview (200x200)
  - Tap to view full screen
  - Full-screen viewer with zoom/pan
- **Combined**: Text + image supported

**Message Actions** (Long press):
- **Add Reaction**: Emoji picker (👍, ❤️, 😂, 😮, 😢, 🙏)
- **Edit Message**: Only for own messages
- **Delete Message**: Only for own messages (with confirmation)

**Reactions**:
- Display below message
- Shows emoji and count
- Highlights if user reacted
- Tap to toggle reaction
- Double-tap message for quick 👍 reaction

### Message Input
**Text Input**:
- Multi-line text field
- Placeholder: "Ask admin..."
- Auto-expanding
- Send button (enabled when text/image present)

**Image Attachment**:
- Attach button (paperclip icon)
- Choose from gallery or camera
- Image preview before sending
- Remove button on preview
- Image compression (max 700KB)
- Base64 encoding for Firestore storage

**Send Button**:
- Disabled when:
  - Text is empty AND no image
  - Image is uploading
- Enabled when:
  - Text has content OR image selected
  - Not currently uploading

### Image Handling
- **Compression**: Automatic compression to fit Firestore limits
- **Quality Adjustment**: Progressive quality reduction if needed
- **Size Limits**: Max 700KB before base64 encoding
- **Formats**: JPEG format
- **Error Handling**: User-friendly error messages

### Message Features
- **Read Status**: Admin messages marked as read when viewed
- **Timestamp Format**: 
  - "Now" for < 1 minute
  - "Xm" for minutes
  - "Xh" for hours
  - "Xd" for days
  - "MMM d" for older
- **Auto-scroll Logic**: 
  - Immediate scroll on first load
  - Smooth scroll on new messages
  - Handles image loading delays
  - Multiple scroll attempts for images

### Real-time Synchronization
- **Stream Subscription**: Listens to all messages
- **Filtering**: Only shows user-admin conversation
- **Sorting**: Chronological order (oldest to newest)
- **Updates**: Instant updates when admin responds

---

## Job Postings Screen

### Header
- **Title**: "Job Postings"
- **Logo**: Blue gradient icon
- **Favorites Button**: 
  - Bookmark icon
  - Badge showing favorite count
  - Tap to view saved jobs

### Search Section
**Search Bar**:
- Placeholder: "Search jobs, companies, or locations..."
- Real-time search
- Searches: Job title, company name, location
- Clear button when text entered

**Filter Chips** (Horizontal scrollable):
1. **All**: All active jobs
2. **Full-time**: Full-time positions only
3. **Part-time**: Part-time positions only
4. **Remote**: Remote work positions
5. **Internship**: Internship positions

**Sort Dropdown**:
- Options:
  - Newest (default)
  - Oldest
  - Salary: High to Low
  - Salary: Low to High
- Updates results immediately

### Job Count Display
- Shows: "[X] jobs found"
- Updates with filters/search

### Job Listings
**Job Card Components**:
- **Company Logo**: Placeholder icon
- **Company Name**: Small text above title
- **Job Title**: Bold, prominent
- **Time Posted**: Relative time (e.g., "2h ago", "3d ago")
- **Bookmark Button**: 
  - Outline when not favorited
  - Filled when favorited
  - Tap to toggle favorite

**Job Details Row**:
- **Job Type Badge**: Full-time, Part-time, etc.
- **Location Badge**: City/Country
- **Remote Badge**: If remote position

**Salary & Experience**:
- **Salary**: Green money icon + range
- **Experience Level**: Orange star icon + level

**Action Buttons**:
- **View Details**: Outlined button
- **Apply**: Filled primary button

### Job Details Modal
**Full-screen bottom sheet** with:
- **Header**:
  - Job title (large)
  - Company name
  - Bookmark button
  - Close button

**Details Section**:
- Job Type
- Location
- Salary Range
- Experience Level
- Application Deadline (formatted date)

**Description**:
- Full job description text
- Formatted display

**Requirements**:
- Bulleted list
- Each requirement on new line

**Benefits**:
- Checkmark list
- Green checkmarks
- Each benefit on new line

**Apply Button**:
- Full-width button
- Shows success message
- Closes modal on apply

### Favorites System
**Features**:
- Save jobs to favorites
- View all favorited jobs
- Remove from favorites
- Real-time sync via stream
- Badge count on header icon

**Favorite Jobs Dialog**:
- Bottom sheet showing all saved jobs
- Same job card layout
- Remove favorite option
- Empty state when no favorites

### Job Filtering Logic
- **Combined Filters**: Search + Type filter + Sort
- **Real-time Updates**: Instant filtering
- **Preserves State**: Maintains filters during navigation

### Empty State
- Icon: Work outline
- Message: "No jobs found"
- Subtitle: "Try adjusting your search or filters"

---

## ID Tracer Screen

### Purpose
Track and report employment status for alumni tracking purposes.

### Header
- **Title**: "ID Tracer"
- **Icon**: Search icon (gold)
- **View Submission Button**: (if record exists)
  - Eye icon
  - Shows existing submission

### Form Sections

#### Employment Status
- **Radio Options**:
  - Employed
  - Unemployed
- **Required Field**: Must select one
- **Dynamic Fields**: Shows/hides fields based on selection

#### Unemployed Section (if Unemployed selected)
- **Months Unemployed**: 
  - Number input
  - Required field
  - Validates numeric input

#### Employment Details (if Employed selected)
- **Company Name**: Text input
- **Position/Job Title**: Text input
- **Industry**: Text input
- **Employment Type**: Dropdown
  - Full-time
  - Part-time
  - Contract
  - Freelance
  - Self-employed
- **Start Date**: Date picker
  - Format: "MMM d, yyyy"
  - Max date: Today
- **Salary Range**: Text input (optional)
- **Location Section**:
  - City
  - Province
  - Country

#### Contact Information
- **Email**: 
  - Auto-filled from Firebase Auth
  - Required field
  - Email validation
- **Contact Number**: 
  - Required field
  - Phone input type
- **School ID Number**: 
  - Required field
  - Number input type

### Form Actions
- **Submit Button**: 
  - Primary action
  - Validates all required fields
  - Shows loading state
  - Success/error messages
- **Clear Button**: 
  - Resets all fields
  - Clears form state

### Existing Record Handling
- **Info Banner**: Shows if previous submission exists
- **Auto-fill**: Loads existing data
- **Update Mode**: Replaces existing record on submit
- **View Submission**: 
  - Shows full record details
  - Verification status badge
  - Admin notes (if any)
  - Edit option

### Verification Status
**Status Types**:
- **Pending**: Yellow badge (default)
- **Verified**: Green badge
- **Rejected**: Red badge

**Status Display**:
- Color-coded badge
- Icon indicator
- Shown in view submission dialog

### Submission Details View
**Shows**:
- Verification status badge
- All submitted information
- Submission timestamp
- Last updated timestamp
- Verified timestamp (if verified)
- Admin notes (if provided)

**Actions**:
- Close dialog
- Edit record (returns to form)

### Data Validation
- **Required Fields**: Email, Contact Number, School ID
- **Conditional Required**: Months unemployed (if unemployed)
- **Email Format**: Validates @ symbol
- **Numeric Validation**: Months unemployed, School ID
- **Date Validation**: Start date cannot be future

### Audit Logging
- Logs submission/update actions
- Tracks in audit trail
- Includes user ID and timestamp

---

## Profile Screen

### Profile Picture Section
- **Circular Avatar**: 
  - 120x120 pixels
  - Border: 3px blue
  - Shadow effect
- **Upload Functionality**:
  - Tap picture to change
  - Camera icon overlay
  - Gallery picker
  - Image compression (max 1MB)
  - Base64 encoding for Firestore
  - Progress indicator during upload
- **Display**:
  - Shows uploaded image
  - Fallback to person icon
  - Error handling for failed loads

### User Information Card
**Editable Fields** (tap to edit):
1. **Full Name**
   - Icon: Person
   - Editable via dialog
   - Updates Firebase Auth display name

2. **Email**
   - Icon: Email
   - Read-only (from Firebase Auth)
   - Shows current email

3. **ID Number**
   - Icon: Badge
   - Editable via dialog
   - Stored in Firestore

4. **Course**
   - Icon: School
   - Editable via dialog
   - Academic course/program

5. **Phone Number**
   - Icon: Phone
   - Editable via dialog
   - Contact information

**Edit Dialog**:
- Text field with current value
- Save button
- Cancel button
- Auto-saves on save
- Reloads data after save

### Settings Card
**Menu Items**:
1. **General Settings**
   - Icon: Settings
   - Placeholder (not functional)

2. **Security**
   - Icon: Lock
   - Placeholder (not functional)

3. **Notifications**
   - Icon: Notifications
   - Placeholder (not functional)

4. **Privacy**
   - Icon: Info
   - Placeholder (not functional)

5. **Linked Accounts**
   - Icon: Link
   - Placeholder (not functional)

6. **Help & Support**
   - Icon: Help outline
   - Placeholder (not functional)

7. **Logout**
   - Icon: Logout (red)
   - **Functional**:
     - Logs audit action
     - Signs out from Firebase
     - Navigates to login screen
     - Clears navigation stack

### Profile Data Management
- **Auto-load**: Loads on screen init
- **Firestore Sync**: Saves to users collection
- **Firebase Auth Sync**: Updates display name
- **Real-time Updates**: Reflects changes immediately
- **Error Handling**: User-friendly error messages

### Image Upload Process
1. **Selection**: User picks image from gallery
2. **Compression**: 
   - Max dimensions: 500x500
   - Quality: 50%
   - Max size: 1MB
3. **Conversion**: Base64 encoding
4. **Storage**: Saves to Firestore as data URL
5. **Update**: Updates profile picture URL
6. **Display**: Shows new image immediately

### Audit Logging
- Logs profile update actions
- Tracks field changes
- Includes user ID and timestamp

---

## Authentication & Access

### Login Flow
1. **Login Screen**: Email and password
2. **Firebase Authentication**: Validates credentials
3. **Role Detection**: Retrieves role from Firestore
4. **Navigation**:
   - Admin → Admin Dashboard Web
   - User → Main Navigation (User Portal)

### User Role
- **Default Role**: "user"
- **Stored In**: Firestore `users` collection
- **Field**: `role: "user"`
- **Auto-assigned**: On registration

### Session Management
- **Persistent Login**: Firebase handles session
- **Auto-logout**: On token expiration
- **Manual Logout**: Available in Profile screen

### Access Control
- **User-only Features**: 
  - Events (upcoming only)
  - Messages (user-admin only)
  - Job applications
  - ID Tracer submissions
  - Profile management

### Data Privacy
- **User Data**: Only accessible by user
- **Messages**: Private user-admin conversations
- **Employment Records**: User can view own submission
- **Profile**: User can edit own profile only

---

## Technical Features

### Real-time Updates
- **Firebase Streams**: 
  - Events
  - Messages
  - Notifications
  - Job favorites
- **Auto-refresh**: Data updates without manual refresh
- **Optimistic Updates**: UI updates immediately

### Offline Support
- **Firestore Caching**: Local cache for offline access
- **Sync on Reconnect**: Automatic sync when online

### Performance Optimizations
- **Image Compression**: Reduces file sizes
- **Lazy Loading**: Loads data as needed
- **Pagination**: (Where applicable)
- **Caching**: Reduces redundant API calls

### Error Handling
- **User-friendly Messages**: Clear error descriptions
- **Retry Mechanisms**: Options to retry failed operations
- **Fallback States**: Empty states and error states
- **Loading Indicators**: Shows progress during operations

### Responsive Design
- **Mobile-first**: Optimized for mobile devices
- **Adaptive Layouts**: Adjusts to screen sizes
- **Touch-friendly**: Large tap targets
- **Smooth Animations**: Polished user experience

---

## Data Models

### User Profile
```dart
{
  uid: String,
  email: String,
  displayName: String,
  role: "user",
  idNumber: String?,
  course: String?,
  phoneNumber: String?,
  profileImageUrl: String? (base64),
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Event
```dart
{
  id: String,
  theme: String,
  batchYear: String,
  date: DateTime,
  startTime: String,
  endTime: String,
  venue: String,
  description: String,
  status: "active" | "archived",
  createdAt: Timestamp
}
```

### Message
```dart
{
  id: String,
  senderId: String,
  senderDocId: String?,
  senderName: String,
  senderEmail: String,
  senderRole: "user" | "admin",
  recipientId: String,
  recipientDocId: String?,
  messageText: String,
  imageUrl: String? (base64),
  timestamp: Timestamp,
  isRead: Boolean,
  reactions: Map<String, List<String>>
}
```

### Job Posting
```dart
{
  id: String,
  companyName: String,
  jobTitle: String,
  jobType: String,
  location: String,
  salaryRange: String,
  description: String,
  requirements: List<String>,
  benefits: List<String>,
  postedDate: Timestamp,
  applicationDeadline: Timestamp,
  isRemote: Boolean,
  experienceLevel: String,
  status: "active" | "archived",
  isActive: Boolean
}
```

### Employment Record
```dart
{
  id: String,
  userId: String,
  userName: String,
  userEmail: String,
  schoolId: String,
  employmentStatus: "Employed" | "Unemployed",
  monthsUnemployed: int?,
  companyName: String?,
  position: String?,
  industry: String?,
  employmentType: String?,
  startDate: DateTime?,
  salaryRange: String?,
  city: String?,
  province: String?,
  country: String?,
  contactNumber: String,
  submittedAt: Timestamp,
  lastUpdated: Timestamp,
  verificationStatus: "Pending" | "Verified" | "Rejected",
  verifiedAt: Timestamp?,
  notes: String?
}
```

---

## Future Enhancements (Not Yet Implemented)

### Planned Features
1. **Event RSVP System**: Allow users to RSVP to events
2. **Event Sharing**: Share events via social media
3. **Advanced Job Filters**: More filter options
4. **Job Application Tracking**: Track application status
5. **Profile Settings**: Functional settings pages
6. **Push Notifications**: Native push notifications
7. **Dark Mode**: Theme switching
8. **Multi-language Support**: Internationalization
9. **Alumni Directory**: Browse other alumni profiles
10. **Event Calendar Export**: Export to calendar apps

---

## Summary

The User Portal provides a comprehensive set of features for alumni members to:
- ✅ Stay informed about upcoming events
- ✅ Communicate with administrators
- ✅ Find and apply for job opportunities
- ✅ Track employment status
- ✅ Manage personal information

**Current Completion**: ~70%  
**Core Features**: Fully functional  
**Polish & Enhancements**: Ongoing

---

*Last Updated: December 2025*


