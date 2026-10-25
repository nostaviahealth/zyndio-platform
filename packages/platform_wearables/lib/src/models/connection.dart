import '../providers.dart';

class BrandConnection {
  final BrandProvider provider;
  final String status;
  final DateTime? connectedAt;
  final DateTime? lastSyncAt;

  BrandConnection({
    required this.provider,
    required this.status,
    this.connectedAt,
    this.lastSyncAt,
  });

  factory BrandConnection.fromMap(Map<String, dynamic> map) {
    return BrandConnection(
      provider: BrandProvider.values.firstWhere(
        (e) => e.name == map['provider'],
      ),
      status: map['status'] as String,
      connectedAt: map['connectedAt'] != null
          ? DateTime.parse(map['connectedAt'])
          : null,
      lastSyncAt:
          map['lastSyncAt'] != null ? DateTime.parse(map['lastSyncAt']) : null,
    );
  }
}
