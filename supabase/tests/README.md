# Database verification

Use a new, disposable PostgreSQL database with UTF-8 encoding, owned by the test
connection role. Do not run test fixtures or bootstrap roles against the hosted
Supabase project. No Docker, Supabase Auth, OAuth credentials, or pgTAP is needed.

Using standard PostgreSQL client tools on a dedicated local test instance:

```sh
createdb tarab_space_test
psql -X --set ON_ERROR_STOP=1 --dbname tarab_space_test \
  --file supabase/tests/bootstrap_roles.sql \
  --file supabase/migrations/20261106000100_library_foundation.sql \
  --file supabase/migrations/20261106000200_permissions_and_audit.sql \
  --file supabase/tests/foundation.sql
```

The test connection must be allowed to create the three test-only roles and
switch roles. They are cluster-level roles, so use a dedicated test PostgreSQL
instance and do not reuse the bootstrap on a cluster that already has them.
`foundation.sql` runs its fixtures/assertions inside a transaction and rolls
back on success. The migrations themselves remain in this disposable database.
A nonzero `psql` exit indicates a failed migration or assertion.

For this milestone, both migrations and `foundation.sql` were also executed
successfully in an ephemeral PGlite PostgreSQL engine installed under `/tmp`,
with no application dependency added. This verifies actual PostgreSQL SQL,
constraints, triggers, permissions, and transactional behavior; it does not
replace future hosted integration or concurrent-connection tests.

## Invitation migration

On a **fresh disposable** plain PostgreSQL instance, add the Auth test stub before
running migration 003. Do not create this stub on Supabase; Supabase owns `auth`.

```sh
psql -X --set ON_ERROR_STOP=1 --dbname tarab_space_test \
  --file supabase/tests/auth_stub.sql \
  --file supabase/migrations/20261106000300_invitation_membership.sql \
  --file supabase/tests/foundation.sql \
  --file supabase/tests/invitations.sql
```

This assumes the first two migrations and test-only roles from the earlier
command are already present. Invitation tests emulate validated Auth claims with
privileged SQL settings; browser clients cannot set those SQL settings. They
cover verified-email gating, username binding, ordinary-member invitations,
admin-only complete imports, duplicate redemption, immutable graph identity,
revocation, removed eligibility, expiry, bans, and private schema isolation.
These are not end-to-end email delivery tests. Keep all fixtures off hosted data.
