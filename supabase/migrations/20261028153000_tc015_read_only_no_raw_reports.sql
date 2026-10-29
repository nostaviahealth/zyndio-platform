-- TC-015 fix round (Leo ruling, 28 Oct, supersedes the fix-round migration
-- 20261028150000): read_only gets the roster, the detail (header + treatment
-- whitelist) and the Labs tab data (lab_results, trends, latest) - NOT the
-- raw lab_reports rows/`data` (the report viewer is TC-016). Henry's H2
-- ruling stands for lab_reports (also patient_profiles, consents). This
-- drops the read_only SELECT policy added in 20261028150000; the identity-
-- hold exclusion that depended on it is made independent of lab_reports
-- access in the next migration (20261028154000).
drop policy lab_reports_staff_read_only_select on public.lab_reports;
