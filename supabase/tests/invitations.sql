-- Disposable database ONLY. Requires Supabase Auth or the documented test stub.
begin;
create function pg_temp.assert_true(ok boolean, message text) returns void language plpgsql as $$ begin if ok is distinct from true then raise exception 'FAIL: %',message; end if; end $$;
create function pg_temp.expect_error(command text, expected_state text) returns void language plpgsql as $$ begin begin execute command; exception when others then if sqlstate=expected_state then return; end if; raise exception 'Expected %, received %: %',expected_state,sqlstate,sqlerrm; end; raise exception 'Expected error %, command succeeded',expected_state; end $$;

insert into auth.users(id,email,email_confirmed_at) values
 ('11111111-1111-1111-1111-111111111111','root@example.test',now()),
 ('22222222-2222-2222-2222-222222222222','new@example.test',now()),
 ('33333333-3333-3333-3333-333333333333','other@example.test',now()),
 ('44444444-4444-4444-4444-444444444444','unverified@example.test',null);
insert into tarab_private.members(id,username,auth_user_id) values
 ('00000000-0000-0000-0000-000000000001','root_admin','11111111-1111-1111-1111-111111111111');
select set_config('tarab.actor_id','00000000-0000-0000-0000-000000000001',true);
insert into tarab_private.member_roles(member_id,role) values ('00000000-0000-0000-0000-000000000001','admin');
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
select public.tarab_import_eligibility(array['u/New_User','other_user','future_user'],'test snapshot',now());
select pg_temp.assert_true((select count(*)=3 from tarab_private.eligible_usernames where active),'snapshot normalizes usernames');
select pg_temp.expect_error($q$select public.tarab_import_eligibility(array[]::text[],'empty',now())$q$,'22023');
select pg_temp.expect_error($q$select public.tarab_import_eligibility(array['bad username'],'invalid',now())$q$,'22023');
select pg_temp.expect_error($q$select public.tarab_import_eligibility(array['new_user'],'stale',now()-interval '9 days')$q$,'22023');

create temp table test_links(name text primary key,payload jsonb);
insert into test_links values('first',public.tarab_create_invitation('u/New_User'));
select pg_temp.assert_true((select token_hash <> payload->>'token' from tarab_private.invitations i,test_links t where i.id=(payload->>'id')::uuid),'only a hash is stored');
select pg_temp.assert_true((select payload->>'token' ~ '^[A-Za-z0-9_-]{43}$' from test_links),'URL safe token format');
select pg_temp.assert_true((select expires_at-created_at between interval '47 hours 59 minutes' and interval '48 hours 1 minute' from tarab_private.invitations),'48-hour expiry');
select pg_temp.assert_true(not (public.tarab_list_invitations()->0 ? 'token_hash') and not (public.tarab_list_invitations()->0 ? 'token'),'listing reveals no token or hash');
select pg_temp.expect_error($q$select public.tarab_create_invitation('not_listed')$q$,'22023');

-- Being authenticated or knowing a listed username is not platform membership.
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
select pg_temp.expect_error($q$select public.tarab_my_membership()$q$,'42501');
select pg_temp.expect_error($q$select public.tarab_create_invitation('other_user')$q$,'42501');
select pg_temp.expect_error($q$select public.tarab_accept_invitation('short','new_user')$q$,'22023');
select pg_temp.expect_error($q$select public.tarab_accept_invitation((select payload->>'token' from test_links),'other_user')$q$,'22023');
select set_config('request.jwt.claim.sub','44444444-4444-4444-4444-444444444444',true);
select pg_temp.expect_error($q$select public.tarab_accept_invitation((select payload->>'token' from test_links),'new_user')$q$,'42501');

select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',true);
select public.tarab_accept_invitation((select payload->>'token' from test_links),'u/NEW_USER');
select public.tarab_accept_invitation((select payload->>'token' from test_links),'new_user');
select pg_temp.assert_true((select count(*)=1 from tarab_private.members where auth_user_id='22222222-2222-2222-2222-222222222222'),'same-user retry is idempotent');
select pg_temp.assert_true((select m.invitation_id=i.id and i.invited_by='00000000-0000-0000-0000-000000000001' and i.accepted_at is not null from tarab_private.members m join tarab_private.invitations i on i.accepted_by=m.id where m.username='new_user'),'graph edge and acceptance time retained');
-- An ordinary member with no editor/admin role can invite.
insert into test_links values('member_invite',public.tarab_create_invitation('other_user'));
select pg_temp.expect_error($q$select public.tarab_import_eligibility(array['other_user'],'not admin',now())$q$,'42501');
select pg_temp.expect_error($q$select public.tarab_revoke_invitation((select (payload->>'id')::uuid from test_links where name='first'))$q$,'22023');

select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
select pg_temp.expect_error($q$select public.tarab_accept_invitation((select payload->>'token' from test_links where name='first'),'new_user')$q$,'22023');
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
select public.tarab_revoke_invitation((select (payload->>'id')::uuid from test_links where name='member_invite'));
select pg_temp.assert_true((select revoked_by='00000000-0000-0000-0000-000000000001' from tarab_private.invitations where id=(select (payload->>'id')::uuid from test_links where name='member_invite')),'admin revocation records actor');
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
select pg_temp.expect_error($q$select public.tarab_accept_invitation((select payload->>'token' from test_links where name='member_invite'),'other_user')$q$,'22023');

-- Eligibility is rechecked at redemption, and imports are atomic snapshots.
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
insert into test_links values('removed',public.tarab_create_invitation('future_user'));
select public.tarab_import_eligibility(array['other_user'],'new snapshot',clock_timestamp());
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
select pg_temp.expect_error($q$select public.tarab_accept_invitation((select payload->>'token' from test_links where name='removed'),'future_user')$q$,'22023');
select pg_temp.assert_true((select accepted_at is null from tarab_private.invitations where id=(select (payload->>'id')::uuid from test_links where name='removed')),'failed redemption does not consume token');
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
insert into test_links values('banned_inviter',public.tarab_create_invitation('other_user'));
-- Ban the ordinary inviter as admin, then ensure they cannot invite or list.
select public.tarab_my_membership();
update tarab_private.members set banned_at=now(),ban_reason='test ban' where username='new_user';
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',true);
select pg_temp.expect_error($q$select public.tarab_create_invitation('other_user')$q$,'42501');
select pg_temp.expect_error($q$select public.tarab_list_invitations()$q$,'42501');

-- Banning an inviter blocks redemption of their still-pending links.
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
select public.tarab_import_eligibility(array['other_user','future_user'],'fresh complete snapshot',clock_timestamp());
update tarab_private.members set banned_at=null where username='new_user';
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',true);
insert into test_links values('pending_before_ban',public.tarab_create_invitation('future_user'));
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
select public.tarab_my_membership();
update tarab_private.members set banned_at=now(),ban_reason='test second ban' where username='new_user';
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
select pg_temp.expect_error($q$select public.tarab_accept_invitation((select payload->>'token' from test_links where name='pending_before_ban'),'future_user')$q$,'22023');
-- A caller cannot override the authenticated identity using a forged actor.
select set_config('tarab.actor_id','00000000-0000-0000-0000-000000000001',true);
select pg_temp.expect_error($q$select public.tarab_import_eligibility(array['other_user'],'forged',clock_timestamp())$q$,'42501');
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
do $$ begin
  while (select count(*) from tarab_private.invitations where invited_by='00000000-0000-0000-0000-000000000001' and created_at>clock_timestamp()-interval '24 hours') < 10 loop
    perform public.tarab_create_invitation('other_user');
  end loop;
end $$;
select pg_temp.expect_error($q$select public.tarab_create_invitation('other_user')$q$,'22023');

-- Expired invitation and stale roster fail closed without creating members.
insert into tarab_private.invitations(token_hash,recipient_username,invited_by,created_at,expires_at)
 values(encode(sha256(convert_to(repeat('X',43),'UTF8')),'hex'),'other_user','00000000-0000-0000-0000-000000000001',now()-interval '3 days',now()-interval '1 day');
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
select pg_temp.expect_error($q$select public.tarab_accept_invitation(repeat('X',43),'other_user')$q$,'22023');
select pg_temp.expect_error($q$update tarab_private.invitations set recipient_username='new_user'$q$,'42501');
select pg_temp.expect_error($q$delete from tarab_private.invitations$q$,'42501');
select pg_temp.expect_error($q$update tarab_private.members set auth_user_id=null where username='new_user'$q$,'42501');

-- Stale data also blocks pending redemption; imported history is not silently
-- replaced by an empty/failed scraper response.
update tarab_private.eligibility_imports set observed_at=now()-interval '9 days';
select pg_temp.expect_error($q$select public.tarab_accept_invitation((select payload->>'token' from test_links where name='banned_inviter'),'other_user')$q$,'22023');
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
select pg_temp.expect_error($q$select public.tarab_create_invitation('other_user')$q$,'22023');

select pg_temp.assert_true(not has_schema_privilege('authenticated','tarab_private','usage'),'private schema remains private');
select pg_temp.assert_true(not has_function_privilege('anon','public.tarab_accept_invitation(text,text)','execute'),'anonymous cannot redeem');
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
select public.tarab_my_membership();
select pg_temp.expect_error($q$select * from tarab_private.members$q$,'42501');
select pg_temp.expect_error($q$select * from tarab_private.eligible_usernames$q$,'42501');
reset role;
rollback;
