-- Patient AI memory store (embed-memory / search-memory Edge Functions,
-- flutter_app/lib/services/memory_service.dart).
--
-- Both functions and the app's "AI memories" settings screen used
-- public.chat_memories and public.match_memories, but those only existed in
-- supabase/_legacy/rag_memory_schema.sql, which no tooling applies - so against
-- a schema built from migrations every memory call failed. This is the real
-- definition, reworked to this repo's rules:
--   * rows belong to a patient (FK public.patients, so deleting the patient or
--     their auth user removes their memories);
--   * RLS enabled AND forced; a patient can read and delete only their own rows,
--     with a confirmed email and an active record link (same gate as
--     lab_reports); there is NO client insert/update - rows are written only by
--     embed-memory (service role) after its auth, kill-switch and rate checks;
--   * no "service role has full access" policy (service_role bypasses RLS);
--   * size caps so a caller cannot store unbounded text or metadata;
--   * match_memories is service-role only (not on the TC-040 allowlist), pins
--     search_path, clamps match_count, and only ever reads the given user.
-- Embeddings are 1536-d: embed-memory asks gemini-embedding-001 for 1536
-- dimensions explicitly and rejects any other length.

create extension if not exists vector with schema extensions;

create table if not exists public.chat_memories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.patients (id) on delete cascade,
  content text not null,
  embedding extensions.vector(1536),
  memory_type text not null default 'conversation_summary',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint chat_memories_memory_type_check
    check (memory_type in ('conversation_summary', 'user_fact', 'health_event')),
  constraint chat_memories_content_length_check
    check (char_length(content) between 1 and 4000),
  constraint chat_memories_metadata_object_check
    check (jsonb_typeof(metadata) = 'object'),
  constraint chat_memories_metadata_size_check
    check (pg_column_size(metadata) <= 4096)
);

create index if not exists chat_memories_user_created_idx
  on public.chat_memories (user_id, created_at desc);
create index if not exists chat_memories_embedding_idx
  on public.chat_memories using hnsw (embedding extensions.vector_cosine_ops);

alter table public.chat_memories enable row level security;
alter table public.chat_memories force row level security;

revoke all on public.chat_memories from public, anon, authenticated;
grant select, delete on public.chat_memories to authenticated;
grant all on public.chat_memories to service_role;

drop policy if exists chat_memories_self_select on public.chat_memories;
create policy chat_memories_self_select on public.chat_memories
  for select to authenticated
  using (
    user_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists chat_memories_self_delete on public.chat_memories;
create policy chat_memories_self_delete on public.chat_memories
  for delete to authenticated
  using (
    user_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

create or replace function public.match_memories(
  query_embedding extensions.vector(1536),
  match_user_id uuid,
  match_count int default 5,
  match_threshold double precision default 0.3
)
returns table (
  id uuid,
  content text,
  memory_type text,
  metadata jsonb,
  similarity double precision,
  created_at timestamptz
)
language sql
stable
security invoker
set search_path = pg_catalog, public, extensions
as $$
  select cm.id,
         cm.content,
         cm.memory_type,
         cm.metadata,
         1 - (cm.embedding <=> query_embedding) as similarity,
         cm.created_at
    from public.chat_memories cm
   where cm.user_id = match_user_id
     and cm.embedding is not null
     and 1 - (cm.embedding <=> query_embedding) > match_threshold
   order by cm.embedding <=> query_embedding
   limit least(greatest(coalesce(match_count, 5), 1), 20);
$$;

revoke all on function public.match_memories(extensions.vector, uuid, int, double precision)
  from public, anon, authenticated;
grant execute on function public.match_memories(extensions.vector, uuid, int, double precision)
  to service_role;

comment on table public.chat_memories is
  'Patient AI memories (RAG). Written only by the embed-memory Edge Function; patients read/delete their own rows.';
comment on function public.match_memories(extensions.vector, uuid, int, double precision) is
  'Service-role only: cosine similarity search over one patient''s chat_memories (search-memory Edge Function).';
