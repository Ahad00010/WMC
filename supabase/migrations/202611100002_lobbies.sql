create table public.wmc_lobbies (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.rider_profiles(id) on delete cascade,
  mode text not null check (mode in ('race','qualifying_race')),
  created_at timestamptz not null default now()
);
create table public.wmc_lobby_members (
  lobby_id uuid not null references public.wmc_lobbies(id) on delete cascade,
  user_id uuid not null unique references public.rider_profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key(lobby_id,user_id)
);
create table public.wmc_lobby_invites (
  id uuid primary key default gen_random_uuid(),
  lobby_id uuid not null references public.wmc_lobbies(id) on delete cascade,
  sender uuid not null references public.rider_profiles(id) on delete cascade,
  recipient uuid not null references public.rider_profiles(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '10 seconds')
);
alter table public.wmc_lobbies enable row level security;
alter table public.wmc_lobby_members enable row level security;
alter table public.wmc_lobby_invites enable row level security;
revoke all on public.wmc_lobbies, public.wmc_lobby_members, public.wmc_lobby_invites from anon, authenticated;

create function public.wmc_lobby_action(action text, params jsonb default '{}'::jsonb) returns jsonb
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
   select count(*) into cnt from public.wmc_lobby_members where lobby_id=lid; if cnt>=15 then raise exception 'Lobby is full'; end if;
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
   select count(*) into cnt from public.wmc_lobby_members where lobby_id=lid; if cnt>=15 then raise exception 'Lobby is full'; end if;
   insert into public.wmc_lobby_members(lobby_id,user_id) values(lid,me);
   delete from public.wmc_lobby_invites where recipient=me;
 else raise exception 'Unknown lobby action'; end if;
 return jsonb_build_object('ok',true,'lobby_id',lid);
end; $$;

create function public.wmc_lobby_snapshot() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare me uuid:=auth.uid(); lobby jsonb; invites jsonb;
begin
 if me is null then raise exception 'Sign in first'; end if;
 select jsonb_build_object('id',l.id,'mode',l.mode,'host_id',l.host_id,'members',
   (select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'username',p.username,'display_name',p.display_name,'number',p.rider_number,'color',p.plate_color) order by m.joined_at),'[]'::jsonb) from public.wmc_lobby_members m join public.rider_profiles p on p.id=m.user_id where m.lobby_id=l.id)) into lobby
 from public.wmc_lobbies l join public.wmc_lobby_members mine on mine.lobby_id=l.id where mine.user_id=me;
 select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'sender',p.display_name,'username',p.username,'expires_at',i.expires_at) order by i.expires_at),'[]'::jsonb) into invites
 from public.wmc_lobby_invites i join public.rider_profiles p on p.id=i.sender where i.recipient=me and i.expires_at>now();
 return jsonb_build_object('user_id',me,'lobby',lobby,'invites',invites,'server_time',now());
end; $$;
revoke all on function public.wmc_lobby_action(text,jsonb),public.wmc_lobby_snapshot() from public, anon;
grant execute on function public.wmc_lobby_action(text,jsonb),public.wmc_lobby_snapshot() to authenticated;
