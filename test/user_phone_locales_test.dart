import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/coin_purchase.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/support_page.dart';
import 'package:growth_circle/user_features.dart';
import 'package:growth_circle/user_translations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'coin_purchase_test.dart' show FakePurchases;
import 'profile_layout_test.dart' show FakeProfileGateway, user;
import 'signup_flow_test.dart' show FakeAuth;

const _locales = [
  Locale('en'),
  Locale('hi'),
  Locale('ta'),
  Locale('ar'),
  Locale('ml'),
];
String translated(String lang, String en, String ml) =>
    lang == 'ml' ? ml : userTranslations[lang]?[en] ?? en;

const phoneScale = bool.fromEnvironment('PHONE_SCALE_LARGE') ? 2.0 : 1.4;

Widget screen(String locale, Widget page, {double scale = phoneScale}) =>
    MaterialApp(
      theme: growthTheme(),
      locale: Locale(locale),
      supportedLocales: _locales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    );

void main() {
  for (final locale in ['en', 'hi', 'ta', 'ar', 'ml']) {
    testWidgets(
      'phone login, signup and OTP screen fit and retain values in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final actions = FakeAuth();
        await tester.pumpWidget(
          screen(
            locale,
            AuthScreen(actions: actions, captchaProvider: (_) async => null),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('email')), findsOneWidget);
        final signup = switch (locale) {
          'hi' => 'नए हैं? खाता बनाएँ',
          'ta' => 'புதியவரா? கணக்கை உருவாக்கு',
          'ar' => 'مستخدم جديد؟ أنشئ حساباً',
          'ml' => words['noAccount']![1],
          _ => words['noAccount']![0],
        };
        await tester.ensureVisible(find.text(signup));
        await tester.tap(find.text(signup));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('signup_referral_hint')), findsOneWidget);
        expect(
          find.text(
            translated(
              locale,
              'After signing in, open Profile, choose Referral program, then tap Enter a referral code.',
              'Sign in ചെയ്ത ശേഷം Profile തുറന്ന് Referral പദ്ധതി തിരഞ്ഞെടുക്കുക. തുടർന്ന് Referral കോഡ് നൽകുക എന്നതിൽ code നൽകുക.',
            ),
          ),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('email')),
          'person@example.test',
        );
        await tester.enterText(
          find.byKey(const Key('password')),
          'Synthetic-123A',
        );
        await tester.enterText(find.byKey(const Key('name')), 'Sample Name');
        final button = switch (locale) {
          'hi' => 'खाता बनाएँ',
          'ta' => 'கணக்கை உருவாக்கு',
          'ar' => 'إنشاء حساب',
          'ml' => words['register']![1],
          _ => words['register']![0],
        };
        await tester.ensureVisible(find.widgetWithText(FilledButton, button));
        await tester.tap(find.widgetWithText(FilledButton, button));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('otp')), findsOneWidget);
        expect(actions.submittedName, 'Sample Name');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('phone home and task cards remain reachable in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      language.value = Locale(locale);
      addTearDown(() => language.value = const Locale('en'));
      await tester.pumpWidget(
        screen(
          locale,
          Scaffold(
            body: Dashboard(
              uid: 'synthetic',
              onBrowse: () {},
              balanceStream: Stream.value([
                {
                  'id': 'synthetic',
                  'balance': 120,
                  'held_balance': 20,
                  'is_active': true,
                  'wallet_number': '1234567890',
                },
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(translated(locale, 'Wallet', 'വാലറ്റ്')),
        findsOneWidget,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        screen(
          locale,
          Scaffold(
            body: TaskList(
              uid: 'synthetic',
              controlsStream: Stream.value([
                {'action_type': 'follow', 'enabled': true},
              ]),
              presenceStream: Stream.value([]),
              claimsStream: Stream.value([]),
              campaignsStream: Stream.value([
                {
                  'id': 'c',
                  'ownerId': 'other',
                  'status': 'active',
                  'type': 'follow',
                  'link': 'https://instagram.com/example',
                  'reward_per_task': 3,
                },
              ]),
              loadSavedIds: () async => [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('https://instagram.com/example'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('https://instagram.com/example'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'phone profile, settings, support, help and coin purchase fit in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          screen(
            locale,
            Scaffold(
              body: Profile(
                user: user,
                gateway: FakeProfileGateway(),
                authorizeChange: () async => true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Diana Larussa'), findsOneWidget);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          screen(
            locale,
            UserSettingsPage(
              enabledLoader: () async => false,
              authorizeChange: () async => true,
              pushUpdater: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Larger text can place this control below the initial viewport.
        await tester.scrollUntilVisible(
          find.byType(Switch),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(Switch), findsOneWidget);
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(DropdownButton<String>),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(DropdownButton<String>), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          screen(
            locale,
            CoinPurchasePage(
              source: FakePurchases(),
              loadRates: () async => {
                'like': 1,
                'follow': 1,
                'comment': 1,
                'share': 1,
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('₹49'),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('₹49'), findsOneWidget);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final client = SupabaseClient(
          'https://example.invalid',
          'synthetic-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        await tester.pumpWidget(
          screen(
            locale,
            SupportPage(client: client, loadTickets: () async => []),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(translated(locale, 'Support', 'സഹായം')), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(screen(locale, const UserHelpPage()));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        unawaited(client.dispose());
      },
    );
  }
}
