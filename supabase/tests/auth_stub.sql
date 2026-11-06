-- Disposable plain PostgreSQL test instance ONLY, never a Supabase project.
-- Minimal Auth tables/claim reader for SQL tests, not a production Auth service.
create schema auth;
create table auth.users(id uuid primary key, email text, email_confirmed_at timestamptz);
create function auth.uid() returns uuid language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid; $$;
