# TC-008 demo screenshot index

One row per PNG under `docs/screenshots/tc-008/<screen>/<state>--<light|dark>.png`. Test/check IDs are from
`/workspace/techteam/team3/projects/zyndio/docs/TC-008_TEST_PLAN.md`. "none in plan" means the state has no
test-plan ID of its own (it's still covered by a widget test in the file listed).

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
