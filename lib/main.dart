import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/config/supabase_config.dart';
import 'package:alumni_system/core/navigation/app_navigator.dart';
import 'package:alumni_system/features/auth/presentation/auth_gate.dart';
import 'package:alumni_system/features/notifications/push/push_service.dart';
import 'package:alumni_system/shared/widgets/user/portal_overlay_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installWebDebugErrorGuards();

  if (!SupabaseConfig.isConfigured) {
    throw StateError(
      'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY.',
    );
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  PushService.instance.initialize();

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
      title: 'Alumni Portal',
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
              ? Theme.of(context)
              : PortalOverlayTheme.apply(Theme.of(context)),
          child: child!,
        ),
      ),
      // AuthGate restores an existing Supabase session (if any) before Login.
      home: const AuthGate(),
    );
  }
}
