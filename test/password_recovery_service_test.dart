import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:growth_circle/password_recovery.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('isolated Auth client sends recovery OTP and uses verified session for update', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final calls = <Map<String, dynamic>>[];
    final user = {
      'id': '11111111-1111-4111-8111-111111111111',
      'aud': 'authenticated',
      'email': 'person@example.test',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {},
    };
    final subscription = server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      calls.add({
        'path': request.uri.path,
        'authorization': request.headers.value('authorization'),
        'body': body.isEmpty ? {} : jsonDecode(body),
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(switch (request.uri.path) {
          '/verify' => {
            'access_token': 'synthetic-token',
            'refresh_token': 'synthetic-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': user,
          },
          '/user' => user,
          _ => <String, dynamic>{},
        }),
      );
      await request.response.close();
    });
    final client = GoTrueClient(
      url: 'http://127.0.0.1:${server.port}',
      autoRefreshToken: false,
      flowType: AuthFlowType.implicit,
    );
    final gateway = PasswordRecoveryClient(
      client,
      'space.freelan.app://login-callback/',
    );
    try {
      await gateway.send('person@example.test', 'challenge');
      await gateway.verify('person@example.test', '123456');
      await gateway.update('Synthetic-123A!');
      expect(calls.map((c) => c['path']).take(3), [
        '/recover',
        '/verify',
        '/user',
      ]);
      expect(
        calls[0]['body']['gotrue_meta_security']['captcha_token'],
        'challenge',
      );
      expect(calls[1]['body']['type'], 'recovery');
      expect(calls[1]['body']['token'], '123456');
      expect(calls[2]['authorization'], 'Bearer synthetic-token');
      expect(calls[2]['body']['password'], 'Synthetic-123A!');
    } finally {
      await gateway.close();
      await server.close(force: true);
      await subscription.cancel();
    }
  });
}
