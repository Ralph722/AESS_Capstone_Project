# EmailJS Setup & Connection Guide

## Current Configuration

Your EmailJS is already configured with:

```
Service ID: service_in5juiq
Template ID: template_41fnprx
Public Key: 748FM3kJtVQ3g2-y9
```

## Step 1: Verify Your EmailJS Account

1. **Go to EmailJS Website**
   - Visit: https://www.emailjs.com/

2. **Sign In or Create Account**
   - If you don't have an account, click "Sign Up"
   - Create a free account

3. **Go to Dashboard**
   - After login, you'll see the dashboard

## Step 2: Verify Service ID

1. **In EmailJS Dashboard**
   - Click **Email Services** (left sidebar)
   - You should see a service with ID: `service_in5juiq`
   - If not, create a new service:
     - Click **Add Service**
     - Select your email provider (Gmail, Outlook, etc.)
     - Follow the setup instructions
     - Copy the **Service ID**

2. **Update Config if Needed**
   - Edit: `lib/config/emailjs_config.dart`
   - Update `serviceId` with your actual Service ID

## Step 3: Verify Template ID

1. **In EmailJS Dashboard**
   - Click **Email Templates** (left sidebar)
   - You should see a template with ID: `template_41fnprx`
   - If not, create a new template:
     - Click **Create New Template**
     - Name: "OTP Verification"
     - Add template variables: `{{user_name}}`, `{{email}}`, `{{otp}}`
     - Example template:
       ```
       Hi {{user_name}},

       Your OTP code is: {{otp}}

       Please use this code to verify your email address.

       Best regards,
       Alumni System
       ```
     - Copy the **Template ID**

2. **Update Config if Needed**
   - Edit: `lib/config/emailjs_config.dart`
   - Update `templateId` with your actual Template ID

## Step 4: Get Public Key

1. **In EmailJS Dashboard**
   - Click **Account** (left sidebar)
   - Look for **Public Key**
   - Copy your public key: `748FM3kJtVQ3g2-y9`

2. **Update Config if Needed**
   - Edit: `lib/config/emailjs_config.dart`
   - Update `publicKey` with your actual Public Key

## Step 5: Test EmailJS Connection

### Test via EmailJS Dashboard

1. **In EmailJS Dashboard**
   - Go to **Email Templates**
   - Select your template
   - Click **Test it**
   - Fill in test parameters:
     - `user_name`: Test User
     - `email`: your_email@example.com
     - `otp`: 123456
   - Click **Send**
   - Check your email for the test message

### Test via Flutter App

1. **Run the app**
   ```bash
   flutter run
   ```

2. **Go to Register Screen**
   - Click "Register"
   - Fill in the form:
     - Username: Test User
     - Email: your_email@example.com
     - Graduation Year: 2024
     - Password: Test@123
     - Confirm Password: Test@123
   - Click "Register"
   - Should receive OTP email

3. **Check Email**
   - Look for email from EmailJS
   - Copy the OTP code
   - Enter it in the app

## Configuration File

Your EmailJS configuration is in: `lib/config/emailjs_config.dart`

```dart
class EmailJsConfig {
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

## Email Service Implementation

Your email service is in: `lib/services/email_service.dart`

It sends OTP emails using:
- EmailJS API endpoint: `https://api.emailjs.com/api/v1.0/email/send`
- HTTP POST request with JSON payload
- Automatic error handling

## Troubleshooting

### Email Not Received

**Check 1: Verify EmailJS Credentials**
- Go to EmailJS Dashboard
- Confirm Service ID, Template ID, and Public Key are correct
- Update `emailjs_config.dart` if needed

**Check 2: Verify Email Service**
- In EmailJS Dashboard → Email Services
- Make sure service is connected and active
- Check email provider credentials

**Check 3: Verify Email Template**
- In EmailJS Dashboard → Email Templates
- Make sure template exists and is active
- Verify template variables match: `{{user_name}}`, `{{email}}`, `{{otp}}`

**Check 4: Check Email Spam Folder**
- EmailJS emails might go to spam
- Add EmailJS to your contacts

**Check 5: Check Console Logs**
- Run app in debug mode
- Look for error messages in console
- Check network requests

### Common Errors

**Error: "Failed to send OTP via EmailJS (401)"**
- Public Key is incorrect
- Update `publicKey` in `emailjs_config.dart`

**Error: "Failed to send OTP via EmailJS (404)"**
- Service ID or Template ID is incorrect
- Update `serviceId` or `templateId` in `emailjs_config.dart`

**Error: "Failed to send OTP via EmailJS (400)"**
- Template variables don't match
- Check template has: `{{user_name}}`, `{{email}}`, `{{otp}}`

## Step-by-Step Setup (If Starting Fresh)

### 1. Create EmailJS Account
- Visit https://www.emailjs.com/
- Sign up for free account

### 2. Add Email Service
- Dashboard → Email Services → Add Service
- Select your email provider (Gmail recommended)
- Follow authentication steps
- Copy **Service ID**

### 3. Create Email Template
- Dashboard → Email Templates → Create New Template
- Name: "OTP Verification"
- Add template content with variables:
  ```
  Hi {{user_name}},
  Your OTP: {{otp}}
  Email: {{email}}
  ```
- Copy **Template ID**

### 4. Get Public Key
- Dashboard → Account
- Copy **Public Key**

### 5. Update Config
- Edit `lib/config/emailjs_config.dart`
- Update all three values:
  ```dart
  static const serviceId = 'your_service_id';
  static const templateId = 'your_template_id';
  static const publicKey = 'your_public_key';
  ```

### 6. Test
- Run app: `flutter run`
- Go to Register
- Try signing up
- Check email for OTP

## Verification Checklist

- [ ] EmailJS account created
- [ ] Email service added and connected
- [ ] Email template created with variables
- [ ] Public key obtained
- [ ] Config file updated with correct IDs
- [ ] Test email sent successfully
- [ ] App registration sends OTP email
- [ ] OTP received in email
- [ ] OTP verification works

## Important Notes

✅ EmailJS is **free** for up to 200 emails/month  
✅ No credit card required for free tier  
✅ Emails are sent from EmailJS servers  
✅ Your email credentials are secure  
✅ Public Key is safe to expose (it's meant to be public)  

## Support

- **EmailJS Documentation**: https://www.emailjs.com/docs/
- **EmailJS Support**: https://www.emailjs.com/contact/
- **Common Issues**: https://www.emailjs.com/docs/faq/

---

**Status**: ✅ EmailJS Configured and Ready
**Last Updated**: November 25, 2025
