enum UploadStatus { queued, uploading, failed, saved }

class UploadItem {
  UploadItem({
    required this.id,
    required this.fileName,
    required this.status,
  });

  final String id;
  final String fileName;
  UploadStatus status;

  Map<String, String> toMap() =>
      {'id': id, 'fileName': fileName, 'status': status.name};

  static UploadItem fromMap(Map<String, String> map) => UploadItem(
        id: map['id']!,
        fileName: map['fileName']!,
        status: UploadStatus.values.byName(map['status']!),
      );
}

/// Injectable persistence for [UploadQueue] so a queued item survives a new
/// queue instance (app kill/reopen). [InMemoryQueueStore] is the test fake;
/// the app supplies an app-private storage-backed implementation that lives
/// outside `logic/`/`data/` (those stay pure Dart, no Flutter imports).
abstract class QueueStore {
  List<Map<String, String>> load();
  void save(List<Map<String, String>> items);
}

/// Test-only fake. Construct a shared instance and pass it to multiple
/// [UploadQueue]s to simulate the queue surviving an app restart.
class InMemoryQueueStore implements QueueStore {
  List<Map<String, String>> _items = [];

  @override
  List<Map<String, String>> load() =>
      _items.map(Map<String, String>.from).toList();

  @override
  void save(List<Map<String, String>> items) =>
      _items = items.map(Map<String, String>.from).toList();
}

/// Offline-aware upload queue. Items enqueued while offline sit as `queued`
/// with the label [waitingForConnectionLabel] and are retried automatically
/// once [setOnline] flips to true. Every mutation is persisted through
/// [store], so a fresh [UploadQueue] built on the same store picks up where
/// the last one left off instead of dropping queued work on app kill.
class UploadQueue {
  UploadQueue({this.isOnline = true, QueueStore? store})
      : _store = store ?? InMemoryQueueStore() {
    _items.addAll(_store.load().map(UploadItem.fromMap));
    _counter = _items.length;
  }

  static const String waitingForConnectionLabel = 'Waiting for connection';

  bool isOnline;

  final QueueStore _store;
  final List<UploadItem> _items = [];
  int _counter = 0;

  List<UploadItem> get items => List.unmodifiable(_items);

  UploadItem enqueue(String fileName) {
    final item = UploadItem(
      id: 'upload-${_counter++}',
      fileName: fileName,
      status: isOnline ? UploadStatus.uploading : UploadStatus.queued,
    );
    _items.add(item);
    _persist();
    return item;
  }

  String labelFor(UploadItem item) {
    switch (item.status) {
      case UploadStatus.queued:
        return waitingForConnectionLabel;
      case UploadStatus.uploading:
        return 'Uploading';
      case UploadStatus.failed:
        return 'Failed';
      case UploadStatus.saved:
        return 'Saved';
    }
  }

  /// Flips connectivity. Coming back online retries every still-queued item
  /// exactly once — items already `uploading`/`saved`/`failed` are left
  /// alone, so calling this twice in a row (e.g. two reconnect events) never
  /// re-queues or double-uploads the same item.
  void setOnline(bool online) {
    isOnline = online;
    if (!online) return;
    var changed = false;
    for (final item in _items) {
      if (item.status == UploadStatus.queued) {
        item.status = UploadStatus.uploading;
        changed = true;
      }
    }
    if (changed) _persist();
  }

  void markSaved(String id) {
    _findById(id).status = UploadStatus.saved;
    _persist();
  }

  void markFailed(String id) {
    _findById(id).status = UploadStatus.failed;
    _persist();
  }

  UploadItem _findById(String id) => _items.firstWhere((i) => i.id == id);

  void _persist() => _store.save(_items.map((i) => i.toMap()).toList());
}
