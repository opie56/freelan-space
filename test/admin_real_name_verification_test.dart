import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/admin_main.dart';
import 'package:growth_circle/admin_real_name_verification.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('admin can inspect both sides and must give a rejection reason', (
    tester,
  ) async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg==';
    Map<String, dynamic>? decision;
    final client = SupabaseClient(
      'https://example.test',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        Object? response;
        if (path.endsWith('admin_real_name_requests')) {
          response = [
            {
              'request_id': 'request-1',
              'submitted_name': 'Taylor Example',
              'current_name': 'Taylor Example',
              'submitted_at': '2026-11-26T10:00:00Z',
            },
          ];
        } else if (path.endsWith('admin_real_name_proofs')) {
          response = {'document_type': 'pan', 'front': png, 'back': png};
        } else if (path.endsWith('admin_decide_real_name')) {
          decision = jsonDecode(request.body) as Map<String, dynamic>;
        }
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AdminRealNameVerificationPage(client: client, canEdit: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Taylor Example'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Taylor Example'));
      await tester.pump();
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Front photo'), findsOneWidget);
    expect(find.text('Back photo'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Reject'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'The reverse is blurred.');
    await tester.pump();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(decision, {
      'p_request_id': 'request-1',
      'p_approve': false,
      'p_reason': 'The reverse is blurred.',
    });
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });

  for (final locale in ['en', 'ml']) {
    testWidgets('desktop opens real name requests ($locale)', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = SupabaseClient(
        'https://example.test',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final dynamic response =
              request.url.path.endsWith('admin_workspace_role')
              ? 'editor'
              : request.url.path.endsWith('admin_real_name_requests')
              ? [
                  {
                    'request_id': 'request-1',
                    'user_id': 'user-1',
                    'email': 'alice@example.test',
                    'submitted_name': 'Alice Example',
                    'current_name': 'Alice Example',
                    'submitted_at': '2026-11-26T10:00:00Z',
                  },
                ]
              : [];
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          supportedLocales: const [Locale('en'), Locale('ml')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: AdminDesktopConsole(
            gateway: SupabaseAdminGateway(client),
            onLogout: () async {},
            onLanguage: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = locale == 'ml'
          ? 'പേര് പരിശോധന അപേക്ഷകൾ'
          : 'Real name requests';
      final entry = find.widgetWithText(ListTile, title);
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
      expect(tester.takeException(), isNull);
      expect(find.byType(AdminRealNameVerificationPage), findsOneWidget);
      expect(find.text('Alice Example'), findsOneWidget);
      expect(find.text(title), findsNWidgets(3)); // Sidebar, header and page.
      await tester.pumpWidget(const SizedBox.shrink());
      client.dispose();
    });
  }
}
