import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_main.dart';
import 'package:growth_circle/admin_destination.dart';
import 'package:growth_circle/brand_wordmark.dart';

import 'admin_workspace_test.dart' show WorkspaceFake;

Finder sidebarScroll() => find.descendant(
  of: find.byKey(const Key('admin_sidebar')),
  matching: find.byType(Scrollable),
);

Future<void> tapMenu(WidgetTester tester, Finder item) async {
  // Items from both ends of the sidebar can be reached from any scroll offset.
  await tester.drag(sidebarScroll(), const Offset(0, 1400));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(item, 100, scrollable: sidebarScroll());
  await tester.pumpAndSettle();
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item.hitTestable());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'desktop sidebar persists through reports and user detail routes',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: adminTheme(),
          home: AdminDesktopConsole(
            gateway: WorkspaceFake(),
            onLogout: () async {},
            onLanguage: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FreelanMark), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('admin@example.test'), findsNothing);
      await tapMenu(tester, find.widgetWithText(ListTile, 'App management'));
      await tapMenu(tester, find.widgetWithText(ListTile, 'Admin users'));
      await tester.pumpAndSettle();
      expect(find.text('admin@example.test'), findsOneWidget);
      await tapMenu(tester, find.widgetWithText(ListTile, 'Users'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Details').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Details').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Referrals: 1'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Reports & CSV'), findsOneWidget);
      await tapMenu(tester, find.widgetWithText(ListTile, 'Reports & CSV'));
      await tester.pumpAndSettle();
      expect(find.text('Export CSV'), findsOneWidget);
      await tapMenu(tester, find.widgetWithText(ListTile, 'Overview'));
      await tester.pumpAndSettle();
      expect(find.text('20'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('collapsed menu keeps the current route and can navigate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: adminTheme(),
        home: AdminDesktopConsole(
          gateway: WorkspaceFake(),
          onLogout: () async {},
          onLanguage: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sidebar = find.byKey(const Key('admin_sidebar'));
    expect(tester.getSize(sidebar).width, 230);
    await tester.ensureVisible(find.text('Details').last);
    await tester.tap(find.text('Details').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Referrals: 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Collapse menu'));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 72);
    expect(find.textContaining('Referrals: 1'), findsOneWidget);
    await tapMenu(tester, find.byTooltip('Reports & CSV'));
    await tester.pumpAndSettle();
    expect(find.text('Export CSV'), findsOneWidget);
    await tester.tap(find.byTooltip('Expand menu'));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 230);
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Reports & CSV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('menu groups collapse and a short desktop page scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AdminScrollBehavior(),
        home: AdminDesktopConsole(
          gateway: WorkspaceFake(),
          onLogout: () async {},
          onLanguage: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final group = find.widgetWithText(ListTile, 'Monitoring');
    final reports = find.widgetWithText(ListTile, 'Reports & CSV');
    await tapMenu(tester, group);
    expect(reports, findsNothing);
    await tapMenu(tester, group);
    expect(reports, findsOneWidget);
    final page = find
        .descendant(
          of: find.byType(AdminDashboard),
          matching: find.byType(SingleChildScrollView),
        )
        .first;
    final viewport = find
        .descendant(of: page, matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(viewport).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.dragFrom(
      tester.getTopLeft(page) + const Offset(32, 76),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(find.byType(Scrollbar), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop viewer cannot change access from directory table', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: adminTheme(),
        home: AdminDesktopConsole(
          gateway: WorkspaceFake(role: 'viewer'),
          onLogout: () async {},
          onLanguage: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Block app access'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
