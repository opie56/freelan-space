import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/engagement_benefits.dart';
import 'package:growth_circle/user_features.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient clientFor(Future<http.Response> Function(http.Request) fn) =>
    SupabaseClient(
      'https://example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final r = await fn(request);
        return http.Response.bytes(
          r.bodyBytes,
          r.statusCode,
          headers: r.headers,
          request: request,
        );
      }),
    );
http.Response jsonResponse(Object? value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);
void main() {
  testWidgets('user saves alert preferences', (tester) async {
    Map? sent;
    final client = clientFor((r) async {
      if (r.url.path.endsWith('user_feature_settings')) {
        return jsonResponse({
          'campaign_progress_alerts': true,
          'low_balance_alerts': true,
        });
      }
      if (r.url.path.endsWith('/user_extra_alerts')) {
        return jsonResponse({'progress': true, 'low_balance': 5});
      }
      if (r.url.path.endsWith('set_user_extra_alerts')) {
        sent = jsonDecode(r.body) as Map;
        return jsonResponse(null);
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExtraAlertSettings(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '8');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(sent, {'p_progress': true, 'p_low': 8});
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('resubmission helper uses selected rejection', (tester) async {
    Map? selected;
    final client = clientFor((r) async {
      if (r.url.path.endsWith('user_feature_settings')) {
        return jsonResponse({
          'submission_appeals': false,
          'resubmit_help': true,
        });
      }
      if (r.url.path.endsWith('user_submission_history')) {
        return jsonResponse([
          {
            'submission_id': 'submission',
            'campaign_id': 'campaign',
            'status': 'rejected',
            'action_type': 'like',
            'campaign_link': 'https://instagram.com/p/A/',
            'submitted_at': '2026-11-24',
            'rejection_reason': 'Screenshot missing',
          },
        ]);
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: SubmissionHistoryPage(
          client: client,
          onResubmit: (_, r) => selected = r,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('How to resubmit'));
    await tester.pumpAndSettle();
    expect(selected?['campaign_id'], 'campaign');
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
}
