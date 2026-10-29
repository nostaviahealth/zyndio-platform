// TC-021 item 11: the patient app must never call the `intelligence` Edge
// Function before sign-in. Previously the Authorization header fell back to
// the anon key (`accessToken ?? SupabaseConfig.anonKey`), so a signed-out
// app still sent requests. These tests route package:http through a
// MockClient and assert that, with no session, NO request leaves the app.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zyndio_patient/services/azure_openai_service.dart';

void main() {
  late List<http.BaseRequest> sent;
  late MockClient mock;

  setUp(() {
    sent = <http.BaseRequest>[];
    mock = MockClient((request) async {
      sent.add(request);
      return http.Response('{"choices":[{"message":{"content":"hi"}}]}', 200,
          headers: {'content-type': 'application/json'});
    });
  });

  test('signed out: callAzureAPI sends no request to intelligence', () async {
    final result = await http.runWithClient(
      () => AzureOpenAIService().callAzureAPI([
        {'role': 'user', 'content': 'hello'}
      ]),
      () => mock,
    );
    expect(sent, isEmpty, reason: 'no intelligence call may be made before sign-in; sent: ${sent.map((r) => '${r.url} auth=${r.headers['Authorization']}').toList()}');
    expect(result, isNull);
  });

  test('signed out: getChatResponse sends no request to intelligence', () async {
    await http.runWithClient(
      () => AzureOpenAIService().getChatResponse([
        {'role': 'user', 'content': 'hello'}
      ]),
      () => mock,
    );
    expect(sent, isEmpty, reason: 'no intelligence call may be made before sign-in; sent: ${sent.map((r) => '${r.url} auth=${r.headers['Authorization']}').toList()}');
  });

  test('signed out: the streaming chat sends no request to intelligence', () async {
    await http.runWithClient(
      () => AzureOpenAIService().getChatResponseStream([
        {'role': 'user', 'content': 'hello'}
      ]).toList(),
      () => mock,
    );
    expect(sent, isEmpty, reason: 'no intelligence call may be made before sign-in; sent: ${sent.map((r) => '${r.url} auth=${r.headers['Authorization']}').toList()}');
  });
}
