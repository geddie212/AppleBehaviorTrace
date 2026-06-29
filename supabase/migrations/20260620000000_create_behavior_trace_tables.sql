create table if not exists public.profiles (
  id uuid primary key references auth.users(id),
  email text,
  role text not null default 'user' check (role in ('admin', 'user')),
  created_at timestamptz default now()
);

update public.profiles
set role = case
  when lower(email) = 'pauliusgedrimas@gmail.com' then 'admin'
  else 'user'
end
where role is null
   or lower(email) = 'pauliusgedrimas@gmail.com';

alter table public.profiles alter column role set default 'user';
alter table public.profiles alter column role set not null;
alter table public.profiles enable row level security;

drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile"
on public.profiles for select
to authenticated
using (auth.uid() = id);

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
    case
      when lower(new.email) = 'pauliusgedrimas@gmail.com' then 'admin'
      else 'user'
    end
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

create table if not exists public.forms (
  id bigint generated always as identity primary key,
  title text not null,
  description text,
  created_by uuid references public.profiles(id),
  created_at timestamptz default now()
);

create table if not exists public.labels (
  id bigint generated always as identity primary key,
  form_id bigint references public.forms(id),
  label_name text not null,
  prompt_text text,
  prompt_interval_seconds int not null,
  active boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.user_states (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id),
  form_id bigint references public.forms(id),
  label_id bigint references public.labels(id),
  started_at timestamptz default now(),
  ended_at timestamptz,
  active boolean default true,
  last_prompted_at timestamptz,
  last_confirmed_at timestamptz
);

create table if not exists public.health_samples (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id),
  sample_type text not null,
  start_time timestamptz not null,
  end_time timestamptz,
  value double precision,
  unit text,
  source text,
  created_at timestamptz default now()
);

create table if not exists public.ml_windows (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id),
  label_id bigint references public.labels(id),
  window_start timestamptz,
  window_end timestamptz,
  features jsonb,
  label_name text
);
