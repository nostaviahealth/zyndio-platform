# TC-021: roster summary maintenance notes

## Item 16: bulk lab-result loads rebuild the summary row by row (Low, known)

Migration `supabase/migrations/20261029150000_tc021_roster_flag_latest_per_marker.sql`
(item 5) replaced the two refresh functions. The maintenance triggers are
unchanged from `20261028160000_tc015_roster_summary.sql`.
`trg_lab_results_roster_summary` is `FOR EACH ROW`, so every inserted, updated or
deleted `lab_results` row calls `refresh_roster_summary(patient_id)` once. That
call recomputes that patient's whole rollup from `patient_latest_results`.

- **Cost:** a bulk insert does N patient rebuilds, even when many rows belong to
  the same patient. Clara measured this in her #18 review: **45,000 rows took
  ≈25.7 s**.
- **Read path is unaffected:** the roster still reads `patient_roster_summary` by
  primary key, so the 200 ms at 5,000 patients budget holds.
- **Decision (Henry, 29 Oct):** Low priority and not needed before 7 Nov. Don't
  change it now. Switch to a statement-level trigger, `FOR EACH STATEMENT` with a
  `REFERENCING NEW/OLD TABLE` transition table, that refreshes each distinct
  patient once. Only do this if a card is written for a lab-result importer or
  bulk-load path.
