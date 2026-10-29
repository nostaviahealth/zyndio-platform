# TC-021 round 1 (item 1) screenshots

Real captures of the preview build (`npm run build:preview`, `#/__preview`
harness, headless Chromium), 1440×900 and 1024×768, light and dark.

- `before/`: main at 548d726. `after/`: this branch.
- `detail-chart--*`: Jordan Rivera's HbA1c trend. Y-axis labels
  5 / 5.5 / 6 / 6.5 before, 5.0 / 5.5 / 6.0 / 6.5 after; "Default range below
  5.7%" legend under the chart in both.
- `detail-error--*`, `roster-error--*`: "Try again" without (before) and with
  (after) the refresh icon.

Each folder has a `SHA256SUMS`. None of the 24 hashes matches any of the
4,107 distinct file hashes under `/workspace/design` (checked Oct 29, 2026), and
no capture is byte-identical to another.
