# Sign-Up System Update

## Overview

The sign-up system has been updated so that **all new sign-ups are automatically created as regular users**. Admin accounts can only be created manually in Firebase.

## How It Works

### Sign-Up Flow

```
User clicks "Register"
    ↓
Fills in registration form
    ↓
Verifies OTP
    ↓
Account created in Firebase
    ↓
Role automatically set to "user" in Firestore
    ↓
User is directed to Main Navigation (User Interface)
```

### Key Changes

1. **AuthService Updated**
   - `registerWithEmailPassword()` now only takes 3 parameters:
     - Email
     - Password
     - Full Name
   - Role parameter removed
   - New sign-ups automatically get `role: "user"`

2. **Register Screen Updated**
   - Uses AuthService for registration
   - No role selection in sign-up form
   - All new accounts are regular users

3. **Admin Accounts**
   - Can only be created manually in Firebase
   - Must be set up by administrator
   - Role must be set to `"admin"` in Firestore

## Account Setup

### Creating a Regular User Account

**Option 1: Through Sign-Up (Recommended)**
1. Open the app
2. Click "Register"
3. Fill in the form:
   - Username
   - Email
   - Graduation Year
   - Password
   - Confirm Password
4. Verify OTP
5. Account created automatically as regular user
6. Directed to Main Navigation

**Option 2: Manual in Firebase**
1. Create user in Firebase Authentication
2. Set role to `"user"` in Firestore `users` collection

### Creating an Admin Account

Admin accounts can **only** be created manually:

1. **Go to Firebase Console**
2. **Create user in Authentication**
   - Email: admin@example.com
   - Password: secure_password
3. **Set role in Firestore**
   - Collection: `users`
   - Document ID: admin's UID
   - Field: `role` = `"admin"`

## Firestore Structure

```
users/
├── regular_user_uid/
│   └── role: "user"
│
└── admin_uid/
    └── role: "admin"
```

## Testing

### Test User Sign-Up
1. Open app
2. Click "Register"
3. Fill form and verify OTP
4. Account created as regular user
5. Directed to Main Navigation

### Test Admin Login
1. Create admin account manually in Firebase
2. Open app
3. Click "Login"
4. Enter admin credentials
5. Directed to Admin Dashboard Web

### Test User Login
1. Create user account via sign-up
2. Open app
3. Click "Login"
4. Enter user credentials
5. Directed to Main Navigation

## Benefits

✅ **Secure**: Only admins can create admin accounts  
✅ **Simple**: Users don't need to select roles  
✅ **Automatic**: New sign-ups automatically get user role  
✅ **Clear**: Admin accounts are manually managed  
✅ **Professional**: Standard sign-up process  

## Files Modified

| File | Changes |
|------|---------|
| `lib/services/auth_service.dart` | Updated `registerWithEmailPassword()` to auto-set role to "user" |
| `lib/screens/register_screen.dart` | Updated to use AuthService, removed Firebase Auth direct calls |

## Important Notes

- **All new sign-ups are regular users** - no exceptions
- **Admin accounts must be created manually** in Firebase
- **Role is automatically set** when user signs up
- **No role selection in sign-up form** - keeps it simple
- **Users only see standard registration form** - no admin/user options

## Security Considerations

1. **Sign-Up**: Only creates regular user accounts
2. **Admin Creation**: Manual process only
3. **Role Validation**: Always check role in Firestore
4. **Backend Rules**: Implement Firestore security rules

## Troubleshooting

### User can't sign up
- Check Firebase Authentication is enabled
- Verify email is valid
- Check password meets requirements

### New user not getting user role
- Check Firestore `users` collection
- Verify document was created with role field
- Check Firestore connection

### Admin account not working
- Verify role is set to `"admin"` (lowercase)
- Check UID matches between Auth and Firestore
- Verify Firestore security rules

## Summary

The system now works as follows:

- **Sign-Up**: Creates regular user accounts automatically
- **Admin**: Only created manually in Firebase
- **Login**: Routes based on role in Firestore
- **User Experience**: Simple, no role selection needed

Users can create their own accounts through sign-up, and they will automatically be regular users. Admin accounts are managed separately and can only be created by administrators in Firebase.

---

**Status**: ✅ Complete and Tested
**Last Updated**: November 25, 2025
