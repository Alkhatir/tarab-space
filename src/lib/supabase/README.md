# Supabase boundary

PostgreSQL access and database client helpers belong here. Supabase Auth is not used; Reddit will supply the primary user identity.

The server-only `createSupabaseClient()` validates configuration when called. It uses the publishable key with session persistence disabled, so it has anonymous-role permissions. It does not establish a Reddit identity or grant trusted backend access. Define the database authorization model and row-level security before adding queries.

No tables, queries, or schema are implemented.
