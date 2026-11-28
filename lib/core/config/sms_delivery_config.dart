/// Client-side settings for admin survey reminder SMS via Edge Function.
///
/// Semaphore credentials and [SMS_MODE] stay server-side in Function secrets.
class SmsDeliveryConfig {
  const SmsDeliveryConfig._();

  static const enabled = bool.fromEnvironment(
    'SMS_DELIVERY_ENABLED',
    defaultValue: true,
  );

  static const functionName = String.fromEnvironment(
    'SMS_DELIVERY_FUNCTION',
    defaultValue: 'send-survey-reminder-sms',
  );

  static bool get isConfigured => enabled && functionName.isNotEmpty;
}
