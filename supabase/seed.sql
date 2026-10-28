-- Local-only seed. Fictional Vault pepper for TC-012 link codes.
-- NEVER put a real production pepper here. Production: create per-env at deploy
-- (see SUPABASE-SETUP.md § Deploy checklist).
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'link_code_pepper') then
    perform vault.create_secret(
      'tc012-local-only-fictional-pepper-not-for-prod',
      'link_code_pepper',
      'LOCAL ONLY fictional pepper — replace per environment at deploy'
    );
  end if;
end $$;
