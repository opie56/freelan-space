import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/referral_history.dart';

void main() {
  testWidgets(
    'campaign limits displays the latest server settings and retries errors',
    (tester) async {
      var fail = true;
      Future<CampaignPlan> load() async {
        if (fail) throw StateError('offline');
        return const CampaignPlan(
          maxTasks: 10,
          campaignCount: 2,
          windowHours: 12,
          baseTasks: 6,
          referralBonus: 4,
        );
      }

      await tester.pumpWidget(
        MaterialApp(home: CampaignLimitsPage(loadPlan: load)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to load campaign limits.'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('2 campaign(s) every 12 hours'), findsOneWidget);
      expect(find.text('6 tasks per campaign'), findsOneWidget);
      expect(find.text('4 extra tasks with a referral'), findsOneWidget);
      expect(
        find.textContaining('up to 10 tasks per campaign'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'invite opens referral code and refreshes the current limit on return',
    (tester) async {
      var referred = false;
      var loads = 0;
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return CampaignLimitsPage(
                loadPlan: () async {
                  loads++;
                  return CampaignPlan(maxTasks: referred ? 8 : 3);
                },
                onOpenReferrals: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const Scaffold(body: Text('Referral code screen')),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invite a friend to unlock more tasks'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('campaign_limits_invite')),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -150));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('campaign_limits_invite')));
      await tester.pumpAndSettle();
      expect(find.text('Referral code screen'), findsOneWidget);
      referred = true;
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(loads, 2);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Referral bonus unlocked'), findsOneWidget);
      expect(find.text('Invite a friend to unlock more tasks'), findsNothing);
      expect(
        find.text(
          'Additional referrals do not add more tasks. Standard coin charges apply.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('no referral reward is promoted when admin sets bonus to zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CampaignLimitsPage(
          loadPlan: () async =>
              const CampaignPlan(maxTasks: 6, baseTasks: 6, referralBonus: 0),
          onOpenReferrals: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('6'), findsOneWidget);
    expect(find.byKey(const Key('campaign_limits_invite')), findsNothing);
    expect(find.textContaining('extra tasks'), findsNothing);
  });

  for (final language in ['en', 'ml', 'hi', 'ta', 'ar']) {
    testWidgets(
      'campaign limits fit a narrow screen in $language at large text size',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
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
            home: CampaignLimitsPage(
              loadPlan: () async => const CampaignPlan(maxTasks: 3),
              onOpenReferrals: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -900));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('campaign_limits_invite')), findsOneWidget);
      },
    );
  }
}
