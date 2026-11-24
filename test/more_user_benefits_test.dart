import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_user_benefits.dart';
import 'package:growth_circle/more_user_benefits.dart';
import 'package:growth_circle/main.dart' as app;
import 'package:growth_circle/referral_history.dart' show CampaignPlan;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient clientFor(
  Future<http.Response> Function(http.Request) handler,
) => SupabaseClient(
  'https://example.test',
  'public-test-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((req) async {
    final r = await handler(req);
    return http.Response.bytes(
      r.bodyBytes,
      r.statusCode,
      headers: r.headers,
      request: req,
    );
  }),
);
http.Response jsonResult(Object? data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  testWidgets('daily reward and personal goal reach the server', (
    tester,
  ) async {
    bool claimed = false;
    int? target;
    final calls = <String>[];
    final client = clientFor((req) async {
      final name = req.url.pathSegments.last;
      calls.add(name);
      if (name == 'user_feature_settings') {
        return jsonResult({
          'daily_bonus': true,
          'achievement_badges': true,
          'coin_goal': true,
        });
      }
      if (name == 'user_reward_status') {
        return jsonResult({
          'daily_amount': 2,
          'daily_claimed': claimed,
          'approved': 5,
          'badge_5': 0,
          'badge_10': 0,
          'badge_25': 0,
          'claimed_badges': [],
        });
      }
      if (name == 'user_coin_goal') {
        return jsonResult(
          target == null ? null : {'target': target, 'balance': 12},
        );
      }
      if (name == 'claim_daily_bonus') {
        claimed = true;
        return jsonResult(2);
      }
      if (name == 'set_user_coin_goal') {
        target = (jsonDecode(req.body) as Map)['p_target'] as int?;
        return jsonResult(null);
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: RewardsAndGoal(client: client)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claim'));
    await tester.pumpAndSettle();
    expect(find.text('Claimed'), findsOneWidget);
    expect(calls, contains('claim_daily_bonus'));
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(target, 100);
    expect(find.text('12 / 100 coins'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('draft saves and restores its fields', (tester) async {
    Map<String, dynamic>? saved, restored;
    final client = clientFor((req) async {
      switch (req.url.pathSegments.last) {
        case 'user_feature_settings':
          return jsonResult({'campaign_drafts': true});
        case 'save_campaign_draft':
          saved = jsonDecode(req.body) as Map<String, dynamic>;
          return jsonResult('draft');
        case 'user_campaign_drafts':
          return jsonResult([
            {
              'id': 'draft',
              'kind': 'like',
              'username': 'person',
              'link': 'example',
              'task_count': 3,
            },
          ]);
        default:
          return http.Response('', 404);
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampaignDraftControls(
            client: client,
            current: () => {
              'kind': 'like',
              'link': 'example',
              'username': 'person',
              'count': 3,
            },
            restore: (v) => restored = v,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(saved?['p_count'], 3);
    await tester.tap(find.text('Open drafts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('like · person'));
    await tester.pumpAndSettle();
    expect(restored?['task_count'], 3);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('support request includes the selected reference', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    final client = clientFor((req) async {
      if (req.url.pathSegments.last == 'user_feature_settings') {
        return jsonResult({'support_reference': true});
      }
      if (req.url.pathSegments.last == 'support_reference_ticket') {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return jsonResult('ticket');
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportReferenceButton(
            client: client,
            kind: 'transaction',
            id: 'tx',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get help'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Need help');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(sent, {
      'p_kind': 'transaction',
      'p_id': 'tx',
      'p_message': 'Need help',
    });
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('editor changes reward limits', (tester) async {
    Map<String, dynamic>? saved;
    final client = clientFor((req) async {
      if (req.url.pathSegments.last == 'admin_benefit_rewards') {
        return jsonResult({
          'daily_amount': 1,
          'daily_limit': 1000,
          'badge_5': 0,
          'badge_10': 0,
          'badge_25': 0,
        });
      }
      if (req.url.pathSegments.last == 'admin_set_benefit_rewards') {
        saved = jsonDecode(req.body) as Map<String, dynamic>;
        return jsonResult(null);
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BenefitRewardSettings(client: client, canEdit: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '4');
    await tester.ensureVisible(find.text('Save reward settings'));
    await tester.tap(find.text('Save reward settings'));
    await tester.pumpAndSettle();
    expect(saved?['p_daily_amount'], 4);
    expect(saved?['p_daily_limit'], 1000);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  test('statement paginates and escapes spreadsheet formulas', () async {
    final offsets = <int>[];
    final client = clientFor((req) async {
      final args = jsonDecode(req.body) as Map<String, dynamic>;
      final offset = args['p_offset'] as int;
      offsets.add(offset);
      return jsonResult(
        List.generate(
          offset == 0 ? 200 : 1,
          (index) => {
            'created_at': '2026-11-24T00:00:00Z',
            'amount': -2,
            'reason': '=HYPERLINK(1)',
            'reference_id': '123',
          },
        ),
      );
    });
    final rows = await loadWalletStatement(
      client,
      DateTime.utc(2026, 11, 1),
      DateTime.utc(2026, 12, 1),
    );
    expect(rows.length, 201);
    expect(offsets, [0, 200]);
    final csv = walletStatementCsv(rows.take(1).toList());
    expect(csv, contains('"-2"'));
    expect(csv, contains("\"'=HYPERLINK(1)\""));
    client.dispose();
  });
  testWidgets('benefits fit a narrow screen with larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = clientFor((req) async {
      switch (req.url.pathSegments.last) {
        case 'user_feature_settings':
          return jsonResult({
            'daily_bonus': true,
            'achievement_badges': true,
            'coin_goal': true,
          });
        case 'user_reward_status':
          return jsonResult({
            'daily_amount': 2,
            'daily_claimed': false,
            'approved': 5,
            'badge_5': 3,
            'badge_10': 0,
            'badge_25': 0,
            'claimed_badges': [],
          });
        case 'user_coin_goal':
          return jsonResult({'target': 100, 'balance': 12});
        default:
          return http.Response('', 404);
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(children: [RewardsAndGoal(client: client)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('opening a draft restores the campaign form without reserving', (
    tester,
  ) async {
    final client = clientFor((req) async {
      if (req.url.pathSegments.last == 'user_feature_settings') {
        return jsonResult({'campaign_drafts': true});
      }
      if (req.url.pathSegments.last == 'user_campaign_drafts') {
        return jsonResult([
          {
            'id': 'draft',
            'kind': 'like',
            'username': 'person',
            'link': 'https://instagram.com/p/test',
            'task_count': 3,
          },
        ]);
      }
      return http.Response('', 404);
    });
    var reservations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: app.CreateCampaign(
          loadAccounts: () async => ['person'],
          loadRates: () async => [
            {'key': 'follow', 'amount': 1},
            {'key': 'like', 'amount': 1},
          ],
          loadPlan: () async => const CampaignPlan(maxTasks: 8),
          controls: Stream.value([
            {'action_type': 'follow', 'enabled': true},
            {'action_type': 'like', 'enabled': true},
          ]),
          reserve: (_, _, _, _) async {
            reservations++;
          },
          draftsClient: client,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Open drafts'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Open drafts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('like · person'));
    await tester.pumpAndSettle();
    expect(find.text('Like'), findsOneWidget);
    expect(find.text('@person'), findsOneWidget);
    expect(find.text('https://instagram.com/p/test'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(reservations, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
}
