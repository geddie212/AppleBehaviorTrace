alter table public.forms
add column if not exists study_code text;

alter table public.forms
add column if not exists study_password text;

update public.forms
set study_code = 'STUDY-' || id::text
where study_code is null;

update public.forms
set study_password = 'changeme'
where study_password is null;

alter table public.forms alter column study_code set not null;
alter table public.forms alter column study_password set not null;

create unique index if not exists forms_study_code_key on public.forms (study_code);

alter table public.forms enable row level security;
alter table public.labels enable row level security;

drop policy if exists "Authenticated users can read forms" on public.forms;
create policy "Authenticated users can read forms"
on public.forms for select
to authenticated
using (true);

drop policy if exists "Admins can create forms" on public.forms;
create policy "Admins can create forms"
on public.forms for insert
to authenticated
with check (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'admin'
  )
);

drop policy if exists "Authenticated users can read labels" on public.labels;
create policy "Authenticated users can read labels"
on public.labels for select
to authenticated
using (true);

drop policy if exists "Admins can create labels" on public.labels;
create policy "Admins can create labels"
on public.labels for insert
to authenticated
with check (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'admin'
  )
);

notify pgrst, 'reload schema';
