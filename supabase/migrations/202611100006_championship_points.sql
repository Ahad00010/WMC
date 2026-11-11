-- Points start with races recorded after this migration. Historical match rows do
-- not contain classifications, so reconstructing old points would be inaccurate.
alter table public.wmc_authoritative_stats add column championship_points integer not null default 0 check (championship_points >= 0);

create or replace function public.wmc_record_authoritative_match(match_id uuid,entrants jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare entry jsonb; rank integer:=0; rider uuid; inserted uuid; award integer; points integer[]:=array[25,20,16,13,11,10,9,8,7,6,5,4,3,2,1];
begin
 if auth.role() <> 'service_role' then raise exception 'server only'; end if;
 if match_id is null or jsonb_typeof(entrants)<>'array' or jsonb_array_length(entrants) not between 2 and 15 then raise exception 'invalid result'; end if;
 if (select count(distinct item->>'id') from jsonb_array_elements(entrants) item)<>jsonb_array_length(entrants) then raise exception 'duplicate or missing rider'; end if;
 insert into public.wmc_authoritative_matches(id) values(match_id) on conflict do nothing returning id into inserted;
 if inserted is null then return false; end if;
 for entry in select value from jsonb_array_elements(entrants) loop
  rider:=(entry->>'id')::uuid;
  if rider is null or jsonb_typeof(entry->'dnf')<>'boolean' then raise exception 'invalid rider result'; end if;
  if not (entry->>'dnf')::boolean then rank:=rank+1; award:=coalesce(points[rank],0); else award:=0; end if;
  insert into public.wmc_authoritative_stats(user_id,races,wins,seconds,thirds,championship_points) values(rider,1,case when award>0 and rank=1 then 1 else 0 end,case when award>0 and rank=2 then 1 else 0 end,case when award>0 and rank=3 then 1 else 0 end,award)
  on conflict(user_id) do update set races=public.wmc_authoritative_stats.races+1,wins=public.wmc_authoritative_stats.wins+excluded.wins,seconds=public.wmc_authoritative_stats.seconds+excluded.seconds,thirds=public.wmc_authoritative_stats.thirds+excluded.thirds,championship_points=public.wmc_authoritative_stats.championship_points+excluded.championship_points;
 end loop; return true;
end $$;

drop function public.wmc_lobby_stats();
create function public.wmc_lobby_stats() returns table(id uuid,races integer,wins integer,seconds integer,thirds integer,championship_points integer) language sql stable security definer set search_path='' as $$
 select m.user_id,coalesce(s.races,0),coalesce(s.wins,0),coalesce(s.seconds,0),coalesce(s.thirds,0),coalesce(s.championship_points,0) from public.wmc_lobby_members mine join public.wmc_lobby_members m on m.lobby_id=mine.lobby_id left join public.wmc_authoritative_stats s on s.user_id=m.user_id where mine.user_id=auth.uid();
$$;
-- The recorded flag avoids presenting a stale pre-race total as a final result.
create function public.wmc_session_championship(match_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('recorded',exists(select 1 from public.wmc_authoritative_matches a where a.id=match_id),'riders',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'championship_points',s.championship_points)) from public.wmc_lobby_stats() s),'[]'::jsonb))
 where exists(select 1 from public.wmc_lobby_members m where m.user_id=auth.uid());
$$;
revoke all on function public.wmc_lobby_stats(),public.wmc_session_championship(uuid) from public,anon,authenticated;
grant execute on function public.wmc_lobby_stats(),public.wmc_session_championship(uuid) to authenticated;
