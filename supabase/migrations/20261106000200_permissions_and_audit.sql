-- This transaction-local actor context may only be set by trusted server code
-- after session verification. It is NOT a JWT or a public authentication scheme.
-- No runtime principal has schema/table/function privileges in this milestone.
create function tarab_private.current_actor() returns uuid
language plpgsql stable security definer set search_path = ''
as $$
declare actor uuid;
begin
  actor := nullif(current_setting('tarab.actor_id', true), '')::uuid;
  if actor is null or not exists (
    select 1 from tarab_private.members where id = actor and banned_at is null
  ) then
    raise exception 'An active member actor is required' using errcode = '42501';
  end if;
  return actor;
end $$;

create function tarab_private.can_edit_track(actor uuid, target_track uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from tarab_private.members m where m.id = actor and m.banned_at is null)
    and exists (select 1 from tarab_private.submissions s where s.track_id = target_track)
    and (
      exists (select 1 from tarab_private.submissions s where s.track_id = target_track and s.submitted_by = actor)
      or exists (select 1 from tarab_private.member_roles r where r.member_id = actor and r.role = 'editor')
    );
$$;

create function tarab_private.require_admin() returns uuid
language plpgsql security definer set search_path = ''
as $$
declare actor uuid;
begin
  -- Serialize administrative mutations to protect the last active admin.
  perform pg_advisory_xact_lock(847233, 1);
  actor := tarab_private.current_actor();
  if not exists (select 1 from tarab_private.member_roles where member_id = actor and role = 'admin') then
    raise exception 'An admin role is required' using errcode = '42501';
  end if;
  return actor;
end $$;

create function tarab_private.guard_submission() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op <> 'INSERT' then
    raise exception 'Original contribution ownership and timestamp are immutable' using errcode = '42501';
  end if;
  if new.submitted_by <> tarab_private.current_actor() then
    raise exception 'A submission must belong to its actor' using errcode = '42501';
  end if;
  new.submitted_at := transaction_timestamp();
  return new;
end $$;
create trigger guard_submission before insert or update or delete on tarab_private.submissions
for each row execute function tarab_private.guard_submission();

create function tarab_private.guard_tag() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare target_track uuid; actor uuid;
begin
  actor := tarab_private.current_actor();
  target_track := case when tg_op = 'DELETE' then old.track_id else new.track_id end;
  -- Parent lock serializes tag changes, including the count limit.
  perform 1 from tarab_private.submissions where track_id = target_track for update;
  if not tarab_private.can_edit_track(actor, target_track) then
    raise exception 'Only the contributor or an editor can change track tags' using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  if tg_op = 'UPDATE' and (new.track_id <> old.track_id or new.id <> old.id) then
    raise exception 'Tag identity and track cannot be changed' using errcode = '42501';
  end if;
  new.label := tarab_private.normalize_tag(new.label);
  if tg_op = 'INSERT' and (select count(*) from tarab_private.track_tags where track_id = target_track) >= 12 then
    raise exception 'A track can have at most 12 tags' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger guard_tag before insert or update or delete on tarab_private.track_tags
for each row execute function tarab_private.guard_tag();

create function tarab_private.guard_role() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare actor uuid;
begin
  -- Bootstrap is restricted to the actual table-owner login, before any admin
  -- exists, and can only grant the acting member their own first admin role.
  perform pg_advisory_xact_lock(847233, 1);
  actor := tarab_private.current_actor();
  if tg_op = 'INSERT' and new.role = 'admin' and new.member_id = actor
    and session_user = pg_get_userbyid((select relowner from pg_class where oid = 'tarab_private.member_roles'::regclass))
    and not exists (select 1 from tarab_private.member_roles where role = 'admin') then
    new.granted_at := transaction_timestamp();
    return new;
  end if;
  actor := tarab_private.require_admin();
  if tg_op = 'UPDATE' then
    raise exception 'Revoke and grant roles instead of rewriting assignments' using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then
    if old.role = 'admin' and not exists (
      select 1 from tarab_private.member_roles r join tarab_private.members m on m.id = r.member_id
      where r.role = 'admin' and r.member_id <> old.member_id and m.banned_at is null
    ) then
      raise exception 'Cannot revoke the last active admin' using errcode = '42501';
    end if;
    return old;
  end if;
  if exists (select 1 from tarab_private.members where id = new.member_id and banned_at is not null) then
    raise exception 'Cannot grant roles to a banned member' using errcode = '42501';
  end if;
  new.granted_at := transaction_timestamp();
  return new;
end $$;
create trigger guard_role before insert or update or delete on tarab_private.member_roles
for each row execute function tarab_private.guard_role();

create function tarab_private.guard_member() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare actor uuid;
begin
  if tg_op = 'INSERT' then
    if new.banned_at is not null or new.banned_by is not null or new.ban_reason is not null then
      raise exception 'Create the member before issuing an audited ban' using errcode = '42501';
    end if;
    new.joined_at := transaction_timestamp();
    return new;
  end if;
  if new.id <> old.id or new.reddit_user_id <> old.reddit_user_id or new.joined_at <> old.joined_at then
    raise exception 'Member identity and join time are immutable' using errcode = '42501';
  end if;
  if row(new.banned_at, new.banned_by, new.ban_reason) is not distinct from row(old.banned_at, old.banned_by, old.ban_reason) then
    return new;
  end if;
  actor := tarab_private.require_admin();
  if old.banned_at is not null and new.banned_at is not null then
    raise exception 'Unban before issuing a new ban' using errcode = '42501';
  end if;
  if new.banned_at is not null then
    if new.id = actor then raise exception 'Cannot ban yourself' using errcode = '42501'; end if;
    if exists (select 1 from tarab_private.member_roles where member_id = new.id and role = 'admin') and not exists (
      select 1 from tarab_private.member_roles r join tarab_private.members m on m.id = r.member_id
      where r.role = 'admin' and r.member_id <> new.id and m.banned_at is null
    ) then
      raise exception 'Cannot ban the last active admin' using errcode = '42501';
    end if;
    new.banned_by := actor;
    new.banned_at := transaction_timestamp();
  else
    new.banned_by := null;
    new.ban_reason := null;
  end if;
  return new;
end $$;
create trigger guard_member before insert or update on tarab_private.members
for each row execute function tarab_private.guard_member();

-- Audit writes happen in the same transaction as the mutation. Before/after
-- values capture tag edits as one event rather than losing the rename history.
create function tarab_private.audit_mutation() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  previous jsonb; following jsonb; event_action text; entity uuid; target_track uuid;
begin
  if tg_op <> 'INSERT' then previous := to_jsonb(old); end if;
  if tg_op <> 'DELETE' then following := to_jsonb(new); end if;
  if tg_table_name = 'submissions' then
    event_action := 'track.submitted'; entity := new.track_id; target_track := new.track_id;
  elsif tg_table_name = 'track_tags' then
    if tg_op = 'UPDATE' and old.label = new.label then return new; end if;
    event_action := case tg_op when 'INSERT' then 'tag.added' when 'UPDATE' then 'tag.edited' else 'tag.removed' end;
    entity := coalesce(new.id, old.id); target_track := coalesce(new.track_id, old.track_id);
  elsif tg_table_name = 'member_roles' then
    event_action := case tg_op when 'INSERT' then 'role.granted' else 'role.revoked' end;
    entity := coalesce(new.member_id, old.member_id);
  else
    if row(new.banned_at, new.banned_by, new.ban_reason) is not distinct from row(old.banned_at, old.banned_by, old.ban_reason) then return new; end if;
    event_action := case when new.banned_at is null then 'member.unbanned' else 'member.banned' end;
    entity := new.id;
    previous := jsonb_build_object('banned_at', old.banned_at, 'banned_by', old.banned_by, 'ban_reason', old.ban_reason);
    following := jsonb_build_object('banned_at', new.banned_at, 'banned_by', new.banned_by, 'ban_reason', new.ban_reason);
  end if;
  insert into tarab_private.audit_events(actor_id, action, entity_id, track_id, before_value, after_value)
    values (tarab_private.current_actor(), event_action, entity, target_track, previous, following);
  return null;
end $$;
create trigger audit_submission after insert on tarab_private.submissions for each row execute function tarab_private.audit_mutation();
create trigger audit_tag after insert or update or delete on tarab_private.track_tags for each row execute function tarab_private.audit_mutation();
create trigger audit_role after insert or delete on tarab_private.member_roles for each row execute function tarab_private.audit_mutation();
create trigger audit_ban after update on tarab_private.members for each row execute function tarab_private.audit_mutation();

create function tarab_private.reject_audit_rewrite() returns trigger
language plpgsql set search_path = ''
as $$ begin raise exception 'Audit history is append-only' using errcode = '42501'; end $$;
create trigger immutable_audit before update or delete on tarab_private.audit_events
for each row execute function tarab_private.reject_audit_rewrite();
create trigger immutable_audit_truncate before truncate on tarab_private.audit_events
for each statement execute function tarab_private.reject_audit_rewrite();

revoke all on all functions in schema tarab_private from public, anon, authenticated, service_role;
