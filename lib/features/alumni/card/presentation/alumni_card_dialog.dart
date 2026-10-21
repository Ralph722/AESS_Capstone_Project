import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:alumni_system/features/alumni/card/data/alumni_card_service.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_data.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_token.dart';
import 'package:alumni_system/features/alumni/card/presentation/alumni_digital_card.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Opens the digital alumni card over a blurred scrim (card + flip hint only).
Future<void> showAlumniCardDialog(
  BuildContext context, {
  AlumniCardService? service,
  Future<AlumniCardToken?> Function()? issueToken,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Digital alumni card',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return AlumniCardDialog(service: service, issueToken: issueToken);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class AlumniCardDialog extends StatefulWidget {
  const AlumniCardDialog({super.key, this.service, this.issueToken});

  final AlumniCardService? service;
  final Future<AlumniCardToken?> Function()? issueToken;

  @override
  State<AlumniCardDialog> createState() => _AlumniCardDialogState();
}

class _AlumniCardDialogState extends State<AlumniCardDialog> {
  late final AlumniCardService _service = widget.service ?? AlumniCardService();
  Future<AlumniCardLoadResult>? _load;
  var _showingBack = false;

  @override
  void initState() {
    super.initState();
    _load = _service.loadForCurrentUser();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred dim behind the card; tap outside dismisses.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(color: Colors.black.withValues(alpha: 0.42)),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kAlumniCardMaxWidth,
                  ),
                  child: FutureBuilder<AlumniCardLoadResult>(
                    future: _load,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const SizedBox(
                          height: 120,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                        );
                      }
                      final result = snap.data;
                      if (result == null ||
                          result.status == AlumniCardStatus.unmatched) {
                        return _StatusOverlay(
                          title: 'Card not ready yet',
                          message:
                              'Your card will be available once the Alumni '
                              'Office confirms your record.',
                          onDismiss: _close,
                        );
                      }
                      if (result.status == AlumniCardStatus.deactivated) {
                        return _StatusOverlay(
                          title: 'Card unavailable',
                          message:
                              'This alumni account is deactivated. Contact '
                              'the Alumni Office if you need help.',
                          onDismiss: _close,
                        );
                      }
                      final data = result.data!;
                      final offline = result.offline;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (offline) ...[
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                'Saved copy · QR needs internet',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          AlumniDigitalCard(
                            data: data,
                            showBack: _showingBack,
                            offline: offline,
                            onFlip: (back) =>
                                setState(() => _showingBack = back),
                            issueToken: offline ? null : widget.issueToken,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Tap the card to switch sides',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
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
        ],
      ),
    );
  }
}

class _StatusOverlay extends StatelessWidget {
  const _StatusOverlay({
    required this.title,
    required this.message,
    required this.onDismiss,
  });

  final String title;
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.badge_outlined,
            size: 40,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onDismiss,
            child: Text('Close', style: TextStyle(color: PortalTheme.gold)),
          ),
        ],
      ),
    );
  }
}
