import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/referral_history.dart';

import 'profile_layout_test.dart' show FakeProfileGateway;

class LargeRewardGateway extends FakeProfileGateway {
  @override
  Future<ProfileInfo> load(String uid) async => const ProfileInfo(
    usernames: [],
    referralCode: 'ABCD123',
    referralCount: 4,
    referralJoined: false,
    pinSet: true,
    referralRewards: {
      'invite': 10000,
      'milestone_5': 10000,
      'milestone_10': 10000,
      'milestone_15': 10000,
    },
  );
}

void main() {
  for (final language in ['en', 'ml', 'ar']) {
    testWidgets('referral pages remain usable at large text in $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = LargeRewardGateway();
      Widget wrapper(Widget child) => MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('ml'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: child,
      );
      for (final section in ReferralSection.values) {
        await tester.pumpWidget(
          wrapper(
            ProfileDetailsPage(
              key: ValueKey(section),
              uid: 'user',
              gateway: gateway,
              accounts: false,
              referralSection: section,
              authorizeChange: () async => true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
        await tester.pumpAndSettle();
        if (section == ReferralSection.code) {
          for (var scroll = 0; scroll < 4; scroll++) {
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -450),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'reward cards in $language',
            );
          }
        }
        expect(tester.takeException(), isNull, reason: '$section in $language');
      }
      await tester.pumpWidget(
        wrapper(ReferralHistoryPage(load: gateway.loadReferralHistory)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('a***@***'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('a***@***'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'history in $language');
    });
  }

  testWidgets('history retries errors and supports page navigation', (
    tester,
  ) async {
    var fail = true;
    final offsets = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ReferralHistoryPage(
          load: (offset) async {
            offsets.add(offset);
            if (fail) throw StateError('offline');
            return List.generate(
              offset == 0 ? 50 : 1,
              (_) => ReferralHistoryEntry.fromRow({
                'direction': 'referred',
                'masked_name': 'A***',
                'masked_email': 'a***@***',
                'created_at': '2026-11-21T00:00:00Z',
              }),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load referral history.'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Next'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(offsets, [0, 0, 50]);
    await tester.ensureVisible(find.text('Previous'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(offsets.last, 0);
  });
}
