import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/health_data_repository.dart';

// ── Keys for SharedPreferences persistence ──
const _kPendingFilePath = 'lab_analysis_pending_file_path';
const _kPendingFileName = 'lab_analysis_pending_file_name';
const _kPendingProfileId = 'lab_analysis_pending_profile_id';
const _kCompletedResult = 'lab_analysis_completed_result';
const _kStatus = 'lab_analysis_status';

enum LabAnalysisStatus {
  idle,
  preparingPdf,   // Converting PDF pages to images
  analyzing,      // Chunked AI extraction
  finalizing,     // Deduplication & post-processing
  completed,      // Done — result available
  error,          // Failed
}

class LabAnalysisState {
  final LabAnalysisStatus status;
  final String statusMessage;
  // Chunk-level progress
  final int currentChunk;
  final int totalChunks;
  // Page-level progress
  final int currentPage;
  final int totalPages;
  // Completed data  
  final Map<String, dynamic>? result;
  // Error
  final String? errorMessage;
  // Pending job info (needed so UI can show what's being processed)
  final String? pendingFilePath;
  final String? pendingFileName;

  const LabAnalysisState({
    this.status = LabAnalysisStatus.idle,
    this.statusMessage = '',
    this.currentChunk = 0,
    this.totalChunks = 0,
    this.currentPage = 0,
    this.totalPages = 0,
    this.result,
    this.errorMessage,
    this.pendingFilePath,
    this.pendingFileName,
  });

  double get progress {
    if (status == LabAnalysisStatus.idle) return 0.0;
    if (status == LabAnalysisStatus.completed) return 1.0;
    if (status == LabAnalysisStatus.error) return 0.0;
    if (totalChunks == 0) return 0.05;
    // Stages: PDF = 0..0.2, AI chunks = 0.2..0.9, Finalizing = 0.9..1.0
    if (status == LabAnalysisStatus.preparingPdf) {
      if (totalPages == 0) return 0.05;
      return 0.05 + (currentPage / totalPages) * 0.15;
    }
    if (status == LabAnalysisStatus.analyzing) {
      return 0.2 + (currentChunk / totalChunks) * 0.7;
    }
    if (status == LabAnalysisStatus.finalizing) return 0.95;
    return 0.0;
  }

  bool get isRunning => status == LabAnalysisStatus.preparingPdf ||
      status == LabAnalysisStatus.analyzing ||
      status == LabAnalysisStatus.finalizing;

  LabAnalysisState copyWith({
    LabAnalysisStatus? status,
    String? statusMessage,
    int? currentChunk,
    int? totalChunks,
    int? currentPage,
    int? totalPages,
    Map<String, dynamic>? result,
    String? errorMessage,
    String? pendingFilePath,
    String? pendingFileName,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return LabAnalysisState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      currentChunk: currentChunk ?? this.currentChunk,
      totalChunks: totalChunks ?? this.totalChunks,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingFilePath: pendingFilePath ?? this.pendingFilePath,
      pendingFileName: pendingFileName ?? this.pendingFileName,
    );
  }
}

class LabAnalysisNotifier extends Notifier<LabAnalysisState> {
  @override
  LabAnalysisState build() {
    // Check for any resumed/pending job on startup
    _checkForPendingJob();
    return const LabAnalysisState();
  }

  /// Called from the upload screen. Initiates a new analysis.
  Future<void> startAnalysis({
    required String filePath,
    required String fileName,
    required String profileId,
  }) async {
    // Clear any previous completed state
    state = LabAnalysisState(
      status: LabAnalysisStatus.preparingPdf,
      statusMessage: 'Preparing document...',
      pendingFilePath: filePath,
      pendingFileName: fileName,
    );

    // Persist job details so we can resume after app kill
    await _persistPendingJob(filePath: filePath, fileName: fileName, profileId: profileId);

    await _runAnalysis(filePath: filePath, fileName: fileName, profileId: profileId);
  }

  /// Resumes a pending job found in SharedPreferences (called on app start).
  /// NOTE: We only resume IN-PROGRESS jobs where the source file still exists.
  /// Completed results are NOT restored — they must be consumed in the same session.
  Future<void> _checkForPendingJob() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStatus = prefs.getString(_kStatus);

      // If there's a stale "completed" key, just wipe it — 
      // completed results should not persist across app restarts.
      if (savedStatus == 'completed') {
        debugPrint('LabAnalysis: Found stale completed result — clearing it');
        await _clearPendingJob();
        return;
      }

      // If there was a job in progress, resume it only if the file still exists
      if (savedStatus == 'running') {
        final filePath = prefs.getString(_kPendingFilePath);
        final fileName = prefs.getString(_kPendingFileName);
        final profileId = prefs.getString(_kPendingProfileId);

        if (filePath != null && fileName != null && profileId != null) {
          if (await File(filePath).exists()) {
            debugPrint('LabAnalysis: Resuming interrupted analysis for $fileName');
            state = LabAnalysisState(
              status: LabAnalysisStatus.preparingPdf,
              statusMessage: 'Resuming analysis...',
              pendingFilePath: filePath,
              pendingFileName: fileName,
            );
            await _runAnalysis(filePath: filePath, fileName: fileName, profileId: profileId);
          } else {
            debugPrint('LabAnalysis: Source file gone — clearing stale job');
            await _clearPendingJob();
          }
        } else {
          // Incomplete job data — clear it
          await _clearPendingJob();
        }
      }
    } catch (e) {
      debugPrint('LabAnalysis: Error checking pending job: $e');
      // On any error, ensure we start clean
      try { await _clearPendingJob(); } catch (_) {}
    }
  }

  Future<void> _runAnalysis({
    required String filePath,
    required String fileName,
    required String profileId,
  }) async {
    try {
      final extractionResults = await HealthDataRepository.analyzeLabReportWithProgress(
        filePath: filePath,
        fileName: fileName,
        profileId: profileId,
        onPdfProgress: (current, total) {
          state = state.copyWith(
            status: LabAnalysisStatus.preparingPdf,
            statusMessage: 'Converting page $current of $total...',
            currentPage: current,
            totalPages: total,
          );
        },
        onChunkProgress: (chunk, total, label) {
          state = state.copyWith(
            status: LabAnalysisStatus.analyzing,
            statusMessage: label,
            currentChunk: chunk,
            totalChunks: total,
          );
        },
        onFinalizing: () {
          state = state.copyWith(
            status: LabAnalysisStatus.finalizing,
            statusMessage: 'Mapping biomarkers...',
          );
        },
      );

      if (extractionResults != null) {
        state = state.copyWith(
          status: LabAnalysisStatus.completed,
          statusMessage: 'Analysis complete!',
          result: extractionResults,
        );
        // Clear the "running" job from prefs — result lives only in memory now
        await _clearPendingJob();
      } else {
        state = state.copyWith(
          status: LabAnalysisStatus.error,
          errorMessage: 'Analysis returned no data. Please try again.',
        );
        await _clearPendingJob();
      }
    } catch (e) {
      debugPrint('LabAnalysis: Error running analysis: $e');
      state = state.copyWith(
        status: LabAnalysisStatus.error,
        errorMessage: e.toString(),
      );
      await _clearPendingJob();
    }
  }

  /// Clears the completed state so the screen returns to idle.
  /// This should be called ONLY after the user saves or discards the report.
  Future<void> consumeResult() async {
    await _clearPendingJob();
    state = const LabAnalysisState();
  }

  /// Manually dismisses a stale or unwanted result.
  Future<void> dismiss() async {
    await _clearPendingJob();
    state = const LabAnalysisState();
    debugPrint('LabAnalysis: Manual dismissal successful');
  }

  /// Manually reset the state to idle (useful for error recovery)
  Future<void> reset() async {
    await _clearPendingJob();
    state = const LabAnalysisState();
  }

  // ── Persistence Helpers ──

  Future<void> _persistPendingJob({
    required String filePath,
    required String fileName,
    required String profileId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingFilePath, filePath);
      await prefs.setString(_kPendingFileName, fileName);
      await prefs.setString(_kPendingProfileId, profileId);
      await prefs.setString(_kStatus, 'running');
    } catch (e) {
      debugPrint('LabAnalysis: Failed to persist job: $e');
    }
  }



  Future<void> _clearPendingJob() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPendingFilePath);
      await prefs.remove(_kPendingFileName);
      await prefs.remove(_kPendingProfileId);
      await prefs.remove(_kCompletedResult);
      await prefs.remove(_kStatus);
      debugPrint('LabAnalysis: Cleared pending job and status keys');
    } catch (e) {
      debugPrint('LabAnalysis: Failed to clear job: $e');
    }
  }
}

final labAnalysisProvider =
    NotifierProvider<LabAnalysisNotifier, LabAnalysisState>(() {
  return LabAnalysisNotifier();
});
