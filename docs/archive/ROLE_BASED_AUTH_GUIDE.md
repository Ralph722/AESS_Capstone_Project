# Role-Based Authentication & Admin Dashboard Guide

## Overview

The Alumni System now features a complete role-based authentication system that separates admin and user flows. Admins are automatically directed to a professional web-like dashboard, while regular users access the mobile-friendly interface.

## Architecture

### 1. Authentication Service (`lib/services/auth_service.dart`)

The `AuthService` class handles all authentication logic:

```dart
enum UserRole { admin, user }

class AuthService {
  // Login with email and password
  Future<User?> loginWithEmailPassword(String email, String password)
  
  // Register with role selection
  Future<User?> registerWithEmailPassword(String email, String password, String fullName, UserRole role)
  
  // Get user role from Firestore
  Future<UserRole?> getUserRole(String uid)
  
  // Set user role in Firestore
  Future<void> setUserRole(String uid, UserRole role)
  
  // Logout
  Future<void> logout()
}
```

### 2. Login Screen with Role Selection

The login screen now includes role selection:

- **User Role**: Regular alumni members
- **Admin Role**: System administrators

Users select their role before logging in, and the role is stored in Firestore.

### 3. Role-Based Navigation

After login, users are automatically routed based on their role:

- **Admin** → `AdminDashboardWeb` (professional web-like interface)
- **User** → `MainNavigation` (mobile-friendly interface)

## Features

### Admin Dashboard Web (`lib/screens/admin_dashboard_web.dart`)

A professional, desktop-oriented admin interface with:

#### Sidebar Navigation
- Dashboard (overview)
- Events Management
- Alumni Members
- Comments
- Archived Events
- User profile section
- Logout button

#### Dashboard Features

**1. Statistics Cards**
- Total Events
- Active Events
- Expiring Soon
- Archived Events

**2. Quick Actions**
- Add New Event
- View Members
- View Comments

**3. Events Management**
- Add new alumni events with form validation
- Search and filter events
- Edit, archive, or delete events
- Professional data table view

**4. Additional Sections**
- Alumni Members Management (coming soon)
- Comments Management (coming soon)
- Archived Events view

### User Interface

Regular users continue to access the mobile-friendly interface with:
- Home screen
- Events screen
- Community screen
- Job Posting screen
- ID Tracer screen
- Profile screen

## How to Use

### Login as Admin

1. **Open the app** and navigate to the login screen
2. **Enter admin credentials**:
   - Email: `admin@example.com`
   - Password: `your_password`
3. **Click Login**
4. **Admin Dashboard Web** will load automatically with full admin features

### Login as User

1. **Open the app** and navigate to the login screen
2. **Enter user credentials**:
   - Email: `user@example.com`
   - Password: `your_password`
3. **Click Login**
4. **Main Navigation** (user interface) will load automatically

**Note**: The system automatically detects the user's role from the database and routes them to the appropriate interface. Users don't need to select their role.

### Admin Dashboard Navigation

Once logged in as admin:

1. **Dashboard**: View overview and statistics
2. **Events Management**: 
   - Add new events using the form
   - Search events by theme, batch year, or venue
   - Edit, archive, or delete events
3. **Alumni Members**: Manage member information
4. **Comments**: Review and manage event comments
5. **Archived Events**: View archived events
6. **Logout**: Click the logout button in the sidebar

## Database Structure (Firestore)

### Users Collection

```
users/
  {uid}/
    role: "admin" | "user"
    createdAt: timestamp
```

## File Structure

```
lib/
├── screens/
│   ├── login_screen.dart (updated with role selection)
│   ├── admin_dashboard_web.dart (NEW - web-like admin interface)
│   ├── main_navigation.dart (user interface)
│   └── ...
├── services/
│   ├── auth_service.dart (NEW - role-based auth)
│   └── email_service.dart
└── ...
```

## Key Changes

### 1. Login Screen (`login_screen.dart`)
- Added role selection UI (User/Admin radio buttons)
- Updated login handler to use `AuthService`
- Routes based on selected role after authentication

### 2. Auth Service (`auth_service.dart`)
- New service for centralized authentication
- Manages user roles in Firestore
- Handles login, registration, and logout

### 3. Admin Dashboard Web (`admin_dashboard_web.dart`)
- Professional web-like interface
- Sidebar navigation
- Multiple content sections
- Event management functionality
- Statistics and quick actions

## Security Considerations

1. **Role Storage**: Roles are stored in Firestore and should be validated on the backend
2. **Access Control**: Implement server-side rules to restrict admin functions
3. **Authentication**: Uses Firebase Authentication for secure login
4. **Data Validation**: Form validation on client side (add server-side validation)

## Future Enhancements

1. **Firestore Security Rules**: Implement proper rules to restrict admin access
2. **Backend Validation**: Validate roles on the server
3. **Audit Logging**: Log all admin actions
4. **Role Management**: Add ability to manage user roles from admin panel
5. **Advanced Permissions**: Implement granular permission system
6. **Two-Factor Authentication**: Add 2FA for admin accounts
7. **Admin Activity Dashboard**: Track admin actions and changes

## Troubleshooting

### Admin Dashboard Not Loading
- Verify Firestore is initialized
- Check that user role is set in Firestore
- Ensure Firebase rules allow reading user documents

### Role Not Being Saved
- Check Firestore connection
- Verify database rules allow write access to users collection
- Check browser console for errors

### Login Fails
- Verify email and password are correct
- Check Firebase Authentication is enabled
- Ensure user account exists in Firebase

## Testing Checklist

- [ ] Login with admin role → Admin Dashboard loads
- [ ] Login with user role → Main Navigation loads
- [ ] Admin can add new events
- [ ] Admin can search events
- [ ] Admin can edit/archive/delete events
- [ ] Admin can logout
- [ ] User interface works normally for regular users
- [ ] Role is persisted in Firestore
- [ ] Navigation is correct after login

## Notes

- The admin dashboard is optimized for desktop/web viewing
- The user interface remains mobile-friendly
- All event data is currently stored locally (not persisted to Firestore)
- To make it production-ready, integrate event data with Firestore
- Consider implementing proper Firestore security rules for production

---

**Status**: ✅ Complete and Ready for Testing
**Last Updated**: November 25, 2025
