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
}

/// Offline-aware upload queue. Items enqueued while offline sit as `queued`
/// with the label [waitingForConnectionLabel] and are retried automatically
/// once [setOnline] flips to true.
class UploadQueue {
  UploadQueue({this.isOnline = true});

  static const String waitingForConnectionLabel = 'Waiting for connection';

  bool isOnline;

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

  /// Flips connectivity. Coming back online retries every queued item.
  void setOnline(bool online) {
    isOnline = online;
    if (!online) return;
    for (final item in _items) {
      if (item.status == UploadStatus.queued) {
        item.status = UploadStatus.uploading;
      }
    }
  }

  void markSaved(String id) => _findById(id).status = UploadStatus.saved;

  void markFailed(String id) => _findById(id).status = UploadStatus.failed;

  UploadItem _findById(String id) => _items.firstWhere((i) => i.id == id);
}
