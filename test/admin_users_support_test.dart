import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_users_support.dart';
import 'package:growth_circle/admin_main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('inbox polling waits for a slow request to finish', (
    tester,
  ) async {
    final response = Completer<void>();
    var loads = 0;
    final client = (await tester.runAsync(
      () async => SupabaseClient(
        'https://example.test',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          loads++;
          await response.future;
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    ))!;
    await tester.pumpWidget(
      MaterialApp(home: AdminUsersSupportPage(client: client, canEdit: true)),
    );
    await tester.pump(const Duration(seconds: 31));
    final concurrentLoads = loads;
    response.complete();
    await tester.pumpAndSettle();
    expect(concurrentLoads, 1);
    expect(find.text('No support chats yet.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(client.dispose);
  });

  testWidgets('desktop menu opens Users Supports', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = SupabaseClient(
      'https://example.test',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          request.url.path.endsWith('admin_workspace_role') ? '"editor"' : '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AdminDesktopConsole(
          gateway: SupabaseAdminGateway(client),
          onLogout: () async {},
          onLanguage: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.widgetWithText(ListTile, 'Users Supports');
    await tester.scrollUntilVisible(
      entry,
      100,
      scrollable: find.descendant(
        of: find.byKey(const Key('admin_sidebar')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(AdminUsersSupportPage), findsOneWidget);
    expect(find.text('Campaign reports'), findsNothing);
    expect(find.text('Admin operations'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

  for (final canEdit in [true, false]) {
    testWidgets('support inbox opens user conversation (editor: $canEdit)', (
      tester,
    ) async {
      final calls = <(String, dynamic)>[];
      final client = SupabaseClient(
        'https://example.test',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          calls.add((
            request.url.path,
            request.body.isEmpty ? null : jsonDecode(request.body),
          ));
          final response = request.url.path.endsWith('admin_support_tickets')
              ? [
                  {
                    'id': 'ticket',
                    'subject': 'Help with wallet',
                    'email': 'member@example.test',
                    'status': 'open',
                  },
                ]
              : request.url.path.endsWith('support_messages')
              ? [
                  {
                    'body': 'Please help',
                    'is_admin': false,
                    'created_at': '2026-11-19T00:00:00Z',
                  },
                ]
              : null;
          return http.Response(
            jsonEncode(response),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AdminUsersSupportPage(client: client, canEdit: canEdit),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Users Supports'), findsOneWidget);
      expect(find.text('Campaign reports'), findsNothing);
      expect(find.text('member@example.test · open'), findsOneWidget);
      await tester.tap(find.text('Help with wallet'));
      await tester.pumpAndSettle();
      expect(find.text('Please help'), findsOneWidget);
      expect(find.text('User'), findsOneWidget);
      if (canEdit) {
        await tester.enterText(find.byType(TextField), 'We can help');
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();
        final reply = calls
            .singleWhere((call) => call.$1.endsWith('/support_reply'))
            .$2;
        expect(reply, {'p_ticket': 'ticket', 'p_body': 'We can help'});
      } else {
        expect(find.text('View only'), findsOneWidget);
        expect(find.text('Send'), findsNothing);
        expect(find.textContaining('This chat is closed'), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      client.dispose();
    });
  }

  testWidgets('support inbox refreshes and editors can close a chat', (
    tester,
  ) async {
    var loads = 0;
    final calls = <String>[];
    final client = SupabaseClient(
      'https://example.test',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        calls.add(request.url.path);
        if (request.url.path.endsWith('admin_support_tickets')) loads++;
        return http.Response(
          request.url.path.endsWith('admin_support_tickets')
              ? jsonEncode([
                  {
                    'id': 'ticket',
                    'subject': 'Help',
                    'email': 'member@example.test',
                    'status': 'open',
                  },
                ])
              : 'null',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: AdminUsersSupportPage(client: client, canEdit: true)),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(loads, greaterThanOrEqualTo(2));
    await tester.tap(find.byTooltip('Close chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close chat'));
    await tester.pumpAndSettle();
    expect(
      calls.where((path) => path.endsWith('/admin_close_ticket')).length,
      1,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
}
