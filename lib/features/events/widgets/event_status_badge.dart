import 'package:flutter/material.dart';
import 'package:alumni_system/features/events/models/event_display_status.dart';
import 'package:alumni_system/features/events/models/event_model.dart';

class EventStatusBadge extends StatelessWidget {
  const EventStatusBadge({
    super.key,
    required this.event,
    this.compact = false,
  });

  final AlumniEvent event;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = deriveEventDisplayStatus(event);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class EventCategoryChip extends StatelessWidget {
  const EventCategoryChip({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF090A4F).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: Color(0xFF090A4F),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
