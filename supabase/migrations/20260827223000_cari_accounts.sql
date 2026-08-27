-- Current accounts hold table bills until they are paid.
create table if not exists public.cari_accounts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create unique index if not exists cari_accounts_tenant_name_idx
  on public.cari_accounts (tenant_id, lower(name));

create table if not exists public.cari_transactions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references auth.users (id) on delete cascade,
  account_id uuid not null references public.cari_accounts (id) on delete cascade,
  table_name text not null default '',
  items jsonb not null default '[]'::jsonb,
  subtotal numeric(12, 2) not null default 0,
  discount numeric(12, 2) not null default 0,
  total numeric(12, 2) not null default 0,
  staff_email text not null default '',
  status text not null default 'open'
    check (status in ('open', 'paid')),
  payment_method text,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

create index if not exists cari_transactions_account_idx
  on public.cari_transactions (tenant_id, account_id, created_at desc);

create index if not exists cari_transactions_open_idx
  on public.cari_transactions (tenant_id, status, created_at desc);

alter table public.cari_accounts enable row level security;
alter table public.cari_transactions enable row level security;

drop policy if exists "cari_accounts_select_own" on public.cari_accounts;
create policy "cari_accounts_select_own"
  on public.cari_accounts for select
  using (tenant_id = auth.uid());

drop policy if exists "cari_accounts_insert_own" on public.cari_accounts;
create policy "cari_accounts_insert_own"
  on public.cari_accounts for insert
  with check (tenant_id = auth.uid());

drop policy if exists "cari_accounts_update_own" on public.cari_accounts;
create policy "cari_accounts_update_own"
  on public.cari_accounts for update
  using (tenant_id = auth.uid())
  with check (tenant_id = auth.uid());

drop policy if exists "cari_accounts_delete_own" on public.cari_accounts;
create policy "cari_accounts_delete_own"
  on public.cari_accounts for delete
  using (tenant_id = auth.uid());

drop policy if exists "cari_transactions_select_own" on public.cari_transactions;
create policy "cari_transactions_select_own"
  on public.cari_transactions for select
  using (tenant_id = auth.uid());

drop policy if exists "cari_transactions_insert_own" on public.cari_transactions;
create policy "cari_transactions_insert_own"
  on public.cari_transactions for insert
  with check (
    tenant_id = auth.uid()
    and exists (
      select 1
      from public.cari_accounts a
      where a.id = account_id
        and a.tenant_id = auth.uid()
    )
  );

drop policy if exists "cari_transactions_update_own" on public.cari_transactions;
create policy "cari_transactions_update_own"
  on public.cari_transactions for update
  using (tenant_id = auth.uid())
  with check (tenant_id = auth.uid());

drop policy if exists "cari_transactions_delete_own" on public.cari_transactions;
create policy "cari_transactions_delete_own"
  on public.cari_transactions for delete
  using (tenant_id = auth.uid());

alter table public.cari_accounts replica identity full;
alter table public.cari_transactions replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.cari_accounts;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.cari_transactions;
exception
  when duplicate_object then null;
end $$;
