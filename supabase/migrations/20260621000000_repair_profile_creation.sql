create table if not exists public.profiles (
  id uuid primary key references auth.users(id),
  email text,
  role text not null default 'user' check (role in ('admin', 'user')),
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile"
on public.profiles for select
to authenticated
using (auth.uid() = id);

create or replace function public.profile_role_for_email(user_email text)
returns text
language sql
stable
as $$
  select case
    when lower(coalesce(user_email, '')) = 'pauliusgedrimas@gmail.com' then 'admin'
    else 'user'
  end;
$$;

drop policy if exists "Users can create their own profile" on public.profiles;
create policy "Users can create their own profile"
on public.profiles for insert
to authenticated
with check (
  auth.uid() = id
  and lower(email) = lower(coalesce(auth.jwt()->>'email', ''))
  and role = public.profile_role_for_email(email)
);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
on public.profiles for update
to authenticated
using (auth.uid() = id)
with check (
  auth.uid() = id
  and lower(email) = lower(coalesce(auth.jwt()->>'email', ''))
  and role = public.profile_role_for_email(email)
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, role)
  values (
    new.id,
    new.email,
    public.profile_role_for_email(new.email)
  )
  on conflict (id) do update
  set email = excluded.email,
      role = excluded.role;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

drop function if exists public.ensure_own_profile(text);

create or replace function public.ensure_own_profile()
returns setof public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  current_email text;
  resolved_role text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select email
  into current_email
  from auth.users
  where id = auth.uid();

  resolved_role := public.profile_role_for_email(current_email);

  insert into public.profiles (id, email, role)
  values (auth.uid(), current_email, resolved_role)
  on conflict (id) do update
  set email = excluded.email,
      role = excluded.role;

  return query
  select id, email, role, created_at
  from public.profiles
  where id = auth.uid();
end;
$$;

grant execute on function public.ensure_own_profile() to authenticated;

notify pgrst, 'reload schema';
