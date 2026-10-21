import 'package:alumni_system/features/admin/announcements/widgets/admin_announcement_ui.dart';
import 'package:alumni_system/features/admin/dss/widgets/admin_dss_ui.dart';
import 'package:alumni_system/features/admin/events/widgets/admin_event_ui.dart';
import 'package:alumni_system/features/admin/forum/widgets/admin_forum_ui.dart';
import 'package:alumni_system/features/admin/jobs/widgets/admin_job_ui.dart';
import 'package:alumni_system/features/admin/surveys/widgets/admin_survey_ui.dart';
import 'package:alumni_system/shared/widgets/admin/admin_buttons.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _states = <Set<WidgetState>>[
  {},
  {WidgetState.hovered},
  {WidgetState.pressed},
  {WidgetState.disabled},
];

void _expectSameStyle(ButtonStyle actual, ButtonStyle expected) {
  for (final s in _states) {
    expect(
      actual.backgroundColor?.resolve(s),
      expected.backgroundColor?.resolve(s),
    );
    expect(
      actual.foregroundColor?.resolve(s),
      expected.foregroundColor?.resolve(s),
    );
    expect(actual.minimumSize?.resolve(s), expected.minimumSize?.resolve(s));
    expect(actual.padding?.resolve(s), expected.padding?.resolve(s));
    expect(actual.elevation?.resolve(s), expected.elevation?.resolve(s));
    expect(actual.shape?.resolve(s), expected.shape?.resolve(s));
    expect(actual.side?.resolve(s), expected.side?.resolve(s));
  }
}

void main() {
  test('filled style keeps the established admin values', () {
    final style = AdminButtonStyles.filled();
    expect(style.backgroundColor?.resolve({}), AdminColors.primary);
    expect(style.foregroundColor?.resolve({}), Colors.white);
    expect(style.minimumSize?.resolve({}), const Size(0, 36));
    expect(
      style.padding?.resolve({}),
      const EdgeInsets.symmetric(horizontal: 16),
    );
    expect(style.elevation?.resolve({}), 0);
    expect(
      style.shape?.resolve({}),
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  });

  test('outlined style keeps the established admin values', () {
    final style = AdminButtonStyles.outlined();
    expect(style.foregroundColor?.resolve({}), AdminColors.textPrimary);
    expect(
      style.side?.resolve({}),
      const BorderSide(color: AdminColors.border),
    );
    expect(style.minimumSize?.resolve({}), const Size(0, 36));
    expect(
      style.padding?.resolve({}),
      const EdgeInsets.symmetric(horizontal: 14),
    );
  });

  test('danger style is filled with the danger color', () {
    _expectSameStyle(
      AdminButtonStyles.danger(),
      AdminButtonStyles.filled(background: AdminColors.danger),
    );
  });

  test('feature button helpers resolve to the shared styles', () {
    const custom = Color(0xFF123456);
    for (final filled in <ButtonStyle Function({Color? background})>[
      surveyFilledButtonStyle,
      eventFilledButtonStyle,
      jobFilledButtonStyle,
      forumFilledButtonStyle,
      dssFilledButtonStyle,
    ]) {
      _expectSameStyle(filled(), AdminButtonStyles.filled());
      _expectSameStyle(
        filled(background: custom),
        AdminButtonStyles.filled(background: custom),
      );
    }
    _expectSameStyle(
      announcementFilledButtonStyle(foreground: custom),
      AdminButtonStyles.filled(foreground: custom),
    );
    for (final outlined in <ButtonStyle Function()>[
      surveyOutlinedButtonStyle,
      eventOutlinedButtonStyle,
      jobOutlinedButtonStyle,
      forumOutlinedButtonStyle,
      dssOutlinedButtonStyle,
      announcementOutlinedButtonStyle,
    ]) {
      _expectSameStyle(outlined(), AdminButtonStyles.outlined());
    }
  });
}
