-- Digital menu: public QR link for selected menus (no auth for viewers).
-- Admin configures which menu categories appear; edge function serves HTML.

create table if not exists public.digital_menu_config (
  tenant_id  uuid primary key references auth.users(id) on delete cascade,
  token      text not null unique,
  menu_ids   integer[] not null default '{}',
  enabled    boolean not null default true,
  updated_at timestamptz not null default now()
);

create index if not exists digital_menu_config_token_idx
  on public.digital_menu_config (token);

alter table public.digital_menu_config enable row level security;

drop policy if exists digital_menu_config_select on public.digital_menu_config;
create policy digital_menu_config_select on public.digital_menu_config
  for select using (tenant_id = auth.uid());

drop policy if exists digital_menu_config_insert on public.digital_menu_config;
create policy digital_menu_config_insert on public.digital_menu_config
  for insert with check (tenant_id = auth.uid());

drop policy if exists digital_menu_config_update on public.digital_menu_config;
create policy digital_menu_config_update on public.digital_menu_config
  for update using (tenant_id = auth.uid()) with check (tenant_id = auth.uid());

drop policy if exists digital_menu_config_delete on public.digital_menu_config;
create policy digital_menu_config_delete on public.digital_menu_config
  for delete using (tenant_id = auth.uid());
