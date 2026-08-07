/// Client-side settings for email delivery via Supabase Edge Function.
///
/// Gmail SMTP credentials stay server-side in Supabase Function secrets.
class EmailDeliveryConfig {
  const EmailDeliveryConfig._();

  static const enabled = bool.fromEnvironment(
    'EMAIL_DELIVERY_ENABLED',
    defaultValue: true,
  );

  static const functionName = String.fromEnvironment(
    'EMAIL_DELIVERY_FUNCTION',
    defaultValue: 'send-email',
  );

  static bool get isConfigured => enabled && functionName.isNotEmpty;
}
