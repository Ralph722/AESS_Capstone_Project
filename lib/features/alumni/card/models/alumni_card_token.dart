/// Short-lived verification payload for the digital alumni card QR / backup code.
class AlumniCardToken {
  const AlumniCardToken({
    required this.token,
    required this.shortCode,
    required this.expiresAt,
  });

  final String token;
  final String shortCode;
  final DateTime expiresAt;

  /// Display form `K7Q-4MZ`.
  String get displayShortCode {
    final c = shortCode.trim().toUpperCase();
    if (c.length != 6) return c;
    return '${c.substring(0, 3)}-${c.substring(3)}';
  }

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt.toUtc());

  Duration get remaining {
    final left = expiresAt.toUtc().difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  /// Default public Hosting origin used when [Uri.base] is localhost / empty
  /// (typical on Android). Override with `--dart-define=AESS_PUBLIC_WEB_ORIGIN=…`.
  static const String defaultPublicWebOrigin = String.fromEnvironment(
    'AESS_PUBLIC_WEB_ORIGIN',
    defaultValue: 'https://ustp-aess.web.app',
  );

  /// QR payload: app origin with `?verify=<token>`.
  ///
  /// Prefers the live browser origin on web; otherwise [defaultPublicWebOrigin]
  /// so phone cameras do not open `http://localhost/…`.
  String get verifyUrl {
    final base = Uri.base;
    final host = base.host.trim().toLowerCase();
    final useBase = base.hasScheme &&
        host.isNotEmpty &&
        host != 'localhost' &&
        host != '127.0.0.1';
    final origin = useBase
        ? Uri(
            scheme: base.scheme,
            host: base.host,
            port: base.hasPort ? base.port : null,
          )
        : Uri.parse(defaultPublicWebOrigin);
    return origin
        .replace(path: '/', queryParameters: {'verify': token})
        .toString();
  }

  factory AlumniCardToken.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expiresAt'];
    DateTime expiresAt;
    if (expiresRaw is DateTime) {
      expiresAt = expiresRaw.toUtc();
    } else {
      expiresAt = DateTime.tryParse(expiresRaw?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc().add(const Duration(seconds: 60));
    }
    return AlumniCardToken(
      token: (json['token'] ?? '').toString(),
      shortCode: (json['shortCode'] ?? '').toString().toUpperCase(),
      expiresAt: expiresAt,
    );
  }
}

/// Public result of [AlumniCardTokenService.verify] (no login required).
class AlumniCardVerifyResult {
  const AlumniCardVerifyResult._({
    required this.ok,
    required this.status,
    this.fullName,
    this.program,
    this.batchYear,
    this.profileImageUrl,
    this.message,
  });

  const AlumniCardVerifyResult.notValid({String? message})
    : this._(ok: false, status: 'not_valid', message: message);

  factory AlumniCardVerifyResult.verified({
    required String fullName,
    required String program,
    required String batchYear,
    String? profileImageUrl,
  }) => AlumniCardVerifyResult._(
    ok: true,
    status: 'verified',
    fullName: fullName,
    program: program,
    batchYear: batchYear,
    profileImageUrl: profileImageUrl,
  );

  final bool ok;
  final String status;
  final String? fullName;
  final String? program;
  final String? batchYear;
  final String? profileImageUrl;

  /// Optional detail when [ok] is false (e.g. transport / server error).
  final String? message;

  factory AlumniCardVerifyResult.fromJson(Map<String, dynamic> json) {
    if (json['ok'] != true || json['status']?.toString() != 'verified') {
      final msg = json['message']?.toString().trim();
      return AlumniCardVerifyResult.notValid(
        message: (msg == null || msg.isEmpty) ? null : msg,
      );
    }
    final photo = json['profileImageUrl']?.toString().trim();
    return AlumniCardVerifyResult.verified(
      fullName: (json['fullName'] ?? 'Alumni').toString(),
      program: (json['program'] ?? '').toString(),
      batchYear: (json['batchYear'] ?? '').toString(),
      profileImageUrl: (photo == null || photo.isEmpty) ? null : photo,
    );
  }
}
