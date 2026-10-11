import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/notifications/models/notification_model.dart';
import 'package:alumni_system/features/admin/dashboard/application/admin_dashboard_metrics.dart';
import 'package:alumni_system/features/notifications/data/notification_service.dart';
import 'package:alumni_system/features/messages/data/message_open_bus.dart';
import 'package:alumni_system/features/admin/events/presentation/admin_event_comments_dialog.dart';
import 'package:alumni_system/features/admin/feedback/presentation/admin_feedback_detail_page.dart';
import 'package:alumni_system/features/events/data/event_comment_service.dart';
import 'package:alumni_system/features/events/data/event_service.dart';
import 'package:alumni_system/features/events/models/event_model.dart';
import 'package:alumni_system/features/notifications/application/notification_router.dart';
import 'package:alumni_system/features/notifications/push/push_service.dart';
import 'package:alumni_system/features/notifications/application/notification_target.dart';
import 'package:alumni_system/features/notifications/presentation/notification_preferences_page.dart';
import 'package:alumni_system/features/auth/data/auth_service.dart';
import 'package:alumni_system/features/auth/presentation/auth_shell.dart';
import 'package:alumni_system/features/auth/presentation/widgets/change_password_form.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Search / command-palette result that opens the Change password dialog.
/// Negative so it can never collide with an [AdminNavItem.index].
const int _kChangePasswordCommand = -1;

const List<String> _kChangePasswordKeywords = [
  'password',
  'security',
  'account',
  'settings',
];

/// Grouped admin navigation (indices must match dashboard page routing).
class AdminNavItem {
  const AdminNavItem({
    required this.index,
    required this.icon,
    required this.label,
    this.keywords = const [],
  });

  final int index;
  final IconData icon;
  final String label;

  /// Extra terms matched by global search (aliases, related concepts).
  final List<String> keywords;
}

/// Result categories for the header global search panel.
/// Entity kinds (alumni, events, surveys…) are reserved for future providers.
enum AdminSearchCategory {
  recent,
  pages,
  commands,
  alumni,
  events,
  surveys,
  reports,
  settings,
}

extension AdminSearchCategoryX on AdminSearchCategory {
  String get label => switch (this) {
    AdminSearchCategory.recent => 'Recent',
    AdminSearchCategory.pages => 'Pages',
    AdminSearchCategory.commands => 'Commands',
    AdminSearchCategory.alumni => 'Alumni',
    AdminSearchCategory.events => 'Events',
    AdminSearchCategory.surveys => 'Surveys',
    AdminSearchCategory.reports => 'Reports',
    AdminSearchCategory.settings => 'Settings',
  };

  IconData get icon => switch (this) {
    AdminSearchCategory.recent => Icons.history,
    AdminSearchCategory.pages => Icons.menu_book_outlined,
    AdminSearchCategory.commands => Icons.terminal_outlined,
    AdminSearchCategory.alumni => Icons.people_outline,
    AdminSearchCategory.events => Icons.event_outlined,
    AdminSearchCategory.surveys => Icons.poll_outlined,
    AdminSearchCategory.reports => Icons.bar_chart_outlined,
    AdminSearchCategory.settings => Icons.settings_outlined,
  };
}

/// A single hit in the admin global search panel.
class AdminSearchHit {
  const AdminSearchHit({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.menuIndex,
  });

  final AdminSearchCategory category;
  final String title;
  final String subtitle;
  final IconData icon;
  final int menuIndex;
}

class AdminNavSection {
  const AdminNavSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<AdminNavItem> items;
}

/// Grouped admin navigation.
///
/// Item [AdminNavItem.index] values must stay aligned with
/// [AdminDashboardPage] `_pageOrder` / `_buildPageForMenu` routing.
/// Reorder labels and sections freely; do not invent modules or change indices.
const List<AdminNavSection> kAdminNavSections = [
  AdminNavSection(
    id: 'overview',
    title: 'Overview',
    items: [
      AdminNavItem(
        index: 0,
        icon: Icons.dashboard_outlined,
        label: 'Dashboard',
        keywords: ['overview', 'home', 'metrics'],
      ),
    ],
  ),
  AdminNavSection(
    id: 'alumni',
    title: 'Alumni',
    items: [
      AdminNavItem(
        index: 2,
        icon: Icons.people_outline,
        label: 'Alumni Directory',
        keywords: ['alumni', 'members', 'roster', 'directory', 'tracer'],
      ),
      AdminNavItem(
        index: 10,
        icon: Icons.poll_outlined,
        label: 'Surveys',
        keywords: ['poll', 'questionnaire', 'responses', 'survey'],
      ),
      AdminNavItem(
        index: 9,
        icon: Icons.bar_chart_outlined,
        label: 'Reports & Analytics',
        keywords: ['reports', 'analytics', 'stats', 'charts', 'insights'],
      ),
      AdminNavItem(
        index: 15,
        icon: Icons.lightbulb_outline,
        label: 'Program Insights',
        keywords: [
          'dss',
          'decision support',
          'recommendations',
          'flags',
          'thresholds',
          'unemployment',
          'curriculum',
        ],
      ),
    ],
  ),
  AdminNavSection(
    id: 'community',
    title: 'Community',
    items: [
      AdminNavItem(
        index: 1,
        icon: Icons.event_outlined,
        label: 'Events',
        keywords: ['calendar', 'schedule', 'event'],
      ),
      AdminNavItem(
        index: 11,
        icon: Icons.campaign_outlined,
        label: 'Announcements',
        keywords: ['news', 'broadcast', 'bulletin'],
      ),
      AdminNavItem(
        index: 12,
        icon: Icons.forum_outlined,
        label: 'Forum',
        keywords: ['discussion', 'posts', 'community'],
      ),
      AdminNavItem(
        index: 6,
        icon: Icons.mail_outline,
        label: 'Messages',
        keywords: ['inbox', 'chat', 'mail', 'messaging'],
      ),
    ],
  ),
  AdminNavSection(
    id: 'careers',
    title: 'Careers',
    items: [
      AdminNavItem(
        index: 5,
        icon: Icons.work_outline,
        label: 'Job Postings',
        keywords: ['jobs', 'careers', 'hiring', 'employment'],
      ),
    ],
  ),
  AdminNavSection(
    id: 'system',
    title: 'System',
    items: [
      AdminNavItem(
        index: 7,
        icon: Icons.history,
        label: 'Activity Logs',
        keywords: ['audit', 'logs', 'history', 'activity'],
      ),
      AdminNavItem(
        index: 4,
        icon: Icons.archive_outlined,
        label: 'Archives',
        keywords: ['archive', 'storage', 'backup'],
      ),
      AdminNavItem(
        index: 14,
        icon: Icons.feedback_outlined,
        label: 'Feedback',
        keywords: ['feedback', 'tickets', 'support'],
      ),
      AdminNavItem(
        index: 13,
        icon: Icons.auto_awesome_outlined,
        label: 'AI Assistant',
        keywords: ['ai', 'assistant', 'chatbot', 'help'],
      ),
    ],
  ),
];

/// A create shortcut surfaced by the header Quick Actions menu.
///
/// Each entry must map to a module that already exposes the create flow —
/// no new services, dialogs, or permissions are introduced here.
class AdminQuickAction {
  const AdminQuickAction({
    required this.label,
    required this.destination,
    required this.icon,
    required this.menuIndex,
  });

  final String label;

  /// Module the admin lands on, where the existing create action lives.
  final String destination;
  final IconData icon;
  final int menuIndex;
}

/// Quick Actions shown in the admin header.
///
/// Only modules with an existing create entry point are listed:
/// Events, Surveys, Announcements, Job Postings.
const List<AdminQuickAction> kAdminQuickActions = [
  AdminQuickAction(
    label: 'Create Event',
    destination: 'Events',
    icon: Icons.event_outlined,
    menuIndex: 1,
  ),
  AdminQuickAction(
    label: 'Create Survey',
    destination: 'Surveys',
    icon: Icons.poll_outlined,
    menuIndex: 10,
  ),
  AdminQuickAction(
    label: 'New Announcement',
    destination: 'Announcements',
    icon: Icons.campaign_outlined,
    menuIndex: 11,
  ),
  AdminQuickAction(
    label: 'Post New Job',
    destination: 'Job Postings',
    icon: Icons.work_outline,
    menuIndex: 5,
  ),
];

class AdminDashboardSidebar extends StatefulWidget {
  const AdminDashboardSidebar({
    super.key,
    required this.selectedMenuItem,
    required this.onMenuSelected,
    required this.currentUser,
    required this.onLogout,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  final int selectedMenuItem;
  final ValueChanged<int> onMenuSelected;
  final User? currentUser;
  final VoidCallback onLogout;

  /// When true, renders an icon-only mini-rail (desktop Console pattern).
  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  /// Enterprise rail width — dense but readable labels.
  static const double expandedWidth = 264;
  static const double collapsedWidth = 72;

  @override
  State<AdminDashboardSidebar> createState() => _AdminDashboardSidebarState();
}

/// Layout tokens for the admin sidebar (Phase 2 — layout only).
abstract final class _AdminSidebarLayout {
  static const Color navy = Color(0xFF090A4F);
  static const Color navyDeep = Color(0xFF1A1B5E);
  static const Color gold = Color(0xFFFFD700);

  static const double itemHeight = 40;
  static const double iconGutter = 36;
  static const double railPadH = 10;
  static const double sectionGap = 6;
  static const double radius = 8;
  static const Duration collapse = Duration(milliseconds: 220);
  static const Duration itemMotion = Duration(milliseconds: 140);
  static const Duration tooltipWait = Duration(milliseconds: 350);
}

/// Shared chrome tokens for header controls + floating panels (Phase 14).
abstract final class _AdminChrome {
  static const Color surface = Color(0xFFF4F6FA);
  static const Color border = Color(0xFFE5E7EB);
  static const Color panelShadow = Color(0x2E000000);

  static const double controlHeight = 38;
  static const double controlRadius = 8;
  static const double panelRadius = 10;
  static const double panelElevation = 12;
  static const double controlGap = 8;

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration panel = Duration(milliseconds: 160);
}

class _AdminDashboardSidebarState extends State<AdminDashboardSidebar> {
  @override
  Widget build(BuildContext context) {
    final width = widget.collapsed
        ? AdminDashboardSidebar.collapsedWidth
        : AdminDashboardSidebar.expandedWidth;

    return Semantics(
      container: true,
      label: widget.collapsed
          ? 'Admin navigation, collapsed'
          : 'Admin navigation',
      child: FocusTraversalGroup(
        child: AnimatedContainer(
          duration: _AdminSidebarLayout.collapse,
          curve: Curves.easeOutCubic,
          width: width,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_AdminSidebarLayout.navy, _AdminSidebarLayout.navyDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(2, 0),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: widget.collapsed
                ? KeyedSubtree(
                    key: const ValueKey('rail-collapsed'),
                    child: _buildCollapsed(),
                  )
                : KeyedSubtree(
                    key: const ValueKey('rail-expanded'),
                    child: _buildExpanded(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton({required bool collapsed}) {
    if (widget.onToggleCollapse == null) return const SizedBox.shrink();
    return Tooltip(
      message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      waitDuration: _AdminSidebarLayout.tooltipWait,
      child: IconButton(
        onPressed: widget.onToggleCollapse,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: Icon(
          collapsed ? Icons.chevron_right : Icons.chevron_left,
          size: 20,
          color: Colors.white.withValues(alpha: 0.9),
        ),
        tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      ),
    );
  }

  Widget _buildCollapsed() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
          child: Column(
            children: [
              _SidebarLogoMark(size: 36, radius: 9),
              const SizedBox(height: 6),
              _buildCollapseButton(collapsed: true),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            children: [
              for (var s = 0; s < kAdminNavSections.length; s++) ...[
                if (s > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.white.withValues(alpha: 0.1),
                      indent: 10,
                      endIndent: 10,
                    ),
                  ),
                for (final item in kAdminNavSections[s].items)
                  _CollapsedNavItem(
                    index: item.index,
                    icon: item.icon,
                    label: item.label,
                    selectedMenuItem: widget.selectedMenuItem,
                    onMenuSelected: widget.onMenuSelected,
                  ),
              ],
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        _SidebarAdminFooter(collapsed: true, onLogout: widget.onLogout),
      ],
    );
  }

  Widget _buildExpanded() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 8, 12),
          child: Row(
            children: [
              const _SidebarLogoMark(size: 40, radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  label: 'Alumni Portal Admin',
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alumni Portal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Admin',
                        style: TextStyle(
                          color: _AdminSidebarLayout.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildCollapseButton(collapsed: false),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              _AdminSidebarLayout.railPadH,
              10,
              _AdminSidebarLayout.railPadH,
              10,
            ),
            children: [
              for (final section in kAdminNavSections)
                _SidebarSection(
                  section: section,
                  selectedMenuItem: widget.selectedMenuItem,
                  onMenuSelected: widget.onMenuSelected,
                ),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        _SidebarAdminFooter(collapsed: false, onLogout: widget.onLogout),
      ],
    );
  }
}

/// Sidebar footer — a single Logout action pinned to the bottom of the rail.
///
/// Account details, feedback shortcut, and the identity card were removed in
/// favour of a clean, full-width Logout (icon-only when the rail is collapsed).
class _SidebarAdminFooter extends StatelessWidget {
  const _SidebarAdminFooter({required this.collapsed, required this.onLogout});

  final bool collapsed;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
        child: Tooltip(
          message: 'Logout',
          waitDuration: _AdminSidebarLayout.tooltipWait,
          child: IconButton(
            onPressed: onLogout,
            visualDensity: VisualDensity.compact,
            tooltip: 'Logout',
            icon: Icon(Icons.logout, size: 20, color: Colors.red.shade300),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Logout', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade200,
            side: BorderSide(
              color: Colors.red.shade200.withValues(alpha: 0.45),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_AdminSidebarLayout.radius),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminAvatar extends StatelessWidget {
  const _AdminAvatar({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD700), Color(0xFFFFC107)],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: _AdminSidebarLayout.navy,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SidebarLogoMark extends StatelessWidget {
  const _SidebarLogoMark({required this.size, required this.radius});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(size * 0.12),
        child: Image.asset(
          'assets/images/system_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.school,
            color: _AdminSidebarLayout.navy,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}

class _CollapsedNavItem extends StatefulWidget {
  const _CollapsedNavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.selectedMenuItem,
    required this.onMenuSelected,
  });

  final int index;
  final IconData icon;
  final String label;
  final int selectedMenuItem;
  final ValueChanged<int> onMenuSelected;

  @override
  State<_CollapsedNavItem> createState() => _CollapsedNavItemState();
}

class _CollapsedNavItemState extends State<_CollapsedNavItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selectedMenuItem == widget.index;
    final bg = isSelected
        ? Colors.white.withValues(alpha: _hovered || _focused ? 0.2 : 0.14)
        : _hovered || _focused
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.transparent;
    final fg = isSelected
        ? _AdminSidebarLayout.gold
        : Colors.white.withValues(alpha: _hovered || _focused ? 1.0 : 0.95);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: widget.label,
        waitDuration: _AdminSidebarLayout.tooltipWait,
        preferBelow: false,
        child: Semantics(
          button: true,
          selected: isSelected,
          label: widget.label,
          hint: isSelected ? 'Current page' : 'Navigate to ${widget.label}',
          child: Focus(
            onFocusChange: (value) => setState(() => _focused = value),
            child: MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onMenuSelected(widget.index),
                  borderRadius: BorderRadius.circular(
                    _AdminSidebarLayout.radius,
                  ),
                  hoverColor: Colors.transparent,
                  focusColor: Colors.white.withValues(alpha: 0.08),
                  child: AnimatedContainer(
                    duration: _AdminSidebarLayout.itemMotion,
                    curve: Curves.easeOut,
                    width: 56,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(
                        _AdminSidebarLayout.radius,
                      ),
                      border: Border.all(
                        color: _focused
                            ? Colors.white.withValues(alpha: 0.85)
                            : isSelected
                            ? _AdminSidebarLayout.gold.withValues(alpha: 0.55)
                            : Colors.transparent,
                        width: _focused ? 2 : 1,
                      ),
                    ),
                    child: Icon(widget.icon, size: 20, color: fg),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarSection extends StatelessWidget {
  const _SidebarSection({
    required this.section,
    required this.selectedMenuItem,
    required this.onMenuSelected,
  });

  final AdminNavSection section;
  final int selectedMenuItem;
  final ValueChanged<int> onMenuSelected;

  bool get _hasSelection =>
      section.items.any((item) => item.index == selectedMenuItem);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _AdminSidebarLayout.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            label: '${section.title} section',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text(
                section.title.toUpperCase(),
                style: TextStyle(
                  color: _hasSelection
                      ? _AdminSidebarLayout.gold
                      : Colors.white.withValues(alpha: 0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          for (final item in section.items)
            _SidebarItem(
              index: item.index,
              icon: item.icon,
              label: item.label,
              selectedMenuItem: selectedMenuItem,
              onMenuSelected: onMenuSelected,
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.selectedMenuItem,
    required this.onMenuSelected,
  });

  final int index;
  final IconData icon;
  final String label;
  final int selectedMenuItem;
  final ValueChanged<int> onMenuSelected;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selectedMenuItem == widget.index;
    final bg = isSelected
        ? Colors.white.withValues(alpha: _hovered || _focused ? 0.18 : 0.12)
        : _hovered || _focused
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.transparent;
    final iconColor = isSelected
        ? _AdminSidebarLayout.gold
        : Colors.white.withValues(alpha: _hovered || _focused ? 1.0 : 0.95);
    final labelColor = isSelected
        ? Colors.white
        : Colors.white.withValues(alpha: _hovered || _focused ? 1.0 : 0.95);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: widget.label,
        hint: isSelected ? 'Current page' : 'Navigate to ${widget.label}',
        child: Focus(
          onFocusChange: (value) => setState(() => _focused = value),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onMenuSelected(widget.index),
                borderRadius: BorderRadius.circular(_AdminSidebarLayout.radius),
                hoverColor: Colors.transparent,
                focusColor: Colors.white.withValues(alpha: 0.08),
                child: AnimatedContainer(
                  duration: _AdminSidebarLayout.itemMotion,
                  curve: Curves.easeOut,
                  height: _AdminSidebarLayout.itemHeight,
                  padding: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(
                      _AdminSidebarLayout.radius,
                    ),
                    border: _focused
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 2,
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        width: 3,
                        height: isSelected ? 20 : 0,
                        margin: const EdgeInsets.only(left: 2, right: 6),
                        decoration: BoxDecoration(
                          color: _AdminSidebarLayout.gold,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(
                        width: _AdminSidebarLayout.iconGutter,
                        child: Icon(widget.icon, size: 18, color: iconColor),
                      ),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: _AdminSidebarLayout.itemMotion,
                          style: TextStyle(
                            color: labelColor,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                            letterSpacing: 0.1,
                          ),
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboardTopHeader extends StatefulWidget {
  const AdminDashboardTopHeader({
    super.key,
    required this.currentUser,
    required this.onMenuSelected,
    required this.metrics,
    this.onLogout,
    this.selectedMenuItem = 0,
  });

  final User? currentUser;
  final ValueChanged<int> onMenuSelected;
  final AdminDashboardMetrics metrics;

  /// Signs the admin out from the header account menu.
  final VoidCallback? onLogout;

  /// Currently active nav index — drives the header page title.
  final int selectedMenuItem;

  @override
  State<AdminDashboardTopHeader> createState() =>
      _AdminDashboardTopHeaderState();
}

class _AdminDashboardTopHeaderState extends State<AdminDashboardTopHeader> {
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  StreamSubscription<int>? _unreadCountSubscription;
  StreamSubscription<int>? _badgeCountSubscription;
  StreamSubscription<List<NotificationModel>>? _notificationsSubscription;

  int _unreadCount = 0;
  int _unreadBadgeCount = 0;
  List<NotificationModel> _notifications = [];
  bool _notificationsOpen = false;
  bool _searchOpen = false;
  final LayerLink _notificationLink = LayerLink();
  final LayerLink _searchLink = LayerLink();
  OverlayEntry? _notificationOverlay;
  OverlayEntry? _searchOverlay;
  bool _commandPaletteOpen = false;

  /// Session recent pages (most recent first). Max [_kMaxRecentPages].
  final List<int> _recentPages = [];
  static const int _kMaxRecentPages = 6;

  /// Width of the header search field — mirrored by the overlay panel.
  double _searchFieldWidth = 340;

  /// Keyboard highlight index inside the global search overlay.
  int _searchHighlightIndex = 0;

  /// Notification panel filter.
  /// `null` + [_attentionFilter] false = All;
  /// [_attentionFilter] true = Needs attention only;
  /// non-null type = that category.
  NotificationType? _notificationCategoryFilter;
  bool _attentionFilter = false;

  static const _navy = Color(0xFF090A4F);

  int get _totalBadgeCount =>
      widget.metrics.attentionCount + _unreadBadgeCount;

  List<_AdminActivityAlert> get _activityAlerts {
    final m = widget.metrics;
    final items = <_AdminActivityAlert>[];

    if (m.unreadMessages > 0) {
      items.add(
        _AdminActivityAlert(
          title:
              '${m.unreadMessages} message${m.unreadMessages == 1 ? '' : 's'}',
          subtitle: 'Unread alumni messages',
          icon: Icons.mail_outline,
          color: const Color(0xFFE53935),
          menuIndex: 6,
          urgent: true,
          notificationType: NotificationType.message,
        ),
      );
    }
    if (m.pendingSurveyAssignments > 0) {
      items.add(
        _AdminActivityAlert(
          title:
              '${m.pendingSurveyAssignments} new survey response${m.pendingSurveyAssignments == 1 ? '' : 's'}',
          subtitle: 'Review newly submitted responses',
          icon: Icons.pending_actions,
          color: const Color(0xFFFF9800),
          menuIndex: 10,
          notificationType: NotificationType.survey,
        ),
      );
    }
    if (m.openFeedback > 0) {
      items.add(
        _AdminActivityAlert(
          title:
              '${m.openFeedback} feedback item${m.openFeedback == 1 ? '' : 's'}',
          subtitle: 'Open feedback awaiting review',
          icon: Icons.feedback_outlined,
          color: const Color(0xFF1A1851),
          menuIndex: 14,
          notificationType: NotificationType.feedback,
        ),
      );
    }
    if (m.registeredWithoutTracer > 0) {
      items.add(
        _AdminActivityAlert(
          title:
              '${m.registeredWithoutTracer} incomplete tracer${m.registeredWithoutTracer == 1 ? '' : 's'}',
          subtitle: 'Registered alumni missing tracer data',
          icon: Icons.assignment_late_outlined,
          color: const Color(0xFF607D8B),
          menuIndex: 2,
          // No NotificationType — visible under All / Attention only.
        ),
      );
    }

    return items;
  }

  @override
  void didUpdateWidget(AdminDashboardTopHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metrics != widget.metrics) {
      // OverlayEntry.markNeedsBuild() must not run during build/update.
      _scheduleOverlayRebuild(_notificationOverlay);
    }
    if (oldWidget.selectedMenuItem != widget.selectedMenuItem) {
      _rememberRecentPage(widget.selectedMenuItem);
      _scheduleOverlayRebuild(_searchOverlay);
    }
  }

  void _rememberRecentPage(int menuIndex) {
    _recentPages.remove(menuIndex);
    _recentPages.insert(0, menuIndex);
    if (_recentPages.length > _kMaxRecentPages) {
      _recentPages.removeRange(_kMaxRecentPages, _recentPages.length);
    }
  }

  void _scheduleOverlayRebuild(OverlayEntry? entry) {
    if (entry == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Avoid rebuilding an overlay that was dismissed before this frame.
      if (!identical(entry, _searchOverlay) &&
          !identical(entry, _notificationOverlay)) {
        return;
      }
      entry.markNeedsBuild();
    });
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
    _rememberRecentPage(widget.selectedMenuItem);
    _startNotificationListeners();
    NotificationRouter.registerAdminHandler(_openNotificationTarget);
    PushService.instance.syncForSignedInUser();
  }

  @override
  void dispose() {
    NotificationRouter.unregisterAdminHandler(_openNotificationTarget);
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _unreadCountSubscription?.cancel();
    _badgeCountSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _removeNotificationOverlay();
    _removeSearchOverlay();
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyK) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return false;
    if (!_commandPaletteOpen) _showCommandPalette();
    return true;
  }

  Future<void> _showCommandPalette() async {
    if (_commandPaletteOpen || !mounted) return;

    _removeSearchOverlay();
    _removeNotificationOverlay();
    _searchFocusNode.unfocus();
    setState(() {
      _searchOpen = false;
      _notificationsOpen = false;
      _commandPaletteOpen = true;
    });

    final selected = await showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close command palette',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: _AdminChrome.panel,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AdminCommandPalette(
          currentMenuIndex: widget.selectedMenuItem,
          recentMenuIndices: List<int>.unmodifiable(_recentPages),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() => _commandPaletteOpen = false);
    if (selected == _kChangePasswordCommand) {
      await _showChangePasswordDialog();
      return;
    }
    if (selected != null) {
      _rememberRecentPage(selected);
      widget.onMenuSelected(selected);
    }
  }

  void _startNotificationListeners() {
    _unreadCountSubscription = _notificationService
        .getUnreadCountStream()
        .listen((count) {
          if (mounted) setState(() => _unreadCount = count);
        }, onError: (_) {});

    // Unread alumni messages are already part of metrics.attentionCount.
    _badgeCountSubscription = _notificationService
        .getUnreadCountStream(excludeType: NotificationType.message)
        .listen((count) {
          if (mounted) setState(() => _unreadBadgeCount = count);
        }, onError: (_) {});

    _notificationsSubscription = _notificationService
        .getNotificationsStream(limit: 30)
        .listen((items) {
          if (mounted) {
            setState(() => _notifications = items);
            _scheduleOverlayRebuild(_notificationOverlay);
          }
        }, onError: (_) {});
  }

  void _onSearchChanged() {
    _searchHighlightIndex = 0;
    if (_searchOverlay != null) {
      _scheduleOverlayRebuild(_searchOverlay);
    } else if (_searchFocusNode.hasFocus || _searchController.text.isNotEmpty) {
      _showSearchOverlay();
    }
    setState(() {});
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchOverlay == null) {
      _showSearchOverlay();
    }
  }

  /// Builds categorized search hits for the current query.
  ///
  /// Today: pages + recent + lightweight "Go to…" commands.
  /// Reserved categories (alumni, events, surveys, reports, settings) are
  /// ready for future providers without changing the panel UI.
  List<AdminSearchHit> _buildSearchHits(String query) {
    final normalized = query.trim().toLowerCase();
    final hits = <AdminSearchHit>[];

    if (normalized.isEmpty) {
      for (final index in _recentPages) {
        final resolved = _resolveNavItem(index);
        if (resolved == null) continue;
        hits.add(
          AdminSearchHit(
            category: AdminSearchCategory.recent,
            title: resolved.item.label,
            subtitle: resolved.sectionTitle,
            icon: resolved.item.icon,
            menuIndex: index,
          ),
        );
      }
      for (final section in kAdminNavSections) {
        for (final item in section.items) {
          hits.add(
            AdminSearchHit(
              category: AdminSearchCategory.pages,
              title: item.label,
              subtitle: section.title,
              icon: item.icon,
              menuIndex: item.index,
            ),
          );
        }
      }
      return hits;
    }

    for (final section in kAdminNavSections) {
      for (final item in section.items) {
        if (!_matchesNavItem(item, section.title, normalized)) continue;
        hits.add(
          AdminSearchHit(
            category: AdminSearchCategory.pages,
            title: item.label,
            subtitle: section.title,
            icon: item.icon,
            menuIndex: item.index,
          ),
        );
      }
    }

    // Lightweight "Go to…" commands — only when the query looks like a command.
    final isCommandQuery =
        normalized.startsWith('go') || normalized.startsWith('open');
    if (isCommandQuery) {
      final needle = normalized
          .replaceFirst(RegExp(r'^(go\s*to|go|open)\s*'), '')
          .trim();
      for (final section in kAdminNavSections) {
        for (final item in section.items) {
          if (needle.isNotEmpty &&
              !_matchesNavItem(item, section.title, needle)) {
            continue;
          }
          if (needle.isEmpty &&
              !item.label.toLowerCase().contains(normalized) &&
              !'go to ${item.label}'.toLowerCase().contains(normalized)) {
            continue;
          }
          hits.add(
            AdminSearchHit(
              category: AdminSearchCategory.commands,
              title: 'Go to ${item.label}',
              subtitle: 'Navigate · ${section.title}',
              icon: Icons.subdirectory_arrow_right,
              menuIndex: item.index,
            ),
          );
        }
      }
    }

    if ('change password'.contains(normalized) ||
        _kChangePasswordKeywords.any(
          (k) => k.contains(normalized) || normalized.contains(k),
        )) {
      hits.add(
        const AdminSearchHit(
          category: AdminSearchCategory.settings,
          title: 'Change password',
          subtitle: 'Account · Security',
          icon: Icons.lock_outline,
          menuIndex: _kChangePasswordCommand,
        ),
      );
    }

    return hits;
  }

  bool _matchesNavItem(AdminNavItem item, String sectionTitle, String query) {
    if (item.label.toLowerCase().contains(query)) return true;
    if (sectionTitle.toLowerCase().contains(query)) return true;
    for (final keyword in item.keywords) {
      if (keyword.toLowerCase().contains(query) ||
          query.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  ({AdminNavItem item, String sectionTitle})? _resolveNavItem(int index) {
    for (final section in kAdminNavSections) {
      for (final item in section.items) {
        if (item.index == index) {
          return (item: item, sectionTitle: section.title);
        }
      }
    }
    return null;
  }

  Map<AdminSearchCategory, List<AdminSearchHit>> _groupHits(
    List<AdminSearchHit> hits,
  ) {
    final map = <AdminSearchCategory, List<AdminSearchHit>>{};
    for (final hit in hits) {
      map.putIfAbsent(hit.category, () => []).add(hit);
    }
    return map;
  }

  void _showSearchOverlay() {
    _removeSearchOverlay();
    final overlay = Overlay.of(context);

    _searchOverlay = OverlayEntry(
      builder: (context) {
        final query = _searchController.text;
        final hits = _buildSearchHits(query);
        final grouped = _groupHits(hits);
        final hasQuery = query.trim().isNotEmpty;
        final panelWidth = _searchFieldWidth.clamp(280.0, 420.0);

        // Stable category order for the panel.
        const order = [
          AdminSearchCategory.recent,
          AdminSearchCategory.pages,
          AdminSearchCategory.commands,
          AdminSearchCategory.alumni,
          AdminSearchCategory.events,
          AdminSearchCategory.surveys,
          AdminSearchCategory.reports,
          AdminSearchCategory.settings,
        ];

        // Flatten visible hits for keyboard highlight (mirrors on-screen order).
        final visibleHits = <AdminSearchHit>[];
        for (final category in order) {
          final group = grouped[category];
          if (group == null || group.isEmpty) continue;
          final limited = !hasQuery && category == AdminSearchCategory.pages
              ? group.take(8).toList()
              : group;
          visibleHits.addAll(limited);
        }
        final highlightIndex = visibleHits.isEmpty
            ? 0
            : _searchHighlightIndex.clamp(0, visibleHits.length - 1);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _searchFocusNode.unfocus();
                  _removeSearchOverlay();
                  setState(() => _searchOpen = false);
                },
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _searchLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 42),
              child: Material(
                elevation: _AdminChrome.panelElevation,
                shadowColor: _AdminChrome.panelShadow,
                borderRadius: BorderRadius.circular(_AdminChrome.panelRadius),
                color: Colors.white,
                child: Semantics(
                  container: true,
                  label: hasQuery
                      ? 'Search results, ${visibleHits.length} matches'
                      : 'Quick navigation',
                  child: Container(
                    width: panelWidth,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        _AdminChrome.panelRadius,
                      ),
                      border: Border.all(color: _AdminChrome.border),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          _buildSearchPanelHeader(
                            hasQuery: hasQuery,
                            resultCount: hits
                                .where(
                                  (h) =>
                                      h.category != AdminSearchCategory.recent,
                                )
                                .length,
                          ),
                          if (hits.isEmpty)
                            _buildSearchEmptyState(query)
                          else ...[
                            for (final category in order)
                              if (grouped[category]?.isNotEmpty ?? false)
                                ..._buildSearchCategoryBlock(
                                  category,
                                  grouped[category]!,
                                  showLimit:
                                      !hasQuery &&
                                      category == AdminSearchCategory.pages,
                                  highlightIndex: highlightIndex,
                                  flatHits: visibleHits,
                                ),
                            if (!hasQuery) _buildSearchFutureHint(),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_searchOverlay!);
    setState(() => _searchOpen = true);
  }

  Widget _buildSearchPanelHeader({
    required bool hasQuery,
    required int resultCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasQuery ? 'Search results' : 'Quick navigation',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _navy,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (hasQuery)
            Text(
              '$resultCount match${resultCount == 1 ? '' : 'es'}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchEmptyState(String query) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            'No results for “${query.trim()}”',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a page name, section, or keyword\n(e.g. alumni, surveys, jobs)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSearchCategoryBlock(
    AdminSearchCategory category,
    List<AdminSearchHit> hits, {
    bool showLimit = false,
    required int highlightIndex,
    required List<AdminSearchHit> flatHits,
  }) {
    final visible = showLimit ? hits.take(8).toList() : hits;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Row(
          children: [
            Icon(category.icon, size: 13, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              category.label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: Colors.grey.shade600,
              ),
            ),
            const Spacer(),
            if (showLimit && hits.length > visible.length)
              Text(
                '${hits.length} pages',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
      for (final hit in visible)
        _buildSearchHitTile(
          hit,
          highlighted:
              flatHits.isNotEmpty &&
              highlightIndex >= 0 &&
              highlightIndex < flatHits.length &&
              identical(flatHits[highlightIndex], hit),
        ),
    ];
  }

  Widget _buildSearchHitTile(AdminSearchHit hit, {bool highlighted = false}) {
    final isCurrent = hit.menuIndex == widget.selectedMenuItem;
    return Semantics(
      button: true,
      selected: highlighted || isCurrent,
      label: '${hit.title}, ${hit.subtitle}',
      hint: isCurrent ? 'Current page' : 'Open ${hit.title}',
      child: InkWell(
        onTap: () => _selectSearchResult(hit.menuIndex),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: highlighted || isCurrent
                  ? _navy.withValues(alpha: highlighted ? 0.08 : 0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: highlighted
                  ? Border.all(color: _navy.withValues(alpha: 0.45), width: 1.5)
                  : isCurrent
                  ? Border.all(color: _navy.withValues(alpha: 0.12))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Icon(hit.icon, size: 16, color: _navy),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hit.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent || highlighted
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        hit.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Current',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  )
                else
                  Icon(Icons.north_east, size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchFutureHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 14,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Alumni, events & surveys search coming soon',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeSearchOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  void _selectSearchResult(int menuIndex) {
    final isChangePassword = menuIndex == _kChangePasswordCommand;
    if (!isChangePassword) _rememberRecentPage(menuIndex);
    _removeSearchOverlay();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _searchOpen = false);
    if (isChangePassword) {
      _showChangePasswordDialog();
      return;
    }
    widget.onMenuSelected(menuIndex);
  }

  void _dismissSearchOverlay() {
    _removeSearchOverlay();
    _searchFocusNode.unfocus();
    setState(() => _searchOpen = false);
  }

  void _toggleNotifications() {
    if (_notificationsOpen) {
      _closeNotifications();
    } else {
      _showNotificationOverlay();
    }
  }

  void _showNotificationOverlay() {
    _removeNotificationOverlay();
    final overlay = Overlay.of(context);

    _notificationOverlay = OverlayEntry(
      builder: (context) {
        final screenW = MediaQuery.sizeOf(context).width;
        final panelWidth = screenW < 768 ? screenW - 32 : 380.0;
        final filteredNotifications = _filteredNotifications();
        final filteredAlerts = _filteredActivityAlerts();
        final grouped = _groupNotificationsByDay(filteredNotifications);
        final isEmpty = filteredAlerts.isEmpty && filteredNotifications.isEmpty;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeNotifications,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _notificationLink,
              showWhenUnlinked: false,
              offset: Offset(-panelWidth + 38, 42),
              child: Material(
                elevation: _AdminChrome.panelElevation,
                shadowColor: _AdminChrome.panelShadow,
                borderRadius: BorderRadius.circular(_AdminChrome.panelRadius),
                color: Colors.white,
                child: Container(
                  width: panelWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      _AdminChrome.panelRadius,
                    ),
                    border: Border.all(color: _AdminChrome.border),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 520),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        _buildNotificationPanelHeader(),
                        _buildNotificationFilterBar(),
                        if (isEmpty)
                          _buildNotificationEmptyState()
                        else ...[
                          if (filteredAlerts.isNotEmpty) ...[
                            _buildNotificationSectionLabel(
                              'Needs attention',
                              icon: Icons.priority_high,
                              accent: const Color(0xFFDC2626),
                            ),
                            ...filteredAlerts.map(_buildActivityAlertTile),
                            if (filteredNotifications.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Divider(height: 1),
                              ),
                          ],
                          for (final entry in grouped.entries) ...[
                            _buildNotificationSectionLabel(entry.key),
                            ...entry.value.map(_buildNotificationTile),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_notificationOverlay!);
    setState(() => _notificationsOpen = true);
  }

  List<NotificationModel> _filteredNotifications() {
    if (_attentionFilter) return const [];
    final type = _notificationCategoryFilter;
    if (type == null) return _notifications;
    return _notifications.where((n) => n.type == type).toList();
  }

  List<_AdminActivityAlert> _filteredActivityAlerts() {
    if (_notificationCategoryFilter != null) {
      final type = _notificationCategoryFilter!;
      return _activityAlerts.where((a) => a.notificationType == type).toList();
    }
    if (_attentionFilter) return _activityAlerts;
    return _activityAlerts;
  }

  /// Groups notifications into Today / Yesterday / Earlier (stable order).
  Map<String, List<NotificationModel>> _groupNotificationsByDay(
    List<NotificationModel> items,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = <NotificationModel>[];
    final yesterdayItems = <NotificationModel>[];
    final earlierItems = <NotificationModel>[];

    for (final n in items) {
      final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      if (d == today) {
        todayItems.add(n);
      } else if (d == yesterday) {
        yesterdayItems.add(n);
      } else {
        earlierItems.add(n);
      }
    }

    return {
      if (todayItems.isNotEmpty) 'Today': todayItems,
      if (yesterdayItems.isNotEmpty) 'Yesterday': yesterdayItems,
      if (earlierItems.isNotEmpty) 'Earlier': earlierItems,
    };
  }

  void _setNotificationFilter({
    NotificationType? type,
    bool attention = false,
  }) {
    _notificationCategoryFilter = type;
    _attentionFilter = attention;
    _scheduleOverlayRebuild(_notificationOverlay);
    // Keep State in sync so the next open remembers the filter.
    if (mounted) setState(() {});
  }

  Widget _buildNotificationPanelHeader() {
    final unread = _unreadCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined, size: 16, color: _navy),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _navy,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (unread > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unread unread',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await _notificationService.markAllAsRead();
                if (mounted) {
                  setState(() {
                    _unreadCount = 0;
                    _unreadBadgeCount = 0;
                    _notifications = [
                      for (final n in _notifications) n.copyWith(isRead: true),
                    ];
                  });
                }
                _scheduleOverlayRebuild(_notificationOverlay);
              },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Mark all read',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
          IconButton(
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.refresh, size: 16, color: Colors.grey.shade600),
            onPressed: _refreshNotifications,
          ),
          IconButton(
            tooltip: 'Notification settings',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.tune, size: 16, color: Colors.grey.shade600),
            onPressed: () {
              _closeNotifications();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationPreferencesScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Close',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
            onPressed: _closeNotifications,
          ),
        ],
      ),
    );
  }

  Future<void> _refreshNotifications() async {
    try {
      final results = await Future.wait([
        _notificationService.fetchPage(limit: 30),
        _notificationService.getUnreadCount(),
        _notificationService.getUnreadCount(
          excludeType: NotificationType.message,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _notifications = results[0] as List<NotificationModel>;
        _unreadCount = results[1] as int;
        _unreadBadgeCount = results[2] as int;
      });
      _scheduleOverlayRebuild(_notificationOverlay);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not refresh notifications')),
      );
    }
  }

  Widget _buildNotificationFilterBar() {
    final presentTypes = <NotificationType>{
      for (final n in _notifications) n.type,
      for (final a in _activityAlerts)
        if (a.notificationType != null) a.notificationType!,
    };

    final chips = <Widget>[
      _notificationFilterChip(
        label: 'All',
        selected: !_attentionFilter && _notificationCategoryFilter == null,
        onTap: () => _setNotificationFilter(),
        count: _notifications.length + _activityAlerts.length,
      ),
      if (_activityAlerts.isNotEmpty)
        _notificationFilterChip(
          label: 'Attention',
          selected: _attentionFilter,
          onTap: () => _setNotificationFilter(attention: true),
          count: _activityAlerts.length,
          accent: const Color(0xFFDC2626),
        ),
      for (final type in NotificationType.values)
        if (presentTypes.contains(type))
          _notificationFilterChip(
            label: _notificationTypeLabel(type),
            selected: !_attentionFilter && _notificationCategoryFilter == type,
            onTap: () => _setNotificationFilter(type: type),
            count:
                _notifications.where((n) => n.type == type).length +
                _activityAlerts.where((a) => a.notificationType == type).length,
          ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _notificationFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? count,
    Color? accent,
  }) {
    final color = accent ?? _navy;
    return Semantics(
      button: true,
      selected: selected,
      label: count != null && count > 0 ? '$label, $count' : label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          focusColor: color.withValues(alpha: 0.12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.1)
                  : const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.35)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? color : Colors.grey.shade700,
                  ),
                ),
                if (count != null && count > 0) ...[
                  const SizedBox(width: 5),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? color.withValues(alpha: 0.8)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationSectionLabel(
    String label, {
    IconData? icon,
    Color? accent,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: accent ?? Colors.grey.shade500),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: accent ?? Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationEmptyState() {
    final filtered = _attentionFilter || _notificationCategoryFilter != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtered
                ? Icons.filter_list_off_outlined
                : Icons.notifications_none_outlined,
            size: 36,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            filtered ? 'Nothing in this category' : 'No notifications yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            filtered
                ? 'Try another filter or clear to see all'
                : 'Activity and updates will show up here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.35,
            ),
          ),
          if (filtered) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _setNotificationFilter(),
              child: const Text('Show all'),
            ),
          ],
        ],
      ),
    );
  }

  void _closeNotifications() {
    _removeNotificationOverlay();
    setState(() => _notificationsOpen = false);
  }

  void _removeNotificationOverlay() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
  }

  Future<void> _onNotificationTap(NotificationModel notification) async {
    await _markNotificationReadIfNeeded(notification);
    await _openNotificationTarget(
      NotificationTarget.resolve(notification, isAdmin: true),
    );
  }

  /// Opens the module (and, where possible, the exact item) a notification
  /// points to. Also used for push / reminder taps via [NotificationRouter].
  Future<void> _openNotificationTarget(NotificationTarget target) async {
    if (!mounted) return;
    _closeNotifications();
    final id = target.id;
    switch (target.destination) {
      case NotificationDestination.adminConversation:
        if (id != null && id.isNotEmpty) MessageOpenBus.openConversation(id);
        widget.onMenuSelected(AdminNotificationMenu.messages);
      case NotificationDestination.adminFeedback:
        widget.onMenuSelected(AdminNotificationMenu.feedback);
        if (id == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminFeedbackDetailScreen(feedbackId: id),
          ),
        );
      case NotificationDestination.adminEvent:
        widget.onMenuSelected(AdminNotificationMenu.events);
        if (id == null) return;
        await _openAdminEventComments(id);
      case NotificationDestination.none:
        return;
      default:
        widget.onMenuSelected(
          target.adminMenuIndex ?? AdminNotificationMenu.dashboard,
        );
    }
  }

  Future<void> _openAdminEventComments(String eventId) async {
    AlumniEvent? event;
    try {
      event = await EventService().getEventById(eventId);
    } catch (_) {}
    if (!mounted) return;
    if (event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This event is no longer available.')),
      );
      return;
    }
    final size = MediaQuery.of(context).size;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: size.width.clamp(320.0, 720.0),
          height: size.height * 0.8,
          child: AdminEventCommentsDialog(
            event: event!,
            commentService: EventCommentService(),
            onCommentDeleted: () {},
            asDialog: true,
          ),
        ),
      ),
    );
  }

  Future<void> _markNotificationReadIfNeeded(
    NotificationModel notification,
  ) async {
    if (notification.isRead) return;
    await _notificationService.markAsRead(notification.id);
    // Optimistic local update so the panel reflects state immediately.
    final idx = _notifications.indexWhere((n) => n.id == notification.id);
    if (idx >= 0) {
      _notifications[idx] = notification.copyWith(isRead: true);
    }
    if (_unreadCount > 0) {
      _unreadCount = (_unreadCount - 1).clamp(0, 9999);
    }
    if (notification.type != NotificationType.message &&
        _unreadBadgeCount > 0) {
      _unreadBadgeCount = (_unreadBadgeCount - 1).clamp(0, 9999);
    }
    if (mounted) setState(() {});
    _scheduleOverlayRebuild(_notificationOverlay);
  }

  /// Primary CTA label for a notification type — navigates to the owning module.
  String _primaryActionLabel(NotificationType type) {
    return switch (type) {
      NotificationType.event => 'View events',
      NotificationType.job => 'View jobs',
      NotificationType.message => 'Open inbox',
      NotificationType.announcement => 'View announcements',
      NotificationType.survey => 'Review surveys',
      NotificationType.feedback => 'Open feedback',
      NotificationType.forum => 'Open forum',
      NotificationType.system => 'Go to dashboard',
    };
  }

  String _alertActionLabel(_AdminActivityAlert alert) {
    return switch (alert.menuIndex) {
      6 => 'Open inbox',
      10 => 'Review responses',
      14 => 'Open feedback',
      2 => 'Open directory',
      _ => 'Open',
    };
  }

  Widget _buildNotificationActionChip({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool emphasized = false,
    Color? color,
  }) {
    final c = color ?? _navy;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          focusColor: c.withValues(alpha: 0.12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: emphasized
                  ? c.withValues(alpha: 0.1)
                  : const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: emphasized
                    ? c.withValues(alpha: 0.3)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: c),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityAlertTile(_AdminActivityAlert alert) {
    return InkWell(
      onTap: () {
        _closeNotifications();
        widget.onMenuSelected(alert.menuIndex);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color: alert.urgent
                ? alert.color.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: alert.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: alert.color.withValues(alpha: 0.2)),
                ),
                child: Icon(alert.icon, color: alert.color, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: alert.urgent
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: _navy,
                            ),
                          ),
                        ),
                        if (alert.urgent)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDC2626),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildNotificationActionChip(
                          label: _alertActionLabel(alert),
                          icon: Icons.arrow_forward,
                          emphasized: true,
                          color: alert.color,
                          onPressed: () {
                            _closeNotifications();
                            widget.onMenuSelected(alert.menuIndex);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel notification) {
    final timeText = _formatNotificationTime(notification.createdAt);
    final typeLabel = _notificationTypeLabel(notification.type);
    final actionColor = Color(notification.colorValue);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNotificationTap(notification),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            decoration: BoxDecoration(
              color: notification.isRead
                  ? Colors.transparent
                  : _navy.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: actionColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(
                    _notificationIcon(notification.type),
                    color: actionColor,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: _navy,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDC2626),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: actionColor,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Text(
                              '·',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                          Text(
                            timeText,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildNotificationActionChip(
                            label: _primaryActionLabel(notification.type),
                            icon: Icons.open_in_new,
                            emphasized: true,
                            color: actionColor,
                            onPressed: () async {
                              await _onNotificationTap(notification);
                            },
                          ),
                          if (!notification.isRead)
                            _buildNotificationActionChip(
                              label: 'Mark read',
                              icon: Icons.done,
                              onPressed: () =>
                                  _markNotificationReadIfNeeded(notification),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatNotificationTime(DateTime createdAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final time = intl.DateFormat('h:mm a').format(createdAt);

    if (day == today) return time;
    if (day == yesterday) return 'Yesterday · $time';
    if (now.difference(createdAt).inDays < 7) {
      return '${intl.DateFormat('EEE').format(createdAt)} · $time';
    }
    return intl.DateFormat('MMM d · h:mm a').format(createdAt);
  }

  String _notificationTypeLabel(NotificationType type) {
    return switch (type) {
      NotificationType.event => 'Events',
      NotificationType.job => 'Jobs',
      NotificationType.message => 'Messages',
      NotificationType.announcement => 'Announcements',
      NotificationType.survey => 'Surveys',
      NotificationType.feedback => 'Feedback',
      NotificationType.forum => 'Forum',
      NotificationType.system => 'System',
    };
  }

  IconData _notificationIcon(NotificationType type) {
    return switch (type) {
      NotificationType.event => Icons.event_outlined,
      NotificationType.job => Icons.work_outline,
      NotificationType.message => Icons.message_outlined,
      NotificationType.announcement => Icons.campaign_outlined,
      NotificationType.survey => Icons.poll_outlined,
      NotificationType.feedback => Icons.feedback_outlined,
      NotificationType.forum => Icons.forum_outlined,
      NotificationType.system => Icons.info_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 1100;
    final tight = width < 900;
    final searchWidth = tight ? 180.0 : (compact ? 240.0 : 320.0);
    // Keep overlay follower width in sync without mutating during layout.
    if (_searchFieldWidth != searchWidth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _searchFieldWidth == searchWidth) return;
        setState(() => _searchFieldWidth = searchWidth);
      });
    }

    return Semantics(
      container: true,
      label: 'Admin toolbar',
      child: FocusTraversalGroup(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _AdminChrome.border)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 16,
              6,
              compact ? 10 : 16,
              6,
            ),
            child: Row(
              children: [
                const Spacer(),
                _buildSearchField(width: searchWidth, compact: compact),
                SizedBox(width: _AdminChrome.controlGap),
                _buildQuickActionsButton(showLabel: !compact),
                SizedBox(width: _AdminChrome.controlGap),
                _buildNotificationBell(),
                SizedBox(width: _AdminChrome.controlGap),
                _buildProfileChip(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField({required double width, required bool compact}) {
    final shortcutLabel = Theme.of(context).platform == TargetPlatform.macOS
        ? '⌘ K'
        : 'Ctrl K';
    return SizedBox(
      width: width,
      height: _AdminChrome.controlHeight,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_searchOpen || _searchFocusNode.hasFocus) {
              _dismissSearchOverlay();
            }
          },
          const SingleActivator(LogicalKeyboardKey.arrowDown): () {
            if (!_searchOpen) {
              _showSearchOverlay();
              return;
            }
            final hits = _visibleSearchHits();
            if (hits.isEmpty) return;
            _searchHighlightIndex = (_searchHighlightIndex + 1).clamp(
              0,
              hits.length - 1,
            );
            _scheduleOverlayRebuild(_searchOverlay);
          },
          const SingleActivator(LogicalKeyboardKey.arrowUp): () {
            if (!_searchOpen) return;
            final hits = _visibleSearchHits();
            if (hits.isEmpty) return;
            _searchHighlightIndex = (_searchHighlightIndex - 1).clamp(
              0,
              hits.length - 1,
            );
            _scheduleOverlayRebuild(_searchOverlay);
          },
          const SingleActivator(LogicalKeyboardKey.enter): () {
            if (!_searchOpen) return;
            final hits = _visibleSearchHits();
            if (hits.isEmpty) return;
            final index = _searchHighlightIndex.clamp(0, hits.length - 1);
            _selectSearchResult(hits[index].menuIndex);
          },
        },
        child: CompositedTransformTarget(
          link: _searchLink,
          child: Semantics(
            textField: true,
            label: 'Search admin pages and sections',
            hint:
                'Use arrow keys to move through results, Enter to open, '
                'or $shortcutLabel for the command palette',
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onTap: _showSearchOverlay,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: compact ? 'Search…' : 'Search pages, sections…',
                hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade600,
                  size: 18,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _dismissSearchOverlay();
                        },
                      )
                    : compact
                    ? null
                    : Tooltip(
                        message: 'Open command palette ($shortcutLabel)',
                        child: Semantics(
                          button: true,
                          label: 'Open command palette',
                          child: InkWell(
                            onTap: _showCommandPalette,
                            borderRadius: BorderRadius.circular(5),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: const Color(0xFFD1D5DB),
                                  ),
                                ),
                                child: Text(
                                  shortcutLabel,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 34,
                ),
                filled: true,
                fillColor: _AdminChrome.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    _AdminChrome.controlRadius,
                  ),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    _AdminChrome.controlRadius,
                  ),
                  borderSide: BorderSide(
                    color: _searchOpen
                        ? _navy.withValues(alpha: 0.35)
                        : _AdminChrome.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    _AdminChrome.controlRadius,
                  ),
                  borderSide: BorderSide(color: _navy.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Visible search hits in the same order as the overlay list.
  List<AdminSearchHit> _visibleSearchHits() {
    final query = _searchController.text;
    final hits = _buildSearchHits(query);
    final grouped = _groupHits(hits);
    final hasQuery = query.trim().isNotEmpty;
    const order = [
      AdminSearchCategory.recent,
      AdminSearchCategory.pages,
      AdminSearchCategory.commands,
      AdminSearchCategory.alumni,
      AdminSearchCategory.events,
      AdminSearchCategory.surveys,
      AdminSearchCategory.reports,
      AdminSearchCategory.settings,
    ];
    final visible = <AdminSearchHit>[];
    for (final category in order) {
      final group = grouped[category];
      if (group == null || group.isEmpty) continue;
      visible.addAll(
        !hasQuery && category == AdminSearchCategory.pages
            ? group.take(8)
            : group,
      );
    }
    return visible;
  }

  /// Primary create shortcuts. Navigates to the module that owns the flow —
  /// the create action itself stays in its page (no duplicated logic).
  Widget _buildQuickActionsButton({required bool showLabel}) {
    return Semantics(
      button: true,
      label: 'Quick actions',
      hint: 'Create event, survey, announcement, or job posting',
      child: PopupMenuButton<int>(
        tooltip: 'Quick actions',
        position: PopupMenuPosition.under,
        offset: const Offset(0, 6),
        elevation: _AdminChrome.panelElevation,
        color: Colors.white,
        constraints: const BoxConstraints(minWidth: 244, maxWidth: 268),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_AdminChrome.panelRadius),
          side: const BorderSide(color: _AdminChrome.border),
        ),
        padding: EdgeInsets.zero,
        onSelected: _onQuickActionSelected,
        itemBuilder: (context) => [
          PopupMenuItem<int>(
            enabled: false,
            height: 34,
            child: Text(
              'QUICK ACTIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          for (final action in kAdminQuickActions)
            PopupMenuItem<int>(
              value: action.menuIndex,
              height: 46,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _AdminChrome.surface,
                      borderRadius: BorderRadius.circular(
                        _AdminChrome.controlRadius,
                      ),
                      border: Border.all(color: _AdminChrome.border),
                    ),
                    child: Icon(action.icon, size: 15, color: _navy),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          action.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _navy,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          'in ${action.destination}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.north_east, size: 13, color: Colors.grey.shade400),
                ],
              ),
            ),
        ],
        child: Container(
          height: _AdminChrome.controlHeight,
          padding: EdgeInsets.symmetric(horizontal: showLabel ? 12 : 0),
          width: showLabel ? null : _AdminChrome.controlHeight,
          decoration: BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.circular(_AdminChrome.controlRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 17, color: Colors.white),
              if (showLabel) ...[
                const SizedBox(width: 6),
                const Text(
                  'New',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.expand_more, size: 16, color: Colors.white70),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onQuickActionSelected(int menuIndex) {
    _dismissSearchOverlay();
    _rememberRecentPage(menuIndex);
    widget.onMenuSelected(menuIndex);
  }

  Widget _buildNotificationBell() {
    final label = _totalBadgeCount > 0
        ? 'Notifications, $_totalBadgeCount unread or needing attention'
        : 'Notifications';
    return CompositedTransformTarget(
      link: _notificationLink,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Tooltip(
            message: label,
            child: Semantics(
              button: true,
              label: label,
              expanded: _notificationsOpen,
              child: InkWell(
                onTap: _toggleNotifications,
                borderRadius: BorderRadius.circular(8),
                focusColor: _navy.withValues(alpha: 0.08),
                child: AnimatedContainer(
                  duration: _AdminChrome.fast,
                  width: _AdminChrome.controlHeight,
                  height: _AdminChrome.controlHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _notificationsOpen
                        ? _navy.withValues(alpha: 0.08)
                        : _AdminChrome.surface,
                    borderRadius: BorderRadius.circular(
                      _AdminChrome.controlRadius,
                    ),
                    border: Border.all(
                      color: _notificationsOpen
                          ? _navy.withValues(alpha: 0.3)
                          : _AdminChrome.border,
                    ),
                  ),
                  child: Icon(
                    _notificationsOpen
                        ? Icons.notifications
                        : Icons.notifications_outlined,
                    color: _navy,
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
          if (_totalBadgeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      _totalBadgeCount > 99 ? '99+' : '$_totalBadgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileChip() {
    final email = widget.currentUser?.email ?? 'admin@alumni.com';
    final rawName =
        (widget.currentUser?.userMetadata?['display_name'] as String?)?.trim();
    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : email.split('@').first;

    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? 'A'
        : parts.length == 1
        ? parts.first
              .substring(0, parts.first.length >= 2 ? 2 : 1)
              .toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    return PopupMenuButton<String>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_AdminChrome.panelRadius),
      ),
      onSelected: (value) => _onProfileAction(value),
      itemBuilder: (ctx) => _profileMenuItems(name, email),
      child: Semantics(
        button: true,
        label: 'Account menu for $name, Administrator',
        child: ExcludeSemantics(child: _AdminAvatar(initials: initials, size: 32)),
      ),
    );
  }

  List<PopupMenuEntry<String>> _profileMenuItems(String name, String email) {
    return [
      PopupMenuItem<String>(
        enabled: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              email,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 3),
            Text(
              'Administrator',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'profile',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.person_outline, size: 20),
          title: Text('My profile'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'password',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline, size: 20),
          title: Text('Change password'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'help',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.help_outline, size: 20),
          title: Text('Help'),
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'logout',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.logout, size: 20, color: Colors.red.shade700),
          title: Text('Logout', style: TextStyle(color: Colors.red.shade700)),
        ),
      ),
    ];
  }

  void _onProfileAction(String value) {
    switch (value) {
      case 'profile':
        _showAccountDetails();
      case 'password':
        _showChangePasswordDialog();
      case 'help':
        _showHelp();
      case 'logout':
        widget.onLogout?.call();
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final othersSignedOut = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Change password',
      builder: (_) => const _AdminChangePasswordDialog(),
    );
    if (!mounted || othersSignedOut == null) return;
    showAuthFeedback(
      context,
      othersSignedOut
          ? 'Password changed successfully. Other devices have been signed out.'
          : 'Password changed successfully.',
      error: false,
    );
  }

  Future<void> _showAccountDetails() async {
    final email = widget.currentUser?.email ?? 'admin@alumni.com';
    final rawName =
        (widget.currentUser?.userMetadata?['display_name'] as String?)?.trim();
    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : email.split('@').first;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('My profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(email, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Role · Administrator',
                style: TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showHelp() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & support'),
        content: const Text(
          'Use the search bar (Ctrl/⌘ K) to jump to any page or action. '
          'For assistance with the Alumni Portal, contact your system '
          'administrator or submit a message from the Feedback screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Pops with whether other devices were signed out, or null when cancelled.
class _AdminChangePasswordDialog extends StatelessWidget {
  const _AdminChangePasswordDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PortalTheme.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PortalTheme.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: const Text(
                  'Change password',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: PortalTheme.navy,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Keep your account secure by using a strong password '
                "that you don't use elsewhere.",
                style: PortalTheme.meta.copyWith(height: 1.4),
              ),
              const SizedBox(height: PortalTheme.space4),
              ChangePasswordForm(
                role: UserRole.admin,
                autofocus: true,
                onSuccess: (othersSignedOut) =>
                    Navigator.of(context).pop(othersSignedOut),
                onCancel: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CommandPaletteKind { recent, actions, pages, settings }

class _CommandPaletteEntry {
  const _CommandPaletteEntry({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.menuIndex,
    this.keywords = const [],
  });

  final _CommandPaletteKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final int menuIndex;
  final List<String> keywords;
}

class _AdminCommandPalette extends StatefulWidget {
  const _AdminCommandPalette({
    required this.currentMenuIndex,
    required this.recentMenuIndices,
  });

  final int currentMenuIndex;
  final List<int> recentMenuIndices;

  @override
  State<_AdminCommandPalette> createState() => _AdminCommandPaletteState();
}

class _AdminCommandPaletteState extends State<_AdminCommandPalette> {
  static const _navy = Color(0xFF090A4F);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;

  List<_CommandPaletteEntry> get _entries {
    final all = <_CommandPaletteEntry>[];

    for (final index in widget.recentMenuIndices) {
      final resolved = _resolve(index);
      if (resolved == null) continue;
      all.add(
        _CommandPaletteEntry(
          kind: _CommandPaletteKind.recent,
          title: resolved.item.label,
          subtitle: 'Recent · ${resolved.section.title}',
          icon: resolved.item.icon,
          menuIndex: index,
          keywords: resolved.item.keywords,
        ),
      );
    }

    for (final action in kAdminQuickActions) {
      all.add(
        _CommandPaletteEntry(
          kind: _CommandPaletteKind.actions,
          title: action.label,
          subtitle: 'Quick action · Opens ${action.destination}',
          icon: action.icon,
          menuIndex: action.menuIndex,
          keywords: ['create', 'new', 'add', action.destination],
        ),
      );
    }

    for (final section in kAdminNavSections) {
      for (final item in section.items) {
        all.add(
          _CommandPaletteEntry(
            kind: _CommandPaletteKind.pages,
            title: item.label,
            subtitle: section.title,
            icon: item.icon,
            menuIndex: item.index,
            keywords: item.keywords,
          ),
        );
      }
    }

    all.add(
      const _CommandPaletteEntry(
        kind: _CommandPaletteKind.settings,
        title: 'Change password',
        subtitle: 'Account · Security',
        icon: Icons.lock_outline,
        menuIndex: _kChangePasswordCommand,
        keywords: _kChangePasswordKeywords,
      ),
    );

    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return all;

    return all.where((entry) {
      return entry.title.toLowerCase().contains(query) ||
          entry.subtitle.toLowerCase().contains(query) ||
          entry.keywords.any(
            (keyword) => keyword.toLowerCase().contains(query),
          );
    }).toList();
  }

  ({AdminNavSection section, AdminNavItem item})? _resolve(int index) {
    for (final section in kAdminNavSections) {
      for (final item in section.items) {
        if (item.index == index) return (section: section, item: item);
      }
    }
    return null;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _moveSelection(int delta) {
    final entries = _entries;
    if (entries.isEmpty) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, entries.length - 1);
    });
    if (_scrollController.hasClients) {
      final target = (_selectedIndex * 54.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  void _selectCurrent() {
    final entries = _entries;
    if (entries.isEmpty) return;
    final index = _selectedIndex.clamp(0, entries.length - 1);
    Navigator.of(context).pop(entries[index].menuIndex);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    if (_selectedIndex >= entries.length && entries.isNotEmpty) {
      _selectedIndex = entries.length - 1;
    }

    final width = MediaQuery.sizeOf(context).width;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 64),
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _moveSelection(1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _moveSelection(-1),
              const SingleActivator(LogicalKeyboardKey.enter): _selectCurrent,
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  Navigator.of(context).pop(),
            },
            child: Material(
              color: Colors.white,
              elevation: 20,
              shadowColor: _AdminChrome.panelShadow,
              borderRadius: BorderRadius.circular(_AdminChrome.panelRadius),
              clipBehavior: Clip.antiAlias,
              child: Semantics(
                container: true,
                label: 'Command palette',
                child: Container(
                  width: width < 720 ? width - 32 : 680,
                  constraints: const BoxConstraints(maxHeight: 560),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      _AdminChrome.panelRadius,
                    ),
                    border: Border.all(color: _AdminChrome.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchInput(),
                      Flexible(
                        child: entries.isEmpty
                            ? _buildEmptyState()
                            : _buildResults(entries),
                      ),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: TextField(
        controller: _controller,
        autofocus: true,
        onChanged: (_) => setState(() => _selectedIndex = 0),
        style: const TextStyle(fontSize: 16, color: _navy),
        decoration: InputDecoration(
          hintText: 'Search pages and actions…',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          prefixIcon: const Icon(Icons.search, color: _navy, size: 22),
          suffixIcon: _controller.text.isEmpty
              ? Container(
                  margin: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  child: Text(
                    'ESC',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: () {
                    _controller.clear();
                    setState(() => _selectedIndex = 0);
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 46,
            maxWidth: 46,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildResults(List<_CommandPaletteEntry> entries) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        for (final kind in _CommandPaletteKind.values)
          if (entries.any((entry) => entry.kind == kind)) ...[
            _buildSectionLabel(kind),
            for (final entry in entries.where((entry) => entry.kind == kind))
              _buildEntry(entry, entries.indexOf(entry)),
          ],
      ],
    );
  }

  Widget _buildSectionLabel(_CommandPaletteKind kind) {
    final label = switch (kind) {
      _CommandPaletteKind.recent => 'RECENT',
      _CommandPaletteKind.actions => 'QUICK ACTIONS',
      _CommandPaletteKind.pages => 'PAGES',
      _CommandPaletteKind.settings => 'SETTINGS',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildEntry(_CommandPaletteEntry entry, int index) {
    final selected = index == _selectedIndex;
    final current = entry.menuIndex == widget.currentMenuIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${entry.title}. ${entry.subtitle}',
        hint: current ? 'Current page' : 'Open ${entry.title}',
        child: MouseRegion(
          onEnter: (_) => setState(() => _selectedIndex = index),
          child: InkWell(
            onTap: () => Navigator.of(context).pop(entry.menuIndex),
            borderRadius: BorderRadius.circular(8),
            focusColor: _navy.withValues(alpha: 0.08),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: selected
                    ? _navy.withValues(alpha: 0.07)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: selected
                    ? Border.all(color: _navy.withValues(alpha: 0.12))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.kind == _CommandPaletteKind.actions
                          ? const Color(0xFFFFC107).withValues(alpha: 0.16)
                          : const Color(0xFFF4F6FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Icon(entry.icon, size: 17, color: _navy),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (current)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                    )
                  else if (selected)
                    Icon(
                      Icons.keyboard_return,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 36,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          const Text(
            'No matching command',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a page name or action such as “create event”',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          _keyHint('↑↓'),
          const SizedBox(width: 5),
          Text('Navigate', style: _footerTextStyle()),
          const SizedBox(width: 14),
          _keyHint('↵'),
          const SizedBox(width: 5),
          Text('Open', style: _footerTextStyle()),
          const Spacer(),
          Text(
            '${_entries.length} result${_entries.length == 1 ? '' : 's'}',
            style: _footerTextStyle(),
          ),
        ],
      ),
    );
  }

  Widget _keyHint(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _navy,
          height: 1,
        ),
      ),
    );
  }

  TextStyle _footerTextStyle() {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Colors.grey.shade600,
    );
  }
}

class _AdminActivityAlert {
  const _AdminActivityAlert({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.menuIndex,
    this.urgent = false,
    this.notificationType,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int menuIndex;
  final bool urgent;

  /// Maps this metric alert to a [NotificationType] for category filtering.
  /// Null = only visible under All / Attention (e.g. tracer incompletes).
  final NotificationType? notificationType;
}
