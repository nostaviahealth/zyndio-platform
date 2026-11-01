// TC-026: reusable fake Supabase REST/auth transport for provider/service
// tests. Routes a plain SupabaseClient (no Supabase.initialize(), no
// platform channels) through package:http's MockClient, so test code can
// assert which tables were actually touched - in particular, that the
// removed `profiles` table is never one of them.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const fakeSupabaseUrl = 'https://example.test';
const fakeSupabaseAnonKey = 'fake-anon-key';

class FakeSupabaseRest {
  final List<http.BaseRequest> requests = [];
  String? _signedInUserId;

  /// Table names touched via the PostgREST (`/rest/v1/<table>`) surface, in
  /// request order. This is the thing every TC-026 "no profiles" test
  /// asserts on.
  List<String> get tableNames => requests
      .where((r) => r.url.path.startsWith('/rest/v1/'))
      .map((r) => r.url.path.substring('/rest/v1/'.length))
      .toList();

  List<http.BaseRequest> requestsFor(String table) =>
      requests.where((r) => r.url.path == '/rest/v1/$table').toList();

  late final MockClient mockClient = MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);

    if (request.url.path == '/auth/v1/token') {
      final userId = _signedInUserId ?? '00000000-0000-0000-0000-000000000000';
      return http.Response(
        json.encode({
          'access_token': _fakeJwt(userId),
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'fake-refresh-token',
          'user': {
            'id': userId,
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'patient@example.test',
            'app_metadata': <String, dynamic>{},
            'user_metadata': <String, dynamic>{},
            'created_at': DateTime.now().toIso8601String(),
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // .maybeSingle()/.single() ask PostgREST for a single object via this
    // Accept header; answering an empty array there throws a parse error in
    // the client, so this needs its own branch (null = "no row found").
    final accept = request.headers['accept'] ?? request.headers['Accept'] ?? '';
    if (accept.contains('vnd.pgrst.object')) {
      return http.Response('null', 200, headers: {'content-type': 'application/json'});
    }
    if (request.method == 'GET') {
      return http.Response('[]', 200, headers: {'content-type': 'application/json'});
    }
    // Matches real PostgREST default behavior for writes with no `.select()`
    // chained after them (none of the TC-026 call sites chain one).
    return http.Response('', 204);
  }

  /// Must be constructed from inside `http.runWithClient(..., () =>
  /// harness.mockClient)` - the Supabase client packages resolve
  /// package:http's zone-scoped client at construction time, not per call.
  SupabaseClient buildClient() => SupabaseClient(fakeSupabaseUrl, fakeSupabaseAnonKey);

  /// Simulates an already-authenticated patient with no real network:
  /// setSession() treats its argument as a refresh token and calls
  /// /auth/v1/token, which _handle answers above with a token for [userId].
  Future<void> signIn(SupabaseClient client, String userId) async {
    _signedInUserId = userId;
    await client.auth.setSession('fake-refresh-token');
  }

  String _fakeJwt(String sub) {
    final header = base64Url.encode(utf8.encode(json.encode({'alg': 'none', 'typ': 'JWT'}))).replaceAll('=', '');
    final payload = base64Url
        .encode(utf8.encode(json.encode({
          'sub': sub,
          'exp': DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
          'role': 'authenticated',
        })))
        .replaceAll('=', '');
    return '$header.$payload.fakesig';
  }
}
