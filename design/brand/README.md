# Zyndio brand pack

Official brand files supplied by Zyndio (Brett Hudson), received 8 Nov 2026 as `Zyndio Brand.zip`.

| File | Size | Use |
|---|---|---|
| `zyndio-mark.png` | 1254×1254 | Master Z mark (DNA helix), transparent |
| `zyndio-mark-512.png` | 512×512 | Mark, transparent |
| `zyndio-mark-rounded-512.png` | 512×512 | Mark on a rounded tile |
| `zyndio-mark-180.png` | 180×180 | Mark; identical to `flutter_app/assets/icons/zyndio-mark.png` used in the app |
| `zyndio-logo-wide.png` | 7269×1254 | Horizontal lockup: mark + "ZYNDIO" + "PHYSICIAN - LED TELEHEALTH CARE" |

## Colours sampled from the mark

| Role | Hex | Notes |
|---|---|---|
| Navy | `#031943` | The Z bars |
| Blue | `#0D78EE` / `#12A9EF` | Helix, upper |
| Teal | `#0E839C` | Helix, lower |

The app uses `#0962C0` as its light-theme brand blue: the mark's blue deepened so text and buttons meet WCAG AA (≥ 5.0:1 on every background, 6.0:1 for white text). Dark theme uses `#4FB8F2`. See `flutter_app/lib/config/theme.dart`.

## Tagline

`PHYSICIAN-LED TELEHEALTH CARE`, shown under the wordmark on the patient sign-in screens. It replaces the placeholder "GLP-1 WEIGHT LOSS CARE".

App launcher icons are pinned separately (`scripts/app-icons.sha256`, TC-023) and were already made from this mark. Don't edit them by hand.
