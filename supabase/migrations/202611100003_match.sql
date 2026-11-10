-- Prototype match coordination. Physics and reported laps are client-authoritative.
alter table public.wmc_lobbies add column phase text not null default 'lobby' check (phase in ('lobby','qualifying','race','complete'));
alter table public.wmc_lobbies add column phase_start timestamptz;
alter table public.wmc_lobby_members add column grid_position integer;
alter table public.wmc_lobby_members add column pos_x double precision;
alter table public.wmc_lobby_members add column pos_z double precision;
alter table public.wmc_lobby_members add column heading double precision;
alter table public.wmc_lobby_members add column progress double precision not null default 0;
alter table public.wmc_lobby_members add column best_time double precision;
alter table public.wmc_lobby_members add column completed boolean not null default false;
alter table public.wmc_lobby_members add column finish_at timestamptz;
alter table public.wmc_lobby_members add column updated_at timestamptz;
create table public.wmc_rider_stats (user_id uuid primary key references public.rider_profiles(id) on delete cascade, races integer not null default 0, wins integer not null default 0, podiums integer not null default 0);
alter table public.wmc_rider_stats enable row level security;
revoke all on public.wmc_rider_stats from anon,authenticated;

create function public.wmc_match_start() returns void language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); lobbyrec public.wmc_lobbies%rowtype; n integer;
begin
 select lobby_row.* into lobbyrec from public.wmc_lobbies lobby_row join public.wmc_lobby_members m on m.lobby_id=lobby_row.id where m.user_id=me for update of lobby_row;
 if lobbyrec.id is null or lobbyrec.host_id<>me then raise exception 'Only the host can start'; end if;
 if lobbyrec.phase<>'lobby' then raise exception 'Match already started'; end if;
 select count(*) into n from public.wmc_lobby_members where lobby_id=lobbyrec.id;
 if n<2 or n>15 then raise exception 'A race needs 2 to 15 riders'; end if;
 update public.wmc_lobbies set phase=case when mode='race' then 'race' else 'qualifying' end, phase_start=now()+interval '22 seconds' where id=lobbyrec.id;
 with ranking as (select user_id,row_number() over(order by random()) as r from public.wmc_lobby_members where lobby_id=lobbyrec.id)
 update public.wmc_lobby_members m set grid_position=ranking.r,completed=false,finish_at=null,best_time=null,progress=0,pos_x=null,pos_z=null,updated_at=now() from ranking where m.lobby_id=lobbyrec.id and m.user_id=ranking.user_id;
 delete from public.wmc_lobby_invites where lobby_id=lobbyrec.id;
end $$;

-- A lock prevents joining an active match via an old invitation.
create function public.wmc_match_join_guard() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.wmc_lobbies where id=new.lobby_id and phase<>'lobby') then raise exception 'Match already started'; end if;
 return new;
end $$;
create trigger wmc_match_join_guard before insert on public.wmc_lobby_members for each row execute function public.wmc_match_join_guard();

create function public.wmc_match_tick(report jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); lobbyrec public.wmc_lobbies%rowtype; best double precision; complete boolean; n integer; members jsonb;
begin
 select lobby_row.* into lobbyrec from public.wmc_lobbies lobby_row join public.wmc_lobby_members m on m.lobby_id=lobby_row.id where m.user_id=me for update of lobby_row;
 if lobbyrec.id is null then raise exception 'Not in a lobby'; end if;
 if lobbyrec.phase in ('race','qualifying') and now()>=lobbyrec.phase_start then
   best:=nullif(report->>'best','')::double precision;
   if best is not null and (best<30 or best>3600) then best:=null; end if;
   complete:=coalesce((report->>'completed')::boolean,false);
   update public.wmc_lobby_members set
     pos_x=case when abs(coalesce((report->>'x')::double precision,1e9))<10000 then (report->>'x')::double precision else pos_x end,
     pos_z=case when abs(coalesce((report->>'z')::double precision,1e9))<10000 then (report->>'z')::double precision else pos_z end,
     heading=case when abs(coalesce((report->>'h')::double precision,1e9))<1000 then (report->>'h')::double precision else heading end,
     progress=greatest(progress,least(6,greatest(0,coalesce((report->>'progress')::double precision,0)))),
     best_time=case when lobbyrec.phase='qualifying' and best is not null then least(coalesce(best_time,best),best) else best_time end,
     completed=completed or complete,
     finish_at=case when lobbyrec.phase='race' and complete and finish_at is null then now() else finish_at end,
     updated_at=now() where lobby_id=lobbyrec.id and user_id=me;
   select count(*) into n from public.wmc_lobby_members where lobby_id=lobbyrec.id and not completed;
   if n=0 and lobbyrec.phase='qualifying' then
     with ranking as (select user_id,row_number() over(order by best_time asc nulls last,grid_position) as r from public.wmc_lobby_members where lobby_id=lobbyrec.id)
     update public.wmc_lobby_members m set grid_position=ranking.r,completed=false,finish_at=null,progress=0,pos_x=null,pos_z=null from ranking where m.lobby_id=lobbyrec.id and m.user_id=ranking.user_id;
     update public.wmc_lobbies set phase='race',phase_start=now()+interval '15 seconds' where id=lobbyrec.id returning * into lobbyrec;
   elsif n=0 and lobbyrec.phase='race' then
     with ranked as (select user_id,row_number() over(order by finish_at,user_id) as rank from public.wmc_lobby_members where lobby_id=lobbyrec.id)
     insert into public.wmc_rider_stats(user_id,races,wins,podiums) select user_id,1,case when rank=1 then 1 else 0 end,case when rank<=3 then 1 else 0 end from ranked
     on conflict(user_id) do update set races=public.wmc_rider_stats.races+1,wins=public.wmc_rider_stats.wins+excluded.wins,podiums=public.wmc_rider_stats.podiums+excluded.podiums;
     update public.wmc_lobbies set phase='complete' where id=lobbyrec.id returning * into lobbyrec;
   end if;
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',m.user_id,'username',p.username,'display_name',p.display_name,'number',p.rider_number,'color',p.plate_color,'grid',m.grid_position,'x',m.pos_x,'z',m.pos_z,'h',m.heading,'progress',m.progress,'best',m.best_time,'completed',m.completed,'finish_at',m.finish_at,'wins',coalesce(s.wins,0),'podiums',coalesce(s.podiums,0),'races',coalesce(s.races,0)) order by m.grid_position),'[]'::jsonb) into members
 from public.wmc_lobby_members m join public.rider_profiles p on p.id=m.user_id left join public.wmc_rider_stats s on s.user_id=m.user_id where m.lobby_id=lobbyrec.id;
 return jsonb_build_object('id',lobbyrec.id,'phase',lobbyrec.phase,'mode',lobbyrec.mode,'phase_start',lobbyrec.phase_start,'server_time',now(),'user_id',me,'members',members);
end $$;
revoke all on function public.wmc_match_start(),public.wmc_match_tick(jsonb),public.wmc_match_join_guard() from public,anon,authenticated;
grant execute on function public.wmc_match_start(),public.wmc_match_tick(jsonb) to authenticated;
