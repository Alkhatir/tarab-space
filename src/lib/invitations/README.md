# Invitation membership

Reddit OAuth is replaced by Supabase email/password identity plus invitation-only
platform membership. Every active member, including members without an elevated
role, can invite. The inviter verifies the recipient outside the app, and binds
the invitation to that person's canonical Reddit username. This is social trust,
not technical proof of control over a Reddit account or subreddit subscription.

## Lifecycle

1. An admin imports a complete, dated eligibility snapshot from the weekly scraper.
2. An active member issues a username-bound, single-use, revocable invitation.
3. The recipient creates or signs in to a Supabase email/password account.
4. After email confirmation, they return to the original invitation and accept.
5. The database rechecks token, username, current roster, inviter ban state,
   uniqueness, and account verification before creating membership atomically.

Supabase Auth identity alone grants no Tarab Space membership or database-table
access. Direct Auth API signups can still create uninvited Auth accounts; the
membership gate is enforced in the database, not by hiding a signup button.
If strict prevention of even unused Auth accounts becomes necessary, add a
reviewed Auth signup hook or server-managed account creation before launch.

The database RPCs derive identity from verified JWT `auth.uid()` and check
`auth.users.email_confirmed_at`. They never trust caller-supplied member IDs,
roles, email-verification flags, or user-editable Auth metadata. The browser uses
only the publishable key. All private table/function grants remain revoked.

## Defaults

- Invitations last 48 hours and can be used once; same-account retries are safe.
- A member may issue at most ten invitations per rolling 24 hours.
- Latest 100 own invitations are visible without raw tokens or token hashes.
- The inviter or an active admin can revoke an unused invitation.
- Weekly snapshots expire for onboarding after eight days (one-day grace).
- Removed/inactive usernames cannot redeem an outstanding invitation.
- Stale/removal checks do not automatically ban existing members.
- An inviter's ban blocks pending redemptions but does not automatically ban
  people they previously invited. Admins decide those cases explicitly.

These are initial operational defaults, changed by a new migration if needed.

## Tokens and graph data

Store only SHA-256 token hashes. RPC-issued tokens use two CSPRNG-generated UUIDs
(244 random bits), hashed and encoded as 43-character base64url strings. The
server-only `tokens.ts` utility also supports 256-bit Node-generated tokens for
future server-driven issuance; current RPC issuance never accepts client-chosen
hashes or raw tokens. Validation/hashing alone is not authorization.

Raw links are shown once, held in component memory, and not recoverable through
the invitation list. Links use `/join#invite=…` so the bearer token is not sent in
page URLs or Referer headers. Keep links private. The fragment remains while
onboarding so users can return after email confirmation; it is cleared after
successful acceptance. Never log request bodies/tokens or add analytics that
capture fragments. Invite tokens are not placed in Auth user metadata or emails.

`invitations.invited_by`, `accepted_by`, `created_at`, and `accepted_at`, with
`members.invitation_id`, preserve graph edges, including who invited whom and
when. Revocations retain `revoked_at` and `revoked_by`. Completed invitation
records and membership identity links are immutable. The first owner-bootstrapped
member has no incoming invitation. No public graph or private-roster export is
exposed; a graph dashboard can be built later with appropriate admin permissions.

## Weekly scraper import contract

The source website/URL, permitted access method, and scheduler are not configured.
No scraper, Reddit API call, bypass, or cron job is implemented. An observed
contributor roster is not a list of all subreddit subscribers. Record the source
and observation time honestly.

The admin-only `tarab_import_eligibility(text[], text, timestamptz)` RPC takes a
**complete** snapshot, a source label, and its observation timestamp. It validates
and normalizes every username before any change, rejects empty/invalid/stale or
out-of-order snapshots, deduplicates names, and atomically deactivates names not
in that snapshot. Partial pages, timeouts, and failed scrapes must never be sent
as complete snapshots. Failed imports leave the previous roster intact.

Imports and redemptions use a shared transaction lock. Automatic imports need a
separately configured trusted caller; do not put an admin password or service key
in browser code or grant public roster access. Initial imports can be performed
through an explicit database-owner transaction after the first admin is set up.

## Deployment and limits

Migration `20261106000300_invitation_membership.sql` is prepared locally, **not
applied** to Supabase. Do not edit migrations 001/002, which are already applied.
See `supabase/README.md` for Auth settings and initial-account bootstrap.
Existing legacy member records, if any, need a deliberate verified-identity
backfill migration; runtime identity reassignment is intentionally forbidden.

`/account` supports password sign-in/out and invitation management; `/join`
supports email-account creation and invitation acceptance. Email confirmation
must be enabled in Supabase, and Site URL/redirects must match the development
site. This milestone uses the Supabase SDK's browser session storage; server
components do not infer identity from it. Future server-side mutations need
verified Auth sessions or membership-checked RPCs, never trusted browser state.

Music saving, admin role/ban dashboards, password recovery UI, SMTP deliverability,
CAPTCHA/rate limits for Auth itself, automated scraping, graph visualization, and
hosted end-to-end verification are not implemented by this change.
