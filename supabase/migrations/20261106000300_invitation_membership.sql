-- Forward-only change: preserve contributions, roles, bans, and audit IDs.
-- Reddit OAuth identity becomes optional; verified Supabase email identity is used.
alter table tarab_private.members alter column reddit_user_id drop not null;
alter table tarab_private.members add column auth_user_id uuid unique references auth.users(id) on delete restrict;
alter table tarab_private.members add constraint members_username_format check (username ~ '^[A-Za-z0-9_-]{3,20}$');
create unique index members_username_unique on tarab_private.members(lower(username));

create function tarab_private.normalize_username(value text) returns text
language sql immutable strict set search_path = ''
as $$ select lower(regexp_replace(btrim(value), '^/?u/', '', 'i')); $$;

create table tarab_private.eligibility_imports (
  id uuid primary key default gen_random_uuid(),
  imported_at timestamptz not null default clock_timestamp(),
  observed_at timestamptz not null check (observed_at <= imported_at),
  source text not null check (char_length(btrim(source)) between 1 and 500),
  imported_by uuid not null references tarab_private.members(id),
  username_count integer not null check (username_count > 0)
);
create table tarab_private.eligible_usernames (
  username text primary key check (username ~ '^[a-z0-9_-]{3,20}$'),
  import_id uuid not null references tarab_private.eligibility_imports(id),
  active boolean not null default true
);
create table tarab_private.invitations (
  id uuid primary key default gen_random_uuid(),
  token_hash text not null unique check (token_hash ~ '^[a-f0-9]{64}$'),
  recipient_username text not null references tarab_private.eligible_usernames(username),
  invited_by uuid not null references tarab_private.members(id),
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  revoked_by uuid references tarab_private.members(id),
  accepted_at timestamptz,
  accepted_by uuid unique references tarab_private.members(id),
  check (expires_at > created_at),
  check ((revoked_at is null) = (revoked_by is null)),
  check ((accepted_at is null) = (accepted_by is null)),
  check (not (accepted_at is not null and revoked_at is not null))
);
create index invitations_inviter_idx on tarab_private.invitations(invited_by, created_at);
create index invitations_recipient_idx on tarab_private.invitations(recipient_username);
alter table tarab_private.members add column invitation_id uuid unique references tarab_private.invitations(id);

-- Immutable accepted invitations supply permanent graph edges and timestamps.
create function tarab_private.guard_invitation() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then raise exception 'Invitation history cannot be deleted' using errcode = '42501'; end if;
  if old.accepted_at is not null or old.revoked_at is not null or
     row(new.id,new.token_hash,new.recipient_username,new.invited_by,new.created_at,new.expires_at)
       is distinct from row(old.id,old.token_hash,old.recipient_username,old.invited_by,old.created_at,old.expires_at) then
    raise exception 'Invitation identity and completed history are immutable' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger guard_invitation before update or delete on tarab_private.invitations for each row execute function tarab_private.guard_invitation();

-- Add protection for new identity columns without rewriting the applied guards.
create function tarab_private.guard_member_identity() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.reddit_user_id is distinct from old.reddit_user_id or
     new.auth_user_id is distinct from old.auth_user_id or
     new.invitation_id is distinct from old.invitation_id or
     new.username is distinct from old.username then
    raise exception 'Member identities cannot be reassigned' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger guard_member_identity before update on tarab_private.members for each row execute function tarab_private.guard_member_identity();

create function tarab_private.require_verified_auth() returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare user_id uuid := auth.uid();
begin
  if user_id is null or not exists(select 1 from auth.users where id = user_id and email_confirmed_at is not null and email is not null) then
    raise exception 'Sign in with a verified email account' using errcode = '42501';
  end if;
  return user_id;
end $$;
create function tarab_private.authenticated_member() returns uuid
language plpgsql security definer set search_path = '' as $$
declare member_id uuid;
begin
  perform pg_advisory_xact_lock(847233,1);
  select id into member_id from tarab_private.members where auth_user_id = tarab_private.require_verified_auth() and banned_at is null;
  if member_id is null then raise exception 'Active invited membership is required' using errcode = '42501'; end if;
  perform set_config('tarab.actor_id',member_id::text,true);
  return member_id;
end $$;

-- Only this minimal, membership-checked RPC surface is exposed. No table grants.
create function public.tarab_my_membership() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := tarab_private.authenticated_member();
begin
  return (select jsonb_build_object('username',username,'joinedAt',joined_at) from tarab_private.members where id = actor);
end $$;

create function public.tarab_import_eligibility(p_usernames text[], p_source text, p_observed_at timestamptz) returns uuid
language plpgsql security definer set search_path = '' as $$
declare actor uuid := tarab_private.authenticated_member(); batch uuid; names text[];
begin
  perform tarab_private.require_admin();
  if cardinality(p_usernames) is null or cardinality(p_usernames) not between 1 and 50000 or
     p_source is null or char_length(btrim(p_source)) not between 1 and 500 or
     p_observed_at is null or p_observed_at > clock_timestamp() or p_observed_at < clock_timestamp() - interval '8 days' then
    raise exception 'Invalid or stale eligibility snapshot' using errcode = '22023';
  end if;
  select array_agg(distinct tarab_private.normalize_username(value)) into names from unnest(p_usernames) as value;
  if exists(select 1 from unnest(p_usernames) as value where value is null or tarab_private.normalize_username(value) !~ '^[a-z0-9_-]{3,20}$') then
    raise exception 'Invalid eligibility username' using errcode = '22023';
  end if;
  -- Shared lock with invitation redemption, so removal/import is authoritative.
  perform pg_advisory_xact_lock(847233,2);
  if exists(select 1 from tarab_private.eligibility_imports where observed_at > p_observed_at) then
    raise exception 'Cannot replace a newer eligibility snapshot' using errcode = '22023';
  end if;
  insert into tarab_private.eligibility_imports(observed_at,source,imported_by,username_count)
    values(p_observed_at,btrim(p_source),actor,cardinality(names)) returning id into batch;
  update tarab_private.eligible_usernames set active = false;
  insert into tarab_private.eligible_usernames(username,import_id,active)
    select value,batch,true from unnest(names) as value
    on conflict(username) do update set import_id = excluded.import_id, active = true;
  return batch;
end $$;

create function public.tarab_create_invitation(p_username text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := tarab_private.authenticated_member(); recipient text := tarab_private.normalize_username(p_username); token text; invitation tarab_private.invitations;
begin
  perform pg_advisory_xact_lock(847233,2);
  if recipient is null or not exists (
    select 1 from tarab_private.eligible_usernames e join tarab_private.eligibility_imports b on b.id = e.import_id
    where e.username = recipient and e.active and b.observed_at >= clock_timestamp() - interval '8 days'
  ) or exists(select 1 from tarab_private.members where lower(username) = recipient) then
    raise exception 'Recipient is unavailable or not currently eligible' using errcode = '22023';
  end if;
  -- Per-member issuance limit, enforced in the database, not just the UI.
  if (select count(*) from tarab_private.invitations where invited_by = actor and created_at > clock_timestamp() - interval '24 hours') >= 10 then
    raise exception 'Daily invitation limit reached' using errcode = '22023';
  end if;
  -- Two independently random UUIDs provide 244 random bits. Hash/base64url
  -- encodes them into a 43-character token without requiring pgcrypto.
  token := translate(rtrim(encode(sha256(convert_to(gen_random_uuid()::text || gen_random_uuid()::text,'UTF8')),'base64'),'='),'+/','-_');
  insert into tarab_private.invitations(token_hash,recipient_username,invited_by,expires_at)
    values(encode(sha256(convert_to(token,'UTF8')),'hex'),recipient,actor,clock_timestamp()+interval '48 hours') returning * into invitation;
  return jsonb_build_object('id',invitation.id,'token',token,'username',recipient,'expiresAt',invitation.expires_at);
end $$;

create function public.tarab_list_invitations() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := tarab_private.authenticated_member();
begin
  return (select coalesce(jsonb_agg(jsonb_build_object('id',id,'username',recipient_username,'createdAt',created_at,'expiresAt',expires_at,'acceptedAt',accepted_at,'revokedAt',revoked_at,'expired',expires_at<=clock_timestamp()) order by created_at desc),'[]'::jsonb)
    from (select * from tarab_private.invitations where invited_by = actor order by created_at desc limit 100) as invitations);
end $$;
create function public.tarab_revoke_invitation(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare actor uuid := tarab_private.authenticated_member();
begin
  update tarab_private.invitations set revoked_at = clock_timestamp(), revoked_by = actor where id = p_id and accepted_at is null and revoked_at is null
    and (invited_by = actor or exists(select 1 from tarab_private.member_roles where member_id = actor and role = 'admin'));
  if not found then raise exception 'Invitation is unavailable' using errcode = '22023'; end if;
end $$;
create function public.tarab_accept_invitation(p_token text, p_username text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare user_id uuid := tarab_private.require_verified_auth(); recipient text := tarab_private.normalize_username(p_username); invitation tarab_private.invitations; new_member uuid;
begin
  if p_token is null or p_token !~ '^[A-Za-z0-9_-]{43}$' or recipient is null then
    raise exception 'Invitation is unavailable' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(847233,1);
  perform pg_advisory_xact_lock(847233,2);
  select * into invitation from tarab_private.invitations where token_hash = encode(sha256(convert_to(p_token,'UTF8')),'hex') for update;
  if not found or invitation.recipient_username <> recipient then raise exception 'Invitation is unavailable' using errcode = '22023'; end if;
  if invitation.accepted_by is not null then
    if exists(select 1 from tarab_private.members where id = invitation.accepted_by and auth_user_id = user_id and banned_at is null) then return invitation.accepted_by; end if;
    raise exception 'Invitation is unavailable' using errcode = '22023';
  end if;
  if invitation.revoked_at is not null or invitation.expires_at <= clock_timestamp() or
     not exists(select 1 from tarab_private.members where id = invitation.invited_by and banned_at is null) or
     not exists(select 1 from tarab_private.eligible_usernames e join tarab_private.eligibility_imports b on b.id = e.import_id where e.username = recipient and e.active and b.observed_at >= clock_timestamp()-interval '8 days') or
     exists(select 1 from tarab_private.members where auth_user_id = user_id or lower(username) = recipient) then
    raise exception 'Invitation is unavailable' using errcode = '22023';
  end if;
  insert into tarab_private.members(username,auth_user_id,invitation_id) values(recipient,user_id,invitation.id) returning id into new_member;
  update tarab_private.invitations set accepted_by = new_member, accepted_at = clock_timestamp() where id = invitation.id;
  return new_member;
end $$;

-- Public wrappers always derive identity from auth.uid(), never a client actor.
-- Existing ownership, ban, role, and tag audit triggers continue to use member UUIDs.
alter table tarab_private.eligibility_imports enable row level security;
alter table tarab_private.eligible_usernames enable row level security;
alter table tarab_private.invitations enable row level security;
revoke all on all tables in schema tarab_private from public,anon,authenticated,service_role;
revoke all on all functions in schema tarab_private from public,anon,authenticated,service_role;
revoke all on all sequences in schema tarab_private from public,anon,authenticated,service_role;
revoke all on function public.tarab_my_membership(), public.tarab_import_eligibility(text[],text,timestamptz), public.tarab_create_invitation(text), public.tarab_list_invitations(), public.tarab_revoke_invitation(uuid), public.tarab_accept_invitation(text,text) from public,anon,service_role;
grant execute on function public.tarab_my_membership(), public.tarab_import_eligibility(text[],text,timestamptz), public.tarab_create_invitation(text), public.tarab_list_invitations(), public.tarab_revoke_invitation(uuid), public.tarab_accept_invitation(text,text) to authenticated;
