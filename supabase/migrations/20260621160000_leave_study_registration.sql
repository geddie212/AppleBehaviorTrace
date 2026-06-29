create or replace function public.leave_study(requested_study_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.study_registrations
  using public.forms
  where study_registrations.user_id = auth.uid()
    and study_registrations.form_id = forms.id
    and forms.study_code = requested_study_code;
end;
$$;

grant execute on function public.leave_study(text) to authenticated;

notify pgrst, 'reload schema';
