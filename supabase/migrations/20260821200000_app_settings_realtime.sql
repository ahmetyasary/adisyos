-- Live sync for Ordi corner / settings across devices.
alter table public.app_settings replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.app_settings;
exception
  when duplicate_object then null;
end $$;
