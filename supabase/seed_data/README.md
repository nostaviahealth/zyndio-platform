# common-passwords-10k.txt

Source: SecLists, `Passwords/Common-Credentials/10k-most-common.txt`
<https://github.com/danielmiessler/SecLists>

Fetched (read-only, one-off, via `node --eval 'fetch(...)'`) from:
<https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/Common-Credentials/10k-most-common.txt>

Licence: MIT (SecLists is dual MIT / CC BY-SA 4.0 for data files; the
author's `LICENSE` grants MIT terms project-wide). Used here as the real
replacement for the TC-005 generated stopgap list (see
`supabase/migrations/20261026160100_tc005_review_group_b_blocklist.sql`),
per TC-011 M3.

Kept in-repo only as the documented source of record for the blocklist; the
migration (`supabase/migrations/20261027120000_tc011_real_password_blocklist.sql`)
embeds the same 10,000 entries directly (not a `COPY ... FROM` against this
file), so `supabase db reset` doesn't depend on this path being mounted
inside the Postgres container.
