import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/navigation_benefits.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'coupon shows credit animation only for a successful redemption',
    (tester) async {
      var successful = false;
      final client = SupabaseClient(
        'https://example.test',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final data = request.url.path.endsWith('user_feature_settings')
              ? {'bonus_coupons': true}
              : successful
              ? {'status': 'ok', 'amount': 7}
              : {'status': 'unavailable'};
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CouponEntry(client: client)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'TEST');
      await tester.tap(find.text('Redeem'));
      await tester.pumpAndSettle();
      expect(find.text('Coins credited!'), findsNothing);
      expect(
        find.text('Code unavailable, used or limit reached.'),
        findsOneWidget,
      );
      successful = true;
      await tester.tap(find.text('Redeem'));
      await tester.pumpAndSettle();
      expect(find.text('+7'), findsOneWidget);
      expect(find.text('Coins credited!'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      client.dispose();
    },
  );
}
