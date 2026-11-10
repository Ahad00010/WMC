-- Friend requests are changed only through the checked functions below.
create table public.wmc_friendships (
  id uuid primary key default gen_random_uuid(),
  requester uuid not null references public.rider_profiles(id) on delete cascade,
  recipient uuid not null references public.rider_profiles(id) on delete cascade,
  accepted boolean not null default false,
  created_at timestamptz not null default now(),
  check (requester <> recipient)
);
create unique index wmc_friend_pair on public.wmc_friendships (least(requester, recipient), greatest(requester, recipient));
alter table public.wmc_friendships enable row level security;
revoke all on public.wmc_friendships from anon, authenticated;

create function public.wmc_friend_request(target_username text) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); target uuid;
begin
  if me is null or not exists (select 1 from public.rider_profiles where id=me) then raise exception 'Complete your rider profile first'; end if;
  select id into target from public.rider_profiles where username=lower(trim(target_username));
  if target is null then raise exception 'Username not found'; end if;
  if target=me then raise exception 'You cannot add yourself'; end if;
  begin
    insert into public.wmc_friendships(requester,recipient) values (me,target);
  exception when unique_violation then raise exception 'A request or friendship already exists'; end;
end; $$;

create function public.wmc_friend_respond(request_id uuid, accept_request boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  if accept_request is null then raise exception 'Choose accept or decline'; end if;
  if accept_request then
    update public.wmc_friendships set accepted=true where id=request_id and recipient=auth.uid() and not accepted;
  else
    delete from public.wmc_friendships where id=request_id and recipient=auth.uid() and not accepted;
  end if;
  if not found then raise exception 'Request no longer available'; end if;
end; $$;

create function public.wmc_friend_remove(friendship_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  delete from public.wmc_friendships where id=friendship_id and (requester=auth.uid() or recipient=auth.uid());
  if not found then raise exception 'Friendship no longer available'; end if;
end; $$;

create function public.wmc_friends() returns table (id uuid, username text, display_name text, status text)
language sql stable security definer set search_path = '' as $$
  select f.id, p.username, p.display_name,
    case when f.accepted then 'friend' when f.recipient=auth.uid() then 'incoming' else 'outgoing' end
  from public.wmc_friendships f
  join public.rider_profiles p on p.id=case when f.requester=auth.uid() then f.recipient else f.requester end
  where auth.uid() is not null and (f.requester=auth.uid() or f.recipient=auth.uid())
  order by f.created_at desc;
$$;
revoke all on function public.wmc_friend_request(text), public.wmc_friend_respond(uuid,boolean), public.wmc_friend_remove(uuid), public.wmc_friends() from public, anon;
grant execute on function public.wmc_friend_request(text), public.wmc_friend_respond(uuid,boolean), public.wmc_friend_remove(uuid), public.wmc_friends() to authenticated;
