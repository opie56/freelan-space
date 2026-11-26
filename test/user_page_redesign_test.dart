import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/user_page_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final locale in ['en', 'ml']) {
    testWidgets('empty task filters recover in $locale at large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final index = locale == 'ml' ? 1 : 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          supportedLocales: const [Locale('en'), Locale('ml')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: growthTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: TaskList(
              uid: 'sample',
              controlsStream: Stream.value([
                {'action_type': 'follow', 'enabled': true},
              ]),
              presenceStream: Stream.value([]),
              claimsStream: Stream.value([]),
              campaignsStream: Stream.value([
                {
                  'id': 'available',
                  'ownerId': 'other',
                  'status': 'active',
                  'type': 'follow',
                  'link': 'https://instagram.com/example',
                  'reward_per_task': 2,
                },
              ]),
              loadSavedIds: () async => [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> reveal(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }

      final saved = find.widgetWithText(
        FilterChip,
        words['savedTasks']![index],
      );
      await reveal(saved);
      expect(tester.getSize(saved).height, greaterThanOrEqualTo(48));
      await tester.tap(saved);
      await tester.pumpAndSettle();
      await reveal(find.byType(EarnEmptyState));
      expect(find.text(words['emptySavedTasks']![index]), findsOneWidget);
      expect(find.text(words['emptyTasks']![index]), findsNothing);
      final reset = find.text(words['showAllTasks']![index]);
      await reveal(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(find.byType(EarnEmptyState), findsNothing);
      expect(find.text('https://instagram.com/example'), findsOneWidget);
      final like = find.widgetWithText(ChoiceChip, words['like']![index]);
      await tester.scrollUntilVisible(
        like,
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(like);
      await tester.pumpAndSettle();
      await reveal(find.byType(EarnEmptyState));
      expect(find.text(words['noFilteredTasks']![index]), findsOneWidget);
      await reveal(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(find.byType(EarnEmptyState), findsNothing);
      expect(find.text('https://instagram.com/example'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'profile information and actions remain reachable at large text in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const user = User(
          id: 'sample',
          aud: 'authenticated',
          appMetadata: {},
          userMetadata: {'full_name': 'Alexandra Marie Longname'},
          email: 'alexandra.longname@example.test',
          createdAt: '2026-01-01T00:00:00Z',
        );
        const info = ProfileInfo(
          usernames: ['one'],
          referralCode: 'synthetic',
          referralCount: 2,
          referralJoined: false,
          pinSet: true,
          publicUserId: '12345678',
        );
        var accounts = 0, personal = 0, pin = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            supportedLocales: const [Locale('en'), Locale('ml')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: growthTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: ProfileLayout(
                user: user,
                info: info,
                balance: 2147483647,
                loading: false,
                error: false,
                onRetry: () {},
                onPersonalInfo: () => personal++,
                onAccounts: () => accounts++,
                onReferrals: () {},
                onPin: () => pin++,
                onSignOut: () {},
                onLanguage: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Alexandra Marie Longname'), findsOneWidget);
        expect(find.text('alexandra.longname@example.test'), findsOneWidget);
        expect(find.text('User ID: 12345678'), findsOneWidget);
        final personalInfo = find.text(
          locale == 'en' ? 'Personal information' : 'വ്യക്തിഗത വിവരങ്ങൾ',
        );
        await tester.scrollUntilVisible(
          personalInfo,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(personalInfo);
        expect(personal, 1);
        final account = find.text(
          words['instagramAccounts']![locale == 'ml' ? 1 : 0],
        );
        await tester.scrollUntilVisible(
          account,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(account);
        final pinText = find.text(words['releasePin']![locale == 'ml' ? 1 : 0]);
        await tester.scrollUntilVisible(
          pinText,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(pinText);
        expect(accounts, 1);
        expect(pin, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
