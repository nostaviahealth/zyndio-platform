-- TC-030 item 3 (Clara PR #25 M4): patient_accounts had no length/size limits on
-- name or avatar_url, so a 20,000-char name and a 4 MB base64 avatar data URI
-- were accepted (204). Add DB-level CHECK constraints as the backstop behind the
-- Flutter UI's own caps (the UI caps are reported as needed follow-up; another
-- agent owns the Flutter toolchain). PostgREST is the only "API" that writes
-- these columns - there is no edge function in the write path - so these CHECKs
-- are also the API-layer enforcement: a rejected INSERT/UPDATE comes back as a
-- 400 with SQLSTATE 23514.
--
-- name: display name capped at 80 characters (card item 3). char_length (not
-- octet_length) so the cap counts user-perceived characters, matching an 80-char
-- UI maxLength.
--
-- avatar_url: patients store the avatar inline as a base64 `data:image/...;base64,`
-- URI (patient_provider.dart updateAvatar), so "max 2 MB with a type check" maps
-- to two CHECKs: (1) if the value is a data: URI it must be an image/* one, and
-- (2) its total length is capped so a 2 MB *image* can't blow past the limit.
-- Base64 inflates bytes ~4/3, plus the `data:image/<subtype>;base64,` prefix, so
-- a 2 MB image serializes to roughly 2 MB * 4 / 3 ~= 2.80 MB of text; 3 MB
-- (3145728 chars) is a deliberately comfortable ceiling that still rejects the
-- 4 MB *image* (~5.6 MB of text) Clara flagged, while leaving headroom for a
-- plain https:// avatar URL (always far under the cap). Non-data URLs are only
-- subject to the length cap, not the image/* check, so a social-login
-- https://...jpg avatar (patient_provider.dart social sync) still passes.
--
-- Constraints are NOT VALID-free (added plain) because the table has no
-- pre-existing oversized rows in any environment (the feature shipped in TC-026
-- on the same branch train and no production data exists - .env.example has no
-- hosted project). If that ever changes, add them NOT VALID + VALIDATE instead.
--
-- Down path: `alter table public.patient_accounts
--   drop constraint patient_accounts_name_len,
--   drop constraint patient_accounts_avatar_url_len,
--   drop constraint patient_accounts_avatar_data_uri_is_image;`

alter table public.patient_accounts
  add constraint patient_accounts_name_len
    check (name is null or char_length(name) <= 80),
  add constraint patient_accounts_avatar_url_len
    check (avatar_url is null or char_length(avatar_url) <= 3145728),
  add constraint patient_accounts_avatar_data_uri_is_image
    check (
      avatar_url is null
      or avatar_url not like 'data:%'
      or avatar_url like 'data:image/%'
    );
