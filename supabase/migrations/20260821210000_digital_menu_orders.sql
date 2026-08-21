-- Customer orders placed from the public digital menu (QR), awaiting staff approval.
create table if not exists public.digital_menu_orders (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references auth.users (id) on delete cascade,
  table_id bigint not null,
  table_name text not null default '',
  items jsonb not null default '[]'::jsonb,
  customer_note text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists digital_menu_orders_tenant_status_idx
  on public.digital_menu_orders (tenant_id, status, created_at desc);

create index if not exists digital_menu_orders_tenant_pending_idx
  on public.digital_menu_orders (tenant_id, created_at desc)
  where status = 'pending';

alter table public.digital_menu_orders enable row level security;

drop policy if exists "digital_menu_orders_select_own" on public.digital_menu_orders;
create policy "digital_menu_orders_select_own"
  on public.digital_menu_orders for select
  using (tenant_id = auth.uid());

drop policy if exists "digital_menu_orders_update_own" on public.digital_menu_orders;
create policy "digital_menu_orders_update_own"
  on public.digital_menu_orders for update
  using (tenant_id = auth.uid());

drop policy if exists "digital_menu_orders_delete_own" on public.digital_menu_orders;
create policy "digital_menu_orders_delete_own"
  on public.digital_menu_orders for delete
  using (tenant_id = auth.uid());

-- Inserts come from the edge function (service role); no public insert policy.

alter table public.digital_menu_orders replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.digital_menu_orders;
exception
  when duplicate_object then null;
end $$;
