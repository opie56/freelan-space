import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/referral_history.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeProfileGateway
    implements ProfileGateway, ReferralHistoryGateway, CampaignPlanGateway {
  final usernames = <String>['first'];
  int referralCount = 2;
  bool joined = false, signedOut = false, failLoad = false, pinSet = false;
  String? downloadUrl = 'https://updates.example.test/releases/app.apk';
  bool failDownload = false;
  @override
  Future<ProfileInfo> load(String uid) async {
    if (failLoad) throw StateError('offline');
    return ProfileInfo(
      usernames: List.of(usernames),
      referralCode: 'invite-code',
      referralCount: referralCount,
      referralJoined: joined,
      pinSet: pinSet,
    );
  }

  @override
  Future<CampaignPlan> loadCampaignPlan() async =>
      const CampaignPlan(maxTasks: 8);

  @override
  Future<List<ReferralHistoryEntry>> loadReferralHistory(int offset) async => [
    ReferralHistoryEntry.fromRow({
      'direction': 'referred',
      'masked_name': 'A***',
      'masked_email': 'a***@***',
      'created_at': '2026-11-21T00:00:00Z',
    }),
  ];

  @override
  Stream<int?> balance(String uid) => Stream.value(42);
  @override
  Stream<List<Map<String, dynamic>>> history(String uid) => Stream.value([
    {
      'id': 'one',
      'amount': 10,
      'reason': 'welcome',
      'createdAt': '2026-03-01T00:00:00Z',
    },
  ]);
  @override
  Future<void> addAccount(String username) async {
    usernames.add(username.replaceFirst('@', ''));
  }

  @override
  Future<String> searchInstagram(String username) async {
    if (username == 'business') return 'business';
    throw const InstagramLookupException('not_found_or_unsupported');
  }

  @override
  Future<void> removeAccount(String username) async {
    usernames.remove(username);
  }

  @override
  Future<void> applyReferral(String code) async {
    if (code == 'other-code') joined = true;
  }

  @override
  Future<String?> latestAppDownloadUrl() async {
    if (failDownload) throw StateError('offline');
    return downloadUrl;
  }

  @override
  Future<void> sendPinOtp() async {}
  @override
  Future<String> setPin(String pin, String? currentPin) async {
    pinSet = true;
    return 'ok';
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

const user = User(
  id: 'user',
  appMetadata: {},
  userMetadata: {'full_name': 'Diana Larussa'},
  aud: 'authenticated',
  email: 'diana@example.test',
  createdAt: '2026-03-01T00:00:00Z',
);

Future<void> showProfile(
  WidgetTester tester,
  FakeProfileGateway gateway,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: growthTheme(),
      home: Scaffold(
        body: Profile(
          user: user,
          gateway: gateway,
          authorizeChange: () async => true,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('profile opens separate history and campaign limits pages', (
    tester,
  ) async {
    await showProfile(tester, FakeProfileGateway());
    await tester.ensureVisible(
      find.byKey(const Key('profile_referral_banner')),
    );
    await tester.tap(find.byKey(const Key('profile_referral_banner')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Referral History'));
    await tester.pumpAndSettle();
    expect(find.text('A***'), findsOneWidget);
    expect(find.text('a***@***'), findsOneWidget);
    expect(find.text('Used your code'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Campaign Limits'));
    await tester.tap(find.text('Campaign Limits'));
    await tester.pumpAndSettle();
    expect(find.text('1 campaign(s) every 24 hours'), findsOneWidget);
    expect(find.text('3 tasks per campaign'), findsOneWidget);
    expect(find.text('5 extra tasks with a referral'), findsOneWidget);
  });

  testWidgets('campaign limits invite opens the real referral code page', (
    tester,
  ) async {
    final gateway = FakeProfileGateway()..referralCount = 0;
    await showProfile(tester, gateway);
    await tester.ensureVisible(find.text('Campaign Limits'));
    await tester.tap(find.text('Campaign Limits'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('campaign_limits_invite')));
    await tester.tap(find.byKey(const Key('campaign_limits_invite')));
    await tester.pumpAndSettle();
    expect(find.text('invite-code'), findsOneWidget);
    expect(find.text('Share referral code'), findsOneWidget);
  });

  testWidgets('referral share contains the code and app download link', (
    tester,
  ) async {
    String? shared;
    final gateway = FakeProfileGateway();
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: ProfileDetailsPage(
          uid: 'user',
          gateway: gateway,
          accounts: false,
          shareReferral: (text) async => shared = text,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your referral code'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Share referral code'));
    await tester.tap(find.text('Share referral code'));
    await tester.pumpAndSettle();
    expect(shared, contains('Your referral code: invite-code'));
    expect(shared, contains('Download Freelan Space: ${gateway.downloadUrl}'));
    expect(
      shared,
      contains('Join me on Freelan Space! Use my referral code below.'),
    );
    expect(
      shared,
      contains(
        'After signing in, open Profile, choose Referral program, then tap Enter a referral code.',
      ),
    );
  });

  for (final locale in ['hi', 'ta', 'ar', 'ml']) {
    testWidgets(
      'referral invitation includes localized joining steps in $locale',
      (tester) async {
        String? shared;
        final gateway = FakeProfileGateway();
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            supportedLocales: const [
              Locale('en'),
              Locale('hi'),
              Locale('ta'),
              Locale('ar'),
              Locale('ml'),
            ],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: ProfileDetailsPage(
              uid: 'user',
              gateway: gateway,
              accounts: false,
              referralSection: ReferralSection.code,
              shareReferral: (text) async => shared = text,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final share = find.byIcon(Icons.ios_share_rounded).last;
        await tester.ensureVisible(share);
        await tester.tap(share);
        await tester.pumpAndSettle();
        final expectedStep = switch (locale) {
          'hi' => 'साइन इन करने के बाद प्रोफ़ाइल',
          'ta' => 'உள்நுழைந்த பிறகு சுயவிவரத்தைத்',
          'ar' => 'بعد تسجيل الدخول، افتح الملف الشخصي',
          _ => 'Sign in ചെയ്ത ശേഷം Profile',
        };
        expect(shared, contains(expectedStep));
        expect(shared, contains('invite-code'));
        expect(shared, contains(gateway.downloadUrl));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('referral sharing reports an unavailable download link', (
    tester,
  ) async {
    var shares = 0;
    final gateway = FakeProfileGateway()..downloadUrl = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: ProfileDetailsPage(
          uid: 'user',
          gateway: gateway,
          accounts: false,
          shareReferral: (_) async {
            shares++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your referral code'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Share referral code'));
    await tester.tap(find.text('Share referral code'));
    await tester.pump();
    expect(shares, 0);
    expect(
      find.text(words['referralDownloadNotPublished']![0]),
      findsOneWidget,
    );
    gateway.failDownload = true;
    await tester.tap(find.text('Share referral code'));
    await tester.pump();
    expect(shares, 0);
  });

  testWidgets('profile shows real summary and keeps PIN accessible', (
    tester,
  ) async {
    final gateway = FakeProfileGateway();
    await showProfile(tester, gateway);
    expect(find.text('DL'), findsOneWidget);
    expect(find.text('Diana Larussa'), findsOneWidget);
    expect(find.text('diana@example.test'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Coin history'), findsNothing);
    await tester.ensureVisible(find.text('Security PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Security PIN'));
    await tester.pumpAndSettle();
    expect(find.text('New 4-digit PIN'), findsOneWidget);
    await tester.tap(find.text('Send email OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '123456');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.enterText(find.byType(TextField).at(2), '1234');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(gateway.pinSet, isTrue);
    expect(find.text('Change / reset PIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accounts and referral pages preserve existing actions', (
    tester,
  ) async {
    final gateway = FakeProfileGateway();
    await showProfile(tester, gateway);
    await tester.ensureVisible(find.text('Instagram accounts'));
    await tester.tap(find.text('Instagram accounts'));
    await tester.pumpAndSettle();
    expect(find.text('@first'), findsOneWidget);
    await tester.tap(find.text('Add Instagram username manually'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '@second',
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('@second'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    expect(gateway.usernames, ['second']);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_referral_banner')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Your referral code'));
    await tester.pumpAndSettle();
    expect(find.text('invite-code'), findsOneWidget);
    expect(find.text('People referred: 2'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text(words['referralEnter']![0]));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'other-code');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Referral code already applied.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('separate referral entry still requires security confirmation', (
    tester,
  ) async {
    final gateway = FakeProfileGateway();
    var confirmations = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: ProfileDetailsPage(
          uid: 'user',
          gateway: gateway,
          accounts: false,
          authorizeChange: () async {
            confirmations++;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(words['referralEnter']![0]));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'other-code');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(confirmations, 1);
    expect(gateway.joined, isFalse);
    expect(find.text('other-code'), findsOneWidget);
  });

  testWidgets('account menu copies the full username on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final gateway = FakeProfileGateway()
      ..usernames[0] = 'long.username.example';
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        home: ProfileDetailsPage(
          uid: 'user',
          gateway: gateway,
          accounts: true,
          authorizeChange: () async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy username'));
    await tester.pumpAndSettle();
    expect(copied, '@long.username.example');
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile settings sign out and load errors can be retried', (
    tester,
  ) async {
    final gateway = FakeProfileGateway()..failLoad = true;
    await showProfile(tester, gateway);
    await tester.ensureVisible(find.text('Could not load profile details.'));
    gateway.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load profile details.'), findsNothing);
    await tester.tap(find.byTooltip('Profile settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(gateway.signedOut, isTrue);
  });
  testWidgets('profile fits a narrow screen in Malayalam', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: growthTheme(),
        locale: const Locale('ml'),
        supportedLocales: const [Locale('en'), Locale('ml')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.25)),
          child: child!,
        ),
        home: Scaffold(
          body: Profile(user: user, gateway: FakeProfileGateway()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(words['profile']![1]), findsOneWidget);
    await tester.ensureVisible(find.text(words['releasePin']![1]));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'inline Instagram search carries the query and still requires confirmation',
    (tester) async {
      final gateway = FakeProfileGateway();
      await showProfile(tester, gateway);
      await tester.ensureVisible(find.text('Instagram accounts'));
      await tester.tap(find.text('Instagram accounts'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'business');
      await tester.tap(find.byTooltip('Search Instagram username'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, '@business'), findsOneWidget);
      expect(gateway.usernames, ['first']);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(gateway.usernames, ['first']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'in-app lookup adds only a selected real result and preserves manual entry',
    (tester) async {
      final gateway = FakeProfileGateway();
      await showProfile(tester, gateway);
      await tester.ensureVisible(find.text('Instagram accounts'));
      await tester.tap(find.text('Instagram accounts'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search Instagram username'));
      await tester.pumpAndSettle();
      expect(find.text(words['instagramSearchHelp']![0]), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Add account'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'unknown',
      );
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.text(words['instagramSearchNotFound']![0]), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '@business',
      );
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, '@business'), findsOneWidget);
      expect(find.text(words['instagramSearchOwnership']![0]), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'other',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Add account'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'business',
      );
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      expect(gateway.usernames, ['first', 'business']);
      expect(find.text('@business'), findsOneWidget);
      expect(find.text('Add Instagram username manually'), findsOneWidget);
    },
  );
}
