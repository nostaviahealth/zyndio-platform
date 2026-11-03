import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/lab_report.dart';
import '../services/azure_openai_service.dart';
import '../services/pdf_to_image_service.dart';

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

  /// Analyze a lab report with CHUNKED processing for large PDFs.
  /// Medical-grade: Uses the new lab-faithful extraction pipeline.
  static Future<Map<String, dynamic>?> analyzeLabReport({
    required String filePath,
    required String fileName,
    required String profileId,
    Function(String)? onProgress,
    int chunkSize = 2,
  }) async {
    try {
      // Delegate to the new medical-grade pipeline
      return await analyzeLabReportWithProgress(
        filePath: filePath,
        fileName: fileName,
        profileId: profileId,
        chunkSize: chunkSize,
        onPdfProgress: (current, total) => onProgress?.call('Converting page $current of $total...'),
        onChunkProgress: (chunk, total, label) => onProgress?.call(label),
        onFinalizing: () => onProgress?.call('Finalizing report...'),
      );
    } catch (e, stackTrace) {
      print('HealthDataRepository: Analysis Error: $e');
      print('Stack Trace: $stackTrace');
      return null;
    }
  }

  /// Analyze a lab report with granular typed callbacks for each stage.
  /// Medical-grade: Extracts data exactly as the lab reported it — no preset
  /// biomarker database, no overridden ranges, no assumed categories.
  /// 
  /// Architecture: 2-page chunks × parallel batches of 3 with auto-retry.
  /// Each chunk stays small enough to avoid Supabase Edge Function timeouts
  /// while parallelism ensures maximum throughput.
  static Future<Map<String, dynamic>?> analyzeLabReportWithProgress({
    required String filePath,
    required String fileName,
    required String profileId,
    void Function(int current, int total)? onPdfProgress,
    void Function(int chunk, int total, String label)? onChunkProgress,
    void Function()? onFinalizing,
    int chunkSize = 2,
  }) async {
    try {
      final azureService = AzureOpenAIService();
      final List<File> images = [];

      // 1. PDF → Images
      if (filePath.toLowerCase().endsWith('.pdf')) {
        images.addAll(await PdfToImageService.convertPdfToImages(
          filePath,
          onProgress: (current, total) => onPdfProgress?.call(current, total),
        ));
      } else {
        images.add(File(filePath));
      }

      if (images.isEmpty) throw Exception('No images to analyze.');

      // 2. Build chunks (2 pages each — small enough to avoid Supabase timeout)
      final int totalPages = images.length;
      final int totalChunks = (totalPages / chunkSize).ceil();

      // Accumulate markers across all chunks, preserving categories
      final List<Map<String, dynamic>> allMarkers = [];
      String? reportTitle;
      String? reportDate;
      String? labName;

      // Build all chunk image lists upfront
      final List<List<File>> chunkImageLists = [];
      for (int chunkIdx = 0; chunkIdx < totalChunks; chunkIdx++) {
        final int start = chunkIdx * chunkSize;
        final int end = (start + chunkSize).clamp(0, totalPages);
        chunkImageLists.add(images.sublist(start, end));
      }

      // 3. Process chunks in parallel batches of 3 (concurrency limit)
      //    Each chunk = 2 pages → small payload → no Supabase timeout
      //    3 concurrent requests → fast throughput
      const int maxConcurrent = 3;
      final List<Map<String, dynamic>?> allResults = List.filled(totalChunks, null);
      int completedCount = 0;

      for (int batchStart = 0; batchStart < totalChunks; batchStart += maxConcurrent) {
        final int batchEnd = (batchStart + maxConcurrent).clamp(0, totalChunks);
        final batchIndices = List.generate(batchEnd - batchStart, (i) => batchStart + i);

        onChunkProgress?.call(
          completedCount + 1,
          totalChunks,
          'Analyzing pages ${batchStart * chunkSize + 1}–${(batchEnd * chunkSize).clamp(0, totalPages)} of $totalPages...',
        );

        // Fire batch in parallel — each chunk gets auto-retry on failure
        final batchFutures = batchIndices.map((idx) => _extractWithRetry(
          azureService,
          chunkImageLists[idx],
          chunkIndex: idx,
          totalChunks: totalChunks,
        ));

        final batchResults = await Future.wait(batchFutures);

        for (int i = 0; i < batchResults.length; i++) {
          allResults[batchIndices[i]] = batchResults[i];
          completedCount++;
        }
      }

      // 4. Merge results from all chunks (in order)
      for (int i = 0; i < allResults.length; i++) {
        final rawResults = allResults[i];
        if (rawResults == null || rawResults.isEmpty) {
          debugPrint('HealthDataRepository: Chunk ${i + 1} returned no data — skipping');
          continue;
        }

        // Capture metadata from first chunk that has it
        if (reportTitle == null && rawResults['title'] != null && rawResults['title'].toString().isNotEmpty) {
          reportTitle = rawResults['title'].toString();
        }
        if (reportDate == null && rawResults['date'] != null && rawResults['date'].toString().isNotEmpty) {
          reportDate = rawResults['date'].toString();
        }
        if (labName == null && rawResults['labName'] != null && rawResults['labName'].toString().isNotEmpty) {
          labName = rawResults['labName'].toString();
        }

        // Process categories
        final categories = rawResults['categories'] as List<dynamic>?;
        if (categories != null) {
          for (final cat in categories) {
            final categoryName = cat['name']?.toString() ?? 'General';
            final markers = cat['markers'] as List<dynamic>?;
            if (markers != null) {
              for (final marker in markers) {
                final name = marker['name']?.toString() ?? '';
                final value = marker['value']?.toString() ?? '--';
                final unit = marker['unit']?.toString() ?? '';
                final refRange = marker['referenceRange']?.toString() ?? '--';
                final status = marker['status']?.toString() ?? 'Normal';

                if (name.isEmpty) continue;

                allMarkers.add({
                  'name': name,
                  'value': value,
                  'unit': unit,
                  'range': refRange,
                  'status': status,
                  'category': categoryName,
                  'lab_name': labName,
                  'insight': '',
                });
              }
            }
          }
        }

        // Resiliency: Handle flat 'markers' key if AI ignores categories
        final flatMarkers = rawResults['markers'] as List<dynamic>?;
        if (flatMarkers != null) {
          for (final m in flatMarkers) {
            final name = m['name']?.toString() ?? '';
            if (name.isEmpty) continue;
            
            // Only add if not already added via categories in this same chunk
            if (!allMarkers.any((existing) => existing['name'].toString().toLowerCase() == name.toLowerCase())) {
              allMarkers.add({
                'name': name,
                'value': m['value']?.toString() ?? '--',
                'unit': m['unit']?.toString() ?? '',
                'range': m['referenceRange']?.toString() ?? '--',
                'status': m['status']?.toString() ?? 'Normal',
                'category': 'General',
                'lab_name': labName,
                'insight': '',
              });
            }
          }
        }

        // Resiliency: Handle flat 'additionalParameters'
        if (rawResults['additionalParameters'] != null) {
          for (var param in rawResults['additionalParameters']) {
            final name = param['name']?.toString() ?? '';
            if (name.isEmpty) continue;
            if (!allMarkers.any((existing) => existing['name'].toString().toLowerCase() == name.toLowerCase())) {
              allMarkers.add({
                'name': name,
                'value': param['value']?.toString() ?? '--',
                'unit': param['unit']?.toString() ?? '',
                'range': param['referenceRange']?.toString() ?? '--',
                'status': 'Normal',
                'category': 'Other Tests',
                'lab_name': labName,
                'insight': '',
              });
            }
          }
        }
      }

      if (allMarkers.isEmpty) {
        throw Exception('Analysis returned no biomarkers. The report might be unreadable or blank. Pages analyzed: $totalPages');
      }

      // 3. Deduplicate & finalize — keep first occurrence of each biomarker
      onFinalizing?.call();
      final Map<String, Map<String, dynamic>> deduped = {};
      for (final marker in allMarkers) {
        final key = (marker['name'] as String).toLowerCase().trim();
        if (!deduped.containsKey(key)) deduped[key] = marker;
      }
      final dedupedMarkers = deduped.values.toList();

      return {
        'title': reportTitle ?? fileName,
        'date': reportDate ?? DateTime.now().toIso8601String().split('T')[0],
        'lab_name': labName,
        'markers': dedupedMarkers,
        'summary': 'Lab Report Analyzed. ${dedupedMarkers.length} test results extracted across $totalPages pages.',
      };
    } catch (e, stackTrace) {
      debugPrint('HealthDataRepository: WithProgress Error: $e\n$stackTrace');
      rethrow; // Re-throw so the provider can catch and display the actual error
    }
  }

  /// Extracts biomarkers from a chunk of images with automatic retry.
  /// Returns null on total failure (both attempts) instead of throwing,
  /// so partial results from other chunks can still be used.
  static Future<Map<String, dynamic>?> _extractWithRetry(
    AzureOpenAIService azureService,
    List<File> chunkImages, {
    required int chunkIndex,
    required int totalChunks,
    int maxAttempts = 2,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final result = await azureService.extractBiomarkers(chunkImages);
        debugPrint('HealthDataRepository: Chunk ${chunkIndex + 1}/$totalChunks succeeded on attempt $attempt');
        return result;
      } catch (e) {
        debugPrint('HealthDataRepository: Chunk ${chunkIndex + 1}/$totalChunks attempt $attempt failed: $e');
        if (attempt < maxAttempts) {
          // Wait before retry — exponential backoff
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
    }
    // Both attempts failed — return null so other chunks can still contribute
    debugPrint('HealthDataRepository: Chunk ${chunkIndex + 1}/$totalChunks FAILED after $maxAttempts attempts');
    return null;
  }

  /// Process, analyze, and upload a lab report (Legacy/Direct wrapper)
  static Future<bool> analyzeAndUploadLabReport({
    required String filePath,
    required String fileName,
    required String profileId,
    Function(String)? onProgress,
  }) async {
      final extractedData = await analyzeLabReport(
          filePath: filePath, 
          fileName: fileName, 
          profileId: profileId, 
          onProgress: onProgress
      );
      
      if (extractedData == null) return false;

      // 4. Upload and Save to Supabase
      onProgress?.call('Uploading to secure health vault...');
      return await uploadLabReport(
        filePath: filePath,
        fileName: fileName,
        profileId: profileId,
        extractedData: extractedData,
      );
  }

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
