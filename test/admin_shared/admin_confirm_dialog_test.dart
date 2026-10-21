import 'package:alumni_system/shared/widgets/admin/admin_confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Launcher extends StatefulWidget {
  const _Launcher({this.destructive = false});

  final bool destructive;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  bool? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            final r = await showAdminConfirmDialog(
              context,
              title: 'Delete event?',
              message: 'This removes the event for all alumni.',
              confirmLabel: 'Delete',
              destructive: widget.destructive,
              icon: Icons.delete_outline,
            );
            setState(() => result = r);
          },
          child: Text('open:$result'),
        ),
      ),
    );
  }
}

Type? _focusedButtonType() {
  Type? found;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
    if (e.widget is OutlinedButton || e.widget is FilledButton) {
      found = e.widget.runtimeType;
      return false;
    }
    return true;
  });
  return found;
}

Future<void> _open(WidgetTester tester, {bool destructive = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1366, 768);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: _Launcher(destructive: destructive)),
  );
  await tester.tap(find.text('open:null'));
  await tester.pumpAndSettle();
  expect(find.text('Delete event?'), findsOneWidget);
}

void main() {
  testWidgets('confirm returns true', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('open:true'), findsOneWidget);
  });

  testWidgets('cancel returns false with default label', (tester) async {
    await _open(tester);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('open:false'), findsOneWidget);
  });

  testWidgets('tapping outside returns false', (tester) async {
    await _open(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('open:false'), findsOneWidget);
  });

  testWidgets('Escape returns false', (tester) async {
    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('open:false'), findsOneWidget);
  });

  testWidgets('destructive focuses Cancel', (tester) async {
    await _open(tester, destructive: true);
    expect(_focusedButtonType(), OutlinedButton);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('open:false'), findsOneWidget);
  });

  testWidgets('non-destructive focuses the confirm button', (tester) async {
    await _open(tester);
    expect(_focusedButtonType(), FilledButton);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('open:true'), findsOneWidget);
  });

  testWidgets('no overflow on a 320px screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: _Launcher()));
    await tester.tap(find.text('open:null'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Delete'), findsOneWidget);
  });
}
