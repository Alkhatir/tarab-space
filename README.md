# 🎶 Tarab Space

**Tarab Space** is a community-driven music platform for members of [r/syrian-social-space](https://www.reddit.com/r/syrian-social_space/).

The intended experience: invited community members sign in with a verified email/password account, find a Spotify recording, personalize its tags, and submit it to a shared music library. Tracks are automatically grouped into overlapping clusters, with qualifying clusters synchronized to Spotify playlists. These integrations are planned; the current application is a credential-independent interface preview.

The project aims to turn the musical taste of the community into a collection of continuously evolving playlists.

> **Status:** Early development

---

## ✨ Concept

Tarab Space connects three things:

**Reddit community → Music submissions → Spotify playlists**

An invited member will authenticate through Supabase, select a Spotify recording, review its metadata and editable tags, and submit it. One track may belong to several clusters and therefore appear in several playlists.

```text
Username-bound invitation → Email identity → Shared track library → Overlapping clusters → Spotify playlists
```

The goal is to create playlists that reflect the musical diversity of the community rather than the taste of a single curator.

---

## 🚀 Planned Features

- 🔐 **Invitation-only membership with Supabase email/password login**
- 👤 Associate submissions with authenticated platform members
- 🎵 Submit songs to Tarab Space
- 🏷️ Assign genres and tags to submissions
- 🔎 Retrieve song metadata from Spotify
- 📂 Automatically organize songs by genre
- 🎧 Automatically create and maintain Spotify playlists
- 🔄 Synchronize Tarab Space playlists with Spotify
- 🚫 Prevent duplicate song submissions
- 🛡️ Community eligibility and anti-spam rules
- 📊 Browse songs submitted by the community

---

## 🔄 Planned Flow

### 1. Find a recording

Paste a Spotify track URL, or search by song title or musician. Once the live integration exists, Spotify search will suggest recordings; selecting one will populate title, artist information, and available metadata. Credentials and live requests are deferred.

### 2. Personalize tags

Spotify metadata stays separate from user-edited tags. Users can remove, edit, or add suggested tags before submission, including starting with no suggestions. Spotify's [track response](https://developer.spotify.com/documentation/web-api/reference/get-track) does not include track-level genres. [Artist genres](https://developer.spotify.com/documentation/web-api/reference/get-an-artist), where available, are only suggestions and may be empty or unsuitable for the recording.

### 3. Publish without duplicates

After a successful database save, the track appears immediately; there is no approval queue. A PostgreSQL uniqueness constraint on Spotify track ID will prevent duplicate library entries even for concurrent submissions. A duplicate submission will point to the existing entry rather than create another.

Different Spotify IDs can represent different releases of the same recording. Cross-release deduplication remains a separate future decision; a title/artist text comparison will not be treated as a reliable unique identity. The original contributor and active editors may edit tags; other members see the existing entry and ownership without editing controls. An admin needs the editor role to edit another member's track.

### 4. Group automatically

Tracks can belong to multiple clusters based on shared properties such as normalized tags and artists. Begin with transparent, deterministic grouping rules; do not choose an exclusive, single-cluster algorithm. A new track may create, change, split, or merge clusters. Exact similarity thresholds and weighting will be evaluated against real submissions.

AI is a possible future research direction, not a committed dependency. Spotify's [Developer Policy](https://developer.spotify.com/policy) prohibits ingesting Spotify content into AI/ML models. Do not send Spotify metadata, artwork, or audio into embeddings, LLMs, or model training. Any future AI approach needs a permitted independent data source and review of applicable terms. Rule-based grouping is the initial design, not a claim that arbitrary processing or retention of Spotify content is permitted.

### 5. Synchronize playlists

- A cluster qualifies at **six distinct tracks** (more than five).
- A track may appear in multiple playlists through overlapping membership, but appears only once within each playlist.
- Playlist names reflect dominant tags, artists, or both, with a stable identifier to distinguish similarly named clusters.
- PostgreSQL is the source of truth. Spotify playlists are synchronized external representations.
- Save and publish the submission first; clustering and Spotify synchronization run afterward in small, retryable background batches. A Spotify failure must not discard the saved submission.
- Reconcile the desired playlist contents with Spotify rather than blindly appending tracks on each retry.
- Preserve playlist IDs and URLs when a cluster has a clear successor. Splits and merges may require creating new qualifying playlists and retiring superseded ones.
- The exact retirement behavior for vanished clusters or clusters falling below six tracks is still to be defined before implementing synchronization. Do not automatically delete playlists as an implicit default.

```text
URL or title/artist search
          ↓
Select recording → Metadata + editable tags
          ↓
Unique database save → Immediately visible in Discover
          ↓
Recalculate affected overlapping clusters
          ↓
Reconcile Spotify playlists for qualifying clusters
```

---

## 🏗️ Architecture

Tarab Space starts as a modular monolith. Next.js provides both the frontend (Server Components by default) and backend (Route Handlers) in one application.

```text
Next.js
   │
   ├── Supabase Auth (email/password)
   ├── Weekly eligibility snapshot import (scraper pending)
   ├── Spotify Web API
   └── Supabase PostgreSQL
```

The foundation uses TypeScript strict mode, React, Tailwind CSS, ESLint, pnpm, and Zod. PostgreSQL will be the source of truth; Spotify playlists will be an external synchronized representation. Supabase Auth is now the chosen email/password identity provider; invitations and an independently maintained username allowlist govern platform membership. Reddit OAuth is no longer required.

External integrations will be implemented incrementally. Their boundaries live in `src/lib/reddit`, `src/lib/spotify`, and `src/lib/supabase`. Shared UI components and domain types can be added to `src/components` and `src/types` when needed.

Currently implemented: a shared responsive layout, a Discover homepage with local search and tag filtering, an About page, a submission-interface preview at `/submit`, lazy server-side environment validation, a Supabase client constructor, and `GET /api/health`. Versioned database migrations and permission/audit tests live under `supabase/`. Both initial migrations have been applied to the hosted development project; the project owner verified all eight tables have RLS enabled and the three application roles have no private-schema usage. Invitation migration 003 and the minimal Auth profile were deployed to the development project on 2026-11-07. First-admin bootstrap, initial roster import, and hosted email/onboarding verification remain outstanding. Live Spotify lookup, music saving, clustering, and playlist synchronization are not implemented.

### Database foundation (applied to development)

The [database guide](supabase/README.md) documents the schema, access boundary, migration workflow, and [SQL verification](supabase/tests/README.md). Migrations cover members, separate editor/admin roles, bans, Spotify track/artist identities, original contributions, editable tags, and transactional audit history. The private schema denies all current application-role access; fixture-based pages remain unchanged.

Contributors and editors can change a track's tags. Admins can assign roles and ban/unban members; admin does not imply editor. Bans override action permissions. Duplicate submissions show the original contributor/time and never transfer ownership. Audit events record who added, edited, or removed tags, along with timestamps and before/after values; role and ban changes are audited as well.

### Invitation update (migration 003 deployed to development)

`/account` and `/join` implement email/password account UI and the invitation workflow. Migration `20261106000300_invitation_membership.sql` adds Auth identity mapping, roster snapshots, username-bound hashed invitations, graph provenance, and membership-checked RPCs. It preserves internal member UUIDs and all existing ownership, roles, bans, and audit history. It was applied to the development project on 2026-11-07; all three migration histories match. Read-only hosted checks verified RLS on all eleven tables, denied private-schema usage for app roles, and the six intended authenticated-only RPC grants. Applied migrations must remain unchanged.

### Discover preview

The homepage uses explicitly labeled sample music from `src/lib/demo/tracks.ts`. Tags are illustrative and are not Spotify metadata or clustering results. Search matches track titles, artists, and tags; tag filters combine with search, and filters can be reset from the results or empty state. Track links open Spotify search, not a verified recording or an integrated player.

The layout and pages are Server Components; interactive navigation and discovery controls use small client components in `src/components`. No credentials, database, external requests, or new dependencies are needed. Sample data and its presentation type are temporary UI fixtures, not a contract for the eventual metadata, clustering, or playlist workflow.

### Submission preview

`/submit` provides local sample search by title or artist, Spotify track URL validation, recording selection, read-only sample metadata, an editable tag list, and a draft review. URL validation never fetches metadata or associates a URL with an unrelated sample. The final submission button is disabled and nothing is persisted, including across reloads.

- UI: `src/components/submission/`; the page itself remains a Server Component.
- Fixtures: `src/lib/demo/tracks.ts`, separate from integration code and eventual domain contracts.
- Browser-safe Zod validation: `src/lib/submissions/validation.ts`.
- Preview limits: up to 12 tags, each 1–40 characters after trimming and whitespace normalization. Tags can be removed entirely; duplicate tags are rejected ignoring case, Unicode compatibility differences, and extra spaces. The database migrations mirror these limits; see the database guide for Unicode length/collation differences to verify before wiring saving.
- Full HTTPS Spotify track URLs, including supported `intl-xx` paths and sharing query strings, are recognized. Album, artist, playlist, URI, and shortened-link resolution are deferred.
- A new tag must be added or cleared before reviewing. Selecting a different recording starts a fresh draft; same-recording selection preserves edits.
- There are no mock production endpoints, fake successful submissions, external requests, or browser storage. Live lookup and saving remain unavailable until connected.

---

## 🛡️ Invitation-based community access

Reddit OAuth has been removed from the plan. Every active member can invite someone, regardless of editor/admin roles. The inviter verifies the person outside the app and creates a single-use invitation bound to their Reddit username. The link expires after 48 hours; the inviter or an admin may revoke it. New members use Supabase email/password login and must confirm their email before redemption.

A private allowlist will be refreshed by a weekly website scrape. Reddit does not expose a full subscriber roster, so the table represents eligibility under our chosen source, not proof of subscription. Matching a typed username alone does not establish Reddit ownership; trust comes from the inviter's external verification. The source URL, allowed access method, and scheduler remain to be specified.

Redemption atomically rechecks the invitation, bound username, verified email account, current eligibility, inviter ban status, and unique membership. Snapshots older than eight days block new onboarding; existing members are not automatically banned when a snapshot changes. A Supabase Auth account without an accepted invitation has no platform privileges.

Invitation records retain who invited whom, issue/acceptance timestamps, and revocation attribution for a future graph. Graph data and the eligibility roster are private. See [the invitation guide](src/lib/invitations/README.md) for limits, secure tokens, snapshot import, and deployment requirements.

---

## 🎼 Genre System

The genre system is intended to remain flexible.

Genres may eventually come from a combination of:

1. user-selected genres,
2. predefined Tarab Space categories,
3. Spotify metadata,
4. community-created tags.

This allows music that does not fit neatly into conventional Spotify categories to still have a meaningful place in the collection.

This is particularly relevant for genres and traditions such as:

- Tarab
- Levantine music
- Syrian folk music
- Arabic pop
- Dabke
- Mawwal
- Classical Arabic music

while still supporting international genres such as rock, metal, jazz, hip-hop, electronic music, and others.

---

## 🗺️ Roadmap

### Phase 1 — Foundation and interface previews

- [x] Set up the Next.js modular monolith
- [x] Shared responsive layout and About page
- [x] Discover preview with sample search and tag filtering
- [x] Submission preview with recording selection and editable tags
- [x] Document the agreed lifecycle and integration boundaries

### Phase 2 — Persistence and identity

- [x] Prepare versioned SQL migrations and fail-closed database access model
- [x] SQL tests for contribution ownership, permissions, bans, and audit history
- [x] Review and apply migrations to the hosted development project
- [x] Verify hosted table RLS and denied private-schema usage for app roles
- [ ] Implement trusted server access after verified Supabase sessions and active-membership checks
- [ ] Apply invitation migration 003 and configure Supabase email confirmation
- [ ] Verify invitation signup/sign-in end to end on the hosted development project
- [ ] Persist unique track submissions with immediate visibility
- [ ] Connect Discover to stored submissions
- [x] Define tag permissions: original contributor or editor
- [ ] Protected admin dashboard for role assignment and member bans
- [ ] Configure and validate the weekly scraper source and trusted snapshot importer

### Phase 3 — Live Spotify lookup

- [ ] Configure credentials and verify API access
- [ ] Search by title/artist and resolve Spotify track URLs
- [ ] Populate recording metadata and optional artist-genre suggestions
- [ ] Add rate-limit handling, failures, and server-side validation

### Phase 4 — Grouping and synchronization

- [ ] Implement and evaluate deterministic overlapping grouping
- [ ] Track cluster identities and membership revisions
- [ ] Create playlists at six distinct tracks
- [ ] Generate descriptive, distinguishable playlist names
- [ ] Reconcile playlist contents through retryable background work
- [ ] Handle splits, merges, unavailable tracks, and retirement rules

### Later possibilities

- Cross-release deduplication
- Community statistics and playlist discovery
- AI-assisted grouping only with permitted data and reviewed terms

---

## 💻 Development

Use Node.js 20.9 or newer and pnpm (the exact package manager version is recorded in package.json).

```bash
pnpm install
pnpm dev
```

Open http://localhost:3000. No external credentials or environment file are needed for Discover (`/`), About (`/about`), the submission preview (`/submit`), or the health endpoint.

```bash
pnpm lint
pnpm typecheck
pnpm build
pnpm start
```

`pnpm start` serves the production build. Health check: `GET /api/health` returns `{"status":"ok","service":"tarab-space"}`.

Next, bootstrap the first real admin and import the first eligibility snapshot. Migration 003 and the minimal hosted Auth settings are already deployed. Verify invitation-based onboarding before connecting music persistence. Spotify credentials/integration and deployment configuration remain deferred. Before deployment, address the existing Next.js security advisory reported by the development/build tooling.

---

## 🔑 Environment Variables

Copy `.env.example` to `.env.local` when configuring integrations; never commit credentials. All environment files are ignored except `.env.example`.

`src/lib/env.ts` is server-only. Call `getIntegrationEnv("spotify" | "supabase")` only when the corresponding feature needs it. Missing or invalid values raise an error naming the variables without printing their values. Supabase Auth manages email/password sessions; Reddit OAuth and a custom session secret are no longer required.

Only `NEXT_PUBLIC_` values may be referenced by browser code. These values are public, including the Supabase publishable key. Spotify client secrets must stay on the server. `NEXT_PUBLIC_APP_URL` is reserved for future application links; it is not required by the current page.

The Supabase constructor is server-only and uses the publishable key with anonymous-role permissions. The private schema deliberately denies this helper access. Verified Supabase sessions, active invitation-based membership, and a restricted data-access surface are required for every protected operation. Narrow invitation RPCs are deployed by migration 003; general music queries/writes remain unavailable.

---

## 🤝 Contributing

Tarab Space is currently in an early stage.

Ideas, bug reports, feature suggestions, and contributions are welcome as the project develops.

If you would like to propose a major feature, consider opening an issue first so the idea and implementation can be discussed.

---

## 🎯 Project Philosophy

Tarab Space is not intended to be another music recommendation algorithm.

It is meant to answer a much simpler question:

> **What does our community listen to?**

Instead of playlists generated primarily from listening algorithms, Tarab Space builds playlists from music deliberately shared by people in the community.

Over time, the playlists should become a small musical archive of `r/syrian-social-space` — from Syrian and Arabic music to everything else the community happens to love.

---

## 📜 License

A license has not yet been selected.

---

## ⚠️ Disclaimer

Tarab Space is an independent community project and is not affiliated with, endorsed by, or sponsored by Reddit or Spotify.

Reddit and Spotify are trademarks of their respective owners.
