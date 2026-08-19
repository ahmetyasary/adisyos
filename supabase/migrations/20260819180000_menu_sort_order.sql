-- Persistent display order for menu categories and items.
-- Menu management, table ordering, and stock screens all read this order.

alter table public.menus
  add column if not exists sort_order integer not null default 0;

alter table public.menu_items
  add column if not exists sort_order integer not null default 0;

update public.menus m
set sort_order = s.rn - 1
from (
  select id, row_number() over (partition by tenant_id order by id) as rn
  from public.menus
) s
where m.id = s.id;

update public.menu_items i
set sort_order = s.rn - 1
from (
  select id, row_number() over (partition by menu_id order by id) as rn
  from public.menu_items
) s
where i.id = s.id;

create index if not exists menus_tenant_sort_idx
  on public.menus (tenant_id, sort_order);

create index if not exists menu_items_menu_sort_idx
  on public.menu_items (menu_id, sort_order);
