-- Authoritative stats use a separate table from the old client-reported prototype.
create table public.wmc_authoritative_matches (id uuid primary key, recorded_at timestamptz not null default now());
create table public.wmc_authoritative_stats (user_id uuid primary key references public.rider_profiles(id) on delete cascade, races integer not null default 0, wins integer not null default 0, seconds integer not null default 0, thirds integer not null default 0);
alter table public.wmc_authoritative_matches enable row level security;
alter table public.wmc_authoritative_stats enable row level security;
revoke all on public.wmc_authoritative_matches,public.wmc_authoritative_stats from public,anon,authenticated;
create function public.wmc_record_authoritative_match(match_id uuid,entrants jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare entry jsonb; rank integer:=0; rider uuid; inserted uuid;
begin
 if auth.role() <> 'service_role' then raise exception 'server only'; end if;
 if match_id is null or jsonb_typeof(entrants)<>'array' or jsonb_array_length(entrants) not between 2 and 15 then raise exception 'invalid result'; end if;
 if (select count(distinct item->>'id') from jsonb_array_elements(entrants) item)<>jsonb_array_length(entrants) then raise exception 'duplicate or missing rider'; end if;
 insert into public.wmc_authoritative_matches(id) values(match_id) on conflict do nothing returning id into inserted;
 if inserted is null then return false; end if;
 for entry in select value from jsonb_array_elements(entrants) loop
  rider:=(entry->>'id')::uuid;
  if rider is null or jsonb_typeof(entry->'dnf')<>'boolean' then raise exception 'invalid rider result'; end if;
  if not (entry->>'dnf')::boolean then rank:=rank+1; end if;
  insert into public.wmc_authoritative_stats(user_id,races,wins,seconds,thirds) values(rider,1,case when not (entry->>'dnf')::boolean and rank=1 then 1 else 0 end,case when not (entry->>'dnf')::boolean and rank=2 then 1 else 0 end,case when not (entry->>'dnf')::boolean and rank=3 then 1 else 0 end)
  on conflict(user_id) do update set races=public.wmc_authoritative_stats.races+1,wins=public.wmc_authoritative_stats.wins+excluded.wins,seconds=public.wmc_authoritative_stats.seconds+excluded.seconds,thirds=public.wmc_authoritative_stats.thirds+excluded.thirds;
 end loop; return true;
end $$;
create function public.wmc_lobby_stats() returns table(id uuid,races integer,wins integer,seconds integer,thirds integer) language sql stable security definer set search_path='' as $$
 select m.user_id,coalesce(s.races,0),coalesce(s.wins,0),coalesce(s.seconds,0),coalesce(s.thirds,0) from public.wmc_lobby_members mine join public.wmc_lobby_members m on m.lobby_id=mine.lobby_id left join public.wmc_authoritative_stats s on s.user_id=m.user_id where mine.user_id=auth.uid();
$$;
revoke all on function public.wmc_record_authoritative_match(uuid,jsonb),public.wmc_lobby_stats() from public,anon,authenticated;
grant execute on function public.wmc_record_authoritative_match(uuid,jsonb) to service_role;
grant execute on function public.wmc_lobby_stats() to authenticated;
