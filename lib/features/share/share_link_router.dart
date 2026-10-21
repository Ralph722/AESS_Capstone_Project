import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:alumni_system/features/notifications/application/notification_router.dart';
import 'package:alumni_system/features/share/share_destination.dart';

/// Captures share links (web URL at launch, Android App Links cold/warm)
/// and hands the validated destination to the existing
/// [NotificationRouter], which already holds destinations until the
/// signed-in shell is ready and replays them after login.
abstract final class ShareLinkRouter {
  static final _seen = <String>{};
  static StreamSubscription<Uri>? _appLinksSub;
  static bool _appLinksStarted = false;

  /// Web cold start: the canonical path is in the launch URL.
  static void captureWebLaunch() {
    if (!kIsWeb) return;
    _open(ShareLinkParser.parse(Uri.base));
  }

  /// Android App Links: initial link + links received while running.
  /// No-op on web (the URL itself is the entry point there).
  static void initializeAppLinks() {
    if (kIsWeb || _appLinksStarted) return;
    _appLinksStarted = true;
    final links = AppLinks();
    unawaited(() async {
      try {
        _open(ShareLinkParser.parse(await links.getInitialLink()));
      } catch (_) {
        // No launch link / platform without app-link support.
      }
    }());
    _appLinksSub ??= links.uriLinkStream.listen(
      (uri) => _open(ShareLinkParser.parse(uri)),
      onError: (_) {},
    );
  }

  static void _open(ShareDestination? destination) {
    if (destination == null) return;
    // The OS may deliver the same link twice (initial + stream); the
    // held destination must navigate exactly once.
    if (!_seen.add(destination.notificationRoute)) return;
    unawaited(NotificationRouter.openRoute(destination.notificationRoute));
  }

  /// Called on sign-out so a later account never inherits a link,
  /// and the same link can be opened again after signing back in.
  static void clearPending() {
    _seen.clear();
    NotificationRouter.clearPending();
  }
}
