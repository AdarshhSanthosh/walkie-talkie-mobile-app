-- Phase 2: profiles table (spec §12) + auto-create trigger + RLS.
-- Paste this into the Supabase dashboard's SQL Editor and run it once.

create table if not exists public.profiles (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  username     text unique not null,
  display_name text not null,
  avatar_url   text,
  status       text not null default 'offline'
               check (status in ('online', 'away', 'offline', 'dnd')),
  last_seen    timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Any signed-in user can see basic profile info (needed for friends lists,
-- presence, etc. in later phases).
create policy "Profiles are viewable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

-- Users may only modify their own profile.
create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Auto-create a profile row whenever someone signs up, seeded from the
-- username/display_name passed in AuthService.signUp's `data:` map.
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
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
