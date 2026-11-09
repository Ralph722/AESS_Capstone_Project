import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
/// Visuals follow the physical-ID mockup: white faces, gold/navy accents,
/// alumni mark on the front, gold verify band on the back.
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _swap;
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
                                offline: widget.offline,
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
    required this.offline,
  });

  final AlumniCardData data;
  final DateTime now;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final clock = DateFormat('EEE, MMM d · h:mm:ss a').format(now);
    final fs = alumniCardFontSize;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: PortalTheme.navy.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(child: _FrontDecor()),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.topRight,
                  child: _AlumniMark(),
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
                              color: PortalTheme.navy,
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
                                color: PortalTheme.textSecondary,
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
                                label: 'ID Number',
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        offline
                            ? 'Saved copy · not live'
                            : 'Lifetime Member',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: PortalTheme.navy,
                          fontWeight: FontWeight.w700,
                          fontSize: fs(context, 9.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      clock,
                      style: TextStyle(
                        color: PortalTheme.textMuted,
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

/// Physical-ID decorative shapes (navy + gold) on the white front face.
class _FrontDecor extends StatelessWidget {
  const _FrontDecor();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: w * 0.026,
                  top: h * 0.052,
                  child: _DecorDisc(
                    size: w * 0.108,
                    color: PortalTheme.gold,
                  ),
                ),
                Positioned(
                  left: w * 0.082,
                  top: h * 0.034,
                  child: _DecorDisc(
                    size: w * 0.068,
                    color: PortalTheme.navy,
                  ),
                ),
                Positioned(
                  left: w * 0.35,
                  top: -h * 0.32,
                  child: Transform.rotate(
                    angle: -19 * math.pi / 180,
                    child: Container(
                      width: w * 0.36,
                      height: w * 0.36,
                      decoration: BoxDecoration(
                        color: PortalTheme.navy,
                        borderRadius: BorderRadius.circular(w * 0.08),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -w * 0.14,
                  bottom: -h * 0.48,
                  child: _DecorDisc(
                    size: w * 0.58,
                    color: PortalTheme.gold,
                  ),
                ),
                Positioned(
                  right: -w * 0.10,
                  bottom: -h * 0.07,
                  child: Transform.rotate(
                    angle: 50 * math.pi / 180,
                    child: Container(
                      width: w * 0.18,
                      height: w * 0.18 / 0.9,
                      decoration: BoxDecoration(
                        color: PortalTheme.gold,
                        borderRadius: BorderRadius.circular(w * 0.04),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DecorDisc extends StatelessWidget {
  const _DecorDisc({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _AlumniMark extends StatelessWidget {
  const _AlumniMark();

  static const _size = 54.0;
  static const _radius = 3.0;
  static const _border = 2.0;
  static const _pad = 3.0;

  @override
  Widget build(BuildContext context) {
    // Outer box draws the gold frame; inner ClipRRect crops the scaled SVG
    // so the border is never clipped (Clip.hardEdge on the same Container
    // was eating the stroke on web).
    return Semantics(
      image: true,
      label: 'USTP Alumni Association mark',
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: PortalTheme.gold, width: _border),
        ),
        padding: const EdgeInsets.all(_pad),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            math.max(0, _radius - _border / 2),
          ),
          child: ColoredBox(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 1.55,
              child: SvgPicture.asset(
                'assets/ALUMNI.svg',
                fit: BoxFit.contain,
                allowDrawingOutsideViewBox: true,
                placeholderBuilder: (_) => const Icon(
                  Icons.groups_rounded,
                  color: PortalTheme.navy,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
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
    final bandRight = offline ? 'OFFLINE' : 'USTP ALUMNI OFFICE';
    final fs = alumniCardFontSize;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
            color: PortalTheme.gold,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Text(
                  offline ? 'OFFLINE COPY' : 'SCAN TO VERIFY',
                  style: TextStyle(
                    color: PortalTheme.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: fs(context, 10),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  bandRight,
                  style: TextStyle(
                    color: PortalTheme.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: fs(context, 10),
                    letterSpacing: 0.5,
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
            colors: [Color(0xFF5B6BD6), Color(0xFF1A1851)],
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
              color: PortalTheme.textMuted,
              fontSize: alumniCardFontSize(context, 8.5),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: PortalTheme.navy,
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
        child: Container(
          padding: const EdgeInsets.only(bottom: 3),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
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
      ),
    );
  }
}
