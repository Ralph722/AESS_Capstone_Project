import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:alumni_system/core/constants/ustp_colors.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/alumni/card/data/alumni_card_token_service.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_data.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_token.dart';
import 'package:alumni_system/features/alumni/card/presentation/alumni_card_text.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Same outer footprint as before (CR80 ≈ 1.586). Mockup art is 3:2 and
/// letterboxed/cropped inside via SVG `slice` fit.
const double kAlumniCardAspectRatio = 1.586;

/// Keeps the card phone-sized on tablet/desktop (does not stretch full width).
const double kAlumniCardMaxWidth = 380;

/// Digital alumni card (front = identity, back = personal details + verify QR).
///
/// Visuals follow `docs/mockups/digital_app_card_mockup.html`: white faces,
/// official navy/gold accents, alumni mark + photo on the front, personal
/// details + live QR on the back. Side changes use a soft crossfade + scale.
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
    _swap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: _showBack ? 1 : 0,
    );
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_showBack) setState(() {});
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
          forceRefresh:
              force ||
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
          ? 'Alumni card personal details and QR for $name. '
                'Double tap to show identity.'
          : 'Alumni card front for $name'
                '${sid.isEmpty ? '' : ', student ID $sid'}'
                '${widget.offline ? ', offline copy' : ''}'
                '. Double tap to show personal details and QR.',
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

String _hex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.data, required this.offline});

  final AlumniCardData data;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final membership = offline ? 'Saved copy' : 'Lifetime Member';
    final batch = data.batchYear.trim().isEmpty
        ? ''
        : 'Batch ${data.batchYear.trim()}';
    return _CardShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final cqw = w / 100;
          return Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: _FrontDecorSvg()),
              // Alumni mark — top right
              Positioned(
                top: constraints.maxHeight * 0.048,
                right: w * 0.032,
                width: w * 0.236,
                height: constraints.maxHeight * 0.354,
                child: _AlumniMark(borderWidth: math.max(1.5, 0.6 * cqw)),
              ),
              // Photo — bottom left
              Positioned(
                left: w * 0.019,
                bottom: constraints.maxHeight * 0.028,
                width: w * 0.284,
                height: constraints.maxHeight * 0.474,
                child: _Photo(
                  data: data,
                  borderWidth: math.max(1.8, 0.7 * cqw),
                  radius: math.max(10, 2.8 * cqw),
                ),
              ),
              // Identity block
              Positioned(
                left: w * 0.37,
                right: w * 0.065,
                top: constraints.maxHeight * 0.575,
                bottom: constraints.maxHeight * 0.11,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: w * 0.565),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          data.fullName.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: PortalTheme.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: alumniCardFontSize(context, 3.35 * cqw),
                            height: 1.15,
                            letterSpacing: 0.4,
                          ),
                        ),
                        SizedBox(height: 1.45 * cqw),
                        Text(
                          data.studentId.isEmpty
                              ? '—'
                              : data.studentId.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: UstpColors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: alumniCardFontSize(context, 2.0 * cqw),
                            height: 1.2,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 0.25 * cqw),
                        Text(
                          membership.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: PortalTheme.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: alumniCardFontSize(context, 2.65 * cqw),
                            height: 1.15,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (batch.isNotEmpty) ...[
                          SizedBox(height: 0.7 * cqw),
                          Text(
                            batch.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: UstpColors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: alumniCardFontSize(
                                context,
                                1.92 * cqw,
                              ),
                              height: 1.2,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
    final birth = data.birthDate == null
        ? '—'
        : DateFormat('MM/dd/yyyy').format(data.birthDate!.toLocal());
    final remaining = token?.remaining ?? Duration.zero;
    final secs = remaining.inSeconds.clamp(0, 60);
    final countdown =
        'Refreshes in ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';

    return _CardShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final cqw = w / 100;
          // Labels stay regular; values go bold. On Flutter web, nearby
          // weights (w600/w800) often render identically — use a clear jump.
          final labelStyle = TextStyle(
            color: PortalTheme.navy.withValues(alpha: 0.72),
            fontWeight: FontWeight.w400,
            fontSize: alumniCardFontSize(context, 2.52 * cqw),
            height: 1.22,
            letterSpacing: 0.6,
          );
          final valueStyle = TextStyle(
            color: PortalTheme.navy,
            fontWeight: FontWeight.w800,
            fontSize: alumniCardFontSize(context, 2.52 * cqw),
            height: 1.22,
            letterSpacing: 0.35,
          );
          final addressValueStyle = TextStyle(
            color: PortalTheme.navy,
            fontWeight: FontWeight.w800,
            fontSize: alumniCardFontSize(context, 1.98 * cqw),
            height: 1.28,
            letterSpacing: 0.2,
          );
          final qrRadius = 2.2 * cqw;
          final qrPad = math.max(6.0, 1.2 * cqw);
          return Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: _BackDecorSvg()),
              Positioned(
                left: w * 0.027,
                top: h * 0.162,
                // Leave the right half for the QR + side margin.
                right: w * 0.52,
                bottom: h * 0.06,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PERSONAL DETAILS',
                      style: TextStyle(
                        color: PortalTheme.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: alumniCardFontSize(context, 3.85 * cqw),
                        height: 1.15,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 6.2 * cqw),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _BackDetail(
                              label: 'SEX: ',
                              value: _dash(data.sex).toUpperCase(),
                              labelStyle: labelStyle,
                              valueStyle: valueStyle,
                            ),
                            SizedBox(height: 0.95 * cqw),
                            _BackDetail(
                              label: 'BIRTHDATE: ',
                              value: birth,
                              labelStyle: labelStyle,
                              valueStyle: valueStyle,
                            ),
                            SizedBox(height: 0.95 * cqw),
                            _BackDetail(
                              label: 'DEGREE/PROGRAM: ',
                              value: _dash(data.program).toUpperCase(),
                              labelStyle: labelStyle,
                              valueStyle: valueStyle,
                              maxLines: 2,
                            ),
                            SizedBox(height: 0.95 * cqw),
                            _BackDetail(
                              label: 'CONTACT NUMBER: ',
                              value: _dash(data.contactNumber),
                              labelStyle: labelStyle,
                              valueStyle: valueStyle,
                              maxLines: 1,
                            ),
                            SizedBox(height: 0.95 * cqw),
                            Text('HOME ADDRESS:', style: labelStyle),
                            SizedBox(height: 0.35 * cqw),
                            Text(
                              _dash(data.address),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: addressValueStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                // Center in the open band between details (~48%) and right edge.
                left: w * 0.60,
                top: h * 0.162,
                width: w * 0.26,
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Semantics(
                        label: offline
                            ? 'QR unavailable offline'
                            : token == null
                            ? 'Verification code loading'
                            : 'Verification QR code',
                        child: Container(
                          padding: EdgeInsets.all(qrPad),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(qrRadius),
                            border: Border.all(
                              color: PortalTheme.navy.withValues(alpha: 0.15),
                              width: math.max(1, 0.35 * cqw),
                            ),
                          ),
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
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    math.max(0, qrRadius - qrPad * 0.35),
                                  ),
                                  child: QrImageView(
                                    data: token!.verifyUrl,
                                    version: QrVersions.auto,
                                    gapless: true,
                                    padding: EdgeInsets.zero,
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
                    ),
                    SizedBox(height: 1.2 * cqw),
                    Text(
                      offline
                          ? 'QR needs internet'
                          : token == null
                          ? (failed
                                ? (failHint == null || failHint!.isEmpty
                                      ? 'QR unavailable'
                                      : failHint!)
                                : 'Getting QR…')
                          : countdown,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PortalTheme.textMuted,
                        fontSize: alumniCardFontSize(context, 1.45 * cqw),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (offline) ...[
                      SizedBox(height: 0.4 * cqw),
                      Text(
                        'OFFLINE COPY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: PortalTheme.navy,
                          fontSize: alumniCardFontSize(context, 1.35 * cqw),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _dash(String v) {
    final t = v.trim();
    return t.isEmpty ? '—' : t;
  }
}

class _BackDetail extends StatelessWidget {
  const _BackDetail({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
    this.maxLines = 2,
  });

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label, style: labelStyle),
          TextSpan(text: value, style: valueStyle),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
      child: child,
    );
  }
}

class _FrontDecorSvg extends StatelessWidget {
  const _FrontDecorSvg();

  @override
  Widget build(BuildContext context) {
    final navy = _hex(PortalTheme.navy);
    final gold = _hex(PortalTheme.gold);
    final svg =
        '''
<svg viewBox="0 0 850 567" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid slice">
  <rect width="850" height="567" fill="#FFFFFF"/>
  <circle cx="58" cy="124" r="41" fill="$gold"/>
  <circle cx="88.5" cy="89.5" r="30.5" fill="$navy"/>
  <rect x="245" y="-150" width="335" height="325" rx="44" ry="44" fill="$navy" transform="rotate(-18.5 412 20)"/>
  <circle cx="118" cy="550" r="180" fill="$gold"/>
  <rect x="758" y="375" width="260" height="260" rx="44" ry="44" fill="$gold" transform="rotate(-36 888 505)"/>
</svg>''';
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SvgPicture.string(svg, fit: BoxFit.cover),
      ),
    );
  }
}

class _BackDecorSvg extends StatelessWidget {
  const _BackDecorSvg();

  @override
  Widget build(BuildContext context) {
    final navy = _hex(PortalTheme.navy);
    final svg =
        '''
<svg viewBox="0 0 850 567" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid slice">
  <rect width="850" height="567" fill="#FFFFFF"/>
  <rect x="-58" y="-192" width="302" height="245" rx="52" ry="52" fill="$navy" transform="rotate(21.5 93 -69.5)"/>
  <rect x="795" y="265" width="290" height="310" rx="62" ry="62" fill="$navy" transform="rotate(-26 940 420)"/>
</svg>''';
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SvgPicture.string(svg, fit: BoxFit.cover),
      ),
    );
  }
}

class _AlumniMark extends StatelessWidget {
  const _AlumniMark({required this.borderWidth});

  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final radius = math.max(3.0, borderWidth * 2);
    return Semantics(
      image: true,
      label: 'USTP Alumni Association mark',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: PortalTheme.gold, width: borderWidth),
        ),
        padding: EdgeInsets.all(borderWidth * 1.4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            math.max(0, radius - borderWidth),
          ),
          child: Transform.scale(
            scale: 1.45,
            child: SvgPicture.asset(
              'assets/ALUMNI.svg',
              fit: BoxFit.contain,
              allowDrawingOutsideViewBox: true,
              placeholderBuilder: (_) => const Icon(
                Icons.groups_rounded,
                color: PortalTheme.navy,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({
    required this.data,
    required this.borderWidth,
    required this.radius,
  });

  final AlumniCardData data;
  final double borderWidth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final provider =
        (data.profileImageUrl == null || data.profileImageUrl!.isEmpty)
        ? null
        : AppImage.provider(data.profileImageUrl);
    // Outer box draws the gold stroke; inner ClipRRect crops the photo so
    // Clip.antiAlias on the same box does not eat the border (especially on web).
    final innerRadius = math.max(0.0, radius - borderWidth);
    return Semantics(
      image: true,
      label: 'Photo of ${data.fullName}',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: PortalTheme.gold, width: borderWidth),
        ),
        padding: EdgeInsets.all(borderWidth * 0.15),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
          child: provider == null
              ? DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [PortalTheme.navyMid, PortalTheme.navy],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      data.initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: alumniCardFontSize(context, 22),
                      ),
                    ),
                  ),
                )
              : Image(
                  image: provider,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
        ),
      ),
    );
  }
}
