import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/config/supabase_config.dart';
import 'package:alumni_system/core/navigation/app_navigator.dart';
import 'package:alumni_system/features/alumni/card/data/alumni_card_verify_launch.dart';
import 'package:alumni_system/features/alumni/card/presentation/alumni_card_verify_page.dart';
import 'package:alumni_system/features/auth/presentation/auth_gate.dart';
import 'package:alumni_system/features/notifications/push/push_service.dart';
import 'package:alumni_system/features/share/share_link_router.dart';
import 'package:alumni_system/shared/widgets/admin/admin_theme.dart';
import 'package:alumni_system/shared/widgets/environment_banner.dart';
import 'package:alumni_system/shared/widgets/user/portal_overlay_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installWebDebugErrorGuards();

  final configError = SupabaseConfig.configurationError;
  if (configError != null) throw StateError(configError);
  // Release builds must target live defaults without a demo/staging ribbon.
  if (kReleaseMode && SupabaseConfig.environment.isNotEmpty) {
    throw StateError(
      'Release builds must omit AESS_ENV '
      '(got "${SupabaseConfig.environment}").',
    );
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  PushService.instance.initialize();
  // Share links: web reads the launch URL here; Android App Links are
  // delivered async. Validated destinations are held by NotificationRouter
  // until AuthGate / the signed-in shell is ready (login continuation).
  ShareLinkRouter.captureWebLaunch();
  ShareLinkRouter.initializeAppLinks();

  runApp(const MyApp());
}

/// Flutter web debug can enter an error loop after hot restart:
/// dumping an error via [FlutterError.dumpErrorToConsole] may itself throw
/// `LegacyJavaScriptObject is not a subtype of DiagnosticsNode`, and a
/// teardown race can assert `Trying to render a disposed EngineFlutterView`.
///
/// Present errors as plain text on web so the console stays usable.
void _installWebDebugErrorGuards() {
  if (!kIsWeb || !kDebugMode) return;

  FlutterError.presentError = (FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    if (message.contains('disposed EngineFlutterView') ||
        (message.contains('LegacyJavaScriptObject') &&
            message.contains('DiagnosticsNode'))) {
      return;
    }
    debugPrint('══╡ FLUTTER ERROR ╞══');
    debugPrint(message);
    final stack = details.stack;
    if (stack != null) {
      debugPrint(stack.toString());
    }
  };
}

/// Shared Supabase client for services.
SupabaseClient get supabase => Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AESS',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigator.navigatorKey,
      scaffoldMessengerKey: AppNavigator.messengerKey,
      navigatorObservers: [AppNavigator.routeObserver],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF090A4F)),
        useMaterial3: true,
      ),
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: PortalOverlayTheme.suspended,
        child: child,
        builder: (context, suspended, child) => Theme(
          data: suspended
              ? AdminOverlayTheme.apply(Theme.of(context))
              : PortalOverlayTheme.apply(Theme.of(context)),
          child: EnvironmentBanner(
            label: SupabaseConfig.environmentLabel,
            child: child!,
          ),
        ),
      ),
      // Staff QR scan: /?verify=<token> skips login and shows the result page.
      // AuthGate restores an existing Supabase session (if any) before Login.
      home: () {
        final verifyCode = AlumniCardVerifyLaunch.takeCode();
        if (verifyCode != null) {
          return AlumniCardVerifyPage(code: verifyCode);
        }
        return const AuthGate();
      }(),
    );
  }
}
