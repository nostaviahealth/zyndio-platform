import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/lab_report.dart';
import 'lab_submission.dart';

class HealthDataRepository {
  
  /// TC-037: the patient's own lab reports, newest first, from the real
  /// lab_reports columns (supabase/migrations/*_tc005_schema.sql and
  /// *_tc015_schema.sql). The patient's identity key is their auth user id,
  /// which is what RLS checks (lab_reports_self_select: patient_id =
  /// auth.uid(), email confirmed, active record link). Identity-held reports
  /// (possibly not this patient's) are left out, matching the server's
  /// latest-results rule. The exact request is pinned by
  /// tests/contracts/patient-lab-reports-query.json.
  static const labReportsSelect = 'id,report_type,data,created_at,pdf_path';

  /// Errors are NOT caught here: a failed query must reach the caller so
  /// Biomarkers shows its error state (an empty list means "no results yet").
  /// Nothing is printed, so no backend error text ends up in device logs.
  static Future<List<LabReport>> fetchReports(String? patientId) async {
      if (patientId == null) return [];
      final client = SupabaseConfig.client;
      if (client == null) {
          throw StateError('Supabase is not initialized');
      }
      final rows = await client
          .from('lab_reports')
          .select(labReportsSelect)
          .eq('patient_id', patientId)
          .eq('identity_hold', false)
          .order('created_at', ascending: false);
      return rows.map(labReportFromRow).toList();
  }

  /// Maps one real lab_reports row onto the app's LabReport: the report body
  /// (title, markers, summary, ...) lives in the `data` jsonb payload; the id,
  /// report type, file path (TC-036: the `pdf_path` column only - anything
  /// URL-like left in the payload is ignored) and (when the payload has no
  /// date of its own) the date come from the row's columns.
  static LabReport labReportFromRow(Map<String, dynamic> row) {
      final data = row['data'];
      final payload = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      return LabReport.fromJson({
          ...payload,
          'id': row['id'],
          'date': payload['date'] is String ? payload['date'] : row['created_at'],
          'reportType': payload['reportType'] ?? row['report_type'],
          'pdf_path': row['pdf_path'],
      });
  }

  /// APP-05: the patient app's ONE lab path. Files the report, then has the
  /// server read it (Edge Function analyze-lab-report: AI extractor behind a
  /// flag, reviewed LOINC table, US units, plausibility, confidence,
  /// identity check). Nothing is extracted on the device any more.
  ///
  ///  1. SHA-256 of the file. If this patient already filed the same file,
  ///     nothing is uploaded: [LabSubmissionOutcome.duplicate] - unless that
  ///     report was never read (still `pending`, e.g. the app was killed
  ///     after filing), in which case it goes straight to step 3.
  ///  2. Upload into the private bucket and insert the lab_reports row with
  ///     `file_sha256` (unique per patient, so a race is still refused).
  ///  3. Ask analyze-lab-report to read it. Whatever it answers, the report
  ///     stays filed; the outcome says what the patient is told.
  ///
  /// Pinned by tests/contracts/patient-lab-report-submit.json. Throws a
  /// [StateError] with a fixed message when the report could not be filed;
  /// nothing is printed (no backend text in device logs).
  static Future<LabSubmission> submitLabReport({
    required String filePath,
    required String fileName,
    required String profileId,
    void Function()? onUploaded,
  }) async {
    final client = SupabaseConfig.client;
    if (client == null) throw StateError('lab report not filed');
    final file = File(filePath);
    if (!await file.exists()) throw StateError('lab report not filed');
    final String hash;
    try {
      hash = await fileSha256(file);
    } catch (_) {
      throw StateError('lab report not filed');
    }

    final List<Map<String, dynamic>> existing;
    final String orgId;
    final String objectPath;
    try {
      existing = await client
          .from('lab_reports')
          .select('id,extraction_status')
          .eq('patient_id', profileId)
          .eq('file_sha256', hash);
      if (existing.isEmpty) {
        orgId = await _ownOrgId(client, profileId);
        objectPath = newLabReportObjectPath(profileId, fileName);
        await client.storage.from(labReportsBucket).upload(
              objectPath,
              file,
              fileOptions: const FileOptions(upsert: false),
            );
      } else {
        orgId = '';
        objectPath = '';
      }
    } catch (_) {
      // Fixed text only: the backend's message never leaves this method.
      throw StateError('lab report not filed');
    }
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as String;
      if (existing.first['extraction_status'] == 'pending') {
        onUploaded?.call();
        return _analyze(client, id);
      }
      return LabSubmission(outcome: LabSubmissionOutcome.duplicate, reportId: id);
    }

    String reportId;
    try {
      final rows = await client.from('lab_reports').insert({
        'org_id': orgId,
        'patient_id': profileId,
        'report_type': 'patient_upload',
        // The user's file name is not stored (it can carry personal
        // details); the server fills in date / lab name once read.
        'data': {
          'title': 'Lab report',
          'date': _localDate(),
          'summary': 'Uploaded from mobile app.',
          'markers': const [],
        },
        'pdf_path': objectPath,
        'file_sha256': hash,
      }).select('id');
      reportId = rows.single['id'] as String;
    } catch (e) {
      try {
        await client.storage.from(labReportsBucket).remove([objectPath]);
      } catch (_) {}
      if (e is PostgrestException && e.code == '23505') {
        return const LabSubmission(outcome: LabSubmissionOutcome.duplicate);
      }
      throw StateError('lab report not filed');
    }

    try {
      await client.from('patient_accounts').upsert({
        'patient_id': profileId,
        'stage': 'lab_processing',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'patient_id');
    } catch (_) {}

    onUploaded?.call();
    return _analyze(client, reportId);
  }

  /// Asks the server to read a filed report. Never throws: the report is
  /// filed whatever happens here.
  static Future<LabSubmission> _analyze(SupabaseClient client, String reportId) async {
    try {
      final res = await client.functions
          .invoke(analyzeLabReportFunction, body: {'report_id': reportId});
      return LabSubmission.fromAnalyzeResponse(reportId, res.status, res.data);
    } on FunctionException catch (e) {
      return LabSubmission.fromAnalyzeResponse(reportId, e.status, e.details);
    } catch (_) {
      return LabSubmission(
          outcome: LabSubmissionOutcome.analysisFailed, reportId: reportId);
    }
  }

  static const analyzeLabReportFunction = 'analyze-lab-report';

  /// Lower-case hex SHA-256 of [file] (the lab_reports.file_sha256 dedupe key).
  static Future<String> fileSha256(File file) async =>
      sha256.convert(await file.readAsBytes()).toString();

  /// TC-036: private storage bucket for patient-uploaded report files.
  static const labReportsBucket = 'lab-reports';

  /// The patient's clinic. lab_reports_self_insert only accepts a row whose
  /// org_id is the patient's own (from public.patients, which the patient
  /// can read for themself). Pinned by
  /// tests/contracts/patient-lab-report-writes.json (org_lookup).
  static Future<String> _ownOrgId(SupabaseClient client, String patientId) async {
    final rows = await client.from('patients').select('org_id').eq('id', patientId);
    if (rows.isEmpty || rows.first['org_id'] is! String) {
      throw StateError('No linked patient record');
    }
    return rows.first['org_id'] as String;
  }

  /// Object path for a new upload: `<patient_id>/<random uuid>.<ext>`. The
  /// user's file name is never used (it can carry personal details, and the
  /// storage policy only accepts uuid names, so files are never overwritten).
  static String newLabReportObjectPath(String patientId, String fileName) {
    final dot = fileName.lastIndexOf('.');
    var ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    if (ext == 'jpeg') ext = 'jpg';
    const allowed = {'pdf', 'jpg', 'png', 'heic', 'webp'};
    if (!allowed.contains(ext)) {
      throw ArgumentError.value(fileName, 'fileName', 'unsupported lab report file type');
    }
    return '$patientId/${_uuidV4()}.$ext';
  }

  static String _uuidV4() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Uploads a lab report file into the private lab-reports bucket and files
  /// it as a lab_reports row (real columns; the report body lives in `data`,
  /// the file is referenced by its object PATH, never by a URL). Pinned by
  /// tests/contracts/patient-lab-report-writes.json (upload_insert).
  ///
  /// [profileId] is the signed-in patient's auth user id (= patient_id).
  /// Returns false on any failure; nothing is printed (no backend error text
  /// in device logs).
  static Future<bool> uploadLabReport({
    required String filePath,
    required String fileName,
    required String profileId,
    Map<String, dynamic>? extractedData,
  }) async {
    try {
      final client = SupabaseConfig.client;
      if (client == null) return false;
      final file = File(filePath);
      if (!await file.exists()) return false;

      final orgId = await _ownOrgId(client, profileId);
      final objectPath = newLabReportObjectPath(profileId, fileName);

      await client.storage.from(labReportsBucket).upload(
            objectPath,
            file,
            fileOptions: const FileOptions(upsert: false),
          );

      try {
        await client.from('lab_reports').insert({
          'org_id': orgId,
          'patient_id': profileId,
          'report_type': 'patient_upload',
          'data': {
            'title': extractedData?['title'] ?? fileName,
            'date': extractedData?['date'] ?? _localDate(),
            'summary': extractedData?['summary'] ?? 'Uploaded from mobile app.',
            'markers': extractedData?['markers'] ?? const [],
          },
          'pdf_path': objectPath,
        });
      } catch (_) {
        // Not filed: remove the upload so no orphan is left in the bucket.
        // (The storage policy lets a patient delete only their own objects
        // that no lab_reports row points at.)
        try {
          await client.storage.from(labReportsBucket).remove([objectPath]);
        } catch (_) {}
        return false;
      }

      // Best-effort: move the patient's journey stage on.
      try {
        await client.from('patient_accounts').upsert({
          'patient_id': profileId,
          'stage': 'lab_processing',
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'patient_id');
      } catch (_) {}

      return true;
    } catch (_) {
      return false;
    }
  }

  static String _localDate() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// TC-036: how long a link to a report file stays valid. The link is made
  /// when the patient taps to open the report and is used straight away; a
  /// signed link can't be revoked and works for whoever holds it, so it
  /// should outlive that single open by as little as possible. 5 minutes
  /// covers a slow connection / PDF viewer hand-off (TC-036 cap: 10).
  static const labReportLinkLifetime = Duration(minutes: 5);

  static final _objectPathPattern = RegExp(r'^[0-9a-f-]{36}/[A-Za-z0-9_][A-Za-z0-9._-]*$');

  /// A short-lived signed link to a lab report's file, made only when the
  /// report is opened. [pdfPath] is the report's `pdf_path`. Storage checks
  /// the caller's access (storage.objects RLS) before signing. Returns null
  /// when the path isn't a bare object path or storage refuses. The link is
  /// never stored or logged.
  static Future<String?> signedLabReportUrl(String pdfPath) async {
    if (!_objectPathPattern.hasMatch(pdfPath) || pdfPath.contains('..')) return null;
    try {
      final client = SupabaseConfig.client;
      if (client == null) return null;
      return await client.storage
          .from(labReportsBucket)
          .createSignedUrl(pdfPath, labReportLinkLifetime.inSeconds);
    } catch (_) {
      return null;
    }
  }

  /// Deletes a lab report row. Note: lab_reports are immutable from the
  /// patient side (no patient DELETE policy), so for a patient session this
  /// returns false; the report's file stays (it is still referenced).
  /// Nothing is printed.
  static Future<bool> deleteLabReport(String reportId, String profileId, String? pdfPath) async {
      try {
          final client = SupabaseConfig.client;
          if (client == null) return false;
          final response = await client.from('lab_reports').delete().eq('id', reportId).select('id');
          return response.isNotEmpty;
      } catch (_) {
          return false;
      }
  }

  /// Files a manually entered biomarker value as a new one-marker
  /// `manual_entry` lab report (real columns, pinned by
  /// tests/contracts/patient-lab-report-writes.json manual_entry_insert).
  ///
  /// Patients can INSERT lab_reports but never UPDATE or DELETE them (RLS:
  /// reports are immutable from the patient side), so a correction is a new
  /// entry; the latest value wins in the patient's views. Returns false on
  /// any failure; nothing is printed.
  static Future<bool> saveManualBiomarker({
    required String profileId,
    required String markerName,
    required String value,
    required String unit,
  }) async {
    try {
      final client = SupabaseConfig.client;
      if (client == null) return false;
      final orgId = await _ownOrgId(client, profileId);
      await client.from('lab_reports').insert({
        'org_id': orgId,
        'patient_id': profileId,
        'report_type': 'manual_entry',
        'data': {
          'title': 'Manual Entry',
          'date': _localDate(),
          'summary': 'Entered by the patient.',
          'markers': [
            {
              'name': markerName,
              'value': '$value $unit',
              'range': '--',
              'status': 'Normal',
              'insight': 'Manually entered.',
            }
          ],
        },
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
