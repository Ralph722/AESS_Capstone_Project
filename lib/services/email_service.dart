import 'dart:convert';

import 'package:http/http.dart' as http;

class EmailService {
  EmailService({
    required this.serviceId,
    required this.templateId,
    required this.publicKey,
  });

  final String serviceId;
  final String templateId;
  final String publicKey;

  Future<void> sendOtpEmail({
    required String toEmail,
    required String otp,
    required String username,
  }) async {
    final uri = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    final payload = {
      'service_id': serviceId,
      'template_id': templateId,
      'user_id': publicKey,
      'template_params': {
        'to_email': toEmail,
        'user_name': username,
        'otp_code': otp,
      },
    };

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to send OTP via EmailJS (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error sending OTP: $e');
    }
  }
}
