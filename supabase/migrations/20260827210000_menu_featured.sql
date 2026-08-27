-- Optional customer-facing highlight badge for digital menu categories.
alter table public.menus
  add column if not exists is_featured boolean not null default false;
