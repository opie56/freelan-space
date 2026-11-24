import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('only valid referral app links are accepted', () {
    pendingReferral.value = null;
    rememberReferral(
      Uri.parse('space.freelan.app://login-callback?code=abcd123'),
    );
    expect(pendingReferral.value, isNull);
    rememberReferral(Uri.parse('https://referral?code=abcd123'));
    expect(pendingReferral.value, isNull);
    rememberReferral(Uri.parse('space.freelan.app://referral?code=abcd123'));
    expect(pendingReferral.value, 'ABCD123');
    rememberReferral(
      Uri.parse('space.freelan.app://referral?code=ABCD123&evil=1'),
    );
    expect(pendingReferral.value, 'ABCD123');
    pendingReferral.value = null;
  });
  testWidgets('filters restore search and hide paused campaigns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskList(
            uid: 'me',
            controlsStream: Stream.value([
              {'action_type': 'like', 'enabled': true},
            ]),
            presenceStream: Stream.value([]),
            claimsStream: Stream.value([]),
            campaignsStream: Stream.value([
              {
                'id': 'a',
                'ownerId': 'other',
                'status': 'active',
                'type': 'like',
                'link': 'https://instagram.com/alpha',
                'reward_per_task': 2,
                'createdAt': '2026-11-23',
              },
              {
                'id': 'b',
                'ownerId': 'other',
                'status': 'active',
                'type': 'like',
                'link': 'https://instagram.com/beta',
                'reward_per_task': 5,
                'createdAt': '2026-11-24',
                'paused': true,
              },
            ]),
            loadSavedIds: () async => [],
            searchFeatureLoader: () async => true,
            filtersFeatureLoader: () async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.ensureVisible(find.text('Save filters'));
    await tester.tap(find.text('Save filters'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'beta');
    await tester.ensureVisible(find.text('Load saved filters'));
    await tester.tap(find.text('Load saved filters'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'alpha',
    );
    await tester.ensureVisible(find.text('https://instagram.com/alpha'));
    expect(find.text('https://instagram.com/beta'), findsNothing);
  });
}
