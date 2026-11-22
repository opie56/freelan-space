import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/user_translations.dart';

import 'signup_flow_test.dart' show FakeAuth;

void main() {
  for (final locale in ['en', 'ml', 'hi', 'ta', 'ar']) {
    testWidgets('signup invitation works on a narrow screen in $locale', (
      tester,
    ) async {
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
          home: AuthScreen(actions: FakeAuth()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('email')),
        'new@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('password')),
        'Test-1234-Password',
      );
      final invitation = find.byKey(const Key('auth_signup_invitation'));
      await tester.scrollUntilVisible(
        invitation,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(tester.element(invitation), alignment: .5);
      await tester.pumpAndSettle();
      final explanation = locale == 'ml'
          ? 'Approved tasks വഴി coins നേടി campaigns-ന് ഉപയോഗിക്കൂ.'
          : userTranslations[locale]?['Earn coins from approved tasks and use them for campaigns.'] ??
                'Earn coins from approved tasks and use them for campaigns.';
      expect(find.text(explanation), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(invitation);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('name')), findsOneWidget);
      expect(find.byKey(const Key('auth_signup_invitation')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('email')))
            .controller!
            .text,
        'new@example.test',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('password')))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
