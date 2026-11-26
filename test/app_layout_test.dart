import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/design.dart';
import 'package:growth_circle/home_slides.dart';
import 'package:growth_circle/user_page_design.dart';

void main() {
  tearDown(() => language.value = const Locale('en'));
  testWidgets('home places slideshow above wallet and removes action section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Dashboard(
            uid: 'sample',
            onBrowse: () {},
            balanceStream: Stream.value([
              {'balance': 0},
            ]),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getTopLeft(find.byType(HomeSlideshow)).dy,
      lessThan(tester.getTopLeft(find.byType(BalanceCard)).dy),
    );
    expect(find.text('Small actions. Shared momentum.'), findsNothing);
    expect(find.byType(DashboardTaskTile), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('home wallet opens history with transaction references', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: Scaffold(
          body: Dashboard(
            uid: 'sample',
            onBrowse: () {},
            balanceStream: Stream.value([
              {'balance': 20},
            ]),
            historyStream: Stream.value([
              {
                'amount': 10,
                'reason': 'welcome',
                'createdAt': '2026-01-03',
                'reference_id': 'RG0000000001',
              },
              {
                'amount': 5,
                'reason': 'referral',
                'createdAt': '2026-01-02',
                'reference_id': 'RF0000000002',
              },
              {
                'amount': -2,
                'reason': 'transfer_sent',
                'createdAt': '2026-01-01',
                'reference_id': '100000000000',
              },
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coin history'));
    await tester.pumpAndSettle();
    expect(find.text('Reference ID: RG0000000001'), findsOneWidget);
    expect(find.text('Reference ID: RF0000000002'), findsOneWidget);
    expect(find.text('Reference ID: 100000000000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['en', 'ml']) {
    testWidgets(
      'page header actions keep their position and style in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0;
        Rect? bellRect, settingsRect;
        for (final page in ['home', 'earn', 'campaigns', 'profile']) {
          final profile = page == 'profile';
          final header = UserPageHeader(
            title: words[page]![locale == 'ml' ? 1 : 0],
            subtitle: page == 'campaigns' ? 'Campaign description' : null,
            notifications: Stream.value([
              <String, dynamic>{'read_at': null},
            ]),
            onNotifications: () => opened++,
            onSignOut: profile ? () {} : null,
            primary: !profile,
          );
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              supportedLocales: const [Locale('en'), Locale('ml')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: growthTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 24),
                  textScaler: const TextScaler.linear(1.5),
                ),
                child: child!,
              ),
              home: Scaffold(
                appBar: profile ? null : header,
                body: profile
                    ? SafeArea(child: Column(children: [header]))
                    : const SizedBox(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final bell = find.byTooltip(
            words['notifications']![locale == 'ml' ? 1 : 0],
          );
          final settings = find.byTooltip(
            profile
                ? words['profileSettings']![locale == 'ml' ? 1 : 0]
                : (locale == 'en' ? 'Settings' : 'ക്രമീകരണങ്ങൾ'),
          );
          final currentBell = tester.getRect(bell);
          final currentSettings = tester.getRect(settings);
          bellRect ??= currentBell;
          settingsRect ??= currentSettings;
          expect(currentBell, bellRect, reason: page);
          expect(currentSettings, settingsRect, reason: page);
          expect(currentBell.size, const Size(48, 48));
          expect(currentSettings.size, const Size(48, 48));
          final bellButton = tester.widget<IconButton>(
            find
                .ancestor(
                  of: find.byIcon(Icons.notifications_none_outlined),
                  matching: find.byType(IconButton),
                )
                .first,
          );
          final settingsButton = tester.widget<IconButton>(
            find
                .ancestor(
                  of: find.byIcon(Icons.settings_outlined),
                  matching: find.byType(IconButton),
                )
                .first,
          );
          expect(
            bellButton.style!.backgroundColor!.resolve({}),
            const Color(0xffeee4ff),
          );
          expect(
            settingsButton.style!.backgroundColor!.resolve({}),
            const Color(0xffeee4ff),
          );
          expect(bellButton.style!.foregroundColor!.resolve({}), growthPurple);
          expect(settingsButton.style!.foregroundColor!.resolve({}), growthInk);
          expect(
            tester.widget<Badge>(find.byType(Badge)).isLabelVisible,
            isTrue,
          );
          await tester.tap(bell);
          expect(tester.takeException(), isNull);
        }
        expect(opened, 4);
      },
    );
  }

  testWidgets('all task categories share one row at reference phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: TaskTypePicker(
              selected: 'all',
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chips = find.byType(ChoiceChip);
    expect(chips, findsNWidgets(5));
    final y = tester.getCenter(chips.first).dy;
    for (var i = 1; i < 5; i++) {
      expect((tester.getCenter(chips.at(i)).dy - y).abs(), lessThan(1));
    }
    await tester.tap(chips.last);
    expect(selected, 'share');
    expect(tester.takeException(), isNull);
  });
  testWidgets('rounded navigation remains usable on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: StatefulBuilder(
            builder: (context, setState) => GrowthNavigation(
              selected: selected,
              labels: const ['Home', 'Earn', 'Campaigns', 'Profile'],
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Campaigns'));
    await tester.pump();
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['en', 'ml']) {
    testWidgets('home wallet works at narrow width in $locale', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      language.value = Locale(locale);
      await tester.pumpWidget(
        MaterialApp(
          theme: growthTheme(),
          locale: Locale(locale),
          supportedLocales: const [Locale('en'), Locale('ml')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: Dashboard(
              uid: 'sample',
              balanceStream: Stream.value([
                {'balance': 128},
              ]),
              onBrowse: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('128'), findsNothing);
      await tester.tap(
        find.byTooltip(
          locale == 'en' ? 'Check balance' : 'Balance പരിശോധിക്കുക',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('128'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text(words['browse']![locale == 'ml' ? 1 : 0]), findsNothing);
      expect(find.text(words['create']![locale == 'ml' ? 1 : 0]), findsNothing);
      expect(find.byType(DashboardTaskTile), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shared page content stays centered on a wide window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: Scaffold(body: AppListView(children: const [Text('Content')])),
      ),
    );
    expect(tester.getSize(find.byType(ListView)).width, 560);
    expect(tester.getTopLeft(find.byType(ListView)).dx, 320);
    expect(tester.takeException(), isNull);
  });
}
