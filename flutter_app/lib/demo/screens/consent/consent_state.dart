import 'package:flutter/foundation.dart';

/// A versionable consent document. Copy is placeholder per `screens.md §02`
/// until Zyndio and its counsel supply the real Terms, Privacy and consent
/// text.
class ConsentDoc {
  const ConsentDoc({required this.id, required this.title, required this.subline});

  final String id;
  final String title;
  final String subline;
}

const List<ConsentDoc> consentDocs = [
  ConsentDoc(id: 'terms', title: 'Terms of Service', subline: 'Version 0.1 · placeholder text'),
  ConsentDoc(id: 'privacy', title: 'Privacy Notice', subline: 'Version 0.1 · placeholder text'),
  ConsentDoc(
    id: 'consent',
    title: 'Consent to use my health data',
    subline: "Version 0.1 · for your care team's review",
  ),
];

@immutable
class ConsentDocState {
  const ConsentDocState({
    required this.doc,
    this.checked = false,
    this.hasError = false,
    this.showRequiredError = false,
  });

  final ConsentDoc doc;
  final bool checked;
  final bool hasError;
  final bool showRequiredError;

  ConsentDocState copyWith({bool? checked, bool? hasError, bool? showRequiredError}) {
    return ConsentDocState(
      doc: doc,
      checked: checked ?? this.checked,
      hasError: hasError ?? this.hasError,
      showRequiredError: showRequiredError ?? this.showRequiredError,
    );
  }
}

/// Maps the screenshot harness's `?state=` query param to a fixture
/// [ConsentState]. Unknown/missing values fall back to `unchecked`.
ConsentState consentStateForQueryState(String? queryState) => switch (queryState) {
      'complete' => ConsentState.complete(),
      'partner-on' => ConsentState.partnerOn(),
      'validation' => ConsentState.validation(),
      'loading' => ConsentState.loading(),
      'error' => ConsentState.docLoadError(),
      _ => ConsentState.unchecked(),
    };

/// Immutable view-state for [ConsentView]. Each factory matches one of the
/// 6 screenshot states (unchecked, partner-on, validation, loading, error,
/// complete).
@immutable
class ConsentState {
  const ConsentState({
    this.isLoading = false,
    this.docs = const [],
    this.partnerSharingOn = false,
  });

  factory ConsentState.loading() => const ConsentState(isLoading: true);

  factory ConsentState.unchecked() =>
      ConsentState(docs: consentDocs.map((d) => ConsentDocState(doc: d)).toList());

  factory ConsentState.complete() => ConsentState(
        docs: consentDocs.map((d) => ConsentDocState(doc: d, checked: true)).toList(),
      );

  factory ConsentState.partnerOn() => ConsentState(
        docs: consentDocs.map((d) => ConsentDocState(doc: d, checked: true)).toList(),
        partnerSharingOn: true,
      );

  factory ConsentState.validation() => ConsentState(
        docs: [
          ConsentDocState(doc: consentDocs[0], checked: true),
          ConsentDocState(doc: consentDocs[1], showRequiredError: true),
          ConsentDocState(doc: consentDocs[2], checked: true),
        ],
      );

  factory ConsentState.docLoadError() => ConsentState(
        docs: [
          ConsentDocState(doc: consentDocs[0], checked: true),
          ConsentDocState(doc: consentDocs[1], hasError: true),
          ConsentDocState(doc: consentDocs[2], checked: true),
        ],
      );

  final bool isLoading;
  final List<ConsentDocState> docs;
  final bool partnerSharingOn;

  bool get allChecked => docs.isNotEmpty && docs.every((d) => d.checked);

  ConsentState copyWith({bool? isLoading, List<ConsentDocState>? docs, bool? partnerSharingOn}) {
    return ConsentState(
      isLoading: isLoading ?? this.isLoading,
      docs: docs ?? this.docs,
      partnerSharingOn: partnerSharingOn ?? this.partnerSharingOn,
    );
  }
}
