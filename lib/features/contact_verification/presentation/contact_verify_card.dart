import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alumni_system/features/contact_verification/data/contact_verification_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// One changed contact: previous and new value, an Edit action, and the
/// send-code / enter-code / verified flow.
///
/// The parent owns the value and the verified state: [onValueChanged] is
/// called when the alumnus fixes the value here, [onVerified] with the
/// contact as the server stores it.
class ContactVerifyCard extends StatefulWidget {
  const ContactVerifyCard({
    super.key,
    required this.channel,
    required this.original,
    required this.value,
    required this.verified,
    required this.onValueChanged,
    required this.onVerified,
    this.label,
    this.verifiedText,
    this.enabled = true,
    this.service,
  });

  final ContactChannel channel;
  final String original;
  final String value;
  final bool verified;
  final ValueChanged<String> onValueChanged;
  final ValueChanged<String> onVerified;

  /// Title, e.g. "Email address (Q3)". Defaults to the channel name.
  final String? label;

  /// Line shown once verified. Defaults to "… saved when you submit."
  final String? verifiedText;
  final bool enabled;
  final ContactVerificationService? service;

  @override
  State<ContactVerifyCard> createState() => _ContactVerifyCardState();
}

class _ContactVerifyCardState extends State<ContactVerifyCard> {
  late final ContactVerificationService _service =
      widget.service ?? ContactVerificationService();
  final _code = TextEditingController();
  final _edit = TextEditingController();

  bool _editing = false;
  String? _editError;
  bool _busy = false;
  String? _error;
  ContactCodeSent? _sent;
  int _cooldown = 0;
  Timer? _timer;

  bool get _isEmail => widget.channel == ContactChannel.email;

  @override
  void didUpdateWidget(covariant ContactVerifyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!ContactNormalizer.same(
      widget.channel,
      oldWidget.value,
      widget.value,
    )) {
      _sent = null;
      _error = null;
      _code.clear();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _edit.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _send() async {
    final target = ContactNormalizer.normalize(widget.channel, widget.value);
    if (target == null) {
      setState(() => _error = ContactNormalizer.invalidMessage(widget.channel));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sent = await _service.sendCode(widget.channel, target);
      if (!mounted) return;
      setState(() => _sent = sent);
      _code.clear();
      _startCooldown(sent.resendAfterSeconds);
    } on ContactVerificationException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      final wait = e.retryAfterSeconds;
      if (wait != null) _startCooldown(wait);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final sent = _sent;
    final code = _code.text.trim();
    if (sent == null || code.length != ContactVerificationService.codeLength) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final target = await _service.verifyCode(
        widget.channel,
        sent.target,
        code,
      );
      if (!mounted) return;
      widget.onVerified(target);
    } on ContactVerificationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startEdit() {
    _edit.text = widget.value;
    setState(() {
      _editing = true;
      _editError = null;
    });
  }

  void _saveEdit() {
    final text = _edit.text.trim();
    if (ContactNormalizer.normalize(widget.channel, text) == null) {
      setState(
        () => _editError = ContactNormalizer.invalidMessage(widget.channel),
      );
      return;
    }
    setState(() => _editing = false);
    if (text != widget.value.trim()) widget.onValueChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    final verified = widget.verified;
    return Container(
      padding: const EdgeInsets.all(PortalTheme.space4),
      decoration: BoxDecoration(
        color: PortalTheme.card,
        borderRadius: BorderRadius.circular(PortalTheme.radius2xl),
        border: Border.all(
          color: verified
              ? PortalTheme.success.withValues(alpha: 0.45)
              : PortalTheme.border.withValues(alpha: 0.75),
        ),
        boxShadow: PortalTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(verified),
          const SizedBox(height: 12),
          if (_editing) _editor() else _values(verified),
          if (!_isEmail) ...[
            const SizedBox(height: 12),
            const _Note(
              icon: Icons.sms_outlined,
              text:
                  "We'll text a 6-digit code to this Philippine mobile "
                  'number. Standard SMS rates may apply.',
            ),
          ],
          if (!_editing) ...[
            const SizedBox(height: 14),
            if (verified) _verifiedRow() else _codeFlow(),
          ],
        ],
      ),
    );
  }

  Widget _header(bool verified) {
    final color = verified ? PortalTheme.success : PortalTheme.warning;
    return Row(
      children: [
        Icon(
          _isEmail ? Icons.email_outlined : Icons.smartphone_outlined,
          color: PortalTheme.navy,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.label ?? (_isEmail ? 'Email address' : 'Mobile number'),
            style: PortalTheme.cardTitle.copyWith(fontSize: 15),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            verified ? 'Verified' : 'Needs verification',
            style: PortalTheme.meta.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _values(bool verified) {
    final unchanged = ContactNormalizer.same(
      widget.channel,
      widget.original,
      widget.value,
    );
    final hasOriginal = widget.original.trim().isNotEmpty && !unchanged;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasOriginal) ...[
                Text('Previous', style: PortalTheme.caption),
                const SizedBox(height: 2),
                Text(
                  widget.original.trim(),
                  style: PortalTheme.bodySecondary.copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: PortalTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                hasOriginal
                    ? 'New'
                    : unchanged
                    ? (_isEmail ? 'Email' : 'Number')
                    : 'Added',
                style: PortalTheme.caption,
              ),
              const SizedBox(height: 2),
              SelectableText(
                widget.value.trim(),
                style: PortalTheme.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: widget.enabled && !_busy ? _startEdit : null,
          style: PortalTheme.ghostButton(dense: true),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
        ),
      ],
    );
  }

  Widget _editor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _edit,
          autofocus: true,
          keyboardType: _isEmail
              ? TextInputType.emailAddress
              : TextInputType.phone,
          decoration: InputDecoration(
            labelText: _isEmail ? 'Email address' : 'Mobile number',
            errorText: _editError,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => _saveEdit(),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _editing = false),
              style: PortalTheme.ghostButton(dense: true),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saveEdit,
              style: PortalTheme.primaryButton(dense: true),
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _codeFlow() {
    final sent = _sent;
    final canResend = !_busy && _cooldown == 0 && widget.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sent == null)
          FilledButton.icon(
            onPressed: canResend ? _send : null,
            style: PortalTheme.primaryButton(),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _cooldown > 0
                  ? 'Send code in ${_clock(_cooldown)}'
                  : _isEmail
                  ? 'Send code to this email'
                  : 'Send code by text',
            ),
          )
        else ...[
          Semantics(
            liveRegion: true,
            child: Text(
              sent.isDemo
                  ? 'Enter the 6-digit code below to confirm this number.'
                  : _isEmail
                  ? 'We sent a 6-digit code to ${sent.target}. It expires in '
                        '10 minutes. Check your spam folder if you '
                        "don't see it."
                  : 'We texted a 6-digit code to ${sent.target}. It expires '
                        'in 10 minutes.',
              style: PortalTheme.bodySecondary.copyWith(fontSize: 13),
            ),
          ),
          if (sent.isDemo) ...[
            const SizedBox(height: 8),
            _DemoCode(code: sent.demoCode!),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  label: 'Verification code, 6 digits',
                  child: TextField(
                    controller: _code,
                    enabled: widget.enabled && !_busy,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                        ContactVerificationService.codeLength,
                      ),
                    ],
                    style: const TextStyle(
                      fontSize: 18,
                      letterSpacing: 6,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      hintText: '000000',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _verify(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed:
                    widget.enabled &&
                        !_busy &&
                        _code.text.length ==
                            ContactVerificationService.codeLength
                    ? _verify
                    : null,
                style: PortalTheme.primaryButton(),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verify'),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: canResend ? _send : null,
              style: PortalTheme.ghostButton(dense: true),
              child: Text(
                _cooldown > 0
                    ? 'Resend code in ${_clock(_cooldown)}'
                    : 'Resend code',
              ),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: PortalTheme.meta.copyWith(
                color: PortalTheme.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _verifiedRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: PortalTheme.success,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              widget.verifiedText ??
                  (_isEmail
                      ? 'Email verified. It will be saved when you submit.'
                      : 'Number confirmed. It will be saved when you submit.'),
              style: PortalTheme.body.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: PortalTheme.success,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PortalTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(color: PortalTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: PortalTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: PortalTheme.meta.copyWith(height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _DemoCode extends StatelessWidget {
  const _DemoCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PortalTheme.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
        border: Border.all(color: PortalTheme.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            'Demo code',
            style: PortalTheme.meta.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          SelectableText(
            code,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: PortalTheme.navy,
            ),
          ),
        ],
      ),
    );
  }
}
