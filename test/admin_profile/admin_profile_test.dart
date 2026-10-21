import 'dart:typed_data';

import 'package:alumni_system/features/admin/profile/data/admin_profile_service.dart';
import 'package:alumni_system/features/admin/profile/presentation/admin_profile_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeService implements AdminProfileService {
  final calls = <({String name, Uint8List? photo, bool removePhoto})>[];
  bool fail = false;

  @override
  Future<AdminProfile> load() async => throw UnimplementedError();

  @override
  Future<AdminProfile> save({
    required AdminProfile current,
    required String name,
    Uint8List? photo,
    bool removePhoto = false,
  }) async {
    calls.add((name: name, photo: photo, removePhoto: removePhoto));
    if (fail) throw StateError('offline');
    return AdminProfile(
      name: AdminProfile.normalizeName(name),
      email: current.email,
      avatarUrl: photo != null
          ? 'https://example.com/a.jpg'
          : (removePhoto ? null : current.avatarUrl),
    );
  }
}

const _ana = AdminProfile(name: 'Ana Reyes', email: 'ana@ustp.edu.ph');

/// Opens the dialog from a button and records what it pops.
Future<List<bool?>> _openDialog(
  WidgetTester tester,
  AdminProfileController controller, {
  AdminPhotoPicker? pickPhoto,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1366, 900);
  addTearDown(tester.view.reset);
  final results = <bool?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              results.add(
                await showDialog<bool>(
                  context: context,
                  builder: (_) => pickPhoto == null
                      ? AdminProfileDialog(controller: controller)
                      : AdminProfileDialog(
                          controller: controller,
                          pickPhoto: pickPhoto,
                        ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

FilledButton _saveButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Save changes'),
);

void main() {
  group('AdminProfile', () {
    test('initials', () {
      expect(_ana.initials, 'AR');
      expect(
        const AdminProfile(name: 'admin', email: '').initials,
        'AD',
      );
      expect(const AdminProfile(name: '', email: '').initials, 'A');
    });

    test('name validation and normalising', () {
      expect(AdminProfile.normalizeName('  Ana   Reyes '), 'Ana Reyes');
      expect(AdminProfile.validateName('   '), isNotNull);
      expect(AdminProfile.validateName('A'), isNotNull);
      expect(AdminProfile.validateName('x' * 61), isNotNull);
      expect(AdminProfile.validateName('Ana Reyes'), isNull);
    });

    test('falls back to the email name, then "Admin"', () {
      expect(AdminProfile.fromUser(null).name, 'Admin');
    });
  });

  group('Edit profile dialog', () {
    testWidgets('save stays disabled until something changes', (tester) async {
      final controller = AdminProfileController(
        initial: _ana,
        service: _FakeService(),
      );
      await _openDialog(tester, controller);

      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('ana@ustp.edu.ph'), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextFormField), 'Ana  Reyes ');
      await tester.pump();
      expect(_saveButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextFormField), 'Ana Cruz');
      await tester.pump();
      expect(_saveButton(tester).onPressed, isNotNull);
    });

    testWidgets('renaming saves, updates the profile and closes', (
      tester,
    ) async {
      final service = _FakeService();
      final controller = AdminProfileController(
        initial: _ana,
        service: service,
      );
      final results = await _openDialog(tester, controller);

      await tester.enterText(find.byType(TextFormField), '  Ana   Cruz ');
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(service.calls.single.photo, isNull);
      expect(service.calls.single.removePhoto, isFalse);
      expect(controller.value.name, 'Ana Cruz');
      expect(results, [true]);
      expect(find.text('Edit profile'), findsNothing);
    });

    testWidgets('a too-short name is rejected without saving', (
      tester,
    ) async {
      final service = _FakeService();
      final controller = AdminProfileController(
        initial: _ana,
        service: service,
      );
      await _openDialog(tester, controller);

      await tester.enterText(find.byType(TextFormField), 'A');
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Name must be at least 2 characters.'), findsOneWidget);
      expect(service.calls, isEmpty);
    });

    testWidgets('picked photo is uploaded on save', (tester) async {
      final service = _FakeService();
      final controller = AdminProfileController(
        initial: _ana,
        service: service,
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      await _openDialog(tester, controller, pickPhoto: () async => bytes);

      expect(find.text('Upload photo'), findsOneWidget);
      expect(find.text('Remove photo'), findsNothing);

      await tester.tap(find.text('Upload photo'));
      await tester.pump();
      expect(find.text('Change photo'), findsOneWidget);
      expect(find.text('Remove photo'), findsOneWidget);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(service.calls.single.photo, bytes);
      expect(controller.value.hasAvatar, isTrue);
    });

    testWidgets('removing the stored photo saves removePhoto', (
      tester,
    ) async {
      final service = _FakeService();
      final controller = AdminProfileController(
        initial: const AdminProfile(
          name: 'Ana Reyes',
          email: 'ana@ustp.edu.ph',
          avatarUrl: 'https://example.com/old.jpg',
        ),
        service: service,
      );
      await _openDialog(tester, controller);

      await tester.tap(find.text('Remove photo'));
      await tester.pump();
      expect(find.text('Upload photo'), findsOneWidget);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(service.calls.single.removePhoto, isTrue);
      expect(controller.value.hasAvatar, isFalse);
    });

    testWidgets('a failed save keeps the dialog open with an error', (
      tester,
    ) async {
      final service = _FakeService()..fail = true;
      final controller = AdminProfileController(
        initial: _ana,
        service: service,
      );
      final results = await _openDialog(tester, controller);

      await tester.enterText(find.byType(TextFormField), 'Ana Cruz');
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Couldn't save your profile"), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(controller.value, _ana);
      expect(results, isEmpty);
    });

    testWidgets('cancel closes without saving', (tester) async {
      final service = _FakeService();
      final controller = AdminProfileController(
        initial: _ana,
        service: service,
      );
      final results = await _openDialog(tester, controller);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(results, [false]);
      expect(service.calls, isEmpty);
    });
  });
}
