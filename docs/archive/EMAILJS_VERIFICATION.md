# EmailJS Verification Checklist

## Your Current Configuration

✅ **Service ID**: `service_in5juiq`  
✅ **Template ID**: `template_41fnprx`  
✅ **Public Key**: `748FM3kJtVQ3g2-y9`  

## Quick Verification Steps

### Step 1: Verify EmailJS Account
1. Go to https://www.emailjs.com/
2. Sign in with your account
3. Go to **Dashboard**

### Step 2: Verify Service ID
1. Click **Email Services** (left sidebar)
2. Look for service with ID: `service_in5juiq`
3. Make sure it's **Active** (green status)
4. If not found, you need to create/update it

### Step 3: Verify Template ID
1. Click **Email Templates** (left sidebar)
2. Look for template with ID: `template_41fnprx`
3. Make sure it has these variables:
   - `{{user_name}}`
   - `{{email}}`
   - `{{otp}}`

### Step 4: Verify Public Key
1. Click **Account** (left sidebar)
2. Find **Public Key**: `748FM3kJtVQ3g2-y9`
3. Make sure it matches

## Test EmailJS Connection

### Option 1: Test in EmailJS Dashboard
1. Go to **Email Templates**
2. Select your template
3. Click **Test it**
4. Fill in:
   - `user_name`: Test User
   - `email`: your_email@gmail.com
   - `otp`: 123456
5. Click **Send**
6. Check your email inbox

### Option 2: Test in Flutter App
1. Run: `flutter run`
2. Go to **Register** screen
3. Fill form:
   - Username: TestUser
   - Email: your_email@gmail.com
   - Graduation Year: 2024
   - Password: Test@123
   - Confirm: Test@123
4. Click **Register**
5. Should receive OTP email

## If EmailJS is Not Working

### Issue: No email received

**Solution 1: Check Spam Folder**
- EmailJS emails might go to spam
- Add to contacts to whitelist

**Solution 2: Verify Service is Active**
- Go to EmailJS Dashboard
- Email Services → Check status is green
- If red, reconnect your email provider

**Solution 3: Verify Template Variables**
- Go to Email Templates
- Make sure template has all three variables:
  - `{{user_name}}`
  - `{{email}}`
  - `{{otp}}`

**Solution 4: Check Public Key**
- Go to Account
- Copy exact Public Key
- Update in `lib/config/emailjs_config.dart`

### Issue: Error 401 (Unauthorized)

**Solution: Update Public Key**
1. Go to EmailJS Account
2. Copy exact Public Key
3. Update `lib/config/emailjs_config.dart`:
   ```dart
   static const publicKey = 'your_exact_public_key';
   ```

### Issue: Error 404 (Not Found)

**Solution: Update Service or Template ID**
1. Go to EmailJS Dashboard
2. Copy exact Service ID and Template ID
3. Update `lib/config/emailjs_config.dart`:
   ```dart
   static const serviceId = 'your_service_id';
   static const templateId = 'your_template_id';
   ```

## Configuration File Location

**File**: `lib/config/emailjs_config.dart`

```dart
class EmailJsConfig {
  const EmailJsConfig._();

  static const serviceId = String.fromEnvironment(
    'EMAILJS_SERVICE_ID',
    defaultValue: 'service_in5juiq',
  );
  static const templateId = String.fromEnvironment(
    'EMAILJS_TEMPLATE_ID',
    defaultValue: 'template_41fnprx',
  );
  static const publicKey = String.fromEnvironment(
    'EMAILJS_PUBLIC_KEY',
    defaultValue: '748FM3kJtVQ3g2-y9',
  );
}
```

## Email Service File

**File**: `lib/services/email_service.dart`

Handles sending OTP emails via EmailJS API.

## Quick Links

- **EmailJS Website**: https://www.emailjs.com/
- **EmailJS Dashboard**: https://dashboard.emailjs.com/
- **EmailJS Docs**: https://www.emailjs.com/docs/
- **EmailJS FAQ**: https://www.emailjs.com/docs/faq/

## Summary

Your EmailJS is **already configured** with valid credentials. To verify it's working:

1. ✅ Go to https://www.emailjs.com/
2. ✅ Sign in to your account
3. ✅ Verify Service ID `service_in5juiq` is active
4. ✅ Verify Template ID `template_41fnprx` exists
5. ✅ Test sending an email via dashboard
6. ✅ Run app and test registration with OTP

If you receive the test email, EmailJS is connected and working!

---

**Status**: ✅ EmailJS Ready to Use
