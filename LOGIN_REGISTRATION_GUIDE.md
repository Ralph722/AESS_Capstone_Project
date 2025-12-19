# Login & Registration Guide - Alumni System

## 📋 Table of Contents
1. [Overview](#overview)
2. [Login System](#login-system)
3. [Registration System](#registration-system)
4. [Authentication Flow](#authentication-flow)
5. [User Roles & Permissions](#user-roles--permissions)
6. [Security Features](#security-features)
7. [Error Handling](#error-handling)
8. [Step-by-Step User Guides](#step-by-step-user-guides)
9. [Technical Implementation](#technical-implementation)

---

## Overview

The Alumni System uses **Firebase Authentication** for secure user authentication with email and password. The system supports two user roles: **Admin** and **User**, with role-based access control.

### Key Features:
- ✅ Email/Password Authentication
- ✅ OTP Email Verification (Registration)
- ✅ Role-Based Access Control (Admin/User)
- ✅ Remember Me Functionality
- ✅ Password Visibility Toggle
- ✅ Form Validation
- ✅ Audit Logging
- ✅ Secure Session Management

### Technology Stack:
- **Backend**: Firebase Authentication
- **Database**: Cloud Firestore (User roles & profiles)
- **Email Service**: EmailJS (OTP delivery)
- **Framework**: Flutter (Web/Mobile)

---

## Login System

### Login Screen Features

#### 1. **User Interface**
- **Modern Design**: Clean, professional UI with brand colors
- **Responsive Layout**: Works on mobile and web
- **Logo Display**: School icon with circular background
- **Welcome Message**: "Welcome Back!" greeting

#### 2. **Form Fields**

##### Email Address Field
- **Input Type**: Email keyboard
- **Validation**:
  - Required field
  - Must contain "@" symbol
  - Email format validation
- **Icon**: Email outline icon
- **Styling**: Rounded borders, focus states

##### Password Field
- **Input Type**: Password (obscured by default)
- **Validation**:
  - Required field
  - Minimum length check
- **Features**:
  - Show/Hide password toggle (eye icon)
  - Secure text input
- **Icon**: Lock outline icon

#### 3. **Additional Features**

##### Remember Me Checkbox
- **Functionality**: Stores login preference (UI only, implementation pending)
- **Location**: Below password field
- **Styling**: Custom checkbox theme matching brand colors

##### Forgot Password Link
- **Status**: Coming soon (placeholder)
- **Location**: Right side of "Remember Me"
- **Action**: Shows notification that feature is under development

#### 4. **Login Button**
- **Design**: Primary button with brand color (#090A4F)
- **States**:
  - Normal: "Login" text
  - Loading: Circular progress indicator
- **Validation**: Disabled during loading state
- **Action**: Triggers authentication process

#### 5. **Registration Link**
- **Text**: "Don't have an account? Register now"
- **Action**: Navigates to Registration Screen
- **Styling**: Underlined link with brand color

### Login Process Flow

```
1. User enters email and password
   ↓
2. Form validation (client-side)
   ↓
3. Loading state activated
   ↓
4. Firebase Authentication API call
   ↓
5. Check user role from Firestore
   ↓
6. Create user document if missing (default: 'user' role)
   ↓
7. Audit log entry (SUCCESS/FAILED)
   ↓
8. Navigate based on role:
   - Admin → Admin Dashboard
   - User → Main Navigation (User Portal)
```

### Login Validation Rules

| Field | Validation Rules |
|-------|------------------|
| **Email** | - Required<br>- Must contain "@"<br>- Basic email format check |
| **Password** | - Required<br>- No minimum length enforced (Firebase handles) |

### Login Error Handling

The system handles various Firebase Authentication errors:

| Error Code | User Message |
|------------|--------------|
| `user-not-found` | "No user found for that email." |
| `wrong-password` | "Wrong password provided." |
| `invalid-email` | "The email address is invalid." |
| `user-disabled` | "This user account has been disabled." |
| `too-many-requests` | "Too many failed login attempts. Please try again later." |
| `operation-not-allowed` | "Email/password accounts are not enabled." |
| `network-request-failed` | Network error message |

**Note**: All failed login attempts are logged in the audit system.

---

## Registration System

### Registration Screen Features

#### 1. **User Interface**
- **Design**: Matches login screen styling
- **Logo**: Person add icon (different from login)
- **Title**: "Create Account"
- **Subtitle**: "Join our alumni community"

#### 2. **Form Fields**

##### Full Name Field
- **Label**: "Full Name"
- **Validation**: Required field
- **Icon**: Person outline icon
- **Purpose**: User's display name

##### Email Address Field
- **Label**: "Email Address"
- **Input Type**: Email keyboard
- **Validation**:
  - Required field
  - Must contain "@" symbol
- **State**: Disabled after OTP is sent
- **Icon**: Email outline icon

##### Graduation Year Field
- **Label**: "Graduation Year"
- **Input Type**: Number keyboard
- **Validation**: Optional field
- **State**: Disabled after OTP is sent
- **Icon**: School outline icon

##### Password Field
- **Label**: "Password"
- **Validation**:
  - Required field
  - Minimum 6 characters
- **Features**:
  - Show/Hide password toggle
  - Secure text input
- **State**: Disabled after OTP is sent
- **Icon**: Lock outline icon

##### Confirm Password Field
- **Label**: "Confirm Password"
- **Validation**:
  - Required field
  - Must match password field
- **Features**:
  - Show/Hide password toggle
  - Secure text input
- **State**: Disabled after OTP is sent
- **Icon**: Lock outline icon

#### 3. **OTP Verification System**

##### OTP Field (Appears after email submission)
- **Label**: "Enter 6-digit OTP"
- **Input Type**: Number keyboard
- **Max Length**: 6 digits
- **Validation**:
  - Required field
  - Must be exactly 6 digits
- **Styling**: 
  - Green success background
  - Centered text with letter spacing
  - Verified user icon
- **Visual Feedback**: Success message "OTP Sent!"

##### Resend OTP Button
- **Location**: Below OTP field
- **Functionality**: Regenerates and sends new OTP
- **Action**: Clears OTP field and sends new code

#### 4. **Registration Button**
- **Text**: 
  - "Register" (before OTP sent)
  - "Verify & Register" (after OTP sent)
- **States**:
  - Normal: Button text
  - Loading: Circular progress indicator
- **Action**: 
  - First click: Sends OTP email
  - Second click: Verifies OTP and creates account

#### 5. **Login Link**
- **Text**: "Already have an account? Login here"
- **Action**: Navigates back to Login Screen
- **Styling**: Underlined link with brand color

### Registration Process Flow

```
1. User fills registration form
   ↓
2. Form validation (client-side)
   ↓
3. Password match verification
   ↓
4. Click "Register" button
   ↓
5. Generate 6-digit OTP
   ↓
6. Send OTP via EmailJS to user's email
   ↓
7. Show OTP input field
   ↓
8. User enters OTP
   ↓
9. OTP verification (client-side)
   ↓
10. Create Firebase Auth account
    ↓
11. Set user role to 'user' (default)
    ↓
12. Update display name
    ↓
13. Audit log entry (SUCCESS/FAILED)
    ↓
14. Navigate to User Portal (Main Navigation)
```

### Registration Validation Rules

| Field | Validation Rules |
|-------|------------------|
| **Full Name** | - Required<br>- Cannot be empty |
| **Email** | - Required<br>- Must contain "@"<br>- Basic email format check |
| **Graduation Year** | - Optional field<br>- Number input only |
| **Password** | - Required<br>- Minimum 6 characters |
| **Confirm Password** | - Required<br>- Must match password exactly |
| **OTP** | - Required (after email sent)<br>- Must be exactly 6 digits<br>- Must match generated OTP |

### OTP Generation & Verification

#### OTP Generation
- **Method**: Secure random number generation
- **Format**: 6-digit numeric code (100000-999999)
- **Security**: Uses `Random.secure()` for cryptographically secure randomness

#### OTP Delivery
- **Service**: EmailJS API
- **Method**: Email delivery to user's registered email
- **Template**: Customizable email template with OTP code
- **Timeout**: No automatic expiration (manual resend available)

#### OTP Verification
- **Validation**: Client-side comparison
- **Process**: Compares entered OTP with generated OTP
- **Error Handling**: Shows error message if OTP doesn't match

### Registration Error Handling

| Error Type | User Message |
|------------|--------------|
| **Form Validation** | Field-specific error messages |
| **Password Mismatch** | "Passwords do not match" |
| **OTP Not Entered** | "Please enter the OTP sent to your email." |
| **Invalid OTP** | "Invalid OTP. Please try again." |
| **Email Already in Use** | "The email address is already in use." |
| **Weak Password** | "The password provided is too weak." |
| **EmailJS Error** | "Failed to send OTP: [error details]" |
| **Firebase Error** | Firebase error message displayed |

**Note**: All registration attempts (successful and failed) are logged in the audit system.

---

## Authentication Flow

### Complete User Journey

#### New User Registration
```
1. User visits app → Login Screen
   ↓
2. Clicks "Register now" → Registration Screen
   ↓
3. Fills registration form
   ↓
4. Clicks "Register" → OTP sent to email
   ↓
5. Enters OTP → Verifies
   ↓
6. Account created → Auto-login → User Portal
```

#### Returning User Login
```
1. User visits app → Login Screen
   ↓
2. Enters email and password
   ↓
3. Clicks "Login"
   ↓
4. Authentication successful
   ↓
5. Role check:
   - Admin → Admin Dashboard
   - User → User Portal
```

### Session Management

- **Firebase Auth**: Handles session persistence automatically
- **Role Storage**: User roles stored in Firestore `users` collection
- **Auto-Login**: Firebase maintains session across app restarts
- **Logout**: Explicit logout required to end session

---

## User Roles & Permissions

### Role Types

#### 1. **Admin Role**
- **Access**: Admin Dashboard (full system access)
- **Features**:
  - Manage events
  - Manage alumni members
  - Manage job postings
  - View messages
  - View activity logs
  - Manage ID Tracer records
  - Archive management
- **Assignment**: Manual (set in Firestore by existing admin)

#### 2. **User Role** (Default)
- **Access**: User Portal (limited access)
- **Features**:
  - View events
  - View job postings
  - Send messages to admin
  - Update profile
  - Submit ID Tracer information
- **Assignment**: Automatic (all new registrations)

### Role Assignment Process

#### New User Registration
```dart
// Automatic assignment during registration
await setUserRole(user.uid, UserRole.user); // Always 'user' for new sign-ups
```

#### Admin Role Assignment
- **Method**: Manual assignment via Firestore
- **Location**: `users/{uid}/role` field
- **Value**: Set to `"admin"` string
- **Note**: Cannot be assigned during registration

### Role Retrieval

```dart
// During login
var userRole = await _authService.getUserRole(user.uid);
if (userRole == null) {
  // Create user document with default 'user' role
  await _authService.setUserRole(user.uid, UserRole.user);
}
```

### Role-Based Navigation

```dart
if (userRole == UserRole.admin) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const AdminDashboardWeb()),
  );
} else {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const MainNavigation()),
  );
}
```

---

## Security Features

### 1. **Password Security**
- **Hashing**: Firebase handles password hashing (bcrypt)
- **Storage**: Passwords never stored in plain text
- **Validation**: Minimum 6 characters enforced
- **Visibility**: Password fields obscured by default

### 2. **Email Verification**
- **OTP System**: 6-digit code sent via email
- **Secure Generation**: Cryptographically secure random number
- **Verification**: Required before account creation
- **Resend**: Available if OTP not received

### 3. **Form Validation**
- **Client-Side**: Immediate feedback on input errors
- **Server-Side**: Firebase validates credentials
- **Error Messages**: User-friendly error descriptions

### 4. **Audit Logging**
- **Login Attempts**: All login attempts logged (success/failure)
- **Registration Attempts**: All registration attempts logged
- **Information Captured**:
  - Action type (LOGIN/REGISTER)
  - User ID/Email
  - Timestamp
  - Status (SUCCESS/FAILED)
  - User role

### 5. **Session Security**
- **Firebase Auth**: Secure session management
- **Token-Based**: JWT tokens for authentication
- **Auto-Expiry**: Firebase handles token expiration
- **Secure Storage**: Tokens stored securely by Firebase

### 6. **Error Handling**
- **No Information Leakage**: Generic error messages for security
- **Rate Limiting**: Firebase handles brute-force protection
- **Account Lockout**: Automatic after too many failed attempts

---

## Error Handling

### Login Errors

| Error Scenario | Handling |
|----------------|----------|
| **Invalid Email Format** | Form validation prevents submission |
| **Empty Fields** | Form validation shows field-specific errors |
| **Wrong Password** | Firebase error message displayed |
| **User Not Found** | Firebase error message displayed |
| **Network Error** | Error message with retry option |
| **Too Many Attempts** | Firebase rate limiting message |

### Registration Errors

| Error Scenario | Handling |
|----------------|----------|
| **Form Validation Errors** | Field-specific error messages |
| **Password Mismatch** | Red snackbar: "Passwords do not match" |
| **Email Already Exists** | Firebase error: "The email address is already in use." |
| **Weak Password** | Firebase error: "The password provided is too weak." |
| **OTP Send Failure** | Error message: "Failed to send OTP: [details]" |
| **Invalid OTP** | Red snackbar: "Invalid OTP. Please try again." |
| **Network Error** | Error message with retry option |

### Error Display Format

```dart
// Snackbar for user-friendly errors
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(errorMessage),
    backgroundColor: Colors.red,
  ),
);
```

---

## Step-by-Step User Guides

### Guide 1: How to Login

#### For Regular Users

1. **Open the Alumni System App**
   - Navigate to the login screen

2. **Enter Your Credentials**
   - **Email Address**: Enter your registered email
   - **Password**: Enter your password
   - Toggle password visibility if needed (eye icon)

3. **Optional Settings**
   - Check "Remember me" if you want to stay logged in
   - Click "Forgot password?" (feature coming soon)

4. **Click "Login" Button**
   - Wait for authentication (loading indicator will show)

5. **Success**
   - You'll be redirected to the User Portal
   - Access events, job postings, messages, and profile

#### For Admin Users

1. **Follow Steps 1-4 from Regular User Guide**

2. **After Login**
   - You'll be redirected to the Admin Dashboard
   - Access full system management features

### Guide 2: How to Register

1. **Navigate to Registration**
   - From Login Screen, click "Register now" link
   - Or directly access Registration Screen

2. **Fill Registration Form**
   - **Full Name**: Enter your complete name
   - **Email Address**: Enter a valid email (you'll receive OTP here)
   - **Graduation Year**: Enter your graduation year (optional)
   - **Password**: Create a password (minimum 6 characters)
   - **Confirm Password**: Re-enter your password

3. **Submit Registration**
   - Click "Register" button
   - Wait for OTP email (check your inbox)

4. **Verify Email with OTP**
   - Check your email for 6-digit OTP code
   - Enter the OTP in the verification field
   - If you didn't receive it, click "Resend OTP"

5. **Complete Registration**
   - Click "Verify & Register" button
   - Wait for account creation (loading indicator)

6. **Success**
   - Account created successfully
   - You'll be automatically logged in
   - Redirected to User Portal

### Guide 3: Troubleshooting

#### Can't Login?

**Problem**: "No user found for that email"
- **Solution**: Verify email spelling, or register if new user

**Problem**: "Wrong password provided"
- **Solution**: Check password spelling, use "Forgot password?" (when available)

**Problem**: "Too many failed login attempts"
- **Solution**: Wait a few minutes, then try again

#### Can't Register?

**Problem**: "Email already in use"
- **Solution**: Email is already registered, try logging in instead

**Problem**: "Didn't receive OTP email"
- **Solution**: 
  1. Check spam/junk folder
  2. Verify email address is correct
  3. Click "Resend OTP" button
  4. Wait a few minutes and check again

**Problem**: "Invalid OTP"
- **Solution**: 
  1. Verify you entered all 6 digits
  2. Check for typos
  3. Request a new OTP using "Resend OTP"

**Problem**: "Passwords do not match"
- **Solution**: Ensure both password fields have identical values

---

## Technical Implementation

### File Structure

```
lib/
├── screens/
│   ├── login_screen.dart          # Login UI and logic
│   └── register_screen.dart        # Registration UI and logic
├── services/
│   ├── auth_service.dart           # Firebase Auth wrapper
│   ├── email_service.dart          # EmailJS OTP service
│   └── audit_service.dart          # Audit logging
└── config/
    └── emailjs_config.dart         # EmailJS configuration
```

### Key Classes & Methods

#### AuthService (`lib/services/auth_service.dart`)

```dart
// Login
Future<User?> loginWithEmailPassword(String email, String password)

// Registration
Future<User?> registerWithEmailPassword(String email, String password, String fullName)

// Role Management
Future<UserRole?> getUserRole(String uid)
Future<void> setUserRole(String uid, UserRole role)

// Session
Future<void> logout()
User? getCurrentUser()
```

#### EmailService (`lib/services/email_service.dart`)

```dart
// OTP Delivery
Future<void> sendOtpEmail({
  required String toEmail,
  required String otp,
  required String username,
})
```

#### LoginScreen (`lib/screens/login_screen.dart`)

```dart
// Main Methods
Future<void> _handleLogin()        # Login logic
void _obscurePassword              # Password visibility toggle
```

#### RegisterScreen (`lib/screens/register_screen.dart`)

```dart
// Main Methods
Future<void> _handleRegister()     # Registration logic
Future<void> _sendOtp()            # OTP generation and sending
String _generateOtp()              # OTP generation
Future<void> _createAccount()      # Account creation
```

### Firebase Collections

#### Users Collection (`users/{uid}`)
```json
{
  "role": "user" | "admin",
  "createdAt": "timestamp"
}
```

#### Audit Logs Collection (`audit_logs`)
```json
{
  "action": "LOGIN" | "REGISTER",
  "resource": "User" | "Admin",
  "resourceId": "user_uid",
  "description": "User logged in: email@example.com",
  "status": "SUCCESS" | "FAILED",
  "userRole": "user" | "admin",
  "timestamp": "timestamp"
}
```

### Configuration

#### EmailJS Setup
- **Service ID**: Configured in `EmailJsConfig.serviceId`
- **Template ID**: Configured in `EmailJsConfig.templateId`
- **Public Key**: Configured in `EmailJsConfig.publicKey`

#### Firebase Setup
- **Authentication**: Email/Password provider enabled
- **Firestore**: Rules configured for user data access
- **Security**: Role-based access control implemented

### Dependencies

```yaml
dependencies:
  firebase_auth: ^latest    # Authentication
  cloud_firestore: ^latest  # Database
  http: ^latest             # EmailJS API calls
```

---

## Best Practices

### For Users

1. **Password Security**
   - Use a strong, unique password
   - Don't share your password
   - Change password regularly (when feature available)

2. **Email Verification**
   - Use a valid, accessible email address
   - Check spam folder for OTP emails
   - Keep email account secure

3. **Account Security**
   - Log out when using shared devices
   - Don't share your login credentials
   - Report suspicious activity

### For Developers

1. **Error Handling**
   - Always provide user-friendly error messages
   - Log errors for debugging
   - Handle network failures gracefully

2. **Security**
   - Never log passwords or sensitive data
   - Validate all inputs on client and server
   - Use Firebase security rules

3. **User Experience**
   - Show loading states during async operations
   - Provide clear feedback for all actions
   - Validate forms before submission

---

## Future Enhancements

### Planned Features

1. **Password Reset**
   - Forgot password functionality
   - Email-based password reset link
   - Secure token-based reset process

2. **Remember Me**
   - Persistent login sessions
   - Secure token storage
   - Auto-login on app restart

3. **Two-Factor Authentication (2FA)**
   - Additional security layer
   - SMS or authenticator app support

4. **Social Login**
   - Google Sign-In
   - Facebook Login
   - Other OAuth providers

5. **Email Verification**
   - Email verification link
   - Account activation requirement
   - Resend verification email

---

## Support & Contact

### Common Issues

- **Login Problems**: Check email/password, verify account exists
- **Registration Issues**: Verify email format, check OTP email
- **Role Issues**: Contact administrator for role changes

### Getting Help

- Check this documentation first
- Review error messages carefully
- Contact system administrator for account issues

---

**Last Updated**: December 2024  
**Version**: 1.0  
**Status**: Production Ready

