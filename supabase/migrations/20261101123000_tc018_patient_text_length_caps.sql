-- TC-018 (Henry's calls, 1 Nov 2026; Clara PR #23 review finding #2): no
-- length cap on patients.display_name/mrn let a 20MB mrn through the
-- create-patient Edge Function straight into the database. The Edge
-- Function's own cap (added alongside this migration) is the primary
-- defense; this is the DB-level backstop for any other path, present or
-- future, that writes these columns. display_name's 200-char cap matches
-- MAX_FULL_NAME_LENGTH, already enforced for every other full-name field
-- (invite-user, create-patient); mrn's 64-char cap is generous for
-- real-world medical record number formats while still blocking abuse.
alter table public.patients
  add constraint patients_display_name_length check (char_length(display_name) <= 200),
  add constraint patients_mrn_length check (char_length(mrn) <= 64);
