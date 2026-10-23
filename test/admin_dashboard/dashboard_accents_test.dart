import 'package:alumni_system/core/constants/ustp_colors.dart';
import 'package:alumni_system/features/admin/dashboard/application/dashboard_insights.dart';
import 'package:alumni_system/features/admin/dashboard/presentation/admin_dashboard_home.dart';
import 'package:alumni_system/features/admin/dashboard/widgets/admin_dashboard_widgets.dart';
import 'package:alumni_system/shared/widgets/admin/admin_kpi_card.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../admin_shared/admin_test_harness.dart';

/// WCAG relative-luminance contrast ratio.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('greeting', () {
    test('time of day and first name', () {
      expect(
        AdminDashboardHome.greeting(DateTime(2026, 10, 15, 9), 'Ana Reyes'),
        'Good morning, Ana',
      );
      expect(
        AdminDashboardHome.greeting(DateTime(2026, 10, 15, 13), 'Ana'),
        'Good afternoon, Ana',
      );
      expect(
        AdminDashboardHome.greeting(DateTime(2026, 10, 15, 19), '  '),
        'Good evening',
      );
      expect(
        AdminDashboardHome.greeting(DateTime(2026, 10, 15, 12), null),
        'Good afternoon',
      );
    });
  });

  test('every accent foreground is readable on its tint', () {
    for (final accent in [
      AdminAccents.blue,
      AdminAccents.sky,
      AdminAccents.midBlue,
      AdminAccents.gold,
      AdminAccents.orange,
    ]) {
      expect(
        _contrast(accent.onTint, accent.tint),
        greaterThanOrEqualTo(4.5),
        reason: '${accent.color}',
      );
    }
  });

  test('activity colours by action', () {
    expect(AdminDashboardHome.activityColor('DELETE'), AdminColors.danger);
    expect(
      AdminDashboardHome.activityColor('DSS_FLAG_EVIDENCE_REMOVED'),
      AdminColors.danger,
    );
    expect(
      AdminDashboardHome.activityColor('CREATE_ROSTER_MEMBER'),
      AdminColors.success,
    );
    expect(AdminDashboardHome.activityColor('LOGIN'), UstpColors.skyBlue);
    expect(
      AdminDashboardHome.activityColor('EXPORT_CHED_GTS_PDF'),
      UstpColors.gold,
    );
    expect(AdminDashboardHome.activityColor('UPDATE'), UstpColors.blue);
  });

  test('agenda kinds map to brand accents', () {
    expect(
      AdminDashboardHome.agendaAccent(DashboardAgendaKind.tracer),
      AdminAccents.gold,
    );
    expect(
      AdminDashboardHome.agendaAccent(DashboardAgendaKind.job),
      AdminAccents.orange,
    );
    expect(
      AdminDashboardHome.agendaAccent(DashboardAgendaKind.survey),
      AdminAccents.sky,
    );
  });

  testWidgets('KPI card palette tints the icon, with no top strip', (
    tester,
  ) async {
    await pumpAdmin(
      tester,
      const AdminKpiCard(
        label: 'Tracer response',
        value: '40%',
        icon: Icons.school_outlined,
        palette: AdminAccents.sky,
      ),
    );

    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == UstpColors.skyBlue,
      ),
      findsNothing,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.school_outlined)).color,
      UstpColors.midBlue,
    );
  });

  testWidgets('KPI card without a palette has no strip', (tester) async {
    await pumpAdmin(
      tester,
      const AdminKpiCard(
        label: 'Total',
        value: '8',
        icon: Icons.people_outline,
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == AdminColors.primary,
      ),
      findsNothing,
    );
  });

  testWidgets('panel accent tints the header icon', (tester) async {
    await pumpAdmin(
      tester,
      const DashboardPanel(
        title: 'Upcoming & deadlines',
        icon: Icons.event_note_outlined,
        accent: AdminAccents.gold,
        child: SizedBox(height: 40),
      ),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.event_note_outlined)).color,
      UstpColors.blue,
    );
  });
}
