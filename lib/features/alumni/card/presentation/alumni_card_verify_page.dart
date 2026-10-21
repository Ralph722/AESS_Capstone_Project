import 'package:flutter/material.dart';
import 'package:alumni_system/features/alumni/card/data/alumni_card_token_service.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_token.dart';
import 'package:alumni_system/features/alumni/card/presentation/alumni_card_verify_result_view.dart';
import 'package:alumni_system/features/auth/presentation/auth_gate.dart';
import 'package:alumni_system/shared/widgets/aess_logo.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Public staff screen opened from a QR scan (`/?verify=<token>`). No login.
class AlumniCardVerifyPage extends StatefulWidget {
  const AlumniCardVerifyPage({
    super.key,
    required this.code,
    this.tokenService,
  });

  final String code;
  final AlumniCardTokenService? tokenService;

  @override
  State<AlumniCardVerifyPage> createState() => _AlumniCardVerifyPageState();
}

class _AlumniCardVerifyPageState extends State<AlumniCardVerifyPage> {
  late final AlumniCardTokenService _tokens =
      widget.tokenService ?? AlumniCardTokenService();
  Future<AlumniCardVerifyResult>? _future;

  @override
  void initState() {
    super.initState();
    _future = _tokens.verify(widget.code);
  }

  void _openPortal() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortalTheme.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                children: [
                  const AessLogo(height: 44),
                  const SizedBox(height: 10),
                  const Text(
                    'Alumni card check',
                    style: TextStyle(
                      color: PortalTheme.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'USTP Alumni Engagement and Support System',
                    textAlign: TextAlign.center,
                    style: PortalTheme.meta.copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: FutureBuilder<AlumniCardVerifyResult>(
                      future: _future,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: PortalTheme.navy,
                              strokeWidth: 2.5,
                            ),
                          );
                        }
                        final result =
                            snap.data ??
                            const AlumniCardVerifyResult.notValid();
                        return SingleChildScrollView(
                          child: AlumniCardVerifyResultView(result: result),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _openPortal,
                      style: PortalTheme.primaryButton(),
                      child: const Text('Back to portal'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
