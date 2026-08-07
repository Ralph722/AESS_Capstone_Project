import 'package:flutter/material.dart';
import 'package:alumni_system/features/messages/widgets/message_theme.dart';
import 'package:alumni_system/shared/widgets/user/portal_theme.dart';

/// Professional support-channel header aligned with [PortalAppBar] geometry.
class MessageSupportAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const MessageSupportAppBar({
    super.key,
    this.officeName = MessageTheme.officeDisplayName,
    this.showBack = false,
  });

  final String officeName;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(PortalTheme.headerHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBack,
      toolbarHeight: PortalTheme.headerHeight,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(
        color: PortalTheme.textOnNavy,
        size: PortalTheme.headerIconSize,
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: MessageTheme.headerGradient),
      ),
      titleSpacing: PortalTheme.headerHPad,
      title: Semantics(
        header: true,
        label: '$officeName, ${MessageTheme.supportStatusLabel}. '
            '${MessageTheme.supportHoursHint}',
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: PortalTheme.space2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    officeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PortalTheme.pageTitleOnDark.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          MessageTheme.supportStatusLabel,
                          style: PortalTheme.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          MessageTheme.supportHoursHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PortalTheme.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
