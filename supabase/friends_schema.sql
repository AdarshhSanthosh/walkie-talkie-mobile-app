-- Phase 3: friend requests, friendships, and blocking (spec §4, §12).
-- Run this in the SQL Editor after supabase/schema.sql.
--
-- All FKs point at public.profiles (not auth.users) so PostgREST can embed
-- profile data directly in queries (e.g. `select=*,sender:profiles!...`).
-- All state changes go through the RPC functions at the bottom — never
-- raw table writes from the client — per spec §13: "server-side
-- authorization must verify identity... never trust permissions supplied
-- by the mobile client."

-- ── friend_requests ───────────────────────────────────────────────
create table if not exists public.friend_requests (
  id          uuid primary key default gen_random_uuid(),
  sender_id   uuid not null references public.profiles (user_id) on delete cascade,
  receiver_id uuid not null references public.profiles (user_id) on delete cascade,
  status      text not null default 'pending'
              check (status in ('pending', 'accepted', 'rejected')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint no_self_request check (sender_id <> receiver_id),
  unique (sender_id, receiver_id)
);

alter table public.friend_requests enable row level security;

create policy "See your own sent or received requests"
  on public.friend_requests for select
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- ── friendships ────────────────────────────────────────────────────
-- One row per pair, canonicalized so user_id_a < user_id_b.
create table if not exists public.friendships (
  id          uuid primary key default gen_random_uuid(),
  user_id_a   uuid not null references public.profiles (user_id) on delete cascade,
  user_id_b   uuid not null references public.profiles (user_id) on delete cascade,
  created_at  timestamptz not null default now(),
  constraint ordered_pair check (user_id_a < user_id_b),
  unique (user_id_a, user_id_b)
);

alter table public.friendships enable row level security;

create policy "See your own friendships"
  on public.friendships for select
  to authenticated
  using (auth.uid() = user_id_a or auth.uid() = user_id_b);

-- ── blocked_users ──────────────────────────────────────────────────
create table if not exists public.blocked_users (
  id          uuid primary key default gen_random_uuid(),
  blocker_id  uuid not null references public.profiles (user_id) on delete cascade,
  blocked_id  uuid not null references public.profiles (user_id) on delete cascade,
  created_at  timestamptz not null default now(),
  constraint no_self_block check (blocker_id <> blocked_id),
  unique (blocker_id, blocked_id)
);

alter table public.blocked_users enable row level security;

create policy "See who you've blocked"
  on public.blocked_users for select
  to authenticated
  using (auth.uid() = blocker_id);

-- ════════════════════════════════════════════════════════════════════
-- RPCs — the only way friend/friendship/block rows get written.
-- ════════════════════════════════════════════════════════════════════

create or replace function public.send_friend_request(target_user_id uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  req_id uuid;
  lo uuid;
  hi uuid;
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
end;
$$;

create or replace function public.reject_friend_request(request_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.friend_requests set status = 'rejected', updated_at = now()
  where id = request_id and receiver_id = auth.uid();
end;
$$;

create or replace function public.remove_friend(other_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  lo uuid;
  hi uuid;
begin
  lo := least(auth.uid(), other_user_id);
  hi := greatest(auth.uid(), other_user_id);
  delete from public.friendships where user_id_a = lo and user_id_b = hi;
  delete from public.friend_requests
  where (sender_id = auth.uid() and receiver_id = other_user_id)
     or (sender_id = other_user_id and receiver_id = auth.uid());
end;
$$;

create or replace function public.block_user(target_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  lo uuid;
  hi uuid;
begin
  if target_user_id = auth.uid() then
    raise exception 'Cannot block yourself';
  end if;

  insert into public.blocked_users (blocker_id, blocked_id)
  values (auth.uid(), target_user_id)
  on conflict do nothing;

  lo := least(auth.uid(), target_user_id);
  hi := greatest(auth.uid(), target_user_id);
  delete from public.friendships where user_id_a = lo and user_id_b = hi;
  delete from public.friend_requests
  where (sender_id = auth.uid() and receiver_id = target_user_id)
     or (sender_id = target_user_id and receiver_id = auth.uid());
end;
$$;

create or replace function public.unblock_user(target_user_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  delete from public.blocked_users
  where blocker_id = auth.uid() and blocked_id = target_user_id;
end;
$$;
