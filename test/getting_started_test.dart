import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';

void main() {
  testWidgets(
    'home guide explains approval and opens the selected destination',
    (tester) async {
      var browse = 0, campaigns = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard(
              uid: 'sample',
              balanceStream: Stream.value([
                {'balance': 0},
              ]).asBroadcastStream(),
              onBrowse: () => browse++,
              onCampaigns: () => campaigns++,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('getting_started_open')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('getting_started_open'))),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('getting_started_open')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Complete a task and submit the requested details. Coins are awarded after approval.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Use available coins to create a campaign. The required coins are reserved.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('getting_started_browse')),
      );
      await tester.tap(find.byKey(const Key('getting_started_browse')));
      await tester.pumpAndSettle();
      expect(browse, 1);
      expect(campaigns, 0);
      await tester.tap(find.byKey(const Key('getting_started_open')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('getting_started_campaigns')),
      );
      await tester.tap(find.byKey(const Key('getting_started_campaigns')));
      await tester.pumpAndSettle();
      expect(campaigns, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final locale in ['en', 'ml', 'hi', 'ta', 'ar']) {
    testWidgets(
      'guide fits and buttons are reachable in $locale at large text size',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            supportedLocales: const [
              Locale('en'),
              Locale('ml'),
              Locale('hi'),
              Locale('ta'),
              Locale('ar'),
            ],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Dashboard(
                uid: 'sample',
                balanceStream: Stream.value([
                  {'balance': 0},
                ]).asBroadcastStream(),
                onBrowse: () {},
                onCampaigns: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(const Key('getting_started_open')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const Key('getting_started_open'))),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('getting_started_open')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('getting_started_campaigns')),
          180,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const Key('getting_started_campaigns'))),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('getting_started_campaigns')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
