-- Ensure digital_menu_config changes reach other signed-in devices.
alter table public.digital_menu_config replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.digital_menu_config;
exception
  when duplicate_object then null;
end $$;
