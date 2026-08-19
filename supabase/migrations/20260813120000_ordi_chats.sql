-- Ordi AI assistant chat history.
--
-- One row per message. Scoped by `tenant_id` (= auth.uid()) exactly like every
-- other table in the schema, so history syncs across the tenant's devices and
-- is invisible to everyone else.
--
-- Apply with `supabase db push`, or paste into the Supabase SQL editor.

create table if not exists public.ordi_chats (
  id         uuid        primary key default gen_random_uuid(),
  tenant_id  uuid        not null references auth.users(id) on delete cascade,
  role       text        not null check (role in ('user', 'assistant')),
  content    text        not null check (char_length(content) <= 8000),
  -- Which brain produced an assistant message: 'gemini' | 'local' | 'error'.
  -- Null for user messages.
  source     text,
  created_at timestamptz not null default now()
);

-- Every read is "this tenant's messages, oldest → newest", and the edge
-- function's daily quota check is "this tenant's messages since midnight".
create index if not exists ordi_chats_tenant_created_idx
  on public.ordi_chats (tenant_id, created_at);

alter table public.ordi_chats enable row level security;

drop policy if exists ordi_chats_select on public.ordi_chats;
create policy ordi_chats_select on public.ordi_chats
  for select using (tenant_id = auth.uid());

drop policy if exists ordi_chats_insert on public.ordi_chats;
create policy ordi_chats_insert on public.ordi_chats
  for insert with check (tenant_id = auth.uid());

drop policy if exists ordi_chats_delete on public.ordi_chats;
create policy ordi_chats_delete on public.ordi_chats
  for delete using (tenant_id = auth.uid());

-- Keep the table bounded: drop messages older than 30 days on every insert
-- for the inserting tenant. Cheap (index-backed) and avoids needing pg_cron.
create or replace function public.ordi_chats_prune()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.ordi_chats
   where tenant_id = new.tenant_id
     and created_at < now() - interval '30 days';
  return null;
end;
$$;

drop trigger if exists ordi_chats_prune_trg on public.ordi_chats;
create trigger ordi_chats_prune_trg
  after insert on public.ordi_chats
  for each row execute function public.ordi_chats_prune();
