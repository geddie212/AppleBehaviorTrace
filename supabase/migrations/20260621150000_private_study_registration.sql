create extension if not exists pgcrypto;

alter table public.forms
add column if not exists study_password_hash text;

update public.forms
set study_password_hash = encode(extensions.digest(convert_to(study_password, 'UTF8'), 'sha256'), 'hex')
where study_password_hash is null
  and study_password is not null;

alter table public.forms alter column study_password drop not null;

update public.forms
set study_password = null
where study_password is not null;

alter table public.forms alter column study_password_hash set not null;

create table if not exists public.study_registrations (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  form_id bigint not null references public.forms(id) on delete cascade,
  created_at timestamptz default now(),
  unique (user_id, form_id)
);

alter table public.study_registrations enable row level security;

drop policy if exists "Users can read their own study registrations" on public.study_registrations;
create policy "Users can read their own study registrations"
on public.study_registrations for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Admins can read study registrations" on public.study_registrations;
create policy "Admins can read study registrations"
on public.study_registrations for select
to authenticated
using (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'admin'
  )
);

drop policy if exists "Authenticated users can read forms" on public.forms;
drop policy if exists "Admins can read their forms" on public.forms;
create policy "Admins can read their forms"
on public.forms for select
to authenticated
using (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'admin'
      and forms.created_by = auth.uid()
  )
);

drop policy if exists "Registered users can read their forms" on public.forms;
create policy "Registered users can read their forms"
on public.forms for select
to authenticated
using (
  exists (
    select 1
    from public.study_registrations
    where study_registrations.user_id = auth.uid()
      and study_registrations.form_id = forms.id
  )
);

drop policy if exists "Authenticated users can read labels" on public.labels;
drop policy if exists "Admins can read labels for their forms" on public.labels;
create policy "Admins can read labels for their forms"
on public.labels for select
to authenticated
using (
  exists (
    select 1
    from public.forms
    join public.profiles on profiles.id = auth.uid()
    where forms.id = labels.form_id
      and forms.created_by = auth.uid()
      and profiles.role = 'admin'
  )
);

drop policy if exists "Registered users can read labels for their forms" on public.labels;
create policy "Registered users can read labels for their forms"
on public.labels for select
to authenticated
using (
  exists (
    select 1
    from public.study_registrations
    where study_registrations.user_id = auth.uid()
      and study_registrations.form_id = labels.form_id
  )
);

create or replace function public.search_studies(search_query text)
returns table (
  id bigint,
  title text,
  description text,
  study_code text
)
language sql
security definer
set search_path = public
as $$
  select forms.id, forms.title, forms.description, forms.study_code
  from public.forms
  where length(trim(coalesce(search_query, ''))) > 0
    and (
      forms.title ilike '%' || trim(search_query) || '%'
      or coalesce(forms.description, '') ilike '%' || trim(search_query) || '%'
      or forms.study_code ilike '%' || trim(search_query) || '%'
    )
  order by forms.title
  limit 20;
$$;

create or replace function public.register_for_study(requested_form_id bigint, password_hash text)
returns table (
  id bigint,
  title text,
  description text,
  study_code text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.forms
    where forms.id = requested_form_id
      and forms.study_password_hash = password_hash
  ) then
    raise exception 'Invalid study password.';
  end if;

  insert into public.study_registrations (user_id, form_id)
  values (auth.uid(), requested_form_id)
  on conflict (user_id, form_id) do nothing;

  return query
  select forms.id, forms.title, forms.description, forms.study_code
  from public.forms
  where forms.id = requested_form_id;
end;
$$;

create or replace function public.registered_studies()
returns table (
  id bigint,
  title text,
  description text,
  study_code text
)
language sql
security definer
set search_path = public
as $$
  select forms.id, forms.title, forms.description, forms.study_code
  from public.study_registrations
  join public.forms on forms.id = study_registrations.form_id
  where study_registrations.user_id = auth.uid()
  order by study_registrations.created_at desc;
$$;

grant execute on function public.search_studies(text) to authenticated;
grant execute on function public.register_for_study(bigint, text) to authenticated;
grant execute on function public.registered_studies() to authenticated;

notify pgrst, 'reload schema';
