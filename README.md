# 🎶 Tarab Space

**Tarab Space** is a community-driven music platform for members of [r/syrian-social-space](https://www.reddit.com/r/syrian-social_space/).

The intended experience: community members sign in with Reddit, find a Spotify recording, personalize its tags, and submit it to a shared music library. Tracks are automatically grouped into overlapping clusters, with qualifying clusters synchronized to Spotify playlists. These integrations are planned; the current application is a credential-independent interface preview.

The project aims to turn the musical taste of the community into a collection of continuously evolving playlists.

> **Status:** Early development

---

## ✨ Concept

Tarab Space connects three things:

**Reddit community → Music submissions → Spotify playlists**

A user will authenticate using Reddit, select a Spotify recording, review its metadata and editable tags, and submit it. One track may belong to several clusters and therefore appear in several playlists.

```text
Reddit identity → Shared track library → Overlapping clusters → Spotify playlists
```

The goal is to create playlists that reflect the musical diversity of the community rather than the taste of a single curator.

---

## 🚀 Planned Features

- 🔐 **Sign in with Reddit**
- 👤 Associate submissions with authenticated Reddit users
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

Different Spotify IDs can represent different releases of the same recording. Cross-release deduplication remains a separate future decision; a title/artist text comparison will not be treated as a reliable unique identity. How later users can propose tag changes to an existing entry also remains to be defined.

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
   ├── Reddit API / OAuth
   ├── Spotify Web API
   └── Supabase PostgreSQL
```

The foundation uses TypeScript strict mode, React, Tailwind CSS, ESLint, pnpm, and Zod. PostgreSQL will be the source of truth; Spotify playlists will be an external synchronized representation. Reddit will provide the primary user identity, rather than Supabase Auth.

External integrations will be implemented incrementally. Their boundaries live in `src/lib/reddit`, `src/lib/spotify`, and `src/lib/supabase`. Shared UI components and domain types can be added to `src/components` and `src/types` when needed.

Currently implemented: a shared responsive layout, a Discover homepage with local search and tag filtering, an About page, a submission-interface preview at `/submit`, lazy server-side environment validation, a Supabase client constructor, and `GET /api/health`. OAuth, live Spotify lookup, eligibility checks, database schema, saving, duplicate enforcement, clustering, and playlist synchronization are not implemented.

### Discover preview

The homepage uses explicitly labeled sample music from `src/lib/demo/tracks.ts`. Tags are illustrative and are not Spotify metadata or clustering results. Search matches track titles, artists, and tags; tag filters combine with search, and filters can be reset from the results or empty state. Track links open Spotify search, not a verified recording or an integrated player.

The layout and pages are Server Components; interactive navigation and discovery controls use small client components in `src/components`. No credentials, database, external requests, or new dependencies are needed. Sample data and its presentation type are temporary UI fixtures, not a contract for the eventual metadata, clustering, or playlist workflow.

### Submission preview

`/submit` provides local sample search by title or artist, Spotify track URL validation, recording selection, read-only sample metadata, an editable tag list, and a draft review. URL validation never fetches metadata or associates a URL with an unrelated sample. The final submission button is disabled and nothing is persisted, including across reloads.

- UI: `src/components/submission/`; the page itself remains a Server Component.
- Fixtures: `src/lib/demo/tracks.ts`, separate from integration code and eventual domain contracts.
- Browser-safe Zod validation: `src/lib/submissions/validation.ts`.
- Preview limits: up to 12 tags, each 1–40 characters after trimming and whitespace normalization. Tags can be removed entirely; duplicate tags are rejected ignoring case, Unicode compatibility differences, and extra spaces. These are initial UI limits, not a database schema.
- Full HTTPS Spotify track URLs, including supported `intl-xx` paths and sharing query strings, are recognized. Album, artist, playlist, URI, and shortened-link resolution are deferred.
- A new tag must be added or cleared before reviewing. Selecting a different recording starts a fresh draft; same-recording selection preserves edits.
- There are no mock production endpoints, fake successful submissions, external requests, or browser storage. Live lookup and saving remain unavailable until connected.

---

## 🛡️ Community Access

Tarab Space is intended specifically for the **r/syrian-social-space community**.

Authentication alone does not necessarily establish whether someone belongs to or participates in the subreddit, so the exact eligibility system is still being designed.

Possible eligibility rules may include factors such as:

- Reddit account authentication
- activity in `r/syrian-social-space`
- minimum account age
- previous posts or comments in the subreddit
- moderation or community-defined requirements

The purpose of these rules would be to keep playlist contributions community-driven while reducing spam and abuse.

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

- [ ] Versioned SQL migrations and database authorization model
- [ ] Reddit authentication, sessions, and user model
- [ ] Persist unique track submissions with immediate visibility
- [ ] Connect Discover to stored submissions
- [ ] Decide who may edit tags on existing entries
- [ ] Define subreddit eligibility rules before public access

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

Next, define versioned database migrations and authorization around the agreed workflow, then connect persistence and identity. Reddit and Spotify credentials, live integrations, and deployment configuration remain deferred. Before deployment, address the existing Next.js security advisory reported by the development/build tooling.

---

## 🔑 Environment Variables

Copy `.env.example` to `.env.local` when configuring integrations; never commit credentials. All environment files are ignored except `.env.example`.

`src/lib/env.ts` is server-only. Call `getIntegrationEnv("reddit" | "spotify" | "supabase" | "session")` only when the corresponding feature needs it. Missing or invalid values raise an error naming the variables without printing their values. Session configuration requires a secret of at least 32 characters.

Only `NEXT_PUBLIC_` values may be referenced by browser code. These values are public, including the Supabase publishable key. OAuth client secrets and session secrets must stay on the server. `NEXT_PUBLIC_APP_URL` is reserved for future application links; it is not required by the current page.

The Supabase constructor is server-only and uses the publishable key with anonymous-role permissions; database authorization and row-level security must be designed before data access is added.

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
