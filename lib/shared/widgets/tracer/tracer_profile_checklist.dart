import 'package:flutter/material.dart';
import 'package:alumni_system/features/alumni/tracer/models/tracer_profile_model.dart';

/// Demographic + employment tracer steps (profile screen).
class TracerProfileChecklist extends StatelessWidget {
  const TracerProfileChecklist({
    super.key,
    required this.profile,
    required this.hasEmploymentRecord,
    required this.onDemographicsTap,
    required this.onEmploymentTap,
  });

  final TracerProfile? profile;
  final bool hasEmploymentRecord;
  final VoidCallback onDemographicsTap;
  final VoidCallback onEmploymentTap;

  static const _navy = Color(0xFF090A4F);

  @override
  Widget build(BuildContext context) {
    final completion = profile?.completionPercent ?? 0;
    final profileComplete = profile?.isComplete ?? false;
    final allDone = profileComplete && hasEmploymentRecord;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: allDone
                ? Colors.green.shade200
                : const Color(0xFFFFD700).withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.fact_check_outlined, color: _navy),
                SizedBox(width: 8),
                Text(
                  'Graduate Tracer Study',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Complete your demographic profile and employment record.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            _TracerStep(
              label: 'Demographic profile',
              done: profileComplete,
              detail: profileComplete
                  ? 'Complete'
                  : '${completion.toStringAsFixed(0)}% complete',
              onTap: onDemographicsTap,
            ),
            const SizedBox(height: 8),
            _TracerStep(
              label: 'Employment tracer',
              done: hasEmploymentRecord,
              detail: hasEmploymentRecord
                  ? 'Submitted'
                  : 'Not submitted yet',
              onTap: onEmploymentTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _TracerStep extends StatelessWidget {
  const _TracerStep({
    required this.label,
    required this.done,
    required this.detail,
    required this.onTap,
  });

  final String label;
  final bool done;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? Colors.green : Colors.orange,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: TracerProfileChecklist._navy,
                    ),
                  ),
                  Text(
                    detail,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
