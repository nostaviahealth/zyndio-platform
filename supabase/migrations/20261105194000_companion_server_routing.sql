-- PR #37 review: the server decides whether an escalation is an emergency.
-- A client that files emergency language as clinical_question still alerts.
-- A client that labels ordinary text as emergency does not. The alert
-- trigger already runs only when the stored kind is emergency, and it still
-- writes an id-only payload.

create or replace function public.companion_escalations_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v text := lower(coalesce(new.question, ''));
  phrases text[] := array[
    'chest pain', 'chest hurts', 'heart attack', 'stroke',
    'kill myself', 'end my life', 'hurt myself', 'self-harm', 'self harm',
    'want to die', 'bleeding out', 'unconscious', 'seizure',
    'can''t breathe', 'cannot breathe', 'trouble breathing',
    'can''t catch my breath', 'cannot catch my breath', 'shortness of breath',
    'took all my pills', 'emergency'
  ];
  p text;
  pos int;
  before text;
  emergency boolean := false;
begin
  if v ~ 'suicid' or v ~ 'anaphyla' or v ~ 'overdos' then
    emergency := true;
  else
    foreach p in array phrases loop
      pos := position(p in v);
      if pos = 0 then
        continue;
      end if;
      if p like 'can''t%' or p like 'cannot%' then
        emergency := true;
        exit;
      end if;
      before := substring(v from 1 for pos - 1);
      if before ~ '(no|not|without|never|don''t|do not|doesn''t|does not)[[:space:]]+([^[:space:]]+[[:space:]]+){0,4}$' then
        continue;
      end if;
      emergency := true;
      exit;
    end loop;
  end if;

  if emergency then
    new.kind := 'emergency';
  elsif new.kind = 'emergency' then
    new.kind := 'clinical_question';
  end if;

  new.org_id := (select p.org_id from public.patients p where p.id = new.patient_id);
  new.status := 'open';
  new.resolved_at := null;
  new.resolved_by := null;
  new.created_at := now();
  return new;
end;
$$;

revoke all on function public.companion_escalations_before_insert() from public, anon, authenticated;
