# Supabase boundary

Supabase now supplies both PostgreSQL and email/password Auth. `browser.ts` lazily
creates a publishable-key client for Auth and the narrow invitation RPC surface.
It reads only NEXT_PUBLIC variables and adds no service-role credentials.

`server.ts` is still an anonymous data client, not an authenticated session client.
Do not use it to authorize writes or grant anonymous access to private tables.

The first two migrations are applied to development. Migration 003 adds invited
membership and is pending. Private tables remain inaccessible to app roles;
only explicitly granted public RPCs derive identity from `auth.uid()` and check
verified email/membership/ban state. See [the database guide](../../../supabase/README.md)
and [invitation guide](../invitations/README.md).
