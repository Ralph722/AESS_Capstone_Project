import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_system/features/alumni/card/data/alumni_card_token_service.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_token.dart';
import 'package:alumni_system/features/alumni/card/presentation/alumni_card_verify_result_view.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Admin dialog: type the 6-character backup code (or paste a token) to verify.
Future<void> showAlumniCardVerifyDialog(
  BuildContext context, {
  AlumniCardTokenService? tokenService,
}) {
  return showDialog<void>(
    context: context,
    barrierLabel: 'Verify alumni card',
    builder: (_) => AlumniCardVerifyDialog(tokenService: tokenService),
  );
}

class AlumniCardVerifyDialog extends StatefulWidget {
  const AlumniCardVerifyDialog({super.key, this.tokenService});

  final AlumniCardTokenService? tokenService;

  @override
  State<AlumniCardVerifyDialog> createState() => _AlumniCardVerifyDialogState();
}

class _AlumniCardVerifyDialogState extends State<AlumniCardVerifyDialog> {
  late final AlumniCardTokenService _tokens =
      widget.tokenService ?? AlumniCardTokenService();
  final _controller = TextEditingController();
  final _focus = FocusNode();
  AlumniCardVerifyResult? _result;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() {
        _error = 'Enter the backup code from the card.';
        _result = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    final result = await _tokens.verify(code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Verify alumni card',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Text(
                'Type the 6-character code under the QR (for example A1B-2C3), '
                'or paste the long token from a scanned link.',
                style: TextStyle(
                  fontSize: 13,
                  color: AdminColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_busy) _submit();
                },
                // Allow paste of full verify URLs as well as short codes / tokens.
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9A-Fa-f\-\.?/=:&_a-zA-Z]'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: 'Backup code or token',
                  hintText: 'A1B-2C3',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verify'),
              ),
              if (_result != null) ...[
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 16),
                AlumniCardVerifyResultView(result: _result!, compact: true),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Done',
                    style: TextStyle(color: PortalTheme.navy),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
