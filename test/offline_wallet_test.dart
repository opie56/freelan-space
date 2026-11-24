import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/navigation_benefits.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('offline snapshot is hidden again when admin disables it', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    var online = true;
    var enabled = true;
    final client = SupabaseClient(
      'https://example.test',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (!online) throw http.ClientException('offline');
        if (request.url.path.endsWith('user_feature_settings')) {
          return http.Response(
            jsonEncode({'offline_view': enabled}),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('wallets')) {
          return http.Response(
            jsonEncode({'balance': 12, 'held_balance': 2}),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('', 404);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineWalletView(
            client: client,
            uid: 'one',
            project: 'project',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Offline wallet snapshot'), findsNothing);
    expect(
      await const FlutterSecureStorage().read(
        key: 'offline_wallet_project_one',
      ),
      isNotNull,
    );
    online = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Offline wallet snapshot'), findsOneWidget);
    expect(find.textContaining('10 coins'), findsOneWidget);
    online = true;
    enabled = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Offline wallet snapshot'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
  });
}
