import '../utils/clinical_intelligence.dart';

class PanelMetadata {
  final List<Map<String, dynamic>>? phylumRatios;
  final List<Map<String, dynamic>>? diversityIndices;
  final List<Map<String, dynamic>>? pathogens;
  final bool? isOneTime;
  final double? biologicalAge;
  final double? chronologicalAge;
  final double? ageAcceleration;
  final double? paceOfAging;
  final List<Map<String, dynamic>>? clockScores;
  final String? specimenType;
  final String? provocationAgent;
  final String? toxinCategory;
  final double? toxinLoadScore;

  PanelMetadata({
    this.phylumRatios,
    this.diversityIndices,
    this.pathogens,
    this.isOneTime,
    this.biologicalAge,
    this.chronologicalAge,
    this.ageAcceleration,
    this.paceOfAging,
    this.clockScores,
    this.specimenType,
    this.provocationAgent,
    this.toxinCategory,
    this.toxinLoadScore,
  });

  factory PanelMetadata.fromJson(Map<String, dynamic> json) {
    return PanelMetadata(
      phylumRatios: json['phylumRatios'] != null ? List<Map<String, dynamic>>.from(json['phylumRatios']) : null,
      diversityIndices: json['diversityIndices'] != null ? List<Map<String, dynamic>>.from(json['diversityIndices']) : null,
      pathogens: json['pathogens'] != null ? List<Map<String, dynamic>>.from(json['pathogens']) : null,
      isOneTime: json['isOneTime'] as bool?,
      biologicalAge: (json['biologicalAge'] as num?)?.toDouble(),
      chronologicalAge: (json['chronologicalAge'] as num?)?.toDouble(),
      ageAcceleration: (json['ageAcceleration'] as num?)?.toDouble(),
      paceOfAging: (json['paceOfAging'] as num?)?.toDouble(),
      clockScores: json['clockScores'] != null ? List<Map<String, dynamic>>.from(json['clockScores']) : null,
      specimenType: json['specimenType'] as String?,
      provocationAgent: json['provocationAgent'] as String?,
      toxinCategory: json['toxinCategory'] as String?,
      toxinLoadScore: (json['toxinLoadScore'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phylumRatios': phylumRatios,
      'diversityIndices': diversityIndices,
      'pathogens': pathogens,
      'isOneTime': isOneTime,
      'biologicalAge': biologicalAge,
      'chronologicalAge': chronologicalAge,
      'ageAcceleration': ageAcceleration,
      'paceOfAging': paceOfAging,
      'clockScores': clockScores,
      'specimenType': specimenType,
      'provocationAgent': provocationAgent,
      'toxinCategory': toxinCategory,
      'toxinLoadScore': toxinLoadScore,
    };
  }
}
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
  /// TC-036: object path of the report file in the private lab-reports
  /// bucket (lab_reports.pdf_path), never a URL. Open it with
  /// HealthDataRepository.signedLabReportUrl.
  final String? pdfPath;
  final String? reportType;
  final String? aiInterpretation;
  final PanelMetadata? panelMetadata;
  /// Name of the laboratory that generated this report
  final String? labName;
  final List<LabMarker> markers;

  LabReport({
    required this.id,
    required this.date,
    required this.title,
    required this.summary,
    this.pdfPath,
    this.reportType,
    this.aiInterpretation,
    this.panelMetadata,
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
      pdfPath: json['pdf_path'] as String?,
      reportType: json['reportType'] as String?,
      aiInterpretation: json['aiInterpretation'] as String?,
      panelMetadata: json['panelMetadata'] != null ? PanelMetadata.fromJson(json['panelMetadata'] as Map<String, dynamic>) : null,
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
      'pdf_path': pdfPath,
      'reportType': reportType,
      'aiInterpretation': aiInterpretation,
      'panelMetadata': panelMetadata?.toJson(),
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
