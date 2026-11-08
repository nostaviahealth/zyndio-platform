import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:platform_wearables/src/cloud_service.dart';

// The wearables cloud client must authenticate as the signed-in patient with
// their own session token - never a static app key plus a client-chosen
// x-user-id header (which let anyone holding the key act as any patient).
void main() {
  test('sends the session token and anon key, and no x-user-id', () async {
    late http.Request seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response('{"connections": []}', 200);
    });
    final service = CloudService(
      apiKey: 'public-anon-key',
      accessToken: () async => 'patient-session-jwt',
      baseUrl: 'https://example.test/functions/v1',
      httpClient: client,
    );

    await service.getConnections();

    expect(seen.headers['Authorization'], 'Bearer patient-session-jwt');
    expect(seen.headers['apikey'], 'public-anon-key');
    expect(seen.headers.containsKey('x-user-id'), isFalse);
  });

  test('reads the token on every call, so sign-in after init works', () async {
    var token = 'first';
    final seen = <String?>[];
    final client = MockClient((req) async {
      seen.add(req.headers['Authorization']);
      return http.Response('{"connections": []}', 200);
    });
    final service = CloudService(
      apiKey: 'k',
      accessToken: () async => token,
      baseUrl: 'https://example.test',
      httpClient: client,
    );
    await service.getConnections();
    token = 'second';
    await service.getConnections();
    expect(seen, ['Bearer first', 'Bearer second']);
  });

  test('makes no request at all when nobody is signed in', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return http.Response('{}', 200);
    });
    final service = CloudService(
      apiKey: 'k',
      accessToken: () async => null,
      baseUrl: 'https://example.test',
      httpClient: client,
    );
    await expectLater(service.getConnections(), throwsStateError);
    expect(calls, 0);
  });
}
