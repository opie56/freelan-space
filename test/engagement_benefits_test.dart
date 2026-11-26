import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/engagement_benefits.dart';
import 'package:growth_circle/main.dart' show CreateCampaign;
import 'package:growth_circle/referral_history.dart' show CampaignPlan;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient clientFor(Future<http.Response> Function(http.Request) fn) =>
    SupabaseClient(
      'https://example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final response = await fn(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
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
  testWidgets('challenge claims and monthly insights display', (tester) async {
    var claimed = false;
    final client = clientFor((r) async {
      if (r.url.path.endsWith('user_feature_settings')) {
        return jsonResponse({
          'weekly_challenges': true,
          'monthly_coin_insights': true,
        });
      }
      if (r.url.path.endsWith('weekly_challenge_status')) {
        return jsonResponse({
          'completed': 5,
          'target': 5,
          'reward': 3,
          'claimed': claimed,
        });
      }
      if (r.url.path.endsWith('monthly_coin_insights')) {
        return jsonResponse({'task': 2, 'referral': 4, 'bonus': 3});
      }
      if (r.url.path.endsWith('claim_weekly_challenge')) {
        claimed = true;
        return jsonResponse(3);
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EngagementOverview(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Tasks: 2'), findsOneWidget);
    await tester.tap(find.text('Claim'));
    await tester.pumpAndSettle();
    expect(find.text('Coins credited!'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Claimed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('admin managed help respects disabled feature', (tester) async {
    final client = clientFor((r) async => jsonResponse([]));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UserHelpArticles(client: client)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('copied campaign obeys the current task cap', (tester) async {
    var reservations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CreateCampaign(
          initialType: 'like',
          copySource: {
            'link': 'https://instagram.com/p/TEST/',
            'requested': 5,
            'instagram_username': 'example',
          },
          loadAccounts: () async => ['example'],
          loadPlan: () async => const CampaignPlan(maxTasks: 3),
          loadRates: () async => [
            {'key': 'like', 'amount': 2},
          ],
          controls: Stream.value([
            {'action_type': 'like', 'enabled': true},
          ]),
          reserve: (_, _, _, _) async {
            reservations++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('https://instagram.com/p/TEST/'), findsOneWidget);
    final submit = find.widgetWithText(FilledButton, 'Create campaign');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Allowed task count: 1–3'), findsOneWidget);
    expect(reservations, 0);
  });
}
