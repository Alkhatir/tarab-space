-- Run ONLY on a disposable test database after both migrations. All fixtures
-- roll back. No pgTAP, Supabase Auth, API keys, or external services are needed.
begin;

create function pg_temp.assert_true(ok boolean, message text) returns void
language plpgsql as $$ begin if ok is distinct from true then raise exception 'FAIL: %', message; end if; end $$;
create function pg_temp.expect_error(command text, expected_state text) returns void
language plpgsql as $$
begin
  begin
    execute command;
  exception when others then
    if sqlstate = expected_state then return; end if;
    raise exception 'Expected %, received %: %', expected_state, sqlstate, sqlerrm;
  end;
  raise exception 'Expected failure %, command succeeded', expected_state;
end $$;

insert into tarab_private.members(id, reddit_user_id, username) values
 ('00000000-0000-0000-0000-000000000001', 'admin1', 'admin'),
 ('00000000-0000-0000-0000-000000000002', 'owner1', 'contributor'),
 ('00000000-0000-0000-0000-000000000003', 'editor1', 'editor'),
 ('00000000-0000-0000-0000-000000000004', 'other1', 'other'),
 ('00000000-0000-0000-0000-000000000005', 'admin2', 'second_admin');

select set_config('tarab.actor_id', '00000000-0000-0000-0000-000000000001', true);
-- Owner-login-only first-admin bootstrap, audited like any subsequent grant.
insert into tarab_private.member_roles(member_id, role) values
 ('00000000-0000-0000-0000-000000000001', 'admin'),
 ('00000000-0000-0000-0000-000000000003', 'editor');
select pg_temp.assert_true((select count(*) = 2 from tarab_private.audit_events where action = 'role.granted'), 'role grants audited');
select pg_temp.expect_error($q$delete from tarab_private.member_roles where role = 'admin'$q$, '42501');
select pg_temp.expect_error($q$update tarab_private.members set banned_at = now(), ban_reason = 'self' where username = 'admin'$q$, '42501');

insert into tarab_private.artists(id, spotify_id, name) values
 ('10000000-0000-0000-0000-000000000001', 'aaaaaaaaaaaaaaaaaaaaaa', 'Sample musician');
insert into tarab_private.tracks(id, spotify_id, title) values
 ('20000000-0000-0000-0000-000000000001', 'bbbbbbbbbbbbbbbbbbbbbb', 'Test recording');
insert into tarab_private.track_artists(track_id, artist_id, position) values
 ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 0);
select pg_temp.expect_error($q$insert into tarab_private.tracks(spotify_id, title) values ('bbbbbbbbbbbbbbbbbbbbbb', 'Duplicate')$q$, '23505');
insert into tarab_private.tracks(spotify_id, title) values ('bbbbbbbbbbbbbbbbbbbbbb', 'Duplicate retry') on conflict (spotify_id) do nothing;
select pg_temp.assert_true((select count(*) = 1 and bool_and(title = 'Test recording') from tarab_private.tracks), 'duplicate retry preserves original catalog row');
select pg_temp.expect_error($q$insert into tarab_private.tracks(spotify_id, title) values ('invalid', 'Bad ID')$q$, '23514');

select set_config('tarab.actor_id', '00000000-0000-0000-0000-000000000002', true);
select pg_temp.expect_error($q$insert into tarab_private.submissions(track_id, submitted_by) values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004')$q$, '42501');
insert into tarab_private.submissions(track_id, submitted_by) values
 ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002');
select pg_temp.expect_error($q$update tarab_private.submissions set submitted_by = '00000000-0000-0000-0000-000000000004'$q$, '42501');
select pg_temp.expect_error($q$delete from tarab_private.submissions$q$, '42501');
select pg_temp.assert_true((select count(*) = 1 from tarab_private.audit_events where action = 'track.submitted' and actor_id = '00000000-0000-0000-0000-000000000002' and occurred_at is not null), 'contributor and time recorded');

insert into tarab_private.track_tags(id, track_id, label) values
 ('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '  Syrian   folk  ');
select pg_temp.assert_true((select label = 'Syrian folk' from tarab_private.track_tags), 'tag whitespace normalized');
select pg_temp.expect_error($q$insert into tarab_private.track_tags(track_id, label) values ('20000000-0000-0000-0000-000000000001', 'ＳＹＲＩＡＮ folk')$q$, '23505');
select pg_temp.expect_error($q$insert into tarab_private.track_tags(track_id, label) values ('20000000-0000-0000-0000-000000000001', '   ')$q$, '23514');
select pg_temp.expect_error($q$insert into tarab_private.track_tags(track_id, label) values ('20000000-0000-0000-0000-000000000001', repeat('a', 41))$q$, '23514');

select set_config('tarab.actor_id', '00000000-0000-0000-0000-000000000004', true);
select pg_temp.assert_true(not tarab_private.can_edit_track('00000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000001'), 'non-owner cannot edit');
select pg_temp.expect_error($q$update tarab_private.track_tags set label = 'Unauthorized'$q$, '42501');
select pg_temp.expect_error($q$delete from tarab_private.track_tags$q$, '42501');
select pg_temp.expect_error($q$insert into tarab_private.member_roles(member_id, role) values ('00000000-0000-0000-0000-000000000004', 'editor')$q$, '42501');
select pg_temp.expect_error($q$update tarab_private.members set banned_at = now(), ban_reason = 'not admin' where username = 'contributor'$q$, '42501');

-- Admin is NOT implicitly an editor.
select set_config('tarab.actor_id', '00000000-0000-0000-0000-000000000001', true);
select pg_temp.expect_error($q$update tarab_private.track_tags set label = 'Admin edit'$q$, '42501');

select set_config('tarab.actor_id', '00000000-0000-0000-0000-000000000003', true);
select pg_temp.assert_true(not tarab_private.can_edit_track('00000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000099'), 'editor cannot edit a nonexistent entry');
update tarab_private.track_tags set label = 'طرب';
select pg_temp.assert_true((select before_value->>'label' = 'Syrian folk' and after_value->>'label' = 'طرب' and actor_id = '00000000-0000-0000-0000-000000000003' from tarab_private.audit_events where action = 'tag.edited'), 'editor rename captures before, after, and actor');
select pg_temp.expect_error($q$update tarab_private.track_tags set id = gen_random_uuid()$q$, '42501');

-- Rejected operations and rolled-back edits must not create audit events.
select pg_temp.assert_true((select count(*) = 5 from tarab_private.audit_events), 'failed writes leave no audit events');
select pg_temp.expect_error($q$do $body$ begin update tarab_private.track_tags set label = 'Rolled back'; raise exception 'rollback test'; end $body$$q$, 'P0001');
select pg_temp.assert_true((select count(*) = 5 from tarab_private.audit_events), 'audit and edit roll back together');
select pg_temp.assert_true((select label = 'طرب' from tarab_private.track_tags), 'tag edit rolled back');

select set_config('tarab.actor_id', '00000000-0000-0000-0000-000000000001', true);
update tarab_private.members set banned_at = now(), ban_reason = 'Test ban' where username = 'editor';
select pg_temp.assert_true((select banned_by = '00000000-0000-0000-0000-000000000001' from tarab_private.members where username = 'editor'), 'ban actor is authoritative');
select set_config('tarab.actor_id', '00000000-0000-0000-0000-000000000003', true);
select pg_temp.expect_error($q$update tarab_private.track_tags set label = 'Banned edit'$q$, '42501');
select pg_temp.assert_true(not tarab_private.can_edit_track('00000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000001'), 'ban overrides editor role');
select set_config('tarab.actor_id', '00000000-0000-0000-0000-000000000001', true);
select pg_temp.expect_error($q$insert into tarab_private.member_roles(member_id, role) values ('00000000-0000-0000-0000-000000000003', 'admin')$q$, '42501');
update tarab_private.members set banned_at = null where username = 'editor';
delete from tarab_private.member_roles where member_id = '00000000-0000-0000-0000-000000000003' and role = 'editor';
select set_config('tarab.actor_id', '00000000-0000-0000-0000-000000000003', true);
select pg_temp.expect_error($q$update tarab_private.track_tags set label = 'Revoked editor'$q$, '42501');
select set_config('tarab.actor_id', '00000000-0000-0000-0000-000000000001', true);
insert into tarab_private.member_roles(member_id, role) values ('00000000-0000-0000-0000-000000000003', 'editor');
insert into tarab_private.member_roles(member_id, role) values ('00000000-0000-0000-0000-000000000005', 'admin');
delete from tarab_private.member_roles where member_id = '00000000-0000-0000-0000-000000000005' and role = 'admin';
select pg_temp.assert_true((select count(*) = 1 from tarab_private.audit_events where action = 'member.banned'), 'ban audited');
select pg_temp.assert_true((select count(*) = 1 from tarab_private.audit_events where action = 'member.unbanned'), 'unban audited');

select set_config('tarab.actor_id', '00000000-0000-0000-0000-000000000002', true);
insert into tarab_private.track_tags(track_id, label)
 select '20000000-0000-0000-0000-000000000001', 'tag ' || value from generate_series(1, 11) as value;
select pg_temp.expect_error($q$insert into tarab_private.track_tags(track_id, label) values ('20000000-0000-0000-0000-000000000001', 'thirteenth')$q$, '23514');
delete from tarab_private.track_tags where id = '30000000-0000-0000-0000-000000000001';
select pg_temp.assert_true((select before_value->>'label' = 'طرب' and after_value is null from tarab_private.audit_events where action = 'tag.removed'), 'tag removal audited');
select pg_temp.expect_error($q$update tarab_private.audit_events set action = 'tag.added'$q$, '42501');
select pg_temp.expect_error($q$delete from tarab_private.audit_events$q$, '42501');
select pg_temp.expect_error($q$truncate tarab_private.audit_events$q$, '42501');
select set_config('tarab.actor_id', '', true);
select pg_temp.expect_error($q$delete from tarab_private.track_tags$q$, '42501');

-- Every app role fails closed, including when an actor context is forged.
do $$
declare app_role text; item record;
begin
  foreach app_role in array array['anon', 'authenticated', 'service_role'] loop
    perform pg_temp.assert_true(not has_schema_privilege(app_role, 'tarab_private', 'USAGE'), app_role || ' has no schema usage');
    for item in select oid from pg_class where relnamespace = 'tarab_private'::regnamespace and relkind = 'r' loop
      perform pg_temp.assert_true(not has_table_privilege(app_role, item.oid, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE'), app_role || ' has no table access');
    end loop;
    for item in select oid from pg_proc where pronamespace = 'tarab_private'::regnamespace loop
      perform pg_temp.assert_true(not has_function_privilege(app_role, item.oid, 'EXECUTE'), app_role || ' has no function access');
    end loop;
  end loop;
end $$;
select pg_temp.assert_true((select bool_and(relrowsecurity) from pg_class where relnamespace = 'tarab_private'::regnamespace and relkind = 'r'), 'all tables use RLS');
set local role anon;
select set_config('tarab.actor_id', '00000000-0000-0000-0000-000000000001', true);
select pg_temp.expect_error($q$select * from tarab_private.submissions$q$, '42501');
select pg_temp.expect_error($q$insert into tarab_private.member_roles(member_id, role) values ('00000000-0000-0000-0000-000000000004', 'admin')$q$, '42501');
reset role;

-- Defense in depth: RLS still denies reads/writes if a later migration grants
-- ACL access accidentally. These temporary grants are rolled back below.
grant usage on schema tarab_private to authenticated;
grant select, insert on tarab_private.submissions to authenticated;
set local role authenticated;
select set_config('tarab.actor_id', '00000000-0000-0000-0000-000000000002', true);
select pg_temp.assert_true((select count(*) = 0 from tarab_private.submissions), 'RLS hides contributions even with temporary SELECT grant');
select pg_temp.expect_error($q$insert into tarab_private.submissions(track_id, submitted_by) values ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002')$q$, '42501');
reset role;

rollback;
