// TC-039 (TC-034 item 46) / APP-05: the lab-report SUBMIT (analysis) and DELETE paths print
// nothing - no backend / AI-proxy error text, stack trace or file name in
// device logs - and the user sees a fixed error message instead of the
// exception's text. TC-034 item 45: "no-log" here means NOTHING is printed,
// not just two known phrases.
//
// Real repository / service / provider; the network is package:http's
// MockClient. Fictional data only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zyndio_patient/config/supabase_config.dart';
import 'package:zyndio_patient/data/health_data_repository.dart';
import 'package:zyndio_patient/providers/lab_analysis_provider.dart';
import 'package:zyndio_patient/services/azure_openai_service.dart';

const _patientId = '00000000-0000-0000-0000-0000000a1001';
const _reportId = '00000000-0000-0000-0000-0000000a3101';
const _errorText =
    'fictional upstream failure: relation "internal_secret" does not exist';

/// Every request fails with a body carrying [_errorText].
class _FailingBackend {
  final requests = <http.Request>[];
  late final MockClient mock = MockClient((r) async {
    requests.add(r);
    return http.Response(
      json.encode(
          {'error': _errorText, 'message': _errorText, 'code': '42501'}),
      r.url.path.startsWith('/functions/') ? 500 : 403,
      headers: {'content-type': 'application/json'},
      request: r,
    );
  });
}

/// Captures print() and debugPrint() while [body] runs.
Future<T> _capture<T>(
    List<String> sink, _FailingBackend b, Future<T> Function() body) {
  final previous = debugPrint;
  debugPrint = (String? m, {int? wrapWidth}) => sink.add(m ?? '');
  return runZoned(
    () => http.runWithClient(() async {
      SupabaseConfig.debugClientOverride =
          SupabaseClient('https://example.test', 'fake-anon-key');
      return body();
    }, () => b.mock),
    zoneSpecification:
        ZoneSpecification(print: (self, parent, zone, line) => sink.add(line)),
  ).whenComplete(() => debugPrint = previous);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late File image;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tc039-');
    image = File('${tmp.path}/Fictional Person CBC.png')
      ..writeAsBytesSync([0x89, 0x50, 0x4e, 0x47]);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    SupabaseConfig.debugClientOverride = null;
    tmp.deleteSync(recursive: true);
  });

  group('analysis path prints nothing (TC-039 / TC-034 #46)', () {
    test(
        'AI proxy error: nothing printed, backend text not copied into the error',
        () async {
      final b = _FailingBackend();
      final printed = <String>[];
      Object? error;
      await _capture(printed, b, () async {
        try {
          await AzureOpenAIService(accessToken: () => 'fictional-access-token')
              .extractBiomarkers([image]);
        } catch (e) {
          error = e;
        }
      });
      expect(b.requests, hasLength(1));
      expect(error, isNotNull);
      expect(error.toString(), isNot(contains('internal_secret')));
      expect(printed, isEmpty, reason: printed.join('\n'));
    });

    // APP-05: the on-device extraction (analyzeLabReport /
    // analyzeLabReportWithProgress) was removed - reports are read on the
    // server now. The same guarantee holds for the path that replaced them.
    test('submitLabReport: every request fails -> fixed error, nothing printed',
        () async {
      final b = _FailingBackend();
      final printed = <String>[];
      Object? error;
      await _capture(printed, b, () async {
        try {
          await HealthDataRepository.submitLabReport(
            filePath: image.path,
            fileName: 'Fictional Person CBC.png',
            profileId: _patientId,
          );
        } catch (e) {
          error = e;
        }
      });
      expect(error, isA<StateError>());
      expect(error.toString(), isNot(contains('internal_secret')));
      expect(printed, isEmpty, reason: printed.join('\n'));
    });

    test(
        'LabAnalysis provider: error state with a fixed message, nothing printed',
        () async {
      final b = _FailingBackend();
      final printed = <String>[];
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await _capture(printed, b, () async {
        container.read(labAnalysisProvider);
        await container.read(labAnalysisProvider.notifier).startAnalysis(
              filePath: image.path,
              fileName: 'Fictional Person CBC.png',
              profileId: _patientId,
            );
      });
      final state = container.read(labAnalysisProvider);
      expect(state.status, LabAnalysisStatus.error);
      expect(state.errorMessage, labAnalysisFailedMessage);
      expect(printed, isEmpty, reason: printed.join('\n'));
    });
  });

  group('delete path prints nothing (TC-039 / TC-034 #46)', () {
    test('a refused delete returns false and prints nothing', () async {
      final b = _FailingBackend();
      final printed = <String>[];
      final ok = await _capture(
          printed,
          b,
          () => HealthDataRepository.deleteLabReport(_reportId, _patientId,
              '$_patientId/36a00000-0000-4000-8000-000000000001.pdf'));
      expect(ok, isFalse);
      expect(b.requests.single.method, 'DELETE');
      expect(printed, isEmpty, reason: printed.join('\n'));
    });
  });
}
