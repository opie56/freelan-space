import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/user_benefits.dart';
import 'package:growth_circle/main.dart';
import 'package:growth_circle/admin_user_benefits.dart';
import 'package:growth_circle/user_features.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient clientFor(
  Future<http.Response> Function(http.Request) handler,
) => SupabaseClient(
  'https://example.test',
  'public-test-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((request) async {
    final response = await handler(request);
    return http.Response.bytes(
      response.bodyBytes,
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }),
);
http.Response jsonResponse(Object? data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  testWidgets('notification categories save choices to the server', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    final client = clientFor((req) async {
      if (req.url.path.endsWith('/user_feature_settings')) {
        return jsonResponse({'notification_controls': true});
      }
      if (req.url.path.endsWith('/user_notification_preferences')) {
        return jsonResponse({
          'task_updates': true,
          'coin_updates': true,
          'referral_updates': true,
        });
      }
      if (req.url.path.endsWith('/set_user_notification_preferences')) {
        requests.add(jsonDecode(req.body) as Map<String, dynamic>);
        return jsonResponse(null);
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NotificationPreferences(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task updates and review reminders'));
    await tester.pumpAndSettle();
    expect(requests.single, {
      'p_task': false,
      'p_coin': true,
      'p_referral': true,
    });
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(
              SwitchListTile,
              'Task updates and review reminders',
            ),
          )
          .value,
      false,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('rejected history can open a linked appeal', (tester) async {
    Map<String, dynamic>? sent;
    final client = clientFor((req) async {
      if (req.url.path.endsWith('/user_feature_settings')) {
        return jsonResponse({'submission_appeals': true});
      }
      if (req.url.path.endsWith('/user_submission_history')) {
        return jsonResponse([
          {
            'submission_id': 'submission-1',
            'action_type': 'like',
            'status': 'rejected',
            'campaign_link': 'example',
            'submitted_at': '2026-11-24',
          },
        ]);
      }
      if (req.url.path.endsWith('/appeal_submission')) {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return jsonResponse('ticket');
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(
      MaterialApp(home: SubmissionHistoryPage(client: client)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appeal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Please review');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(sent, {
      'p_submission': 'submission-1',
      'p_message': 'Please review',
    });
    expect(find.text('Appeal sent. Follow it in Support.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('task search filters and resets results', (tester) async {
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
              },
            ]),
            loadSavedIds: () async => [],
            searchFeatureLoader: () async => true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('https://instagram.com/alpha'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('https://instagram.com/alpha'), findsOneWidget);
    expect(find.text('https://instagram.com/beta'), findsNothing);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      -180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Show all tasks'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Show all tasks'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });
  testWidgets('administrator feature switch saves and reloads', (tester) async {
    var enabled = true;
    final client = clientFor((req) async {
      if (req.url.path.endsWith('/admin_user_feature_settings')) {
        return jsonResponse({'task_search': enabled});
      }
      if (req.url.path.endsWith('/admin_set_user_feature')) {
        final data = jsonDecode(req.body) as Map<String, dynamic>;
        expect(data['p_key'], 'task_search');
        enabled = data['p_enabled'] as bool;
        return jsonResponse(null);
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(
      MaterialApp(home: AdminUserBenefitsPage(client: client, canEdit: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task search and sorting'));
    await tester.pumpAndSettle();
    expect(enabled, false);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Task search and sorting'),
          )
          .value,
      false,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
}
