# 🎶 Tarab Space

**Tarab Space** is a community-driven music platform for members of [r/syrian-social-space](https://www.reddit.com/r/syrian-social_space/).

The idea is simple: community members sign in with their Reddit account, submit music they enjoy, assign genres or tags, and Tarab Space automatically organizes those submissions into collaborative Spotify playlists.

The project aims to turn the musical taste of the community into a collection of continuously evolving playlists.

> **Status:** Early development

---

## ✨ Concept

Tarab Space connects three things:

**Reddit community → Music submissions → Spotify playlists**

A user authenticates using Reddit, submits a song and its genre, and Tarab Space handles organizing the music into the appropriate playlist.

For example:

```text
r/syrian-social-space
        │
        ▼
   Reddit Login
        │
        ▼
   Tarab Space
        │
        ├── Arabic Pop
        ├── Tarab
        ├── Rock
        ├── Jazz
        ├── Metal
        └── Electronic
                │
                ▼
        Spotify Playlists
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

### 1. Authenticate

Users log in using their Reddit account through Reddit OAuth.

```text
User
  ↓
Reddit OAuth
  ↓
Tarab Space
```

Reddit authentication provides an identity for each contributor and can later be used as part of the community eligibility system.

### 2. Submit Music

Authenticated users can submit a song and select or suggest a genre.

A submission could contain information such as:

```text
Track: ...
Artist: ...
Spotify ID: ...
Genre: ...
Submitted by: u/username
```

### 3. Classify

Tarab Space associates the track with its genre or tags.

Where useful, metadata obtained from Spotify can help with classification and track identification.

### 4. Build Playlists

Each supported genre can correspond to a Spotify playlist.

```text
Genre                 Spotify Playlist
─────────────────────────────────────────
Tarab          →      Tarab Space — Tarab
Arabic Pop     →      Tarab Space — Arabic Pop
Rock           →      Tarab Space — Rock
Jazz           →      Tarab Space — Jazz
Electronic     →      Tarab Space — Electronic
```

When accepted songs are added to Tarab Space, the corresponding Spotify playlists can be updated automatically.

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

Currently implemented: a shared responsive layout, a Discover homepage with local search and tag filtering, an About page, lazy server-side environment validation, a Supabase client constructor, and `GET /api/health`. OAuth, eligibility checks, database schema, queries, and playlist synchronization are not implemented.

### Discover preview

The homepage uses explicitly labeled sample music from `src/lib/demo/tracks.ts`. Tags are illustrative and are not Spotify metadata or clustering results. Search matches track titles, artists, and tags; tag filters combine with search, and filters can be reset from the results or empty state. Track links open Spotify search, not a verified recording or an integrated player.

The layout and pages are Server Components; interactive navigation and discovery controls use small client components in `src/components`. No credentials, database, external requests, or new dependencies are needed. Sample data and its presentation type are temporary UI fixtures, not a contract for the eventual metadata, clustering, or playlist workflow.

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

### Phase 1 — Foundation

- [x] Set up application structure
- [ ] Configure database
- [ ] Implement Reddit OAuth
- [ ] Create user model
- [x] Create basic frontend

### Phase 2 — Music Submission

- [ ] Integrate Spotify API
- [ ] Search Spotify tracks
- [ ] Submit tracks
- [ ] Store track metadata
- [ ] Add genre selection
- [ ] Detect duplicate submissions

### Phase 3 — Playlist Automation

- [ ] Create Spotify playlists automatically
- [ ] Map genres to playlists
- [ ] Add accepted tracks to playlists
- [ ] Synchronize database and Spotify playlists
- [ ] Handle removed or unavailable tracks

### Phase 4 — Community Features

- [ ] Implement subreddit activity/eligibility rules
- [ ] Add moderation tools
- [ ] Add voting or approval system
- [ ] Allow community-generated genres/tags
- [ ] Add user contribution history

### Phase 5 — Discovery

- [ ] Browse community submissions
- [ ] Search by artist or genre
- [ ] Community statistics
- [ ] Most submitted artists
- [ ] Trending tracks
- [ ] Playlist discovery page

---

## 💻 Development

Use Node.js 20.9 or newer and pnpm (the exact package manager version is recorded in package.json).

```bash
pnpm install
pnpm dev
```

Open http://localhost:3000. No external credentials or environment file are needed for the landing page or health endpoint.

```bash
pnpm lint
pnpm typecheck
pnpm build
pnpm start
```

`pnpm start` serves the production build. Health check: `GET /api/health` returns `{"status":"ok","service":"tarab-space"}`.

The next milestone is to define how submitted music metadata, clustering, and playlist creation should work before implementing those integrations. Reddit authentication and the user model remain planned. Deployment configuration is intentionally deferred.

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
