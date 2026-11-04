/// Biomarker segment grouping for the Biomarkers tab (TC-025, PR A).
///
/// Design default (Ava, 3 Nov 2026) — to be confirmed by Zyndio's clinical lead.
///
/// The patient app's lab data is keyed by marker *name* (`LabMarker.name`);
/// there is no `analyte_key` column. This file is the SINGLE source that maps a
/// normalized marker name to one of the four segments. It encodes grouping only,
/// no clinical judgement and no composite score. A marker whose name is not
/// listed here belongs to no segment and is reachable only through
/// "View Full Biomarker Report".
library;

import 'lab_range_wording.dart';

enum BiomarkerSegment { nad, metabolic, hormones, inflammation }

extension BiomarkerSegmentLabel on BiomarkerSegment {
  String get label => switch (this) {
        BiomarkerSegment.nad => 'NAD+',
        BiomarkerSegment.metabolic => 'Metabolic',
        BiomarkerSegment.hormones => 'Hormones',
        BiomarkerSegment.inflammation => 'Inflammation',
      };
}

/// The marker that leads each segment (the Z6 hero), by normalized name.
const Map<BiomarkerSegment, String> kSegmentLead = {
  BiomarkerSegment.nad: 'intracellular nad+',
  BiomarkerSegment.metabolic: 'hba1c',
  BiomarkerSegment.hormones: 'testosterone',
  BiomarkerSegment.inflammation: 'hs-crp',
};

/// Normalized marker name → segment. The one place the grouping lives.
const Map<String, BiomarkerSegment> kBiomarkerSegments = {
  // NAD+ panel — Intracellular NAD+ leads.
  'intracellular nad+': BiomarkerSegment.nad,
  'intracellular nad': BiomarkerSegment.nad,
  'nad+': BiomarkerSegment.nad,
  'nad': BiomarkerSegment.nad,
  'nadh': BiomarkerSegment.nad,
  'nad/nadh ratio': BiomarkerSegment.nad,
  'methylnicotinamide': BiomarkerSegment.nad,
  // Metabolic — HbA1c leads, then fasting glucose, fasting insulin, lipids.
  'hba1c': BiomarkerSegment.metabolic,
  'glucose': BiomarkerSegment.metabolic,
  'fasting glucose': BiomarkerSegment.metabolic,
  'insulin': BiomarkerSegment.metabolic,
  'fasting insulin': BiomarkerSegment.metabolic,
  'total cholesterol': BiomarkerSegment.metabolic,
  'ldl cholesterol': BiomarkerSegment.metabolic,
  'hdl cholesterol': BiomarkerSegment.metabolic,
  'triglycerides': BiomarkerSegment.metabolic,
  // Hormones.
  'testosterone': BiomarkerSegment.hormones,
  'free testosterone': BiomarkerSegment.hormones,
  'estradiol': BiomarkerSegment.hormones,
  'tsh': BiomarkerSegment.hormones,
  'cortisol': BiomarkerSegment.hormones,
  'dhea-s': BiomarkerSegment.hormones,
  'dhea': BiomarkerSegment.hormones,
  // Inflammation — hs-CRP leads, then homocysteine.
  'hs-crp': BiomarkerSegment.inflammation,
  'crp': BiomarkerSegment.inflammation,
  'homocysteine': BiomarkerSegment.inflammation,
};

String normalizeMarkerName(String name) => name.toLowerCase().trim();

/// Which segment a marker name belongs to, or null (→ full report only).
BiomarkerSegment? segmentForMarker(String name) =>
    kBiomarkerSegments[normalizeMarkerName(name)];

/// Whether [name] is the designated lead marker for [segment].
bool isSegmentLead(String name, BiomarkerSegment segment) =>
    kSegmentLead[segment] == normalizeMarkerName(name);

/// Lab-range caption for a MarkerTile / hero (Q11, Ava 3 Nov 2026). The delta
/// shown next to a value is always neutral; this caption is a plain *status*.
///
/// Our lab data carries a free-form `LabMarker.status` plus numeric bounds
/// (`minRange`/`maxRange`). Ava's Q11 is keyed by a `within_range / outside_range
/// / needs_review / baseline / no_range` enum that this model does not have, so
/// we derive the caption honestly: compare the value against the lab reference
/// range, and fall back to the reported status only when a numeric comparison is
/// impossible. (See QUESTIONS.md — status-enum mismatch.)
String biomarkerRangeCaption({
  required double? value,
  required double? low,
  required double? high,
  String status = '',
}) {
  // APP-06: one bounded caption for any out-of-range value, above or below.
  // It never names a condition or a direction of concern; see
  // lib/config/lab_range_wording.dart.
  if (value != null) {
    if (high != null && value > high) return kOutsideClinicRange;
    if (low != null && value < low) return kOutsideClinicRange;
    if (low != null || high != null) return kWithinClinicRange;
  }
  switch (status.toLowerCase().trim()) {
    case 'high':
    case 'low':
    case 'outlier':
    case 'abnormal':
    case 'critical':
      return kOutsideClinicRange;
  }
  if (low == null && high == null) return kNoRangeProvided;
  return kWithinClinicRange;
}
