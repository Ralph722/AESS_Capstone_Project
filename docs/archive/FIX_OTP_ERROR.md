# Fix OTP Error - EmailJS Template Update

## Error Fixed

The error **"The recipients address is empty"** has been fixed by updating the template parameter names.

## What Changed

**Old parameter names:**
```
'email': toEmail
'otp': otp
```

**New parameter names:**
```
'to_email': toEmail
'otp_code': otp
```

## What You Need to Do

### Update Your EmailJS Template

1. **Go to EmailJS Dashboard**
   - Visit: https://dashboard.emailjs.com/

2. **Go to Email Templates**
   - Click **Email Templates** (left sidebar)

3. **Edit Your Template**
   - Find template with ID: `template_41fnprx`
   - Click **Edit**

4. **Update Template Content**
   - Replace all template variables with these:
     - `{{to_email}}` - for recipient email
     - `{{user_name}}` - for username
     - `{{otp_code}}` - for OTP code

5. **Example Template**
   ```
   Subject: Your OTP Verification Code

   Hi {{user_name}},

   Your OTP verification code is: {{otp_code}}

   Please use this code to verify your email address.

   This code will expire in 10 minutes.

   Best regards,
   Alumni System Team
   ```

6. **Save Template**
   - Click **Save**

### Important: Set Recipient Email

1. **In Template Settings**
   - Look for **"Send to"** or **"Recipient"** field
   - Set it to: `{{to_email}}`
   - This tells EmailJS to send to the email address provided

2. **Save**

## Step-by-Step Instructions

### Step 1: Open EmailJS Dashboard
1. Go to https://dashboard.emailjs.com/
2. Sign in with your account

### Step 2: Find Your Template
1. Click **Email Templates** (left sidebar)
2. Look for template ID: `template_41fnprx`
3. Click on it to open

### Step 3: Edit Template
1. Click **Edit** button
2. Update the template content

### Step 4: Update Variables
Replace old variables with new ones:

| Old | New |
|-----|-----|
| `{{email}}` | `{{to_email}}` |
| `{{otp}}` | `{{otp_code}}` |
| `{{user_name}}` | `{{user_name}}` (stays same) |

### Step 5: Set Recipient
1. Find the **"Send to"** field
2. Enter: `{{to_email}}`
3. This is crucial - it tells EmailJS where to send the email

### Step 6: Save
1. Click **Save** button
2. Confirm changes

## Test After Update

1. **Run the app**
   ```bash
   flutter run
   ```

2. **Go to Register Screen**
   - Click "Register"

3. **Fill Form**
   - Username: testuser
   - Email: your_email@gmail.com
   - Graduation Year: 2025
   - Password: Test@123
   - Confirm: Test@123

4. **Click Register**
   - Should send OTP email

5. **Check Email**
   - Look for email from EmailJS
   - Copy the OTP code
   - Enter it in the app

## If Still Not Working

### Check 1: Verify Template Variables
- Make sure template has: `{{to_email}}`, `{{user_name}}`, `{{otp_code}}`
- No typos in variable names

### Check 2: Verify Recipient Field
- Make sure "Send to" is set to: `{{to_email}}`
- Not hardcoded to a specific email

### Check 3: Check Console
- Run app in debug mode
- Look for error messages
- Share the full error message

### Check 4: Test in EmailJS
1. Go to Email Templates
2. Click **Test it**
3. Fill in test values:
   - `to_email`: your_email@gmail.com
   - `user_name`: Test User
   - `otp_code`: 123456
4. Click **Send**
5. Check if email arrives

## Code Changes Made

**File**: `lib/services/email_service.dart`

Changed template parameters from:
```dart
'template_params': {
  'email': toEmail,
  'user_name': username,
  'otp': otp,
},
```

To:
```dart
'template_params': {
  'to_email': toEmail,
  'user_name': username,
  'otp_code': otp,
},
```

## Summary

1. ✅ Code has been updated with correct parameter names
2. ⚠️ You need to update your EmailJS template
3. ⚠️ Make sure "Send to" field is set to `{{to_email}}`
4. ✅ Then test the registration again

---

**Next Steps**: Update your EmailJS template and test registration
