import 'dart:async';

import 'package:growth_circle/app_updates.dart';
import 'package:growth_circle/push_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';

void main() {
  testWidgets('late permission read cannot undo an explicit push change', (
    tester,
  ) async {
    final stale = Completer<bool>();
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: UserSettingsPage(
          authorizeChange: () async => true,
          enabledLoader: () => ++reads == 1 ? Future.value(true) : stale.future,
          pushUpdater: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(reads, 2);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    stale.complete(true);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancelled security check keeps push enabled', (tester) async {
    var updates = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: UserSettingsPage(
          authorizeChange: () async => false,
          enabledLoader: () async => true,
          pushUpdater: (_) async {
            updates++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(updates, 0);
  });
  testWidgets('permission denial offers Android notification settings', (
    tester,
  ) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(updateChannel, (call) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(updateChannel, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: UserSettingsPage(
          authorizeChange: () async => true,
          enabledLoader: () async => false,
          pushUpdater: (_) async => throw const PushPermissionDenied(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(calls, ['openNotificationSettings']);
  });
  testWidgets('sound preference opens the delivery notification channel', (
    tester,
  ) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(updateChannel, (call) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(updateChannel, null),
    );
    await tester.pumpWidget(
      MaterialApp(home: UserSettingsPage(enabledLoader: () async => true)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Notification sound'));
    await tester.tap(find.text('Notification sound'));
    await tester.pumpAndSettle();
    expect(calls, ['openNotificationSoundSettings']);
  });
  tearDown(() => language.value = const Locale('en'));
  testWidgets(
    'settings disables and enables push, preserving state on failure',
    (tester) async {
      final changes = <bool>[];
      bool fail = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: growthTheme(),
          home: UserSettingsPage(
            authorizeChange: () async => true,
            enabledLoader: () async => true,
            pushUpdater: (value) async {
              if (fail) throw StateError('offline');
              changes.add(value);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(changes, [false]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, false);
      fail = true;
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, false);
      fail = false;
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(changes, [false, true]);
      await Scrollable.ensureVisible(
        tester.element(find.byType(DropdownButton<String>)),
        alignment: .4,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('മലയാളം').last);
      await tester.pumpAndSettle();
      expect(language.value.languageCode, 'ml');
    },
  );
}
