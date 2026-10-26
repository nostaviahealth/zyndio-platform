import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../logic/upload_queue.dart';

/// App-private, file-backed [QueueStore]. One JSON file per patient under a
/// given directory, so a queued item survives an app kill/reopen. A corrupt
/// or missing file never crashes the app — it's treated as an empty queue.
class FileQueueStore implements QueueStore {
  FileQueueStore(this._file);

  /// Builds the store for [patientId]'s queue inside [directory], one file
  /// per patient. [patientId] is sanitised to `[A-Za-z0-9_-]` so it's always
  /// a safe file name component.
  factory FileQueueStore.forPatient(Directory directory, String patientId) {
    final safeId = patientId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return FileQueueStore(File('${directory.path}/upload_queue_$safeId.json'));
  }

  final File _file;

  String get _fileName => _file.uri.pathSegments.last;

  @override
  List<Map<String, String>> load() {
    if (!_file.existsSync()) return [];
    try {
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is! List) {
        throw const FormatException('upload queue file is not a JSON list');
      }
      return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) {
      developer.log(
        'Discarding unreadable upload queue file $_fileName',
        name: 'FileQueueStore',
        error: e.runtimeType.toString(),
      );
      return [];
    }
  }

  @override
  void save(List<Map<String, String>> items) {
    final tmp = File('${_file.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(items), flush: true);
    tmp.renameSync(_file.path);
  }
}
