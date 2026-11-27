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
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      final entry = find.widgetWithText(ListTile, title);
      await tester.ensureVisible(entry);
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
