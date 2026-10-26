# TC-008 demo screenshot index

One row per PNG under `docs/screenshots/tc-008/<screen>/<state>--<light|dark>.png`. Test/check IDs are from
`/workspace/techteam/team3/projects/zyndio/docs/TC-008_TEST_PLAN.md`. "none in plan" means the state has no
test-plan ID of its own (it's still covered by a widget test in the file listed).

Step 6 adds `flutter_app/test/demo/flow_test.dart`: one end-to-end walk through the real
sign-in -> consent -> lab upload -> lab review -> lab trends journey (`?flow=journey`), driven by
taps and the real controllers/`DemoBackend` — not by constructing a screen state. It covers
T-AUTH-01/02/03, T-CONS-01/02, T-LAB-03/05 and T-BIO-01/02 as a single live walk, on top of (not
instead of) the per-state tests already listed below for each screen. The Henry-gate forbidden-wording
check (`flutter_app/test/demo/demo_forbidden_wording_test.dart`) also walks this same journey path.

| Screen | State | Mode | Path | Test/check ID(s) | Test file |
|---|---|---|---|---|---|
| signin | default | light | `signin/default--light.png` | none in plan | `flutter_app/test/demo/signin_test.dart` |
| signin | default | dark | `signin/default--dark.png` | none in plan | `flutter_app/test/demo/signin_test.dart` |
| signin | sending | light | `signin/sending--light.png` | none in plan (repeat-tap behaviour, no plan ID) | `flutter_app/test/demo/signin_test.dart` |
| signin | sending | dark | `signin/sending--dark.png` | none in plan (repeat-tap behaviour, no plan ID) | `flutter_app/test/demo/signin_test.dart` |
| signin | code | light | `signin/code--light.png` | T-AUTH-02 | `flutter_app/test/demo/signin_test.dart`, `flutter_app/test/demo/data/demo_backend_test.dart` |
| signin | code | dark | `signin/code--dark.png` | T-AUTH-02 | `flutter_app/test/demo/signin_test.dart`, `flutter_app/test/demo/data/demo_backend_test.dart` |
| signin | error | light | `signin/error--light.png` | none in plan | `flutter_app/test/demo/signin_test.dart` |
| signin | error | dark | `signin/error--dark.png` | none in plan | `flutter_app/test/demo/signin_test.dart` |
| signin | locked | light | `signin/locked--light.png` | T-AUTH-03 | `flutter_app/test/demo/signin_test.dart`, `flutter_app/test/demo/data/demo_backend_test.dart` |
| signin | locked | dark | `signin/locked--dark.png` | T-AUTH-03 | `flutter_app/test/demo/signin_test.dart`, `flutter_app/test/demo/data/demo_backend_test.dart` |
| signin | offline | light | `signin/offline--light.png` | none in plan | `flutter_app/test/demo/signin_test.dart` |
| signin | offline | dark | `signin/offline--dark.png` | none in plan | `flutter_app/test/demo/signin_test.dart` |
| consent | unchecked | light | `consent/unchecked--light.png` | T-CONS-01/02 | `flutter_app/test/demo/consent_test.dart` |
| consent | unchecked | dark | `consent/unchecked--dark.png` | T-CONS-01/02 | `flutter_app/test/demo/consent_test.dart` |
| consent | partner-on | light | `consent/partner-on--light.png` | T-CONS-01/02 | `flutter_app/test/demo/consent_test.dart` |
| consent | partner-on | dark | `consent/partner-on--dark.png` | T-CONS-01/02 | `flutter_app/test/demo/consent_test.dart` |
| consent | validation | light | `consent/validation--light.png` | T-CONS-01/02 | `flutter_app/test/demo/consent_test.dart` |
| consent | validation | dark | `consent/validation--dark.png` | T-CONS-01/02 | `flutter_app/test/demo/consent_test.dart` |
| consent | loading | light | `consent/loading--light.png` | none in plan | `flutter_app/test/demo/consent_test.dart` |
| consent | loading | dark | `consent/loading--dark.png` | none in plan | `flutter_app/test/demo/consent_test.dart` |
| consent | error | light | `consent/error--light.png` | T-CONS-01/02 | `flutter_app/test/demo/consent_test.dart` |
| consent | error | dark | `consent/error--dark.png` | T-CONS-01/02 | `flutter_app/test/demo/consent_test.dart` |
| consent | complete | light | `consent/complete--light.png` | T-CONS-01/02 | `flutter_app/test/demo/consent_test.dart` |
| consent | complete | dark | `consent/complete--dark.png` | T-CONS-01/02 | `flutter_app/test/demo/consent_test.dart` |
| lab-upload | empty | light | `lab-upload/empty--light.png` | none in plan | `flutter_app/test/demo/lab_upload_test.dart` |
| lab-upload | empty | dark | `lab-upload/empty--dark.png` | none in plan | `flutter_app/test/demo/lab_upload_test.dart` |
| lab-upload | default | light | `lab-upload/default--light.png` | none in plan | `flutter_app/test/demo/lab_upload_test.dart` |
| lab-upload | default | dark | `lab-upload/default--dark.png` | none in plan | `flutter_app/test/demo/lab_upload_test.dart` |
| lab-upload | uploading | light | `lab-upload/uploading--light.png` | none in plan | `flutter_app/test/demo/lab_upload_test.dart` |
| lab-upload | uploading | dark | `lab-upload/uploading--dark.png` | none in plan | `flutter_app/test/demo/lab_upload_test.dart` |
| lab-upload | duplicate | light | `lab-upload/duplicate--light.png` | T-LAB-03 | `flutter_app/test/demo/lab_upload_test.dart`, `flutter_app/test/demo/screens/lab_upload_controller_test.dart`, `flutter_app/test/demo/data/demo_backend_test.dart` |
| lab-upload | duplicate | dark | `lab-upload/duplicate--dark.png` | T-LAB-03 | `flutter_app/test/demo/lab_upload_test.dart`, `flutter_app/test/demo/screens/lab_upload_controller_test.dart`, `flutter_app/test/demo/data/demo_backend_test.dart` |
| lab-upload | offline | light | `lab-upload/offline--light.png` | T-LAB-05 | `flutter_app/test/demo/lab_upload_test.dart`, `flutter_app/test/demo/screens/lab_upload_controller_test.dart`, `flutter_app/test/demo/logic/upload_queue_test.dart` |
| lab-upload | offline | dark | `lab-upload/offline--dark.png` | T-LAB-05 | `flutter_app/test/demo/lab_upload_test.dart`, `flutter_app/test/demo/screens/lab_upload_controller_test.dart`, `flutter_app/test/demo/logic/upload_queue_test.dart` |
| lab-upload | error | light | `lab-upload/error--light.png` | none in plan | `flutter_app/test/demo/lab_upload_test.dart` |
| lab-upload | error | dark | `lab-upload/error--dark.png` | none in plan | `flutter_app/test/demo/lab_upload_test.dart` |
| lab-review | loading | light | `lab-review/loading--light.png` | none in plan (no time promise) | `flutter_app/test/demo/lab_review_test.dart` |
| lab-review | loading | dark | `lab-review/loading--dark.png` | none in plan (no time promise) | `flutter_app/test/demo/lab_review_test.dart` |
| lab-review | default | light | `lab-review/default--light.png` | none in plan | `flutter_app/test/demo/lab_review_test.dart`, `flutter_app/test/demo/data/fixtures_test.dart` |
| lab-review | default | dark | `lab-review/default--dark.png` | none in plan | `flutter_app/test/demo/lab_review_test.dart`, `flutter_app/test/demo/data/fixtures_test.dart` |
| lab-review | mismatch | light | `lab-review/mismatch--light.png` | T-LAB-02 | `flutter_app/test/demo/lab_review_test.dart` |
| lab-review | mismatch | dark | `lab-review/mismatch--dark.png` | T-LAB-02 | `flutter_app/test/demo/lab_review_test.dart` |
| lab-review | empty | light | `lab-review/empty--light.png` | none in plan | `flutter_app/test/demo/lab_review_test.dart` |
| lab-review | empty | dark | `lab-review/empty--dark.png` | none in plan | `flutter_app/test/demo/lab_review_test.dart` |
| lab-review | error | light | `lab-review/error--light.png` | none in plan (edits kept on save failure) | `flutter_app/test/demo/lab_review_test.dart`, `flutter_app/test/demo/screens/lab_review_controller_test.dart` |
| lab-review | error | dark | `lab-review/error--dark.png` | none in plan (edits kept on save failure) | `flutter_app/test/demo/lab_review_test.dart`, `flutter_app/test/demo/screens/lab_review_controller_test.dart` |
| lab-review | saved | light | `lab-review/saved--light.png` | none in plan | `flutter_app/test/demo/lab_review_test.dart`, `flutter_app/test/demo/screens/lab_review_controller_test.dart` |
| lab-review | saved | dark | `lab-review/saved--dark.png` | none in plan | `flutter_app/test/demo/lab_review_test.dart`, `flutter_app/test/demo/screens/lab_review_controller_test.dart` |
| lab-trends | loading | light | `lab-trends/loading--light.png` | none in plan | `flutter_app/test/demo/lab_trends_test.dart` |
| lab-trends | loading | dark | `lab-trends/loading--dark.png` | none in plan | `flutter_app/test/demo/lab_trends_test.dart` |
| lab-trends | default | light | `lab-trends/default--light.png` | T-BIO-01 | `flutter_app/test/demo/lab_trends_test.dart`, `flutter_app/test/demo/data/fixtures_test.dart`, `flutter_app/test/demo/widgets/trend_chart_test.dart`, `flutter_app/test/demo/widgets/range_caveat_card_test.dart` |
| lab-trends | default | dark | `lab-trends/default--dark.png` | T-BIO-01 | `flutter_app/test/demo/lab_trends_test.dart`, `flutter_app/test/demo/data/fixtures_test.dart`, `flutter_app/test/demo/widgets/trend_chart_test.dart`, `flutter_app/test/demo/widgets/range_caveat_card_test.dart` |
| lab-trends | above | light | `lab-trends/above--light.png` | T-BIO-02 | `flutter_app/test/demo/lab_trends_test.dart`, `flutter_app/test/demo/widgets/trend_chart_test.dart`, `flutter_app/test/demo/widgets/range_caveat_card_test.dart` |
| lab-trends | above | dark | `lab-trends/above--dark.png` | T-BIO-02 | `flutter_app/test/demo/lab_trends_test.dart`, `flutter_app/test/demo/widgets/trend_chart_test.dart`, `flutter_app/test/demo/widgets/range_caveat_card_test.dart` |
| lab-trends | single | light | `lab-trends/single--light.png` | T-BIO-02 | `flutter_app/test/demo/lab_trends_test.dart`, `flutter_app/test/demo/widgets/trend_chart_test.dart` |
| lab-trends | single | dark | `lab-trends/single--dark.png` | T-BIO-02 | `flutter_app/test/demo/lab_trends_test.dart`, `flutter_app/test/demo/widgets/trend_chart_test.dart` |
| lab-trends | error | light | `lab-trends/error--light.png` | none in plan (cached-data copy) | `flutter_app/test/demo/lab_trends_test.dart` |
| lab-trends | error | dark | `lab-trends/error--dark.png` | none in plan (cached-data copy) | `flutter_app/test/demo/lab_trends_test.dart` |
