-- DISPOSABLE POSTGRESQL TEST INSTANCE ONLY. Never run this on hosted Supabase:
-- Supabase already manages these roles. Requires a privileged test connection.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
