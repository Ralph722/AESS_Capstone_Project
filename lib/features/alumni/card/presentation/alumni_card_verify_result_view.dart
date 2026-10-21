import 'package:flutter/material.dart';
import 'package:alumni_system/core/utils/app_image.dart';
import 'package:alumni_system/features/alumni/card/models/alumni_card_token.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Shared verified / not-valid body used by the public page and admin dialog.
class AlumniCardVerifyResultView extends StatelessWidget {
  const AlumniCardVerifyResultView({
    super.key,
    required this.result,
    this.compact = false,
  });

  final AlumniCardVerifyResult result;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!result.ok) {
      final detail = result.message?.trim();
      return _StatusBlock(
        compact: compact,
        color: PortalTheme.danger,
        icon: Icons.cancel_rounded,
        title: 'Expired / Not valid',
        message: (detail != null && detail.isNotEmpty)
            ? detail
            : 'This code is unknown, already used, or past its 60-second window. '
                'Ask the alumnus to flip their digital card again for a fresh code.',
      );
    }

    final photo = result.profileImageUrl;
    final provider = (photo == null || photo.isEmpty)
        ? null
        : AppImage.provider(photo);
    final initials = _initials(result.fullName ?? '');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF6EE7B7)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_rounded,
                color: PortalTheme.success,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Verified',
                style: TextStyle(
                  color: PortalTheme.success,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 16 : 22),
        Container(
          width: compact ? 88 : 112,
          height: compact ? 108 : 136,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PortalTheme.gold, width: 2.5),
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
                  initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 28 : 34,
                  ),
                )
              : null,
        ),
        SizedBox(height: compact ? 12 : 16),
        Text(
          result.fullName ?? 'Alumni',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: PortalTheme.navy,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 20 : 24,
            height: 1.15,
          ),
        ),
        if ((result.program ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            result.program!,
            textAlign: TextAlign.center,
            style: PortalTheme.bodySecondary.copyWith(fontSize: 14),
          ),
        ],
        if ((result.batchYear ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Batch ${result.batchYear}',
            style: const TextStyle(
              color: PortalTheme.navy,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first;
      return w.length >= 2 ? w.substring(0, 2).toUpperCase() : w.toUpperCase();
    }
    return ('${parts.first[0]}${parts.last[0]}').toUpperCase();
  }
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.compact,
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
  });

  final bool compact;
  final Color color;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 48 : 64, color: color),
        SizedBox(height: compact ? 10 : 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 18 : 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: PortalTheme.bodySecondary.copyWith(
            fontSize: compact ? 13 : 14,
          ),
        ),
      ],
    );
  }
}
