import 'package:alumni_system/core/config/email_delivery_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  EmailService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Tracer survey / announcement reminder via Gmail SMTP.
  Future<void> sendSurveyReminderEmail({
    required String toEmail,
    required String userName,
    required String surveyTitle,
    required String message,
  }) async {
    try {
      await _supabase.functions.invoke(
        EmailDeliveryConfig.functionName,
        body: {
          'kind': 'reminder',
          'toEmail': toEmail,
          'userName': userName,
          'title': surveyTitle,
          'message': message,
        },
      );
    } catch (e) {
      throw Exception('Error sending reminder email: $e');
    }
  }
}
