# User Portal Guide - Features and Functionalities

## Overview

The Alumni System User Portal is a comprehensive mobile-friendly interface designed for alumni members to stay connected, access opportunities, and manage their information. This guide provides detailed documentation of all features and functionalities available in the user portal.

---

## Navigation Structure

The user portal uses a bottom navigation bar with 6 main sections:

1. **Home** - Dashboard and overview
2. **Events** - Alumni events and activities
3. **Messages** - Communication with admin
4. **Jobs** - Job postings and opportunities
5. **ID Tracer** - Employment record submission
6. **Profile** - User profile and settings

---

## 1. Home Screen

### Location
- **Access**: First tab in bottom navigation (Home icon)
- **Purpose**: Central dashboard providing overview of key information

### Features

#### Welcome Section
- **Personalized Greeting**: Displays "Welcome back, [First Name]" with user's profile picture
- **User Badge**: Shows "Alumni Member" badge
- **Profile Image**: Displays user's profile picture (if uploaded) or default icon

#### Quick Stats Cards
Three interactive stat cards showing:
- **Events**: Total count of upcoming events (tappable → navigates to Events screen)
- **Messages**: Count of unread messages from admin (tappable → navigates to Messages screen)
- **Jobs**: Total count of available job postings (tappable → navigates to Jobs screen)

#### Upcoming Events Section
- **Display**: Shows top 3 upcoming events
- **Event Cards Include**:
  - Event date (month and day)
  - Event theme/title
  - Time range (start time - end time)
  - Venue location
  - Time badge ("Today", "Tomorrow", or "X days")
- **Actions**:
  - "View All" button → navigates to Events screen
  - Tap event card → navigates to Events screen

#### Featured Job Opportunities
- **Display**: Horizontal scrolling list of 5 featured job postings
- **Job Cards Include**:
  - Company name
  - Job title
  - Job type badge (Full-time, Part-time, etc.)
  - Remote badge (if applicable)
  - "View Details" button
- **Actions**:
  - "View All" button → navigates to Jobs screen
  - Tap "View Details" → navigates to Jobs screen

#### Quick Links Grid
Four quick access cards:
- **ID Tracer**: Navigate to ID Tracer screen
- **Profile**: Navigate to Profile screen
- **Messages**: Navigate to Messages screen
- **Help & Support**: Navigate to Messages screen

#### Calendar Widget
- **Monthly Calendar View**: 
  - Shows current month with day grid
  - Highlights today's date
  - Weekend days in red
  - Navigation arrows to change months
- **Current Time Display**: Shows full date and time (updates every second)
  - Format: "Day, Month Day, Year • HH:MM:SS AM/PM"

#### Notifications Panel
- **Access**: Bell icon in app bar (top right)
- **Features**:
  - Badge showing unread notification count
  - Real-time notification updates
  - Notification types:
    - Event notifications
    - Job notifications
    - Message notifications
    - System announcements
  - **Actions**:
    - Tap notification → marks as read and navigates to related screen
    - "Mark all as read" button
    - Refresh button
    - Auto-updates in real-time

### Real-time Updates
- Events count updates automatically
- Messages count updates in real-time
- Notifications stream updates live
- Current time updates every second

---

## 2. Events Screen

### Location
- **Access**: Second tab in bottom navigation (Events icon)
- **Purpose**: Browse, search, and interact with alumni events

### Features

#### Search Functionality
- **Search Bar**: Located at the top
- **Search Criteria**: Searches across:
  - Event theme/title
  - Venue
  - Batch year
  - Description
- **Real-time Filtering**: Results update as you type

#### Filter Options
Four filter buttons:
1. **All**: Shows all upcoming events
2. **This Week**: Events within the next 7 days
3. **This Month**: Events within the current month
4. **Newest**: Events sorted by creation date (newest first)

#### View Toggle
- **List View**: Default vertical list layout
- **Grid View**: 2-column grid layout
- **Toggle Button**: Switch between views

#### Event Cards
Each event card displays:
- **Date Badge**: 
  - "Today" (highlighted in gold)
  - "Tomorrow"
  - "X days" (for future events)
- **Event Theme**: Event title/name
- **Date**: Full date display
- **Time**: Start time - End time
- **Venue**: Location of event
- **Batch Year**: Associated batch
- **Description**: Full event description (expandable)

#### Event Actions

##### Set Reminder
- **Button**: "Set Reminder" / "Cancel Reminder"
- **Functionality**:
  - Schedules local notifications:
    - **One day before event**: Notification at 6:00 AM
    - **Day of event**: Notification at 6:00 AM
  - Saves reminder to user's Firestore subcollection
  - Shows "Undo" option after setting
- **Location**: Firestore path: `users/{userId}/reminders/{eventId}`

##### Comment on Event
- **Button**: "Comment" (replaces old "Share" button)
- **Functionality**:
  - Opens comment dialog
  - View all comments and replies
  - Post new comments
  - View admin replies
  - Delete own comments
- **Features**:
  - Real-time comment updates
  - User info display (name, email, avatar)
  - Timestamps for all comments
  - Admin replies are marked with "Admin" badge

#### Event Details Modal
When tapping an event card:
- Full event information
- All event actions (reminder, comment)
- Expanded description
- All event metadata

### Data Source
- **Firestore Collection**: `events`
- **Filter**: Only shows events with status "Active" and date >= today
- **Real-time Updates**: Events list updates automatically when new events are added

---

## 3. Messages Screen (Community)

### Location
- **Access**: Third tab in bottom navigation (Messages icon)
- **Purpose**: Direct communication channel with admin

### Features

#### Chat Interface
- **Layout**: Messenger-style chat interface
- **Background**: Light grey chat background
- **Message Bubbles**:
  - **User messages**: Right-aligned, blue background
  - **Admin messages**: Left-aligned, grey background
- **Avatar Indicators**: Profile pictures for both user and admin

#### Sending Messages

##### Text Messages
- **Input Field**: Text input at bottom
- **Send Button**: Enabled when text is entered or image is selected
- **Validation**: Trims whitespace, rejects empty messages
- **Real-time Delivery**: Messages appear instantly

##### Image Messages
- **Attachment Button**: Paperclip icon
- **Image Source Options**:
  - Gallery
  - Camera
- **Image Preview**: Shows selected image before sending
- **Image Compression**: Automatically compresses images to fit Firestore limits
- **Base64 Encoding**: Images stored as Base64 strings (no Firebase Storage)
- **Full-screen Viewer**: Tap image to view in full-screen, zoomable dialog

#### Message Interactions

##### Long-Press Menu
Long-press any message to reveal options:
- **React**: Add emoji reaction (👍, ❤️, 😂, 😮, 😢, 🙏)
- **Edit**: Edit your own messages (only for user's messages)
- **Delete**: Delete your own messages (only for user's messages)

##### Reactions
- **Display**: Reactions appear overlapping message bubble edge
  - **User's messages**: Lower left corner
  - **Admin's messages**: Lower right corner
- **Reaction Picker**: Shows 6 emoji options on long-press
- **Toggle**: Tap reaction to add/remove
- **Count Display**: Shows number of reactions

##### Edit Message
- **Access**: Long-press own message → "Edit"
- **Functionality**:
  - Opens edit dialog with current message text
  - Update message content
  - Saves updated timestamp
- **Visual Indicator**: Edited messages show "(edited)" label

##### Delete Message
- **Access**: Long-press own message → "Delete"
- **Confirmation**: Shows confirmation dialog
- **Permanent**: Deletes message from Firestore

#### Auto-Scroll
- **Smart Scrolling**: Automatically scrolls to bottom when:
  - New message is sent
  - New message is received
  - Images finish loading
- **Image Loading Detection**: Waits for images to load before final scroll
- **Continuous Scroll**: Uses timer-based approach for images (up to 15 attempts)

#### Message Status
- **Read Status**: Unread messages from admin are highlighted
- **Timestamp**: Shows time for each message
- **Real-time Updates**: Messages update instantly

### Data Storage
- **Firestore Path**: `users/{userId}/messages/{messageId}`
- **Image Storage**: Base64 encoded strings in message document
- **Structure**: Each message contains:
  - `text`: Message content
  - `imageUrl`: Base64 string (if image)
  - `senderId`: User or admin ID
  - `senderName`: Display name
  - `timestamp`: Server timestamp
  - `reactions`: Map of emoji reactions
  - `isEdited`: Boolean flag
  - `editedAt`: Timestamp (if edited)

---

## 4. Job Posting Screen

### Location
- **Access**: Fourth tab in bottom navigation (Jobs icon)
- **Purpose**: Browse and manage job opportunities

### Features

#### Search Functionality
- **Search Bar**: Top of screen
- **Search Criteria**: Searches across:
  - Job title
  - Company name
  - Job description
  - Location
- **Real-time Filtering**: Results update as you type

#### Filter Options
Five filter buttons:
1. **All**: Shows all active jobs
2. **Full-time**: Full-time positions only
3. **Part-time**: Part-time positions only
4. **Remote**: Remote work positions only
5. **Internship**: Internship positions only

#### Sort Options
Dropdown menu with sorting options:
1. **Newest**: Most recently posted jobs first
2. **Oldest**: Oldest posted jobs first
3. **Salary: High to Low**: Highest salary first
4. **Salary: Low to High**: Lowest salary first

#### Job Cards
Each job card displays:
- **Company Name**: Employer name
- **Job Title**: Position title
- **Job Type Badge**: Full-time, Part-time, Contract, etc.
- **Remote Badge**: If position is remote
- **Location**: City, Province, Country
- **Salary Range**: If available
- **Industry**: Job industry
- **Posting Date**: When job was posted
- **Favorite Icon**: Bookmark icon (outlined if not favorited, filled if favorited)

#### Job Actions

##### View Job Details
- **Access**: Tap job card
- **Details Modal Shows**:
  - Full job description
  - All job requirements
  - Application instructions
  - Company information
  - All job metadata

##### Favorite Jobs
- **Toggle**: Tap bookmark icon on job card or in details modal
- **Functionality**:
  - Adds/removes job from favorites
  - Real-time updates
  - Shows confirmation snackbar
- **Favorite Indicator**: Gold filled bookmark icon
- **Favorite Count**: Header shows count of favorited jobs

##### View Favorite Jobs
- **Access**: Tap bookmark icon in header
- **Features**:
  - Lists all favorited jobs
  - Remove from favorites option
  - Empty state message if no favorites

#### Job Information Display
- **Company Logo**: If available
- **Job Description**: Full description with formatting
- **Requirements**: List of job requirements
- **Benefits**: List of benefits (if provided)
- **Application Link**: External link if provided
- **Contact Information**: If available

### Data Source
- **Firestore Collection**: `jobs`
- **Filter**: Only shows jobs with status "active"
- **Real-time Updates**: Job list updates automatically
- **Favorites Storage**: `users/{userId}/favorite_jobs/{jobId}`

---

## 5. ID Tracer Screen

### Location
- **Access**: Fifth tab in bottom navigation (ID Tracer icon)
- **Purpose**: Submit and update employment records for tracking

### Features

#### Form Sections

##### Personal Information
- **Email**: Auto-filled from user account (read-only)
- **Contact Number**: Phone number
- **School ID**: Student/alumni ID number

##### Employment Status
- **Status Options**:
  - **Employed**: Currently employed
  - **Unemployed**: Currently unemployed
    - **Months Unemployed**: Required if unemployed
- **Dynamic Fields**: Form adapts based on employment status

##### Employment Details (If Employed)
- **Company Name**: Current employer
- **Position**: Job title/position
- **Industry**: Industry sector
- **Employment Type**: 
  - Full-time
  - Part-time
  - Contract
  - Freelance
  - Self-employed
- **Start Date**: Date picker for employment start date
- **Salary Range**: Optional salary information

##### Location Information
- **City**: City of employment
- **Province**: Province/state
- **Country**: Country of employment

#### Form Functionality

##### Auto-Load Existing Record
- **On Load**: Automatically loads user's existing employment record
- **Pre-fill**: All fields pre-filled with existing data
- **Update Mode**: Form is in "update" mode if record exists

##### Save/Update Record
- **Submit Button**: "Save Record" or "Update Record"
- **Validation**: 
  - Required fields validated
  - Email format validation
  - Date validation
- **Success Message**: Confirmation snackbar on success
- **Error Handling**: Displays error messages if save fails

##### Form Reset
- **Clear Button**: Clears all form fields
- **Confirmation**: Asks for confirmation before clearing

#### Data Storage
- **Firestore Collection**: `employment_records`
- **User Association**: Linked to user's UID
- **Update Behavior**: Updates existing record or creates new one
- **Audit Trail**: All submissions logged in audit service

#### Record Status
- **Status Display**: Shows current employment status
- **Last Updated**: Timestamp of last update
- **Record History**: Maintains update history

---

## 6. Profile Screen

### Location
- **Access**: Sixth tab in bottom navigation (Profile icon)
- **Purpose**: View and manage user profile information

### Features

#### Profile Header
- **Profile Picture**: 
  - Large circular profile image
  - Default icon if no picture uploaded
  - Tap to change picture
- **Display Name**: User's full name
- **Email**: User's email address (read-only)
- **Edit Button**: Opens profile edit mode

#### Profile Information

##### Editable Fields
- **Full Name**: User's display name
- **ID Number**: School/alumni ID number
- **Course**: Academic course/program
- **Phone Number**: Contact phone number

##### Profile Picture Management
- **Upload**: Tap profile picture to upload new image
- **Image Source**: 
  - Gallery
  - Camera (if available)
- **Image Processing**:
  - Automatic compression
  - Base64 encoding
  - Stored in Firestore (no Firebase Storage)
- **Preview**: Shows selected image before saving
- **Update**: Saves immediately after selection

#### Profile Actions

##### Save Changes
- **Save Button**: Saves all profile updates
- **Validation**: Validates required fields
- **Success Feedback**: Shows confirmation message
- **Real-time Update**: Profile updates reflect immediately

##### Logout
- **Logout Button**: Located at bottom of screen
- **Confirmation**: Asks for confirmation
- **Action**: 
  - Signs out from Firebase
  - Clears session
  - Navigates to login screen
- **Audit Log**: Logs logout action

#### Data Storage
- **Firestore Path**: `users/{userId}`
- **Profile Fields**:
  - `displayName`: Full name
  - `idNumber`: School ID
  - `course`: Academic course
  - `phoneNumber`: Contact number
  - `profileImageUrl`: Base64 encoded image string
  - `email`: Email address (from Firebase Auth)
  - `createdAt`: Account creation timestamp
  - `updatedAt`: Last update timestamp

#### Profile Picture Features
- **Base64 Storage**: Images stored as Base64 strings
- **Compression**: Automatic image compression before storage
- **Size Limit**: Handles images of any size (compresses to fit)
- **Cross-platform**: Works on both web and mobile
- **Error Handling**: Shows error if upload fails

---

## Common Features Across All Screens

### Real-time Updates
- All screens use Firestore streams for real-time data
- Changes reflect immediately without refresh
- Automatic reconnection on network issues

### Error Handling
- User-friendly error messages
- Network error handling
- Validation feedback
- Loading states for async operations

### Navigation
- Bottom navigation bar for main sections
- Back button support
- Deep linking support (via `initialIndex` parameter)
- Smooth transitions between screens

### Data Persistence
- All data stored in Firebase Firestore
- Offline support (Firestore caching)
- Automatic sync when online

### User Authentication
- Firebase Authentication integration
- Session management
- Automatic user identification
- Role-based access (user vs admin)

### Notifications
- Real-time notification system
- Notification badges
- Notification panel accessible from home screen
- Mark as read functionality

### Search and Filter
- Consistent search UI across screens
- Real-time filtering
- Multiple filter options
- Sort functionality where applicable

---

## Technical Details

### Firebase Services Used
- **Firebase Authentication**: User login and session management
- **Cloud Firestore**: Primary database for all data
- **Firebase Storage**: NOT used (images stored as Base64 in Firestore)

### Data Structure
```
users/
  {userId}/
    - Profile data
    - messages/ (subcollection)
    - notifications/ (subcollection)
    - reminders/ (subcollection)
    - favorite_jobs/ (subcollection)

events/
  {eventId}/
    - Event data
    - comments/ (subcollection)

jobs/
  {jobId}/
    - Job data

employment_records/
  {recordId}/
    - Employment data
```

### Image Handling
- **Format**: Base64 encoded strings
- **Compression**: `flutter_image_compress` package
- **Storage**: Firestore document fields
- **Size Limit**: Compressed to fit Firestore's 1MB document limit

### Local Notifications
- **Package**: `flutter_local_notifications`
- **Timezone**: `timezone` package for accurate scheduling
- **Reminders**: Scheduled for event reminders (6 AM, day before and day of event)

---

## User Tips and Best Practices

### Getting Started
1. Complete your profile first (Profile screen)
2. Set reminders for important events
3. Enable notifications for job postings
4. Keep your ID Tracer record updated

### Messaging
- Use images to share documents or photos
- Long-press messages for quick actions
- Reactions are a quick way to acknowledge messages
- Edit messages if you made a typo

### Job Searching
- Use filters to narrow down job types
- Sort by salary to find best-paying positions
- Save interesting jobs to favorites
- Check job details before applying

### Event Management
- Set reminders for events you want to attend
- Comment on events to ask questions
- Check event details for venue and time
- Use filters to find events by timeframe

### Profile Maintenance
- Keep profile picture updated
- Ensure contact information is current
- Update ID Tracer record when employment changes
- Review profile information regularly

---

## Support and Help

### Getting Help
- Use the Messages screen to contact admin
- Check notifications for important updates
- Review event comments for event-related questions

### Troubleshooting
- **Images not uploading**: Check image size, system will compress automatically
- **Messages not sending**: Check internet connection
- **Events not showing**: Ensure events are active and upcoming
- **Profile not updating**: Check required fields are filled

### Feature Requests
- Contact admin through Messages screen
- Provide detailed description of requested feature
- Admin will review and respond

---

## Version Information

This guide covers the current version of the Alumni System User Portal. Features may be updated or added in future versions. For the latest information, check with the system administrator.

---

**Last Updated**: Current Version
**System**: Alumni Management System
**Platform**: Flutter (iOS, Android, Web)

