-- Phase 6: notifications, preferences, and device tokens (spec §9, §10, §12).
-- Run this in the SQL Editor after channels_schema.sql.
--
-- Scope note: this builds the full in-app notification system (real rows,
-- real preferences, real per-channel mute) and generates real notifications
-- from actions that already exist (friend requests/accepts, channel joins).
-- Actually *pushing* those to a device via Firebase Cloud Messaging needs a
-- Firebase project + a server-side sender (a Supabase Edge Function calling
-- the FCM API) — that's a separate follow-up once a Firebase project exists;
-- `device_tokens` is ready to receive tokens in the meantime.

create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (user_id) on delete cascade,
  type        text not null check (type in ('friend_request', 'friend_accept', 'channel_activity')),
  title       text not null,
  body        text not null,
  channel_id  uuid references public.channels (id) on delete cascade,
  sender_id   uuid references public.profiles (user_id) on delete set null,
  read        boolean not null default false,
  created_at  timestamptz not null default now()
);

alter table public.notifications enable row level security;

create policy "See your own notifications"
  on public.notifications for select
  to authenticated
  using (auth.uid() = user_id);

create table if not exists public.notification_preferences (
  user_id             uuid primary key references public.profiles (user_id) on delete cascade,
  friend_requests     boolean not null default true,
  channel_invitations boolean not null default true,
  mentions            boolean not null default true,
  announcements       boolean not null default true,
  -- Spec §9: "Do not send a notification for every voice transmission" —
  -- defaulted off on purpose.
  voice_activity      boolean not null default false,
  direct_messages     boolean not null default true,
  updated_at          timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

create policy "Manage your own notification preferences"
  on public.notification_preferences for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create table if not exists public.device_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (user_id) on delete cascade,
  token       text not null unique,
  platform    text not null check (platform in ('android', 'ios', 'web')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

create policy "Manage your own device tokens"
  on public.device_tokens for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Per-channel mute level (spec §10: "All Notifications / Important Only /
-- Muted"), added to the existing channel_members table from Phase 4.
alter table public.channel_members
  add column if not exists notification_level text not null default 'all'
    check (notification_level in ('all', 'important', 'muted'));

-- ════════════════════════════════════════════════════════════════
-- Auto-create a default preferences row on signup, alongside the
-- existing profile row (redefines the Phase 2 trigger function; the
-- trigger itself doesn't need to be re-created).
-- ════════════════════════════════════════════════════════════════

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (user_id, username, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1))
  )
  on conflict (user_id) do nothing;

  insert into public.notification_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

-- ════════════════════════════════════════════════════════════════
-- RPCs
-- ════════════════════════════════════════════════════════════════

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.notifications set read = true
  where id = p_notification_id and user_id = auth.uid();
end;
$$;

create or replace function public.register_device_token(p_token text, p_platform text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.device_tokens (user_id, token, platform)
  values (auth.uid(), p_token, p_platform)
  on conflict (token) do update set user_id = excluded.user_id, updated_at = now();
end;
$$;

create or replace function public.set_channel_notification_level(p_channel_id uuid, p_level text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.channel_members set notification_level = p_level
  where channel_id = p_channel_id and user_id = auth.uid();
end;
$$;

-- ════════════════════════════════════════════════════════════════
-- Redefine existing Phase 3/4 RPCs to also raise a real notification,
-- respecting the recipient's global + per-channel preferences.
-- ════════════════════════════════════════════════════════════════

create or replace function public.send_friend_request(target_user_id uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  req_id uuid;
  lo uuid;
  hi uuid;
  my_name text;
  wants_it boolean;
begin
  if target_user_id = auth.uid() then
    raise exception 'Cannot friend yourself';
  end if;

  lo := least(auth.uid(), target_user_id);
  hi := greatest(auth.uid(), target_user_id);

  if exists (select 1 from public.friendships where user_id_a = lo and user_id_b = hi) then
    raise exception 'Already friends';
  end if;

  if exists (
    select 1 from public.blocked_users
    where (blocker_id = auth.uid() and blocked_id = target_user_id)
       or (blocker_id = target_user_id and blocked_id = auth.uid())
  ) then
    raise exception 'Cannot send a request to this user';
  end if;

  insert into public.friend_requests (sender_id, receiver_id)
  values (auth.uid(), target_user_id)
  on conflict (sender_id, receiver_id)
  do update set status = 'pending', updated_at = now()
  returning id into req_id;

  select display_name into my_name from public.profiles where user_id = auth.uid();
  select coalesce(friend_requests, true) into wants_it
    from public.notification_preferences where user_id = target_user_id;
  if coalesce(wants_it, true) then
    insert into public.notifications (user_id, type, title, body, sender_id)
    values (target_user_id, 'friend_request', 'Friend request', my_name || ' sent you a friend request', auth.uid());
  end if;

  return req_id;
end;
$$;

create or replace function public.accept_friend_request(request_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  req record;
  lo uuid;
  hi uuid;
  my_name text;
  wants_it boolean;
begin
  select * into req from public.friend_requests where id = request_id;
  if req is null or req.receiver_id <> auth.uid() then
    raise exception 'Request not found';
  end if;

  update public.friend_requests set status = 'accepted', updated_at = now()
  where id = request_id;

  lo := least(req.sender_id, req.receiver_id);
  hi := greatest(req.sender_id, req.receiver_id);
  insert into public.friendships (user_id_a, user_id_b)
  values (lo, hi)
  on conflict do nothing;

  select display_name into my_name from public.profiles where user_id = auth.uid();
  select coalesce(friend_requests, true) into wants_it
    from public.notification_preferences where user_id = req.sender_id;
  if coalesce(wants_it, true) then
    insert into public.notifications (user_id, type, title, body, sender_id)
    values (req.sender_id, 'friend_accept', 'Friend request accepted', my_name || ' accepted your friend request', auth.uid());
  end if;
end;
$$;

create or replace function public.join_channel_by_code(p_invite_code text)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  ch record;
  member_count integer;
  my_name text;
  wants_it boolean;
  owner_level text;
begin
  select * into ch from public.channels where invite_code = upper(trim(p_invite_code));
  if ch is null then
    raise exception 'Invalid invite code';
  end if;

  if exists (
    select 1 from public.channel_members
    where channel_id = ch.id and user_id = auth.uid() and banned = true
  ) then
    raise exception 'You are banned from this channel';
  end if;

  select count(*) into member_count from public.channel_members where channel_id = ch.id;
  if member_count >= ch.max_members then
    raise exception 'Channel is full';
  end if;

  insert into public.channel_members (channel_id, user_id, role)
  values (ch.id, auth.uid(), 'member')
  on conflict (channel_id, user_id) do nothing;

  select display_name into my_name from public.profiles where user_id = auth.uid();
  select coalesce(announcements, true) into wants_it
    from public.notification_preferences where user_id = ch.owner_id;
  select notification_level into owner_level
    from public.channel_members where channel_id = ch.id and user_id = ch.owner_id;
  if coalesce(wants_it, true) and coalesce(owner_level, 'all') <> 'muted' and ch.owner_id <> auth.uid() then
    insert into public.notifications (user_id, type, title, body, channel_id, sender_id)
    values (ch.owner_id, 'channel_activity', ch.name, my_name || ' joined ' || ch.name, ch.id, auth.uid());
  end if;

  return ch.id;
end;
$$;
