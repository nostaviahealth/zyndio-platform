import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/zyndio_repository.dart';
import '../../logic/file_hash.dart';
import '../../logic/upload_queue.dart';
import '../../providers/demo_providers.dart';
import '../../widgets/badge.dart';
import 'lab_upload_state.dart';

/// Drives [LabUploadState] for the interactive demo build: duplicate-hash
/// detection ("warn, never block") and the offline upload queue, both
/// through [ZyndioRepository] so the same server-side policies the tests
/// cover apply here too — never a UI-only shortcut.
class LabUploadController extends Notifier<LabUploadState> {
  @override
  LabUploadState build() => LabUploadState.defaultState();

  ZyndioRepository get _repo => ref.read(zyndioRepositoryProvider);
  RepoSession get _session => requireDemoSession(ref);
  UploadQueue get _queue => _repo.uploadQueueFor(_session);

  String? _pendingFileName;
  Uint8List? _pendingBytes;

  /// Simulates picking a file (the demo has no real file picker/camera).
  /// A hash already seen for this patient shows the duplicate banner and
  /// waits for [confirmUploadAnyway]/[cancelDuplicate]; it never blocks the
  /// upload outright and never checks another patient's hashes.
  void addFile(String fileName, Uint8List bytes) {
    final hash = sha256Hex(bytes);
    final result = _repo.checkDuplicateHash(_session, hash);
    if (result.isDuplicate) {
      _pendingFileName = fileName;
      _pendingBytes = bytes;
      state = state.copyWith(banner: LabUploadBannerKind.duplicate);
      return;
    }
    _enqueue(fileName, hash);
  }

  void confirmUploadAnyway() {
    final fileName = _pendingFileName;
    final bytes = _pendingBytes;
    if (fileName == null || bytes == null) return;
    _enqueue(fileName, sha256Hex(bytes));
    _clearPending();
  }

  void cancelDuplicate() {
    _clearPending();
    state = state.copyWith(banner: LabUploadBannerKind.none);
  }

  void _clearPending() {
    _pendingFileName = null;
    _pendingBytes = null;
  }

  void _enqueue(String fileName, String hash) {
    _repo.recordUploadHash(_session, hash);
    _queue.enqueue(fileName);
    _refresh();
  }

  /// Flips connectivity on the session's queue; reconnecting retries every
  /// still-queued item exactly once (see [UploadQueue.setOnline]).
  void setOnline(bool online) {
    _queue.setOnline(online);
    _refresh();
  }

  void _refresh() {
    final rows = [for (final item in _queue.items) _rowFor(item)];
    state = state.copyWith(
      rows: rows,
      isEmpty: rows.isEmpty,
      banner: _queue.isOnline ? LabUploadBannerKind.none : LabUploadBannerKind.offline,
    );
  }

  UploadRowState _rowFor(UploadItem item) {
    final label = _queue.labelFor(item);
    switch (item.status) {
      case UploadStatus.queued:
        return UploadRowState(
          title: item.fileName,
          subline: label,
          icon: UploadRowIcon.queued,
          badgeLabel: 'Queued',
          badgeVariant: BadgeVariant.warn,
        );
      case UploadStatus.uploading:
        return UploadRowState(title: item.fileName, subline: label, icon: UploadRowIcon.uploading);
      case UploadStatus.failed:
        return UploadRowState(
          title: item.fileName,
          subline: label,
          icon: UploadRowIcon.failed,
          showRetry: true,
        );
      case UploadStatus.saved:
        return UploadRowState(
          title: item.fileName,
          subline: label,
          icon: UploadRowIcon.saved,
          badgeLabel: 'Saved',
          badgeVariant: BadgeVariant.ok,
        );
    }
  }
}

final labUploadControllerProvider = NotifierProvider<LabUploadController, LabUploadState>(
  LabUploadController.new,
);
