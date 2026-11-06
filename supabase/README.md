# Database foundation

All three migrations have been applied to the hosted **development** project.
Music pages still use fixtures. Invitation RPCs and the minimal hosted Auth
profile are deployed; first-member setup and hosted onboarding are not yet tested.

## Development deployment record

On 2026-11-06, the project owner supplied successful CLI migration output for
`tarab-space-dev` (`qmjnfbyubyqgaloixpeo`). Local and remote history both showed:

- `20261106000100_library_foundation.sql`
- `20261106000200_permissions_and_audit.sql`

The owner then ran read-only hosted checks and reported:

- All eight `tarab_private` tables have row-level security enabled.
- `anon`, `authenticated`, and `service_role` all lack schema `USAGE`.

These are owner-reported hosted verification results, not an independent
connection from this workspace. They do not establish end-to-end authentication,
Data API behavior, or concurrency correctness. SQL fixtures remain test-only.

### Verified deployment on 2026-11-07

- Applied `20261106000300_invitation_membership.sql`; all three local/remote
  migration versions match.
- Independently queried the hosted database in read-only transactions: all eleven
  private tables have RLS enabled; `anon`, `authenticated`, and `service_role`
  have no private-schema USAGE.
- Verified all six public `tarab_*` RPCs grant execute to `authenticated`, not
  `anon` or `service_role`, and use security-definer functions with empty search
  paths. Their internal membership/ban/eligibility guards remain mandatory.
- Pushed only `hosted-auth.toml` declarations. The single changed property was
  password minimum length (6 to 12); email signup/confirmation and localhost Site
  URL already matched. Nine undeclared hosted properties were preserved.
- A follow-up config diff reports no declared differences.
- Members, invitations, and roster-import counts are zero. No bootstrap accounts,
  fixture rows, invitation emails, or scraper jobs were created.

The Next.js application itself is not hosted by Supabase. The development Site
URL is still localhost; frontend hosting remains a separate step. No Edge
Function/scraper source exists to deploy yet.

## Invitation update — migration 003 applied to development

The initial two migrations remain unchanged. New migration
`20261106000300_invitation_membership.sql` replaces the Reddit-OAuth assumption:

- `members.auth_user_id` links a verified Supabase email account; legacy Reddit
  IDs become optional. Internal member UUIDs, roles, ownership, and audits stay intact.
- Username identity and invitation links are immutable and case-insensitively unique.
- `eligibility_imports` and `eligible_usernames` store complete private snapshots.
- `invitations` stores token hashes, bound usernames, inviter/recipient graph edges,
  expiry, and revocation attribution. Raw tokens are returned once, not stored.
- Explicit `public.tarab_*` RPCs expose only verified-account membership lookup,
  invitation issuance/list/revocation/redemption, and admin-only snapshot import.
  Authenticated does not itself mean a platform member. No private schema/table
  grants are added. The original fail-closed state is retained for all music data.

The original eight-table hosted verification below describes migrations 001/002.
After migration 003 there will be eleven private tables. Verify their RLS and the
explicit RPC grants as well. This migration was applied on 2026-11-07.
See [the invitation guide](../src/lib/invitations/README.md) for lifecycle and limits.

### Minimal hosted Auth deployment profile

`hosted-auth.toml` declares only the development site URL, signup setting,
12-character password minimum, and confirmed email/password authentication.
Use this profile for hosted configuration, rather than pushing all generated
local defaults in `config.toml`. Unspecified hosted properties remain unchanged.
The CLI expects the profile at `<workdir>/supabase/config.toml`; copy it into a
temporary workdir, preview with `config diff`, then use `config push` with the
explicit development project reference. Never commit CLI login state or secrets.

### Hosted Auth configuration and first member

1. Migration 003 is applied; use the established CLI flow for future migrations.
2. Enable Supabase email/password Auth and **email confirmation**, with a
   minimum password length of 12. Set Site URL
   to the actual development origin, e.g. `http://localhost:3000`. Auth confirmation
   redirects may return to the site home; the user then revisits their original
   invitation and signs in. No Reddit OAuth provider is required.
3. Create your own initial Auth account through the Supabase dashboard using a
   real email you control. Verify it before bootstrapping platform membership.
   No real email or password belongs in a migration or fixture.
4. As database owner, run a reviewed one-time bootstrap transaction (template
   below) for that verified account. It is the only root without an incoming
   invitation. The existing owner-only first-admin guard audits the admin grant.
5. Import an initial complete eligibility snapshot under that admin identity.
   Then use `/account` to issue the first real invitation and verify `/join`.

```sql
-- SQL Editor, database owner only. Replace placeholders with your own values.
-- This writes real membership; review before executing. Not a migration/seed.
begin;
do $$
declare auth_id uuid; member_id uuid;
begin
  select id into auth_id from auth.users
    where lower(email) = lower('YOUR_VERIFIED_EMAIL') and email_confirmed_at is not null;
  if auth_id is null then raise exception 'Verified Auth account not found'; end if;
  if exists(select 1 from tarab_private.member_roles where role = 'admin') then
    raise exception 'An admin already exists; do not bootstrap again';
  end if;
  insert into tarab_private.members(auth_user_id,username)
    values(auth_id,tarab_private.normalize_username('YOUR_REDDIT_USERNAME'))
    returning id into member_id;
  perform set_config('tarab.actor_id',member_id::text,true);
  insert into tarab_private.member_roles(member_id,role) values(member_id,'admin');
end $$;
commit;
```

For an initial owner-operated import, use a transaction in SQL Editor and set
`request.jwt.claim.sub` to the verified root Auth UUID, then invoke
`public.tarab_import_eligibility(ARRAY[...], 'honest source label', observation_time)`.
This is a privileged administrative operation; a browser cannot set that JWT
context. The weekly scraper will need its own deliberately configured trusted
caller. Do not run imports from a partially scraped result.

General role/ban dashboards and music access are still future work. Email account
creation is separate from platform membership; public Supabase Auth signup is not
an authorization grant. Before production, verify SMTP, account abuse controls,
password recovery, session lifecycle, and actual hosted onboarding.

## Model

| Table in `tarab_private` | Responsibility |
| --- | --- |
| `members` | Internal UUID, canonical username, Auth identity (003), join time, ban state |
| `member_roles` | Independent `editor` and `admin` app-role assignments |
| `artists` | Spotify artist identity and display name |
| `tracks` | Unique Spotify track identity, title, metadata-fetch timestamp |
| `track_artists` | Ordered artist credits, including collaborations |
| `submissions` | One original contributor and submission time per track |
| `track_tags` | Editable labels, separate from Spotify catalog metadata |
| `audit_events` | Actor, database timestamp, operation, entity, before/after values |

The original tables below are extended by the pending invitation migration.
There are no cluster tables, playlist tables, audio files, embeddings, or raw Spotify payloads. Catalog refresh/retention rules must
be established before connecting the Spotify API.

Reddit and Spotify IDs are external identities; internal relationships use UUIDs.
The invitation migration freezes the canonical username; future changes require an explicit identity policy. Track ID
uniqueness prevents duplicate catalog rows; submission primary keys prevent a
second owner. This does not deduplicate different Spotify releases of one song.
A future submission transaction must reuse the existing entry on conflict,
without overwriting its owner, timestamps, or tags.

## Permissions

| Actor | Change own track tags | Change another track's tags | Assign/revoke roles; ban/unban |
| --- | --- | --- | --- |
| Active member | Yes | No | No |
| Active editor | Yes | Yes | No |
| Active admin without editor role | Yes | No | Yes |
| Active admin with editor role | Yes | Yes | Yes |
| Banned member, regardless of roles | No | No | No |

The future UI must follow these rules for existing/duplicate entries as well.
Contribution ownership is not transferred by a duplicate submission. Membership
is implicit; editor and admin are additive application roles, unrelated to
Supabase organization membership or PostgreSQL login roles.

Bans suspend actions without deleting submissions, audit history, or role
assignments. Unbanning restores whatever roles remain assigned. Admins cannot
ban themselves, grant roles to banned members, or remove the last active admin.
Administrative writes share a transaction-level advisory lock. Role assignment
changes use revoke/grant rather than rewriting a grant's identity. The dashboard,
active-session invalidation, and platform-wide ban checks are future work.

## Fail-closed access boundary

All application tables are in `tarab_private`, outside the default Data API
schemas. **Do not add this schema to Supabase's exposed schemas.** Row-level
security is enabled with no allow policies. Schema, table, sequence, and function
privileges are revoked from `PUBLIC`, `anon`, `authenticated`, and `service_role`.
See Supabase's [custom-schema guidance](https://supabase.com/docs/guides/api/using-custom-schemas)
and [API security guide](https://supabase.com/docs/guides/api/securing-your-api).

For migrations 001/002, this deliberately blocks direct application table access, even with a
secret API key. Migration 003 grants only its explicit public invitation RPCs. The existing server publishable-key helper does not authenticate members and must not be made to work by granting broad anonymous access.

Migration 003 adds narrow membership-checked invitation RPCs. General music
access still needs a restricted surface that verifies Supabase sessions,
and expose only appropriate public library fields. Browser requests must never
supply a trusted actor ID, choose roles, or write audit records directly. Bans and
roles must be checked against current database state, not only stale cookies.

Triggers use the transaction-local `tarab.actor_id` setting for attribution and
permission checks. **That setting is not authentication.** Only trusted backend
code may populate it from a verified session. No runtime principal currently has
permissions to invoke these functions or mutate the tables. Do not grant generic
SQL access, expose these functions, or trust a browser-provided setting.

Once a restricted backend connection exists, set the actor and perform the write
in one transaction on the same connection:

```sql
begin;
-- Bind this UUID as a query parameter from the verified server session.
select set_config('tarab.actor_id', '<verified internal member UUID>', true);
-- Authorized database mutation goes here.
commit;
```

`true` scopes the context to that transaction; do not set it for a pooled session.
Security-definer functions have an empty search path and explicit schema names.
Their execute privileges are revoked; they exist for internal trigger use.

## Atomic audit history

Submission insertion, tag additions/edits/removals, role grants/revocations, and
ban/unban changes create audit events in the same transaction as the mutation.
Failed or rolled-back changes leave no audit entries. Tag edits retain both the
previous and replacement values. No-op tag updates do not create events.

Audit updates, deletes, and truncation are rejected by triggers. This protects
application-level history, not against a database owner who can change the
schema or disable triggers. Account deletion, retention, and privacy handling
need a separate deliberate design; no destructive application operations are
provided here. Audit/history data and ban reasons are not public library fields.

Tag writes normalize Unicode compatibility forms, trim/collapse whitespace,
reject empty labels, and enforce case-insensitive uniqueness within a track.
There can be zero to twelve tags, each up to forty PostgreSQL characters. The
browser uses the same conceptual limits; JavaScript measures UTF-16 code units,
so it can be stricter for characters outside the basic multilingual plane.
Case folding follows PostgreSQL collation; cross-runtime internationalization
parity must be tested when saving is wired. A parent-row lock serializes tag
mutations before checking the count limit. Existing tag IDs and track IDs cannot
be rewritten, so renames keep stable audit identity.

## Initial admin

Do not create placeholder production members. After verified Supabase email identity can
provision the real member record, bootstrap the first admin through an explicit
reviewed database-owner transaction using that verified member as actor.

The role trigger permits this only when no admin assignment exists, the login
is the actual table owner, and the actor grants **their own** admin role. The
bootstrap grant is audited normally. It does not automatically grant editor.
Afterward, active admins manage roles through the future protected dashboard.
No public bootstrap function or hard-coded administrator account exists.

## Applying future migrations

The initial development deployment is complete. For subsequent changes:

1. All three migrations are applied. Subsequent changes must use new migrations.
2. Explicitly target the intended development project and preview pending
   changes before pushing through Supabase migration tooling.
3. Preserve migration history; do not recreate these tables manually in Table
   Editor or reset a hosted database.
4. After applying changes, verify expected schema objects, table RLS, and
   application-role privileges.
5. Keep hosted verification read-only unless an integration test is explicitly
   designed and authorized for that environment. Never run the disposable
   `tests/bootstrap_roles.sql` or `tests/foundation.sql` there.

The project owner performed CLI login, project linking, and the original two
migrations. With explicit authorization, the assistant applied migration 003 and
the minimal hosted Auth profile on 2026-11-07 and performed read-only verification. Credentials stay in ignored local configuration or your password
manager, never migration files.

## Verification

See [tests/README.md](tests/README.md). The migrations and behavioral tests can run
on an isolated PostgreSQL database without Docker or external APIs. Tests cover
ownership, editors, admins, bans, tag constraints, duplicate identities,
transactional audit, immutability, and denied runtime access. Hosted table RLS and schema-usage checks are recorded above. Supabase Data API
behavior, remaining hosted configuration, multi-connection concurrency, and
end-to-end authenticated access still require testing when those are connected.
