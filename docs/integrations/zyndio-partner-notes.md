# Zyndio partner notes (from Brett Hudson, Oct–Nov 2026)

What Zyndio has told us about integrations and design, so it lives with the code. Source: emails to the development team, 30 Oct – 2 Nov 2026.

## Integrations still to come from Zyndio

| What | How it arrives | Status |
|---|---|---|
| **DEXA scans** (DEXAscan body-composition reports) | Webhook from the scan provider straight to the platform | Zyndio will send the webhook details **once the UI is complete**. Proposed field list: [dexa-webhook-fields.md](./dexa-webhook-fields.md). |
| **NAD cellular biomarkers** | An API from the provider to the platform | Zyndio has the API documentation ready and will share it **once the UI is complete**. |

Nothing can be connected until those details arrive. The platform already stores DEXA scans (`body_composition_scans`, one row per partner scan, measures as JSON) and shows them on the patient Progress tab.

## Design direction

Zyndio prefers its "Zyndio AI" mockup: five screens matching the app's tabs (Today with a score ring, Body Composition, Biomarkers, My Plan, My Care), with a purple-to-blue gradient on navy. The in-app TC-025 screens follow it. They also referred to a "Zyndio AI handoff (face centred)" PDF; it is not in this repo.

Brand files are in [design/brand](../../design/brand/README.md).

## Sample DEXA report

Zyndio sent a sample DEXAscan report showing what a report contains. It names a person and their date of birth, so it is treated as real patient data and **is not stored in this repo** (CLAUDE.md: fictional data only). Only its structure was used: the sections and fields listed in [dexa-webhook-fields.md](./dexa-webhook-fields.md).
