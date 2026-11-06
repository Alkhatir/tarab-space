# Community eligibility boundary

Reddit OAuth is no longer used for application identity. Supabase email/password
accounts can become platform members only by redeeming a valid invitation for an
eligible username, verified outside the app by the inviter.

The project owner plans a weekly website scrape to populate a private eligibility
allowlist. No scraper or Reddit API integration is implemented here. The source
URL, permitted access method, scheduling, and reliability still need definition.
Reddit does not expose a full subscriber roster; observed public contributors
must not be represented as all subscribers or proof of subscription.

See `src/lib/invitations/README.md` and `supabase/README.md` for the import contract.
