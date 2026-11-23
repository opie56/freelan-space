import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/password_recovery.dart';
import 'package:growth_circle/user_saved_login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeRecovery implements PasswordRecoveryClient {
  final calls = <String>[];
  bool failVerify = false;
  @override
  Future<void> send(String email, String? captcha) async =>
      calls.add('send:$email:$captcha');
  @override
  Future<void> verify(String email, String code) async {
    calls.add('verify:$email:$code');
    if (failVerify) throw const AuthException('Invalid');
  }

  @override
  Future<void> update(String password) async => calls.add('update:$password');
  @override
  Future<void> close() async => calls.add('close');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('forgot password verifies OTP before update and shows success', (
    tester,
  ) async {
    final fake = FakeRecovery();
    final saved = UserSavedLogin('https://sample.example');
    await saved.save('person@example.test', 'Old-password-123!');
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          actions: AuthActions(),
          recoveryClient: () => fake,
          captchaProvider: (_) async => 'challenge',
          savedLogin: saved,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('email')),
      'person@example.test',
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(fake.calls, ['send:person@example.test:challenge']);
    expect(find.byKey(const Key('recovery_password')), findsNothing);
    await tester.enterText(find.byKey(const Key('recovery_code')), '12345');
    await tester.tap(find.text('Verify code'));
    await tester.pump();
    expect(fake.calls.length, 1);
    await tester.enterText(find.byKey(const Key('recovery_code')), '123456');
    fake.failVerify = true;
    await tester.tap(find.text('Verify code'));
    await tester.pump();
    expect(find.byKey(const Key('recovery_password')), findsNothing);
    fake.failVerify = false;
    await tester.tap(find.text('Verify code'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('recovery_password')),
      'Synthetic-123A!',
    );
    await tester.enterText(
      find.byKey(const Key('recovery_confirm')),
      'different',
    );
    await tester.ensureVisible(find.text('Update password'));
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('update:')), isEmpty);
    await tester.enterText(
      find.byKey(const Key('recovery_confirm')),
      'Synthetic-123A!',
    );
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(find.text('Password updated'), findsOneWidget);
    expect(await saved.load(), isNull);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(fake.calls.last, 'close');
  });

  testWidgets('resend waits 60 seconds and requests a new challenge', (
    tester,
  ) async {
    final fake = FakeRecovery();
    var challenge = 0;
    var now = DateTime(2026);
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordRecoveryPage(
          createClient: () => fake,
          savedLogin: UserSavedLogin('https://sample.example'),
          initialEmail: 'person@example.test',
          now: () => now,
          captchaProvider: (_) async => 'challenge-${++challenge}',
        ),
      ),
    );
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Resend code (60)'),
          )
          .onPressed,
      isNull,
    );
    now = now.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Resend code'));
    await tester.pump();
    expect(fake.calls, [
      'send:person@example.test:challenge-1',
      'send:person@example.test:challenge-2',
    ]);
    await tester.pumpWidget(const SizedBox());
  });

  for (final locale in ['en', 'ml', 'hi', 'ta', 'ar']) {
    testWidgets('recovery fits $locale on a narrow screen with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fake = FakeRecovery();
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
          home: PasswordRecoveryPage(
            createClient: () => fake,
            savedLogin: UserSavedLogin('https://sample.example'),
            initialEmail: 'person@example.test',
            captchaProvider: (_) async => null,
          ),
        ),
      );
      Future<void> press() async {
        final button = find.byType(FilledButton).last;
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pump();
      }

      await press();
      await tester.enterText(find.byKey(const Key('recovery_code')), '123456');
      await press();
      expect(find.byKey(const Key('recovery_confirm')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
