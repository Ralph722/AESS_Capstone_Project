# EmailJS Template Configuration - Accurate Fix

## The Problem

Error: **"The recipients address is empty"**

This happens because EmailJS doesn't know where to send the email. The template needs to be configured correctly.

## The Solution

Your EmailJS template must use these **exact variable names**:
- `{{to_email}}` - recipient email address
- `{{user_name}}` - username
- `{{otp_code}}` - OTP code

## Step-by-Step Fix

### Step 1: Go to EmailJS Dashboard
1. Visit: https://dashboard.emailjs.com/
2. Sign in with your account
3. Click **Email Templates** (left sidebar)

### Step 2: Find Your Template
1. Look for template with ID: `template_41fnprx`
2. Click on it to open

### Step 3: Delete Old Template (Recommended)
1. Click **Delete** button
2. Confirm deletion
3. This ensures no conflicts with old variable names

### Step 4: Create New Template
1. Click **Create New Template**
2. Name: `OTP Verification`
3. Click **Create**

### Step 5: Configure Template Settings

**In the template editor:**

1. **Subject Line**
   ```
   OTP Verification Code
   ```

2. **Email Content**
   ```
   Hi {{user_name}},

   Your OTP verification code is: {{otp_code}}

   Please use this code to verify your email address.

   This code will expire in 10 minutes.

   Best regards,
   Alumni System Team
   ```

### Step 6: Set the Recipient Email (CRITICAL)

This is the most important step!

1. Look for **"Send to"** field or **"To Email"** field
2. Enter: `{{to_email}}`
3. **Do NOT enter a hardcoded email address**
4. **Do NOT leave it blank**

### Step 7: Save Template
1. Click **Save** button
2. Copy the **Template ID** that appears
3. Update in your config if needed

## Visual Guide

### Template Variables Used
```
Subject: OTP Verification Code

Hi {{user_name}},

Your OTP verification code is: {{otp_code}}

Please use this code to verify your email address.

Best regards,
Alumni System Team
```

### Send To Field
```
{{to_email}}
```

## Verify Configuration

After creating the template:

1. **Go to Email Templates**
2. **Find your template**
3. **Check these fields:**
   - ✅ Subject contains template variables
   - ✅ Body contains: `{{user_name}}`, `{{otp_code}}`
   - ✅ "Send to" field is: `{{to_email}}`
   - ✅ Template is Active (green status)

## Test the Template

### Test in EmailJS Dashboard

1. Go to **Email Templates**
2. Select your template
3. Click **Test it**
4. Fill in test values:
   - `to_email`: your_email@gmail.com
   - `user_name`: Test User
   - `otp_code`: 123456
5. Click **Send**
6. Check your email inbox

### If Test Email Works
- Your template is configured correctly
- The app should work now

### If Test Email Doesn't Work
- Check "Send to" field is `{{to_email}}`
- Check template variables are spelled correctly
- Check email service is active

## Code Changes

**File**: `lib/services/email_service.dart`

The app now sends these parameters:
```dart
'template_params': {
  'to_email': toEmail,      // recipient email
  'user_name': username,    // username
  'otp_code': otp,          // OTP code
},
```

Your template must use these **exact names**.

## Common Mistakes to Avoid

❌ **Wrong**: Using `{{email}}` instead of `{{to_email}}`  
❌ **Wrong**: Using `{{otp}}` instead of `{{otp_code}}`  
❌ **Wrong**: Leaving "Send to" field blank  
❌ **Wrong**: Using hardcoded email in "Send to" field  
❌ **Wrong**: Typos in variable names  

✅ **Right**: Using `{{to_email}}` in "Send to" field  
✅ **Right**: Using `{{otp_code}}` in template body  
✅ **Right**: Using `{{user_name}}` in template body  

## Quick Checklist

- [ ] Deleted old template (optional but recommended)
- [ ] Created new template with correct name
- [ ] Added subject: `OTP Verification Code`
- [ ] Added body with: `{{user_name}}`, `{{otp_code}}`
- [ ] Set "Send to" field to: `{{to_email}}`
- [ ] Saved template
- [ ] Tested template in EmailJS dashboard
- [ ] Received test email successfully
- [ ] Copied new Template ID
- [ ] Updated config file if Template ID changed

## If Template ID Changed

If you created a new template and got a new Template ID:

1. Update: `lib/config/emailjs_config.dart`
2. Change `templateId` to your new Template ID
3. Run app again

## Test in App

After template is configured:

1. Run: `flutter run`
2. Go to **Register**
3. Fill form:
   - Username: testuser
   - Email: your_email@gmail.com
   - Graduation Year: 2025
   - Password: Test@123
   - Confirm: Test@123
4. Click **Register**
5. Should receive OTP email
6. Enter OTP to complete registration

## Troubleshooting

### Still Getting "Recipients Address Empty" Error

**Solution 1**: Check "Send to" field
- Make sure it's set to: `{{to_email}}`
- Not a hardcoded email
- Not blank

**Solution 2**: Check template is saved
- Go to Email Templates
- Make sure your template appears in the list
- Status should be green (Active)

**Solution 3**: Test in EmailJS
- Go to Email Templates
- Click **Test it**
- Fill in test values
- Click **Send**
- Check if email arrives

**Solution 4**: Check variable names
- Make sure template uses:
  - `{{to_email}}`
  - `{{user_name}}`
  - `{{otp_code}}`
- No typos

### Getting Different Error

Share the full error message and we can debug further.

## Summary

1. ✅ Code has been updated to use correct parameter names
2. ⚠️ **You MUST update your EmailJS template**
3. ⚠️ **Most important**: Set "Send to" to `{{to_email}}`
4. ✅ Test template in EmailJS dashboard
5. ✅ Then test registration in app

---

**Status**: Code Fixed - Now Configure EmailJS Template Correctly
