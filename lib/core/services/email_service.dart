import 'package:alumni_system/core/config/email_delivery_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  EmailService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Tracer survey / announcement reminder via Gmail SMTP.
  ///
  /// [actionUrl] must be a canonical AESS link (see ShareLinkConfig); the
  /// Edge Function re-validates it before rendering the CTA button.
  ///
  /// [preferenceType] is the notification type whose email preference the
  /// server checks (`survey`, `announcement`, `event`, `job`, `system`).
  /// Returns false when the recipient opted out and nothing was sent.
  ///
  /// Event/job publish and reminder emails are queued by the database
  /// (`queue_notification_email`) and sent by
  /// `send-queued-notification-emails` — not this client path.
  Future<bool> sendSurveyReminderEmail({
    required String toEmail,
    required String userName,
    required String surveyTitle,
    required String message,
    String? actionUrl,
    String? actionLabel,
    String? deadlineText,
    String preferenceType = 'survey',
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        EmailDeliveryConfig.functionName,
        body: {
          'kind': 'reminder',
          'toEmail': toEmail,
          'userName': userName,
          'title': surveyTitle,
          'message': message,
          'preferenceType': preferenceType,
          if (actionUrl != null && actionUrl.isNotEmpty)
            'actionUrl': actionUrl,
          if (actionLabel != null && actionLabel.isNotEmpty)
            'actionLabel': actionLabel,
          if (deadlineText != null && deadlineText.isNotEmpty)
            'deadlineText': deadlineText,
        },
      );
      final data = response.data;
      if (data is Map && data['skipped'] == true) return false;
      return true;
    } catch (e) {
      throw Exception('Error sending reminder email: $e');
    }
  }
}
