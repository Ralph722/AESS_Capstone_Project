import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/alumni/card/data/alumni_card_token_service.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_data.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_token.dart';
import 'package:alumni_system/features/alumni/card/presentation/alumni_card_text.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// ID-card proportions (85.6 × 54 mm → ratio ≈ 1.586).
const double kAlumniCardAspectRatio = 1.586;

/// Keeps the card phone-sized on tablet/desktop (does not stretch full width).
const double kAlumniCardMaxWidth = 380;

/// Digital alumni card (front = identity, back = verify QR).
///
/// Side changes use a soft crossfade + scale, not a 3D flip.
class AlumniDigitalCard extends StatefulWidget {
  const AlumniDigitalCard({
    super.key,
    required this.data,
    this.showBack = false,
    this.onFlip,
    this.issueToken,
    this.offline = false,
    this.tokensEnabled = true,
  });

  final AlumniCardData data;
  final bool showBack;
  final ValueChanged<bool>? onFlip;

  /// Override for tests; default calls [AlumniCardTokenService.issue].
  final Future<AlumniCardToken?> Function()? issueToken;

  /// Cached copy shown without network — QR is not issued.
  final bool offline;

  /// When false, never mint/refresh codes (e.g. Profile tab kept alive off-screen).
  final bool tokensEnabled;

  @override
  State<AlumniDigitalCard> createState() => AlumniDigitalCardState();
}

class AlumniDigitalCardState extends State<AlumniDigitalCard>
    with TickerProviderStateMixin {
  late final AnimationController _swap;
  late final AnimationController _badgePulse;
  late bool _showBack;
  late DateTime _now;
  Timer? _clock;
  AlumniCardToken? _token;
  var _issuing = false;
  var _tokenFailed = false;
  String? _tokenError;

  bool get showingBack => _showBack;

  @override
  void initState() {
    super.initState();
    _showBack = widget.showBack;
    _now = DateTime.now();
    _swap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: _showBack ? 1 : 0,
    );
    _badgePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      // Only refresh while the verify face is visible and the parent allows
      // minting (Profile keep-alive must pass tokensEnabled: false off-tab).
      if (_canMintTokens) _ensureToken();
    });
    if (widget.offline) {
      _tokenFailed = true;
    } else if (_showBack && widget.tokensEnabled) {
      _ensureToken(force: true);
    }
  }

  bool get _canMintTokens =>
      !widget.offline && widget.tokensEnabled && _showBack;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion || widget.offline) {
      _badgePulse.stop();
      _badgePulse.value = 0;
    } else if (!_badgePulse.isAnimating) {
      _badgePulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AlumniDigitalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showBack != widget.showBack && widget.showBack != _showBack) {
      _setSide(widget.showBack, animate: true);
    }
    if (oldWidget.offline && !widget.offline && _canMintTokens) {
      _ensureToken(force: true);
    }
    if (!oldWidget.tokensEnabled &&
        widget.tokensEnabled &&
        _showBack &&
        !widget.offline) {
      _ensureToken(force: true);
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _badgePulse.dispose();
    _swap.dispose();
    super.dispose();
  }

  void flip() => _setSide(!_showBack, animate: true);

  void _setSide(bool back, {required bool animate}) {
    if (_showBack == back) return;
    setState(() => _showBack = back);
    widget.onFlip?.call(back);
    if (back && widget.tokensEnabled && !widget.offline) {
      _ensureToken(force: true);
    }
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      if (back) {
        _swap.forward();
      } else {
        _swap.reverse();
      }
    } else {
      _swap.value = back ? 1 : 0;
    }
  }

  Future<void> _ensureToken({bool force = false}) async {
    if (!_canMintTokens || _issuing) return;
    final current = _token;
    // Refresh only in the last 2s so staff can finish typing a code that
    // still has most of its 60s window left.
    if (!force &&
        current != null &&
        current.remaining > const Duration(seconds: 2)) {
      return;
    }
    _issuing = true;
    try {
      if (widget.issueToken != null) {
        final next = await widget.issueToken!();
        if (!mounted) return;
        setState(() {
          _token = next;
          _tokenFailed = next == null;
          _tokenError = next == null ? 'Code unavailable' : null;
        });
      } else {
        final result = await AlumniCardTokenService().issueDetailed(
          forceRefresh: force ||
              current == null ||
              current.remaining <= const Duration(seconds: 2),
        );
        if (!mounted) return;
        setState(() {
          _token = result.token;
          _tokenFailed = result.token == null;
          _tokenError = result.error;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _token = null;
        _tokenFailed = true;
        _tokenError = 'Code unavailable';
      });
    } finally {
      _issuing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final name = widget.data.fullName;
    final sid = widget.data.studentId;
    return Semantics(
      button: true,
      label: _showBack
          ? 'Alumni card QR side for $name. Double tap to show identity.'
          : 'Alumni card front for $name'
                '${sid.isEmpty ? '' : ', student ID $sid'}'
                '${widget.offline ? ', offline copy' : ''}'
                '. Double tap to show QR.',
      child: GestureDetector(
        onTap: flip,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kAlumniCardMaxWidth),
            child: AspectRatio(
              aspectRatio: kAlumniCardAspectRatio,
              child: AnimatedBuilder(
                animation: _swap,
                builder: (context, _) {
                  final t = reduceMotion
                      ? (_showBack ? 1.0 : 0.0)
                      : Curves.easeInOutCubic.transform(_swap.value);
                  final frontOpacity = (1.0 - t).clamp(0.0, 1.0);
                  final backOpacity = t.clamp(0.0, 1.0);
                  final frontScale = 1.0 - (0.04 * t);
                  final backScale = 0.96 + (0.04 * t);

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (frontOpacity > 0.01)
                        IgnorePointer(
                          ignoring: t > 0.5,
                          child: Opacity(
                            opacity: frontOpacity,
                            child: Transform.scale(
                              scale: frontScale,
                              child: _CardFront(
                                data: widget.data,
                                now: _now,
                                badgePulse: _badgePulse,
                                offline: widget.offline,
                                reduceMotion: reduceMotion,
                              ),
                            ),
                          ),
                        ),
                      if (backOpacity > 0.01)
                        IgnorePointer(
                          ignoring: t < 0.5,
                          child: Opacity(
                            opacity: backOpacity,
                            child: Transform.scale(
                              scale: backScale,
                              child: _CardBack(
                                data: widget.data,
                                token: widget.offline ? null : _token,
                                failed: widget.offline || _tokenFailed,
                                offline: widget.offline,
                                failHint: _tokenError,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({
    required this.data,
    required this.now,
    required this.badgePulse,
    required this.offline,
    required this.reduceMotion,
  });

  final AlumniCardData data;
  final DateTime now;
  final Animation<double> badgePulse;
  final bool offline;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final clock = DateFormat('EEE, MMM d · h:mm:ss a').format(now);
    final fs = alumniCardFontSize;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const RadialGradient(
          center: Alignment(1.1, -1.0),
          radius: 1.35,
          colors: [Color(0xFF2E2B86), PortalTheme.navy, Color(0xFF121040)],
          stops: [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: PortalTheme.navy.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            bottom: -70,
            child: ExcludeSemantics(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PortalTheme.gold.withValues(alpha: 0.18),
                    width: 10,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Semantics(
                      image: true,
                      label: 'USTP logo',
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PortalTheme.gold,
                            width: 1.5,
                          ),
                          color: Colors.white,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Image.asset(
                            'assets/images/ustp_logo_light.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.school_rounded,
                              color: PortalTheme.navy,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'USTP ALUMNI',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: fs(context, 11),
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            'Alumni Engagement and Support System',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: fs(context, 8.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: offline
                            ? const Color(0xFF94A3B8)
                            : PortalTheme.gold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        offline ? 'OFFLINE' : 'DIGITAL ID',
                        style: TextStyle(
                          color: PortalTheme.navy,
                          fontWeight: FontWeight.w800,
                          fontSize: fs(context, 8.5),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Photo(data: data),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.fullName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: fs(context, 17),
                              height: 1.15,
                            ),
                          ),
                          if (data.program.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              data.program,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: fs(context, 11),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              _Meta(
                                label: 'Student ID',
                                value: data.studentId.isEmpty
                                    ? '—'
                                    : data.studentId,
                              ),
                              if (data.batchYear.isNotEmpty)
                                _Meta(label: 'Batch', value: data.batchYear),
                              _Meta(
                                label: 'Sex',
                                value: data.sex.isEmpty ? '—' : data.sex,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Badge keeps its intrinsic pill width; Flexible+FittedBox only
                // shrinks it if the row is too narrow (avoids footer overflow).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _VerifiedBadge(
                            offline: offline,
                            pulse: badgePulse,
                            reduceMotion: reduceMotion,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      clock,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: fs(context, 9.5),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Status chip with a soft green pulse when the card is live/verified.
class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({
    required this.offline,
    required this.pulse,
    required this.reduceMotion,
  });

  final bool offline;
  final Animation<double> pulse;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final label = offline ? 'Saved copy · not live' : 'Verified active alumnus';
    final fs = alumniCardFontSize;
    final offlineDot = const Color(0xFFCBD5E1);
    final liveDot = const Color(0xFF4ADE80);
    // Dot carries status color; label stays neutral white on the navy card.
    const textColor = Color(0xFFF8FAFC);

    Widget mark({required Color dot, double scale = 1}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: scale,
            child: Icon(Icons.circle, size: 6, color: dot),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: fs(context, 9.5),
            ),
          ),
        ],
      );
    }

    if (offline || reduceMotion) {
      return mark(dot: offline ? offlineDot : liveDot);
    }

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(pulse.value);
        return mark(
          dot: Color.lerp(liveDot, const Color(0xFF86EFAC), t)!,
          scale: 1.0 + t * 0.35,
        );
      },
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({
    required this.data,
    required this.token,
    required this.failed,
    required this.offline,
    this.failHint,
  });

  final AlumniCardData data;
  final AlumniCardToken? token;
  final bool failed;
  final bool offline;
  final String? failHint;

  @override
  Widget build(BuildContext context) {
    final since = DateFormat.yMMMd().format(data.memberSince.toLocal());
    final remaining = token?.remaining ?? Duration.zero;
    final secs = remaining.inSeconds.clamp(0, 60);
    final countdown =
        'Refreshes in ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    final bandRight = offline
        ? 'Offline'
        : token == null
        ? (failed ? 'Unavailable' : 'Loading…')
        : countdown;
    final fs = alumniCardFontSize;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAF6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PortalTheme.borderStrong),
        boxShadow: [
          BoxShadow(
            color: PortalTheme.navy.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: PortalTheme.navy,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Text(
                  offline ? 'OFFLINE COPY' : 'SCAN TO VERIFY',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: fs(context, 10),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  bandRight,
                  style: TextStyle(
                    color: PortalTheme.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: fs(context, 10),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 96,
                    child: Column(
                      children: [
                        Expanded(
                          child: Semantics(
                            label: offline
                                ? 'QR unavailable offline'
                                : token == null
                                ? 'Verification code loading'
                                : 'Verification QR code',
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: PortalTheme.border),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: offline
                                  ? const Center(
                                      child: Icon(
                                        Icons.cloud_off_rounded,
                                        color: PortalTheme.textMuted,
                                        size: 36,
                                      ),
                                    )
                                  : token == null
                                  ? Center(
                                      child: failed
                                          ? const Icon(
                                              Icons.qr_code_2_rounded,
                                              color: PortalTheme.textMuted,
                                              size: 36,
                                            )
                                          : const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: PortalTheme.navy,
                                              ),
                                            ),
                                    )
                                  : QrImageView(
                                      data: token!.verifyUrl,
                                      version: QrVersions.auto,
                                      backgroundColor: Colors.white,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: PortalTheme.navy,
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape:
                                            QrDataModuleShape.square,
                                        color: PortalTheme.navy,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          offline ? '———' : (token?.displayShortCode ?? '———'),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            fontSize: fs(context, 11),
                            color: PortalTheme.navy,
                          ),
                        ),
                        Text(
                          offline
                              ? 'QR needs internet'
                              : token == null
                              ? (failed
                                    ? (failHint == null || failHint!.isEmpty
                                          ? 'Code unavailable'
                                          : failHint!)
                                    : 'Getting code…')
                              : countdown,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: PortalTheme.textMuted,
                            fontSize: fs(context, 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BackRow(
                          label: 'Email',
                          value: data.email.isEmpty ? '—' : data.email,
                        ),
                        _BackRow(label: 'Member since', value: since),
                        _BackRow(label: 'Campus', value: data.campus),
                        const Spacer(),
                        Text(
                          offline
                              ? 'Offline copy. Identity only — staff cannot '
                                    'verify the QR until you are back online.'
                              : 'Non-transferable. Valid only while shown live '
                                    'in the app. Staff may ask for a government '
                                    'ID. Report misuse to the USTP Alumni Office.',
                          style: TextStyle(
                            color: PortalTheme.textMuted.withValues(
                              alpha: 0.95,
                            ),
                            fontSize: fs(context, 8.2),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.data});

  final AlumniCardData data;

  @override
  Widget build(BuildContext context) {
    final provider =
        (data.profileImageUrl == null || data.profileImageUrl!.isEmpty)
        ? null
        : AppImage.provider(data.profileImageUrl);
    return Semantics(
      image: true,
      label: 'Photo of ${data.fullName}',
      child: Container(
        width: 72,
        height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PortalTheme.gold, width: 2),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5B6BD6), Color(0xFF2B2F8F)],
          ),
          image: provider == null
              ? null
              : DecorationImage(
                  image: provider,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
        ),
        alignment: Alignment.center,
        child: provider == null
            ? Text(
                data.initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: alumniCardFontSize(context, 22),
                ),
              )
            : null,
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: alumniCardFontSize(context, 8.5),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: alumniCardFontSize(context, 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackRow extends StatelessWidget {
  const _BackRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        label: '$label $value',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: PortalTheme.textMuted,
                fontSize: alumniCardFontSize(context, 9),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: PortalTheme.navy,
                  fontWeight: FontWeight.w700,
                  fontSize: alumniCardFontSize(context, 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
