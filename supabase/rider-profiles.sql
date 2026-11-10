-- Run once in the Supabase SQL Editor for your own project.
create table if not exists public.rider_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name text not null check (char_length(display_name) between 3 and 15 and display_name ~ '^\S+ \S+( .*\S)?$'),
  rider_number integer not null check (rider_number between 10 and 99),
  plate_color text not null check (plate_color in ('blue','red','yellow','orange','green','cyan','purple','pink','white','black','silver'))
);
alter table public.rider_profiles enable row level security;
grant select, insert, update on public.rider_profiles to authenticated;
create policy "Read own profile" on public.rider_profiles for select to authenticated using (auth.uid() = id);
create policy "Create own profile" on public.rider_profiles for insert to authenticated with check (auth.uid() = id);
create policy "Update own profile" on public.rider_profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
