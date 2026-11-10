-- Limit new lobbies and legacy match starts without deleting existing members.
create or replace function public.wmc_lobby_action(action text, params jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); lid uuid; host uuid; target uuid; inv public.wmc_lobby_invites%rowtype; cnt integer; m text;
begin
 if me is null or not exists(select 1 from public.rider_profiles where id=me) then raise exception 'Sign in and complete your profile first'; end if;
 if action='create' then
   m:=params->>'mode'; if m is null or m not in ('race','qualifying_race') then raise exception 'Invalid mode'; end if;
   if exists(select 1 from public.wmc_lobby_members where user_id=me) then raise exception 'Leave your current lobby first'; end if;
   insert into public.wmc_lobbies(host_id,mode) values(me,m) returning id into lid;
   insert into public.wmc_lobby_members(lobby_id,user_id) values(lid,me);
 elsif action='leave' then
   select lobby_id into lid from public.wmc_lobby_members where user_id=me;
   if lid is null then return jsonb_build_object('ok',true); end if;
   select host_id into host from public.wmc_lobbies where id=lid for update;
   if host=me then delete from public.wmc_lobbies where id=lid; else delete from public.wmc_lobby_members where lobby_id=lid and user_id=me; end if;
 elsif action='invite' then
   select l.id,l.host_id into lid,host from public.wmc_lobbies l join public.wmc_lobby_members x on x.lobby_id=l.id where x.user_id=me for update of l;
   if lid is null or host<>me then raise exception 'Only the lobby host can invite'; end if;
   select id into target from public.rider_profiles where username=lower(trim(params->>'username'));
   if target is null or not exists(select 1 from public.wmc_friendships f where f.accepted and ((f.requester=me and f.recipient=target) or (f.recipient=me and f.requester=target))) then raise exception 'You can only invite accepted friends'; end if;
   if exists(select 1 from public.wmc_lobby_members where user_id=target) then raise exception 'That rider is already in a lobby'; end if;
   select count(*) into cnt from public.wmc_lobby_members where lobby_id=lid; if cnt>=10 then raise exception 'Lobby is full'; end if;
   delete from public.wmc_lobby_invites where lobby_id=lid and recipient=target;
   insert into public.wmc_lobby_invites(lobby_id,sender,recipient) values(lid,me,target);
 elsif action in ('accept','decline') then
   select * into inv from public.wmc_lobby_invites where id=(params->>'invite_id')::uuid and recipient=me for update;
   if inv.id is null then raise exception 'Invite no longer available'; end if;
   if action='decline' then delete from public.wmc_lobby_invites where id=inv.id; return jsonb_build_object('ok',true); end if;
   if inv.expires_at<=now() then raise exception 'Invite expired'; end if;
   select l.id into lid from public.wmc_lobbies l where l.id=inv.lobby_id for update;
   if lid is null then raise exception 'Lobby closed'; end if;
   if exists(select 1 from public.wmc_lobby_members where user_id=me) then raise exception 'Leave your current lobby first'; end if;
   select count(*) into cnt from public.wmc_lobby_members where lobby_id=lid; if cnt>=10 then raise exception 'Lobby is full'; end if;
   insert into public.wmc_lobby_members(lobby_id,user_id) values(lid,me);
   delete from public.wmc_lobby_invites where recipient=me;
 else raise exception 'Unknown lobby action'; end if;
 return jsonb_build_object('ok',true,'lobby_id',lid);
end; $$;

create or replace function public.wmc_match_start() returns void language plpgsql security definer set search_path='' as $$
declare me uuid:=auth.uid(); lobbyrec public.wmc_lobbies%rowtype; n integer;
begin
 select lobby_row.* into lobbyrec from public.wmc_lobbies lobby_row join public.wmc_lobby_members m on m.lobby_id=lobby_row.id where m.user_id=me for update of lobby_row;
 if lobbyrec.id is null or lobbyrec.host_id<>me then raise exception 'Only the host can start'; end if;
 if lobbyrec.phase<>'lobby' then raise exception 'Match already started'; end if;
 select count(*) into n from public.wmc_lobby_members where lobby_id=lobbyrec.id;
 if n<2 or n>10 then raise exception 'A race needs 2 to 10 riders'; end if;
 update public.wmc_lobbies set phase=case when mode='race' then 'race' else 'qualifying' end, phase_start=now()+interval '22 seconds' where id=lobbyrec.id;
 with ranking as (select user_id,row_number() over(order by random()) as r from public.wmc_lobby_members where lobby_id=lobbyrec.id)
 update public.wmc_lobby_members m set grid_position=ranking.r,completed=false,finish_at=null,best_time=null,progress=0,pos_x=null,pos_z=null,updated_at=now() from ranking where m.lobby_id=lobbyrec.id and m.user_id=ranking.user_id;
 delete from public.wmc_lobby_invites where lobby_id=lobbyrec.id;
end $$;

-- Enforce capacity even if another insertion path is added later. The lobby
-- row lock serializes concurrent accepts; do not evict existing members.
create or replace function public.wmc_match_join_guard() returns trigger
language plpgsql security definer set search_path='' as $$
declare lobby_phase text;
begin
 select phase into lobby_phase from public.wmc_lobbies where id=new.lobby_id for update;
 if lobby_phase <> 'lobby' then raise exception 'Match already started'; end if;
 if (select count(*) from public.wmc_lobby_members where lobby_id=new.lobby_id) >= 10 then
   raise exception 'Lobby is full (maximum 10 riders)';
 end if;
 return new;
end $$;
