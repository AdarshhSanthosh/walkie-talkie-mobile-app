-- Phase 4: real channels + membership (spec §5, §12).
-- Run this in the SQL Editor after friends_schema.sql.
--
-- Scope note: this covers the channel lifecycle (create/join-by-code/leave/
-- delete) and basic permissions (owner/admin can remove members; only the
-- owner can delete). Muting, banning, role promotion, and a separate
-- per-friend "invite" flow (distinct from the self-serve code below) are
-- deferred — the schema below leaves room for them (`role`, `muted`,
-- `banned` columns already exist) but no RPCs are wired for them yet.

create table if not exists public.channels (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  description  text not null default '',
  owner_id     uuid not null references public.profiles (user_id) on delete cascade,
  privacy      text not null default 'private'
               check (privacy in ('public', 'private', 'friends_only', 'temporary')),
  max_members  integer not null default 20 check (max_members > 0),
  avatar_emoji text not null default '📻',
  invite_code  text not null unique,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.channel_members (
  channel_id  uuid not null references public.channels (id) on delete cascade,
  user_id     uuid not null references public.profiles (user_id) on delete cascade,
  role        text not null default 'member'
              check (role in ('owner', 'admin', 'moderator', 'member')),
  joined_at   timestamptz not null default now(),
  muted       boolean not null default false,
  banned      boolean not null default false,
  primary key (channel_id, user_id)
);

alter table public.channels enable row level security;
alter table public.channel_members enable row level security;

-- Helper: lets channel_members' own RLS policy check membership without
-- the policy recursively querying the table it's defined on.
create or replace function public.is_channel_member(p_channel_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.channel_members
    where channel_id = p_channel_id and user_id = p_user_id
  );
$$;

create policy "Public channels are visible to everyone; others to members"
  on public.channels for select
  to authenticated
  using (privacy = 'public' or public.is_channel_member(id, auth.uid()));

create policy "Members can see their channel's membership"
  on public.channel_members for select
  to authenticated
  using (public.is_channel_member(channel_id, auth.uid()));

-- ════════════════════════════════════════════════════════════════
-- RPCs — creation/join/leave/remove/delete go through these, not raw
-- table writes, so role checks happen server-side.
-- ════════════════════════════════════════════════════════════════

create or replace function public.create_channel(
  p_name text,
  p_description text,
  p_privacy text,
  p_max_members integer
)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  ch_id uuid;
  code text;
begin
  code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

  insert into public.channels (name, description, owner_id, privacy, max_members, invite_code)
  values (p_name, p_description, auth.uid(), p_privacy, p_max_members, code)
  returning id into ch_id;

  insert into public.channel_members (channel_id, user_id, role)
  values (ch_id, auth.uid(), 'owner');

  return ch_id;
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

  return ch.id;
end;
$$;

create or replace function public.leave_channel(p_channel_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if exists (select 1 from public.channels where id = p_channel_id and owner_id = auth.uid()) then
    raise exception 'Owner cannot leave — delete the channel instead';
  end if;

  delete from public.channel_members
  where channel_id = p_channel_id and user_id = auth.uid();
end;
$$;

create or replace function public.remove_channel_member(p_channel_id uuid, p_target_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  my_role text;
begin
  select role into my_role from public.channel_members
  where channel_id = p_channel_id and user_id = auth.uid();

  if my_role is null or my_role not in ('owner', 'admin') then
    raise exception 'Not authorized to remove members';
  end if;

  if exists (select 1 from public.channels where id = p_channel_id and owner_id = p_target_user_id) then
    raise exception 'Cannot remove the channel owner';
  end if;

  delete from public.channel_members
  where channel_id = p_channel_id and user_id = p_target_user_id;
end;
$$;

create or replace function public.delete_channel(p_channel_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  delete from public.channels where id = p_channel_id and owner_id = auth.uid();
  if not found then
    raise exception 'Not authorized to delete this channel';
  end if;
end;
$$;
