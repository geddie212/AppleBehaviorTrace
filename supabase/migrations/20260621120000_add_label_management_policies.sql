drop policy if exists "Admins can update labels" on public.labels;
create policy "Admins can update labels"
on public.labels for update
to authenticated
using (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'admin'
  )
)
with check (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'admin'
  )
);

drop policy if exists "Admins can delete labels" on public.labels;
create policy "Admins can delete labels"
on public.labels for delete
to authenticated
using (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'admin'
  )
);

notify pgrst, 'reload schema';
