import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/main.dart'
    show NotificationsPage, ClaimSubmissionDialog, ClaimProof;
import 'package:growth_circle/screenshot_editor.dart';
import 'package:growth_circle/task_clarity.dart';
import 'package:growth_circle/user_features.dart' show SubmissionHistoryPage;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient fake(Future<http.Response> Function(http.Request) handler) =>
    SupabaseClient(
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
http.Response jsonResponse(Object? o) => http.Response(
  jsonEncode(o),
  200,
  headers: {'content-type': 'application/json'},
);
Future<Uint8List> synthetic() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 80, 40),
    Paint()..color = Colors.white,
  );
  for (var x = 40; x < 80; x += 4) {
    canvas.drawRect(
      Rect.fromLTWH(x.toDouble(), 0, 2, 40),
      Paint()..color = Colors.black,
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(80, 40);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('crop and blackout are baked into PNG pixels', (tester) async {
    await tester.runAsync(() async {
      final original = await synthetic();
      final output = await renderEditedScreenshot(
        original,
        const Rect.fromLTWH(0, 0, .5, 1),
        [const ScreenshotMask(Rect.fromLTWH(0, 0, .25, 1), blackout: true)],
      );
      final codec = await ui.instantiateImageCodec(output);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 40);
      expect(image.height, 40);
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      int red(int x, int y) => pixels[(y * image.width + x) * 4];
      expect(red(5, 10), 0);
      expect(red(30, 10), 255);
      image.dispose();
      codec.dispose();
    });
  });
  testWidgets('blur changes selected region and keeps outside intact', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final original = await synthetic();
      final output = await renderEditedScreenshot(
        original,
        const Rect.fromLTWH(0, 0, 1, 1),
        [const ScreenshotMask(Rect.fromLTWH(.5, 0, .5, 1))],
      );
      final codec = await ui.instantiateImageCodec(output);
      final image = (await codec.getNextFrame()).image;
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      int red(int x, int y) => pixels[(y * image.width + x) * 4];
      expect(red(10, 20), 255);
      expect(red(60, 20), greaterThan(10));
      expect(red(60, 20), lessThan(245));
      image.dispose();
      codec.dispose();
    });
  });
  testWidgets('notification filters show selected kinds', (tester) async {
    final data = [
      {
        'id': '1',
        'kind': 'approved',
        'read_at': null,
        'created_at': '2026-11-24T00:00:00Z',
      },
      {
        'id': '2',
        'kind': 'coins_received',
        'amount': 4,
        'read_at': '2026-11-24T00:00:00Z',
        'created_at': '2026-11-24T00:00:00Z',
      },
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsPage(
          stream: Stream.value(data),
          markRead: (_) async {},
          filterFeatureLoader: () async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coins'));
    await tester.pumpAndSettle();
    expect(find.textContaining('+4'), findsOneWidget);
    expect(find.text('Submission approved'), findsNothing);
  });
  testWidgets('preferred categories are saved explicitly', (tester) async {
    Map? sent;
    final c = fake((r) async {
      if (r.url.path.endsWith('/user_feature_settings')) {
        return jsonResponse({'preferred_task_alerts': true});
      }
      if (r.url.path.endsWith('/user_preferred_tasks')) return jsonResponse([]);
      if (r.url.path.endsWith('/set_preferred_tasks')) {
        sent = jsonDecode(r.body) as Map;
        return jsonResponse(null);
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PreferredTasksSettings(client: c)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('like'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(sent?['p_categories'], ['like']);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
  testWidgets('screenshot edit control respects administrator flag', (
    tester,
  ) async {
    final image = await tester.runAsync(synthetic);
    var allowed = false;
    final client = fake(
      (r) async => jsonResponse({'screenshot_editing': allowed}),
    );
    Future<void> mount(Key key) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClaimSubmissionDialog(
              key: key,
              featureClient: client,
              picker: () async => ClaimProof(image!, 'image/png'),
              onSubmit: (_, _) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await tester.pumpAndSettle();
    }

    await mount(const Key('disabled'));
    expect(find.text('Crop or blur'), findsNothing);
    allowed = true;
    await mount(const Key('enabled'));
    expect(find.text('Crop or blur'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('private note is saved for the selected task', (tester) async {
    Map? sent;
    var noteReads = 0;
    final client = fake((r) async {
      if (r.url.path.endsWith('/user_feature_settings')) {
        return jsonResponse({'saved_task_notes': true});
      }
      if (r.url.path.endsWith('/user_saved_task_note')) {
        noteReads++;
        return jsonResponse(null);
      }
      if (r.url.path.endsWith('/set_saved_task_note')) {
        sent = jsonDecode(r.body) as Map;
        return jsonResponse(null);
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedTaskNote(client: client, campaignId: 'campaign'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(noteReads, 0);
    await tester.tap(find.text('Task note'));
    await tester.pumpAndSettle();
    expect(noteReads, 1);
    await tester.enterText(find.byType(TextField), 'my private note');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(sent, {'p_campaign': 'campaign', 'p_note': 'my private note'});
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('reports and spending show only returned values', (tester) async {
    final client = fake((r) async {
      if (r.url.path.endsWith('/user_feature_settings')) {
        return jsonResponse({
          'report_tracking': true,
          'spending_insights': true,
        });
      }
      if (r.url.path.endsWith('/user_campaign_reports')) {
        return jsonResponse([
          {
            'id': 'report-1',
            'campaign_link': 'https://instagram.com/p/REPORT/',
            'status': 'resolved',
            'created_at': '2026-11-24',
          },
        ]);
      }
      if (r.url.path.endsWith('/monthly_spending_insights')) {
        return jsonResponse({
          'campaign': 7,
          'transfer': 3,
          'other': 2,
          'refund': 1,
        });
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              UserReportTracking(client: client),
              MonthlySpending(client: client),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Campaign reservations: 7'), findsOneWidget);
    await tester.tap(find.text('My campaign reports'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Resolved'), findsOneWidget);
    expect(
      find.textContaining('https://instagram.com/p/REPORT/'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
  testWidgets('pending history shows waiting time when enabled', (
    tester,
  ) async {
    final client = fake((r) async {
      if (r.url.path.endsWith('/user_feature_settings')) {
        return jsonResponse({
          'submission_waiting': true,
          'submission_appeals': false,
          'resubmit_help': false,
        });
      }
      if (r.url.path.endsWith('/user_submission_history')) {
        return jsonResponse([
          {
            'submission_id': 'submission',
            'campaign_id': 'campaign',
            'status': 'pending',
            'action_type': 'like',
            'campaign_link': 'https://instagram.com/p/A/',
            'submitted_at': DateTime.now()
                .toUtc()
                .subtract(const Duration(minutes: 62))
                .toIso8601String(),
            'rejection_reason': null,
          },
        ]);
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(
      MaterialApp(home: SubmissionHistoryPage(client: client)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Waiting: 1h 2m'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
}
