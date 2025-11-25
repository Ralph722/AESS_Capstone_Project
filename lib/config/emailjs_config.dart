class EmailJsConfig {
  const EmailJsConfig._();

  /// Replace these placeholders with your actual EmailJS values or
  /// inject them at runtime using `--dart-define`.
  static const serviceId = String.fromEnvironment(
    'EMAILJS_SERVICE_ID',
    defaultValue: 'service_in5juiq',
  );
  static const templateId = String.fromEnvironment(
    'EMAILJS_TEMPLATE_ID',
    defaultValue: 'template_7jnfm9h',
  );
  static const publicKey = String.fromEnvironment(
    'EMAILJS_PUBLIC_KEY',
    defaultValue: '748FM3kJtVQ3g2-y9',
  );
}
