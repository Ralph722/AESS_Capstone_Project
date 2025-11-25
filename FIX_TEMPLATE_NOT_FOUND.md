# Fix: Template ID Not Found Error

## The Error

**"Failed to send OTP via EmailJS (400): The template ID not found"**

This means the template ID in your config doesn't match any template in your EmailJS account.

## The Solution

You need to get the **correct Template ID** from your EmailJS dashboard and update the config.

## Step 1: Get Correct Template ID from EmailJS

1. **Go to EmailJS Dashboard**
   - Visit: https://dashboard.emailjs.com/

2. **Click Email Templates**
   - Left sidebar → Email Templates

3. **Find Your OTP Template**
   - Look for the template you just created
   - It should have:
     - Subject: "OTP Verification Code"
     - Content with: `{{user_name}}` and `{{otp_code}}`
     - To Email: `{{to_email}}`

4. **Copy the Template ID**
   - You'll see something like: `template_xxxxx` (different from what you have)
   - Click on the template
   - Look for **Template ID** at the top or in settings
   - Copy the exact ID

## Step 2: Update Config File

1. **Open**: `lib/config/emailjs_config.dart`

2. **Replace the templateId**
   ```dart
   static const templateId = String.fromEnvironment(
     'EMAILJS_TEMPLATE_ID',
     defaultValue: 'YOUR_NEW_TEMPLATE_ID_HERE',
   );
   ```

3. **Example**: If your template ID is `template_abc123`, change it to:
   ```dart
   static const templateId = String.fromEnvironment(
     'EMAILJS_TEMPLATE_ID',
     defaultValue: 'template_abc123',
   );
   ```

4. **Save the file**

## Step 3: Test Again

1. **Run the app**
   ```bash
   flutter run
   ```

2. **Go to Register**
   - Click Register button

3. **Fill Form**
   - Username: testuser
   - Email: your_email@gmail.com
   - Graduation Year: 2025
   - Password: Test@123
   - Confirm: Test@123

4. **Click Register**
   - Should send OTP email now

5. **Check Email**
   - Look for OTP email
   - Copy the code
   - Enter in app

## How to Find Template ID in EmailJS

### Method 1: In Template List
1. Go to Email Templates
2. Hover over your template
3. Template ID should be visible

### Method 2: In Template Editor
1. Go to Email Templates
2. Click on your template to open it
3. Look at the top or in the URL
4. Template ID format: `template_xxxxx`

### Method 3: Copy from Dashboard
1. Go to Email Templates
2. Right-click on template
3. Copy the template ID

## Example Configuration

**Before (Wrong)**:
```dart
static const templateId = String.fromEnvironment(
  'EMAILJS_TEMPLATE_ID',
  defaultValue: 'template_41fnprx',  // ❌ This doesn't exist
);
```

**After (Correct)**:
```dart
static const templateId = String.fromEnvironment(
  'EMAILJS_TEMPLATE_ID',
  defaultValue: 'template_abc123',  // ✅ Your actual template ID
);
```

## Verify Template in EmailJS

Before updating config, make sure your template:

- ✅ Has Subject: `OTP Verification Code`
- ✅ Has Content with: `{{user_name}}` and `{{otp_code}}`
- ✅ Has "To Email" set to: `{{to_email}}`
- ✅ Status is Active (green)
- ✅ Template ID is visible

## Quick Steps Summary

1. Go to https://dashboard.emailjs.com/
2. Click Email Templates
3. Find your OTP template
4. Copy the Template ID
5. Open `lib/config/emailjs_config.dart`
6. Replace `template_41fnprx` with your actual Template ID
7. Save file
8. Run app again
9. Test registration

## If Still Getting Error

### Check 1: Verify Template ID is Correct
- Copy exact Template ID from EmailJS
- No typos
- Matches exactly

### Check 2: Verify Template Exists
- Go to Email Templates
- Make sure your template is in the list
- Status should be green (Active)

### Check 3: Verify Template Variables
- Template should have: `{{user_name}}`, `{{otp_code}}`
- "To Email" should be: `{{to_email}}`

### Check 4: Restart App
- Stop the app: Press `q`
- Run again: `flutter run`
- Try registration again

## Common Mistakes

❌ **Wrong**: Using old template ID that doesn't exist  
❌ **Wrong**: Typo in template ID  
❌ **Wrong**: Template is deleted but config still references it  
❌ **Wrong**: Template is inactive (red status)  

✅ **Right**: Using exact Template ID from EmailJS  
✅ **Right**: Template exists and is active  
✅ **Right**: Template has correct variables  

## File to Update

**File**: `lib/config/emailjs_config.dart`

Change this line:
```dart
defaultValue: 'template_41fnprx',
```

To your actual template ID from EmailJS.

---

**Status**: Update Template ID and Test Again
