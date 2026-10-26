import '../utils/clinical_intelligence.dart';

class LabMarker {
  final String name;
  final String value;
  final String range;
  final String status;
  final String? insight;
  /// Lab-reported category/section (e.g. 'Lipid Profile', 'Complete Blood Count')
  final String category;
  /// Lab-reported unit (e.g. 'mg/dL', 'U/L')
  final String unit;
  /// Name of the laboratory that produced this result (e.g. 'Lal Path Labs', 'Thyrocare')
  final String? labName;
  final double? minRange;
  final double? maxRange;
  final double? minOptimal;
  final double? maxOptimal;
  final List<ClinicalCitation>? citations;

  LabMarker({
    required this.name,
    required this.value,
    required this.range,
    required this.status,
    this.insight,
    this.category = 'General',
    this.unit = '',
    this.labName,
    this.minRange,
    this.maxRange,
    this.minOptimal,
    this.maxOptimal,
    this.citations,
  });

  factory LabMarker.fromJson(Map<String, dynamic> json) {
    var rangeStr = json['range'] as String? ?? '--';
    
    double? parsedMin = (json['min_range'] as num?)?.toDouble();
    double? parsedMax = (json['max_range'] as num?)?.toDouble();

    // Smart Parser: If numeric ranges are missing, try to extract them from the string
    if (parsedMin == null && parsedMax == null && rangeStr != '--') {
      try {
        final cleanRange = rangeStr.replaceAll(RegExp(r'[^0-9.\-<>]'), '');
        if (cleanRange.contains('-')) {
          final parts = cleanRange.split('-');
          if (parts.length == 2) {
            parsedMin = double.tryParse(parts[0]);
            parsedMax = double.tryParse(parts[1]);
          }
        } else if (cleanRange.contains('<')) {
          parsedMax = double.tryParse(cleanRange.replaceAll('<', ''));
          parsedMin = 0;
        } else if (cleanRange.contains('>')) {
          parsedMin = double.tryParse(cleanRange.replaceAll('>', ''));
        }
      } catch (_) {}
    }

    return LabMarker(
      name: json['name'] as String? ?? 'Unknown Marker',
      value: json['value'] as String? ?? '--',
      range: rangeStr,
      status: json['status'] as String? ?? 'In-range',
      insight: json['insight'] as String?,
      category: json['category'] as String? ?? 'General',
      unit: json['unit'] as String? ?? '',
      labName: json['lab_name'] as String?,
      minRange: parsedMin,
      maxRange: parsedMax,
      minOptimal: (json['min_optimal'] as num?)?.toDouble(),
      maxOptimal: (json['max_optimal'] as num?)?.toDouble(),
      citations: (json['citations'] as List<dynamic>?)
          ?.map((e) => ClinicalCitation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // Helper to determine UI color/icon based on these 3 specific categories
  bool get isOutlier => status.toLowerCase() == 'outlier' || status.toLowerCase() == 'abnormal' || status.toLowerCase() == 'high' || status.toLowerCase() == 'low' || status.toLowerCase() == 'critical';
  bool get isOptimal => status.toLowerCase() == 'optimal';
  bool get isInRange => !isOutlier && !isOptimal; // Catch-all for In-range/Normal

  String get displayStatus {
    if (isOptimal) return 'OPTIMAL';
    if (isOutlier) return 'OUTLIER';
    return 'IN-RANGE';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'range': range,
      'unit': unit,
      'status': status,
      'category': category,
      'insight': insight,
      'lab_name': labName,
      'min_range': minRange,
      'max_range': maxRange,
      'min_optimal': minOptimal,
      'max_optimal': maxOptimal,
    };
  }
}

class LabReport {
  final String id;
  final String date;
  final String title;
  final String summary;
  final String? pdfUrl;
  /// Name of the laboratory that generated this report
  final String? labName;
  final List<LabMarker> markers;

  LabReport({
    required this.id,
    required this.date,
    required this.title,
    required this.summary,
    this.pdfUrl,
    this.labName,
    required this.markers,
  });

  factory LabReport.fromJson(Map<String, dynamic> json) {
    final reportLabName = json['lab_name'] as String?;
    return LabReport(
      id: json['id'] as String,
      date: _formatDate(json['date'] as String?),
      title: json['title'] as String? ?? 'Lab Report',
      summary: json['summary'] as String? ?? '',
      pdfUrl: json['pdf_url'] as String?,
      labName: reportLabName,
      markers: (json['markers'] as List<dynamic>?)
              ?.map((e) {
                final markerJson = e as Map<String, dynamic>;
                // Propagate report-level labName to each marker if not already set
                if (markerJson['lab_name'] == null && reportLabName != null) {
                  markerJson['lab_name'] = reportLabName;
                }
                final marker = LabMarker.fromJson(markerJson);
                return ClinicalIntelligence.calibrate(marker);
              })
              .toList() ??
          [],
    );
  }

  static String _formatDate(String? rawDate) {
    if (rawDate == null) return 'Unknown Date';
    try {
      final dt = DateTime.parse(rawDate);
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    } catch (e) {
      return rawDate;
    }
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'title': title,
      'summary': summary,
      'pdf_url': pdfUrl,
      'lab_name': labName,
      'markers': markers.map((m) => m.toJson()).toList(),
    };
  }
}
class ClinicalCitation {
  final String source;
  final String? title;
  final String? url;

  ClinicalCitation({required this.source, this.title, this.url});

  factory ClinicalCitation.fromJson(Map<String, dynamic> json) {
    return ClinicalCitation(
      source: json['source'] as String,
      title: json['title'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'source': source,
    if (title != null) 'title': title,
    if (url != null) 'url': url,
  };
}
