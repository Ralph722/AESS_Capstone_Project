-- contact_normalize_target was executable by anon through the default PUBLIC
-- grant. Only signed-in users and the service role need it.
revoke all on function public.contact_normalize_target(text, text) from public, anon;
grant execute on function public.contact_normalize_target(text, text) to authenticated, service_role;
