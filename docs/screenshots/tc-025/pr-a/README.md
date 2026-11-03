# TC-025 PR A screenshots (5-tab shell, Today, Biomarkers)

Real captures of the production widgets on this branch, not design renders.
`flutter_app/test/tc025/capture_tc025_pr_a_screenshots_test.dart` pumps the real
`MainShell` (5-tab bar) with the real `TodayScreen`, `BiomarkersScreen`,
`ProgressScreen` and `CareScreen` under `BrandTheme` light and dark, at 390×844
logical, DPR 2 (780×1688 PNG), with Inter and Lucide loaded (not Ahem). Data is
fictional and comes in through provider overrides only (profile "Jordan
Rivera", one wearable snapshot, three fictional lab reports).

The capture tests are skipped unless run with `--update-goldens`, so they never
gate CI. Regenerate from `flutter_app/`:

```bash
flutter test test/tc025/capture_tc025_pr_a_screenshots_test.dart --update-goldens
```

Naming: `<screen>-<state>--{light|dark}.png`. Every capture shows the tab bar.

| Screen | States |
|---|---|
| Today | default, no-wearable, offline, loading, error |
| Biomarkers | nad (default, 3-point NAD+ trend), metabolic, hormones-single, empty, loading, error |
| Interim tabs | shell-progress-interim, shell-care-interim |

My Plan (the existing `ProtocolScreen`) is not captured; it is unchanged by PR A.
The greeting follows the capture machine's clock.

`SHA256SUMS` lists all 26 files. Checked 3 Nov 2026: none of the 26 hashes
matches any of the 99 distinct file hashes in
`/workspace/design/team3/zyndio/handoff/tc-025/` or the 5,420 under
`/workspace/design`, and no two captures are byte-identical.
