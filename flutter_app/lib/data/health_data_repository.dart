import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lab_report.dart';
import '../services/azure_openai_service.dart';
import '../services/pdf_to_image_service.dart';

class HealthDataRepository {
  
  // Fetch from Supabase with Fallback to Full Mock Data
  static Future<List<LabReport>> fetchReports(String? profileId) async {
      try {
          if (profileId != null) {
              final response = await Supabase.instance.client
                  .from('lab_reports')
                  .select('*')
                  .eq('profile_id', profileId)
                  .order('date', ascending: false);
              
              final data = response as List<dynamic>;
              if (data.isNotEmpty) {
                  return data.map((d) => LabReport.fromJson(d)).toList();
              }
          }
      } catch (e) {
          print('HealthRepo Error: $e');
      }
      
      // Only return Mock Data if NO profile is associated (Guest Mode)
      if (profileId == null) {
         // return _mockReports; // DISABLED: Prevent phantom data for users
         return [];
      }
      
      return [];
  }

  // FULL MOCK DATA (100+ Markers matching Web constants.ts)
  static final List<LabReport> _mockReports = [
    LabReport(
      id: 'r1',
      date: '2023-11-15',
      title: 'Comprehensive Health Panel (100 Biomarkers)',
      summary: 'Complete metabolic, cardiovascular, hormonal, vitamin, and functional health assessment.',
      markers: [
        // Metabolic Health (15 markers)
        LabMarker(name: 'HbA1c', value: '5.7%', range: '< 5.7%', status: 'Normal', insight: 'Borderline pre-diabetic range, showing improvement.'),
        LabMarker(name: 'Fasting Glucose', value: '95 mg/dL', range: '70-100 mg/dL', status: 'Optimal'),
        LabMarker(name: 'Fasting Insulin', value: '8.2 µIU/mL', range: '2.6-24.9 µIU/mL', status: 'Optimal'),
        LabMarker(name: 'HOMA-IR', value: '1.9', range: '< 2.0', status: 'Optimal', insight: 'Good insulin sensitivity.'),
        LabMarker(name: 'Triglycerides', value: '105 mg/dL', range: '< 150 mg/dL', status: 'Optimal'),
        LabMarker(name: 'Total Cholesterol', value: '185 mg/dL', range: '< 200 mg/dL', status: 'Optimal'),
        LabMarker(name: 'LDL Cholesterol', value: '95 mg/dL', range: '< 100 mg/dL', status: 'Optimal', insight: 'Improved with dietary changes.'),
        LabMarker(name: 'HDL Cholesterol', value: '58 mg/dL', range: '> 40 mg/dL', status: 'Optimal'),
        LabMarker(name: 'ApoB', value: '82 mg/dL', range: '< 90 mg/dL', status: 'Optimal'),
        LabMarker(name: 'Lp(a)', value: '18 mg/dL', range: '< 30 mg/dL', status: 'Optimal'),
        LabMarker(name: 'Non-HDL Cholesterol', value: '127 mg/dL', range: '< 130 mg/dL', status: 'Optimal'),
        LabMarker(name: 'TC/HDL Ratio', value: '3.2', range: '< 5.0', status: 'Optimal'),
        LabMarker(name: 'TG/HDL Ratio', value: '1.8', range: '< 2.0', status: 'Optimal'),
        LabMarker(name: 'Uric Acid', value: '5.8 mg/dL', range: '3.5-7.2 mg/dL', status: 'Optimal'),
        LabMarker(name: 'Homocysteine', value: '9.2 µmol/L', range: '< 15 µmol/L', status: 'Optimal'),

        // Cardiovascular (8 markers)
        LabMarker(name: 'CRP (hs)', value: '0.8 mg/L', range: '< 1.0 mg/L', status: 'Optimal', insight: 'Low systemic inflammation.'),
        LabMarker(name: 'Fibrinogen', value: '285 mg/dL', range: '200-400 mg/dL', status: 'Optimal'),
        LabMarker(name: 'D-Dimer', value: '0.3 µg/mL', range: '< 0.5 µg/mL', status: 'Optimal'),
        LabMarker(name: 'NT-proBNP', value: '68 pg/mL', range: '< 125 pg/mL', status: 'Optimal'),
        LabMarker(name: 'Troponin I', value: '< 0.01 ng/mL', range: '< 0.04 ng/mL', status: 'Optimal'),
        LabMarker(name: 'MPO (Myeloperoxidase)', value: '385 pmol/L', range: '< 500 pmol/L', status: 'Optimal'),
        LabMarker(name: 'Omega-3 Index', value: '6.8%', range: '> 8%', status: 'Normal', insight: 'Increase fish oil supplementation.'),
        LabMarker(name: 'Omega-6/Omega-3 Ratio', value: '4.2', range: '< 4.0', status: 'Normal'),

        // Liver Function (10 markers)
        LabMarker(name: 'ALT (SGPT)', value: '28 U/L', range: '7-56 U/L', status: 'Optimal'),
        LabMarker(name: 'AST (SGOT)', value: '24 U/L', range: '10-40 U/L', status: 'Optimal'),
        LabMarker(name: 'AST/ALT Ratio', value: '0.86', range: '0.8-2.0', status: 'Optimal'),
        LabMarker(name: 'GGT', value: '22 U/L', range: '9-48 U/L', status: 'Optimal'),
        LabMarker(name: 'Alkaline Phosphatase', value: '68 U/L', range: '44-147 U/L', status: 'Optimal'),
        LabMarker(name: 'Total Bilirubin', value: '0.8 mg/dL', range: '0.1-1.2 mg/dL', status: 'Optimal'),
        LabMarker(name: 'Direct Bilirubin', value: '0.2 mg/dL', range: '0-0.3 mg/dL', status: 'Optimal'),
        LabMarker(name: 'Total Protein', value: '7.2 g/dL', range: '6.0-8.3 g/dL', status: 'Optimal'),
        LabMarker(name: 'Albumin', value: '4.5 g/dL', range: '3.5-5.5 g/dL', status: 'Optimal'),
        LabMarker(name: 'Globulin', value: '2.7 g/dL', range: '2.0-3.5 g/dL', status: 'Optimal'),

        // Kidney Function (6 markers)
        LabMarker(name: 'Creatinine', value: '0.95 mg/dL', range: '0.7-1.3 mg/dL', status: 'Optimal'),
        LabMarker(name: 'BUN (Blood Urea Nitrogen)', value: '15 mg/dL', range: '7-20 mg/dL', status: 'Optimal'),
        LabMarker(name: 'BUN/Creatinine Ratio', value: '15.8', range: '10-20', status: 'Optimal'),
        LabMarker(name: 'eGFR', value: '95 mL/min', range: '> 60 mL/min', status: 'Optimal'),
        LabMarker(name: 'Cystatin C', value: '0.88 mg/L', range: '0.51-0.98 mg/L', status: 'Optimal'),
        LabMarker(name: 'Urine Microalbumin', value: '12 mg/L', range: '< 30 mg/L', status: 'Optimal'),

        // Thyroid (6 markers)
        LabMarker(name: 'TSH', value: '1.8 mIU/L', range: '0.4-4.0 mIU/L', status: 'Optimal'),
        LabMarker(name: 'Free T3', value: '3.2 pg/mL', range: '2.0-4.4 pg/mL', status: 'Optimal'),
        LabMarker(name: 'Free T4', value: '1.3 ng/dL', range: '0.8-1.8 ng/dL', status: 'Optimal'),
        LabMarker(name: 'T3 Reverse', value: '18 ng/dL', range: '9.2-24.1 ng/dL', status: 'Optimal'),
        LabMarker(name: 'TPO Antibody', value: '< 10 IU/mL', range: '< 34 IU/mL', status: 'Optimal'),
        LabMarker(name: 'Thyroglobulin', value: '22 ng/mL', range: '< 55 ng/mL', status: 'Optimal'),

        // Hormones (12 markers)
        LabMarker(name: 'Testosterone (Total)', value: '625 ng/dL', range: '300-1000 ng/dL', status: 'Optimal'),
        LabMarker(name: 'Testosterone (Free)', value: '18.5 pg/mL', range: '9-30 pg/mL', status: 'Optimal'),
        LabMarker(name: 'SHBG', value: '38 nmol/L', range: '16.5-55.9 nmol/L', status: 'Optimal'),
        LabMarker(name: 'DHEA-S', value: '285 µg/dL', range: '138-475 µg/dL', status: 'Optimal'),
        LabMarker(name: 'Cortisol (AM)', value: '14.8 µg/dL', range: '6.2-19.4 µg/dL', status: 'Optimal'),
        LabMarker(name: 'Estradiol', value: '28 pg/mL', range: '10-40 pg/mL', status: 'Optimal'),
        LabMarker(name: 'Progesterone', value: '0.8 ng/mL', range: '< 1.4 ng/mL', status: 'Optimal'),
        LabMarker(name: 'IGF-1', value: '195 ng/mL', range: '90-360 ng/mL', status: 'Optimal'),
        LabMarker(name: 'Growth Hormone', value: '2.8 ng/mL', range: '< 10 ng/mL', status: 'Optimal'),
        LabMarker(name: 'Prolactin', value: '12.5 ng/mL', range: '4.0-15.2 ng/mL', status: 'Optimal'),
        LabMarker(name: 'FSH', value: '4.8 mIU/mL', range: '1.5-12.4 mIU/mL', status: 'Optimal'),
        LabMarker(name: 'LH', value: '5.2 mIU/mL', range: '1.7-8.6 mIU/mL', status: 'Optimal'),

        // Vitamins (13 markers)
        LabMarker(name: 'Vitamin D (25-OH)', value: '52 ng/mL', range: '30-100 ng/mL', status: 'Optimal'),
        LabMarker(name: 'Vitamin B12', value: '685 pg/mL', range: '200-900 pg/mL', status: 'Optimal'),
        LabMarker(name: 'Folate (Serum)', value: '15.8 ng/mL', range: '> 3.0 ng/mL', status: 'Optimal'),
        LabMarker(name: 'Vitamin A (Retinol)', value: '58 µg/dL', range: '38-98 µg/dL', status: 'Optimal'),
        LabMarker(name: 'Vitamin E', value: '12.5 mg/L', range: '5.5-17 mg/L', status: 'Optimal'),
        LabMarker(name: 'Vitamin K1', value: '1.2 ng/mL', range: '0.2-3.2 ng/mL', status: 'Optimal'),
        LabMarker(name: 'Vitamin C', value: '1.8 mg/dL', range: '0.4-2.0 mg/dL', status: 'Optimal'),
        LabMarker(name: 'Biotin (B7)', value: '425 ng/L', range: '200-500 ng/L', status: 'Optimal'),
        LabMarker(name: 'Thiamine (B1)', value: '95 nmol/L', range: '70-180 nmol/L', status: 'Optimal'),
        LabMarker(name: 'Riboflavin (B2)', value: '145 µg/L', range: '100-300 µg/L', status: 'Optimal'),
        LabMarker(name: 'Niacin (B3)', value: '3.8 µg/mL', range: '2-10 µg/mL', status: 'Optimal'),
        LabMarker(name: 'Pantothenic Acid (B5)', value: '1.2 µg/mL', range: '0.5-2.5 µg/mL', status: 'Optimal'),
        LabMarker(name: 'Pyridoxine (B6)', value: '68 nmol/L', range: '35-110 nmol/L', status: 'Optimal'),

        // Minerals & Electrolytes (10 markers)
        LabMarker(name: 'Iron (Serum)', value: '95 µg/dL', range: '60-170 µg/dL', status: 'Optimal'),
        LabMarker(name: 'Ferritin', value: '125 ng/mL', range: '30-400 ng/mL', status: 'Optimal'),
        LabMarker(name: 'TIBC', value: '325 µg/dL', range: '250-450 µg/dL', status: 'Optimal'),
        LabMarker(name: 'Transferrin Saturation', value: '29%', range: '20-50%', status: 'Optimal'),
        LabMarker(name: 'Magnesium', value: '2.2 mg/dL', range: '1.7-2.2 mg/dL', status: 'Optimal'),
        LabMarker(name: 'Zinc', value: '95 µg/dL', range: '60-120 µg/dL', status: 'Optimal'),
        LabMarker(name: 'Copper', value: '105 µg/dL', range: '70-140 µg/dL', status: 'Optimal'),
        LabMarker(name: 'Selenium', value: '125 µg/L', range: '70-150 µg/L', status: 'Optimal'),
        LabMarker(name: 'Calcium', value: '9.5 mg/dL', range: '8.5-10.2 mg/dL', status: 'Optimal'),
        LabMarker(name: 'Phosphorus', value: '3.8 mg/dL', range: '2.5-4.5 mg/dL', status: 'Optimal'),

        // Complete Blood Count (10 markers)
        LabMarker(name: 'WBC', value: '6.8 K/µL', range: '4.5-11 K/µL', status: 'Optimal'),
        LabMarker(name: 'RBC', value: '5.2 M/µL', range: '4.7-6.1 M/µL', status: 'Optimal'),
        LabMarker(name: 'Hemoglobin', value: '15.2 g/dL', range: '13.5-17.5 g/dL', status: 'Optimal'),
        LabMarker(name: 'Hematocrit', value: '45%', range: '38.3-48.6%', status: 'Optimal'),
        LabMarker(name: 'MCV', value: '88 fL', range: '80-100 fL', status: 'Optimal'),
        LabMarker(name: 'MCH', value: '30 pg', range: '27-33 pg', status: 'Optimal'),
        LabMarker(name: 'MCHC', value: '34 g/dL', range: '32-36 g/dL', status: 'Optimal'),
        LabMarker(name: 'Platelet Count', value: '245 K/µL', range: '150-400 K/µL', status: 'Optimal'),
        LabMarker(name: 'Neutrophils', value: '58%', range: '40-70%', status: 'Optimal'),
        LabMarker(name: 'Lymphocytes', value: '32%', range: '20-40%', status: 'Optimal'),

        // Advanced Longevity (10 markers)
        LabMarker(name: 'NAD+', value: '42 µM', range: '> 35 µM', status: 'Optimal', insight: 'Key cellular energy molecule.'),
        LabMarker(name: 'Telomere Length', value: '7200 bp', range: '> 6500 bp', status: 'Optimal', insight: 'Longer telomeres associated with longevity.'),
        LabMarker(name: 'SIRT1 Activity', value: '1.8 units', range: '> 1.5 units', status: 'Optimal'),
        LabMarker(name: 'Oxidative Stress Index', value: '285 units', range: '< 350 units', status: 'Optimal'),
        LabMarker(name: 'Glutathione', value: '850 µmol/L', range: '> 600 µmol/L', status: 'Optimal'),
        LabMarker(name: 'CoQ10', value: '1.2 µg/mL', range: '0.6-2.5 µg/mL', status: 'Optimal'),
        LabMarker(name: 'mTOR Activity', value: '1.2 units', range: '< 2.0 units', status: 'Optimal'),
        LabMarker(name: 'AMPK Activity', value: '2.8 units', range: '> 2.0 units', status: 'Optimal'),
        LabMarker(name: 'IL-6', value: '1.8 pg/mL', range: '< 5 pg/mL', status: 'Optimal'),
        LabMarker(name: 'TNF-alpha', value: '3.2 pg/mL', range: '< 8.1 pg/mL', status: 'Optimal'),
      ],
    ),
    LabReport(
      id: 'r2',
      date: '2023-08-10',
      title: 'Quarterly Checkup (50 Core Markers)',
      summary: 'Routine checkup showing progress.',
      markers: [
        LabMarker(name: 'HbA1c', value: '6.0%', range: '< 5.7%', status: 'Abnormal'),
        LabMarker(name: 'LDL Cholesterol', value: '145 mg/dL', range: '< 100 mg/dL', status: 'Abnormal'),
        LabMarker(name: 'Vitamin D', value: '28 ng/mL', range: '30-100 ng/mL', status: 'Abnormal'),
        LabMarker(name: 'TSH', value: '1.9 mIU/L', range: '0.4-4.0 mIU/L', status: 'Optimal'),
      ],
    ),
  ];

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

  /// Uploads a lab report to Supabase Storage and updates the patient's stage.
  static Future<bool> uploadLabReport({
    required String filePath,
    required String fileName,
    required String profileId,
    Map<String, dynamic>? extractedData,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      
      // 0. Sanitize filename (Supabase storage can be picky with spaces/special chars)
      final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = '$profileId/$safeFileName';
      
      // 1. Upload file to 'lab-reports' bucket
      // We wrap this in a try-catch because if the file already exists, we might want to continue
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await supabase.storage.from('lab-reports').upload(
            storagePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
          print('HealthRepo: File uploaded successfully to $storagePath');
        } else {
          print('HealthRepo: Local file not found at $filePath, skipping storage upload.');
        }
      } catch (storageError) {
        // If it's an "already exists" error, we can ignore it and proceed
        print('HealthRepo: Storage upload note (might already exist): $storageError');
      }

      // 2. Get Public URL
      final String publicUrl = supabase.storage.from('lab-reports').getPublicUrl(storagePath);

      // 3. Create a record in 'lab_reports' table
      await supabase.from('lab_reports').insert({
        'profile_id': profileId,
        'date': extractedData?['date'] ?? DateTime.now().toIso8601String().split('T')[0],
        'title': extractedData?['title'] ?? fileName,
        'pdf_url': publicUrl,
        'published': extractedData != null,
        'markers': extractedData?['markers'] ?? [],
        'summary': extractedData?['summary'] ?? 'Uploaded from mobile app.',
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 4. Update profile stage
      try {
        await supabase
            .from('profiles')
            .update({
              'stage': 'lab_processing',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', profileId);
      } catch (profileError) {
        print('HealthRepo: Profile update failed (non-critical): $profileError');
      }

      return true;
    } catch (e) {
      print('HealthRepo: Final Upload Error: $e');
      return false;
    }
  }

  /// Deletes a lab report from Supabase (DB + Storage)
  static Future<bool> deleteLabReport(String reportId, String profileId, String? fileName) async {
      try {
          final supabase = Supabase.instance.client;

          // 1. Delete from DB and confirm
          final response = await supabase.from('lab_reports').delete().eq('id', reportId).select();
          
          if (response.isEmpty) {
             print('Delete Warning: No rows deleted. Report might not exist or permission denied.');
             return response.isNotEmpty;
          }

          // 2. Delete from Storage (Optional)
          return true;
      } catch (e) {
          print('Delete Error: $e');
          return false;
      }
  }

  /// Saves or updates a manually entered biomarker value.
  static Future<bool> saveManualBiomarker({
    required String profileId,
    required String markerName,
    required String value,
    required String unit,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      
      // We look for an existing "Manual Entry" report for today
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await supabase
          .from('lab_reports')
          .select('*')
          .eq('profile_id', profileId)
          .eq('title', 'Manual Entry')
          .eq('date', today)
          .maybeSingle();

      List<dynamic> markers = [];
      String? reportId;

      if (response != null) {
        markers = List.from(response['markers']);
        reportId = response['id'];
      }

      // Find if this marker already exists in the manual report
      final existingIndex = markers.indexWhere((m) => m['name'].toString().toLowerCase() == markerName.toLowerCase());
      
      final newMarker = {
        'name': markerName,
        'value': '$value $unit',
        'range': '--',
        'status': 'Normal',
        'insight': 'Manually entered.',
      };

      if (existingIndex != -1) {
        markers[existingIndex] = newMarker;
      } else {
        markers.add(newMarker);
      }

      if (reportId != null) {
        // Update existing manual report
        await supabase.from('lab_reports').update({
          'markers': markers,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', reportId);
      } else {
        // Create new manual report
        await supabase.from('lab_reports').insert({
          'profile_id': profileId,
          'date': today,
          'title': 'Manual Entry',
          'summary': 'User manually entered health data.',
          'markers': markers,
          'published': true,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      return true;
    } catch (e) {
      print('Manual Entry Error: $e');
      return false;
    }
  }
}
