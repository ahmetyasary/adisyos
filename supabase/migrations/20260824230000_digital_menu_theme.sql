-- Digital menu public appearance: system | light | dark
alter table public.digital_menu_config
  add column if not exists theme_mode text not null default 'system';

alter table public.digital_menu_config
  drop constraint if exists digital_menu_config_theme_mode_check;

alter table public.digital_menu_config
  add constraint digital_menu_config_theme_mode_check
  check (theme_mode in ('system', 'light', 'dark'));
