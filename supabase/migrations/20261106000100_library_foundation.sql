-- Private by design: do not add tarab_private to Supabase's exposed schemas.
-- No runtime role receives access until trusted Reddit sessions are implemented.
create schema tarab_private;
revoke all on schema tarab_private from public, anon, authenticated, service_role;
alter default privileges in schema tarab_private revoke execute on functions from public;

create table tarab_private.members (
  id uuid primary key default gen_random_uuid(),
  reddit_user_id text not null unique check (reddit_user_id ~ '^[a-z0-9]{1,32}$'),
  username text not null check (char_length(btrim(username)) between 1 and 100),
  joined_at timestamptz not null default transaction_timestamp(),
  banned_at timestamptz,
  banned_by uuid references tarab_private.members(id) on delete restrict,
  ban_reason text,
  check (
    (banned_at is null and banned_by is null and ban_reason is null)
    or (banned_at is not null and banned_by is not null and char_length(btrim(ban_reason)) between 1 and 1000 and ban_reason is not null)
  )
);

-- Membership is implicit. Editor and admin are independent, additive app roles.
create table tarab_private.member_roles (
  member_id uuid not null references tarab_private.members(id) on delete restrict,
  role text not null check (role in ('editor', 'admin')),
  granted_at timestamptz not null default transaction_timestamp(),
  primary key (member_id, role)
);

create table tarab_private.artists (
  id uuid primary key default gen_random_uuid(),
  spotify_id text not null unique check (spotify_id ~ '^[A-Za-z0-9]{22}$'),
  name text not null check (char_length(btrim(name)) between 1 and 500)
);

create table tarab_private.tracks (
  id uuid primary key default gen_random_uuid(),
  spotify_id text not null unique check (spotify_id ~ '^[A-Za-z0-9]{22}$'),
  title text not null check (char_length(btrim(title)) between 1 and 1000),
  metadata_fetched_at timestamptz not null default transaction_timestamp()
);

create table tarab_private.track_artists (
  track_id uuid not null references tarab_private.tracks(id) on delete restrict,
  artist_id uuid not null references tarab_private.artists(id) on delete restrict,
  position smallint not null check (position >= 0),
  primary key (track_id, artist_id),
  unique (track_id, position)
);
create index track_artists_artist_idx on tarab_private.track_artists(artist_id);

-- Exactly one contribution/owner per track. A duplicate must reuse this record.
create table tarab_private.submissions (
  track_id uuid primary key references tarab_private.tracks(id) on delete restrict,
  submitted_by uuid not null references tarab_private.members(id) on delete restrict,
  submitted_at timestamptz not null default transaction_timestamp()
);
create index submissions_contributor_idx on tarab_private.submissions(submitted_by);

create function tarab_private.normalize_tag(value text) returns text
language sql immutable strict set search_path = ''
as $$ select btrim(regexp_replace(normalize(value, NFKC), '[[:space:]]+', ' ', 'g')); $$;

-- Suggested Spotify genres are not stored here automatically: this is the
-- contributor's final editable tag set, separate from catalog metadata.
create table tarab_private.track_tags (
  id uuid primary key default gen_random_uuid(),
  track_id uuid not null references tarab_private.submissions(track_id) on delete restrict,
  label text not null check (char_length(label) between 1 and 40),
  normalized_key text generated always as (lower(label)) stored,
  unique (track_id, normalized_key)
);

create table tarab_private.audit_events (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default clock_timestamp(),
  actor_id uuid not null references tarab_private.members(id) on delete restrict,
  action text not null check (action in (
    'track.submitted', 'tag.added', 'tag.edited', 'tag.removed',
    'role.granted', 'role.revoked', 'member.banned', 'member.unbanned'
  )),
  entity_id uuid not null,
  track_id uuid references tarab_private.tracks(id) on delete restrict,
  before_value jsonb,
  after_value jsonb,
  check (before_value is not null or after_value is not null)
);
create index audit_events_track_idx on tarab_private.audit_events(track_id, occurred_at, id);
create index audit_events_actor_idx on tarab_private.audit_events(actor_id, occurred_at, id);

-- RLS without policies is intentionally deny-by-default. Grants are also
-- revoked, including service_role; BYPASSRLS does not replace schema/table ACLs.
do $$
declare item record;
begin
  for item in select tablename from pg_tables where schemaname = 'tarab_private' loop
    execute format('alter table tarab_private.%I enable row level security', item.tablename);
  end loop;
end $$;
revoke all on all tables in schema tarab_private from public, anon, authenticated, service_role;
revoke all on all sequences in schema tarab_private from public, anon, authenticated, service_role;
revoke all on all functions in schema tarab_private from public, anon, authenticated, service_role;
