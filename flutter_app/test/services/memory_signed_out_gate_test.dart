// TC-021 item 19: MemoryService must refuse to call embed-memory /
// search-memory without a signed-in session. Previously the Authorization
// header fell back to the anon key (`accessToken ?? anonKey`), so a request
// still left the app with `Bearer <anon key>` when there was no session token.
// package:http is routed through a MockClient; all data is fictional.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zyndio_patient/services/azure_openai_service.dart';
import 'package:zyndio_patient/services/memory_service.dart';

const _fictionalUserId = '00000000-0000-4000-8000-000000000019';
const _fictionalJwt = 'fictional.test.jwt';

void main() {
  late List<http.BaseRequest> sent;
  late MockClient mock;

  setUp(() {
    sent = <http.BaseRequest>[];
    mock = MockClient((request) async {
      sent.add(request);
      return http.Response('{"memories":[]}', 200, headers: {'content-type': 'application/json'});
    });
  });

  String describe(List<http.BaseRequest> rs) =>
      rs.map((r) => '${r.url.path} auth=${r.headers['Authorization']}').toList().toString();

  MemoryService service({String? token}) => MemoryService(
        AzureOpenAIService(),
        accessToken: () => token,
        userId: () => _fictionalUserId,
      );

  test('no session token: storeMemory sends no request and returns false', () async {
    final ok = await http.runWithClient(
      () => service(token: null).storeMemory(content: 'Fictional fact: likes morning walks'),
      () => mock,
    );
    expect(sent, isEmpty, reason: 'no memory call may leave the app without a session; sent: ${describe(sent)}');
    expect(ok, isFalse);
  });

  test('no session token: recallMemories sends no request and returns []', () async {
    final memories = await http.runWithClient(
      () => service(token: null).recallMemories('walks'),
      () => mock,
    );
    expect(sent, isEmpty, reason: 'no memory call may leave the app without a session; sent: ${describe(sent)}');
    expect(memories, isEmpty);
  });

  test('empty session token is treated as no session', () async {
    await http.runWithClient(
      () => service(token: '').recallMemories('walks'),
      () => mock,
    );
    expect(sent, isEmpty, reason: 'sent: ${describe(sent)}');
  });

  test('signed in: requests carry the user JWT, never the anon key', () async {
    await http.runWithClient(() async {
      final s = service(token: _fictionalJwt);
      await s.storeMemory(content: 'Fictional fact: likes morning walks');
      await s.recallMemories('walks');
    }, () => mock);
    expect(sent.map((r) => r.url.path).toList(), ['/functions/v1/embed-memory', '/functions/v1/search-memory']);
    for (final r in sent) {
      expect(r.headers['Authorization'], 'Bearer $_fictionalJwt');
    }
  });
}
