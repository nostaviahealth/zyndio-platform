# DEXA webhook: proposed measure fields

Zyndio will webhook DEXA scans directly to the platform (see [zyndio-partner-notes.md](./zyndio-partner-notes.md)). This is the field list we propose for the `measures` object, taken from the sections of a DEXAscan body-composition report. The patient Progress tab already labels and groups every key below (`flutter_app/lib/data/dexa_measures.dart`). Unknown keys are still stored and shown as-is, so extra fields do no harm.

Send numbers as plain numbers in the units shown. Leave a field out (don't send `0` or `"-"`) when the scan didn't measure it.

## Scan envelope

| Field | Type | Example (fictional) |
|---|---|---|
| `partner_scan_id` | string, unique per scan | `"scan_000123"` |
| `partner_scan_version` | integer, bump on correction | `1` |
| `partner_patient_id` | string | `"DEX-PAT-000123"` |
| `scan_date` | `YYYY-MM-DD` | `"2026-10-02"` |
| `site_id` | string, optional | `"site-01"` |
| `device_vendor`, `device_model`, `software_version` | strings | `"Vendor"`, `"Model X"`, `"1.0"` |
| `measures` | object, below | |

## `measures`

| Report section | Key | Unit |
|---|---|---|
| Overall | `health_score` | 0–100 |
| | `total_mass_lb` | lb |
| | `weight_lb` | lb |
| | `body_fat_pct` | % |
| | `lean_mass_lb` | lb |
| Muscle index (ALMI) | `almi_kg_m2` | kg/m² |
| | `almi_percentile` | percentile |
| | `almi_z_score`, `almi_t_score` | score |
| | `appendicular_lean_mass_lb` | lb |
| | `lean_mass_index_kg_m2` | kg/m² |
| Fat / visceral | `fat_mass_lb` | lb |
| | `trunk_fat_mass_lb` | lb |
| | `trunk_fat_pct` | % |
| | `vat_area_cm2` | cm² |
| | `visceral_fat_mass_lb` | lb |
| | `visceral_fat` + `visceral_fat_unit` | value + unit string |
| | `fat_mass_index_kg_m2` | kg/m² |
| | `android_gynoid_ratio` | ratio |
| Bone | `bone_t_score`, `bone_z_score` | score |
| | `bone_mineral_density_g_cm2` | g/cm² |
| | `bone_mineral_content_lb` | lb |
| Symmetry | `arm_lean_difference_pct`, `leg_lean_difference_pct` | % |

The outcomes engine (Schedule C) currently reads six of these: `weight_lb`, `fat_mass_lb`, `lean_mass_lb`, `body_fat_pct`, `appendicular_lean_mass_lb`, `visceral_fat`.

Not yet proposed: the per-region table (arms, legs, trunk, head) and the report's own category labels ("Excellent", "Osteopenia"). The app deliberately shows values without clinical categories. If Zyndio wants the regional table, we can agree keys like `region_arm_left_lean_lb`.
