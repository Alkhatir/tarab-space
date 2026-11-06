"use client";

import Link from "next/link";
import { useEffect, useState, type FormEvent } from "react";
import { z } from "zod";
import { getBrowserSupabaseClient } from "@/lib/supabase/browser";
import { accountCredentialsSchema, invitationTokenSchema, invitationUsernameSchema } from "@/lib/invitations/validation";

const membershipSchema = z.object({ username: z.string(), joinedAt: z.string() });
const issuedSchema = z.object({ id: z.string(), token: invitationTokenSchema, username: z.string(), expiresAt: z.string() });
const invitationSchema = z.object({ id: z.string(), username: z.string(), createdAt: z.string(), expiresAt: z.string(), acceptedAt: z.string().nullable(), revokedAt: z.string().nullable(), expired: z.boolean() });
type Membership = z.infer<typeof membershipSchema>;
type Invitation = z.infer<typeof invitationSchema>;

function messageFrom(error: unknown) {
  return error instanceof Error ? error.message : "The request could not be completed. Please try again.";
}

export function AccountPanel({ joining = false }: { joining?: boolean }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [username, setUsername] = useState("");
  const [token, setToken] = useState("");
  const [signedIn, setSignedIn] = useState(false);
  const [membership, setMembership] = useState<Membership | null>(null);
  const [invitations, setInvitations] = useState<Invitation[]>([]);
  const [issuedLink, setIssuedLink] = useState("");
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(true);
  const [ready, setReady] = useState(false);

  // The invitation is a URL fragment: it is not sent in page requests/referrers.
  // Keep it in the link so the user can return after confirming their email.
  useEffect(() => {
    let active = true;
    function syncInvitationToken() {
      if (joining) setToken(new URLSearchParams(window.location.hash.slice(1)).get("invite") ?? "");
    }
    window.addEventListener("hashchange", syncInvitationToken);
    async function load() {
      await Promise.resolve();
      if (!active) return;
      syncInvitationToken();
      try {
        const client = getBrowserSupabaseClient();
        const { data: { user }, error: userError } = await client.auth.getUser();
        if (!active) return;
        if (!user || userError) { setSignedIn(false); return; }
        setSignedIn(true);
        const { data, error: memberError } = await client.rpc("tarab_my_membership");
        if (!active) return;
        if (!memberError) {
          setMembership(membershipSchema.parse(data));
          const result = await client.rpc("tarab_list_invitations");
          if (active && !result.error) setInvitations(z.array(invitationSchema).parse(result.data));
        } else {
          setNotice("Your account has no active platform membership. Accept your invitation, or contact an admin if your membership is suspended.");
        }
      } catch (caught) {
        if (active) setError(messageFrom(caught));
      } finally {
        if (active) { setBusy(false); setReady(true); }
      }
    }
    void load();
    return () => { active = false; window.removeEventListener("hashchange", syncInvitationToken); };
  }, [joining]);

  async function refreshMembership() {
    const client = getBrowserSupabaseClient();
    const result = await client.rpc("tarab_my_membership");
    if (result.error) throw new Error("Account authenticated, but no active invited membership is available yet.");
    setMembership(membershipSchema.parse(result.data));
    const list = await client.rpc("tarab_list_invitations");
    if (list.error) throw new Error(list.error.message);
    setInvitations(z.array(invitationSchema).parse(list.data));
  }

  async function run(action: () => Promise<void>) {
    setBusy(true); setError(""); setNotice("");
    try { await action(); } catch (caught) { setError(messageFrom(caught)); }
    finally { setBusy(false); }
  }

  async function authenticate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await run(async () => {
      const emailResult = z.email("Enter a valid email address.").safeParse(email.trim());
      if (!emailResult.success) throw new Error(emailResult.error.issues[0].message);
      const parsedEmail = emailResult.data;
      if (!password) throw new Error("Enter your password.");
      const result = await getBrowserSupabaseClient().auth.signInWithPassword({ email: parsedEmail, password });
      if (result.error) throw new Error("Sign-in failed. Check your credentials and confirm your email.");
      setPassword(""); setSignedIn(true);
      try { await refreshMembership(); } catch { setNotice("Signed in. Accept your invitation to join, or contact an admin about your membership."); }
    });
  }

  async function register() {
    await run(async () => {
      const tokenResult = invitationTokenSchema.safeParse(token);
      if (!tokenResult.success) throw new Error(tokenResult.error.issues[0].message);
      const nameResult = invitationUsernameSchema.safeParse(username);
      if (!nameResult.success) throw new Error(nameResult.error.issues[0].message);
      const credentials = accountCredentialsSchema.safeParse({ email: email.trim(), password });
      if (!credentials.success) throw new Error(credentials.error.issues[0].message);
      const result = await getBrowserSupabaseClient().auth.signUp(credentials.data);
      if (result.error) throw new Error("Account creation could not be completed. Try signing in if you already have an account.");
      setPassword("");
      if (result.data.session) setSignedIn(true);
      setNotice("Check your email to confirm your account. Then return to this original invitation link and sign in. Creating an email account does not grant Tarab Space membership.");
    });
  }

  async function accept() {
    await run(async () => {
      const parsedToken = invitationTokenSchema.safeParse(token);
      const parsedName = invitationUsernameSchema.safeParse(username);
      if (!parsedToken.success) throw new Error(parsedToken.error.issues[0].message);
      if (!parsedName.success) throw new Error(parsedName.error.issues[0].message);
      const result = await getBrowserSupabaseClient().rpc("tarab_accept_invitation", { p_token: parsedToken.data, p_username: parsedName.data });
      if (result.error) throw new Error("This invitation could not be accepted. Check the username and verified email, or ask your inviter for a current link.");
      await refreshMembership();
      window.history.replaceState(null, "", window.location.pathname);
      setToken(""); setNotice("Welcome to Tarab Space. Your membership is active.");
    });
  }

  async function createInvitation(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await run(async () => {
      setIssuedLink("");
      const recipient = invitationUsernameSchema.safeParse(username);
      if (!recipient.success) throw new Error(recipient.error.issues[0].message);
      const result = await getBrowserSupabaseClient().rpc("tarab_create_invitation", { p_username: recipient.data });
      if (result.error) throw new Error("Could not invite this username. Check current eligibility, existing membership, and your daily invitation limit.");
      const invitation = issuedSchema.parse(result.data);
      const url = new URL("/join", window.location.origin);
      url.hash = new URLSearchParams({ invite: invitation.token }).toString();
      setIssuedLink(url.toString());
      await refreshMembership();
      setNotice(`Invitation for u/${invitation.username} created. Copy the link now; it cannot be recovered later. It expires in 48 hours.`);
    });
  }

  const inputClass = "mt-2 w-full min-w-0 rounded-lg border border-stone-300 bg-white px-4 py-3 text-base";
  const buttonClass = "min-h-11 cursor-pointer rounded-lg bg-teal-950 px-5 py-3 text-sm font-medium text-white hover:bg-teal-800 disabled:cursor-not-allowed disabled:opacity-50";

  return (
    <div className="space-y-6">
      {!ready && <p role="status">Checking account access…</p>}
      {error && <p role="alert" className="break-words rounded-lg bg-red-50 p-4 text-sm text-red-800">{error}</p>}
      {notice && <p role="status" className="rounded-lg bg-teal-50 p-4 text-sm leading-relaxed text-teal-950">{notice}</p>}
      {joining && !membership && (
        <div className="rounded-xl border border-stone-200 bg-white p-5">
          <label htmlFor="invited-username" className="block text-sm font-medium">Your invited Reddit username</label>
          <input id="invited-username" value={username} onChange={(event) => setUsername(event.target.value)} maxLength={24} autoComplete="username" className={inputClass} />
          <p className="mt-3 text-sm leading-relaxed text-stone-600">Use the username your inviter confirmed with you. Invitations are single-use, expire after 48 hours, and require a current eligibility-list match.</p>
          {!token && ready && <p role="alert" className="mt-3 text-sm text-red-800">Open the full invitation link from your inviter. This page has no invitation token.</p>}
        </div>
      )}
      {ready && !signedIn && (
        <form onSubmit={authenticate} className="space-y-5 rounded-xl border border-stone-200 bg-white p-5" noValidate>
          <h2 className="font-serif text-2xl">{joining ? "Create an account or sign in" : "Sign in"}</h2>
          <label className="block text-sm font-medium" htmlFor="account-email">Email<input id="account-email" type="email" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} className={inputClass} /></label>
          <label className="block text-sm font-medium" htmlFor="account-password">Password<input id="account-password" type="password" autoComplete={joining ? "new-password" : "current-password"} value={password} onChange={(event) => setPassword(event.target.value)} maxLength={128} className={inputClass} /></label>
          {joining && <p className="text-sm text-stone-600">New passwords must have at least 12 characters. Confirm your email before accepting your invitation.</p>}
          <div className="flex flex-wrap gap-3">
            <button type="submit" disabled={busy} className={buttonClass}>Sign in</button>
            {joining && <button type="button" disabled={busy || !token} onClick={register} className={buttonClass}>Create email account</button>}
          </div>
        </form>
      )}
      {signedIn && !membership && joining && <button type="button" disabled={busy || !token} onClick={accept} className={buttonClass}>Accept invitation</button>}
      {membership && (
        <section className="space-y-5 rounded-xl border border-stone-200 bg-white p-5">
          <h2 className="font-serif text-2xl">Welcome, u/{membership.username}</h2>
          <p className="text-sm leading-relaxed text-stone-600">Every active member can invite. First confirm the person’s Reddit username outside the app. Knowing a username alone is not proof of account ownership.</p>
          <form onSubmit={createInvitation} className="space-y-4" noValidate>
            <label htmlFor="recipient-username" className="block text-sm font-medium">Username to invite<input id="recipient-username" value={username} onChange={(event) => setUsername(event.target.value)} maxLength={24} className={inputClass} /></label>
            <button type="submit" disabled={busy} className={buttonClass}>Create invitation</button>
          </form>
          {issuedLink && <div><label htmlFor="issued-link" className="block text-sm font-medium">Private invitation link — shown once</label><input id="issued-link" readOnly value={issuedLink} onFocus={(event) => event.target.select()} className={inputClass} /><p className="mt-2 text-sm text-stone-600">Copy and send it privately to the person you verified. Don’t post it publicly.</p></div>}
          <h3 className="font-semibold">Your latest invitations</h3>
          {invitations.length === 0 ? <p className="text-sm text-stone-600">No invitations yet.</p> : <ul className="space-y-3">{invitations.map((invite) => <li key={invite.id} className="flex flex-wrap items-center justify-between gap-3 border-t border-stone-200 py-3 text-sm"><span>u/{invite.username} · {invite.acceptedAt ? "Accepted" : invite.revokedAt ? "Revoked" : invite.expired ? "Expired" : "Pending"}<span className="mt-1 block text-xs text-stone-600">Created {new Date(invite.createdAt).toISOString().slice(0, 16).replace("T", " ")} UTC</span></span>{!invite.acceptedAt && !invite.revokedAt && <button type="button" disabled={busy} onClick={() => run(async () => { const result = await getBrowserSupabaseClient().rpc("tarab_revoke_invitation", { p_id: invite.id }); if (result.error) throw new Error("Invitation could not be revoked."); setIssuedLink(""); await refreshMembership(); })} className="min-h-11 rounded px-3 font-medium text-teal-900 underline disabled:opacity-50">Revoke</button>}</li>)}</ul>}
        </section>
      )}
      {signedIn && <button type="button" disabled={busy} onClick={() => run(async () => { const { error: logoutError } = await getBrowserSupabaseClient().auth.signOut(); if (logoutError) throw new Error("Sign-out failed."); setSignedIn(false); setMembership(null); setInvitations([]); setIssuedLink(""); })} className="min-h-11 rounded px-3 text-sm font-medium text-teal-900 underline">Sign out</button>}
      {!joining && !membership && <p className="text-sm leading-relaxed text-stone-600">New here? Ask a community member for a private invitation link. There is no open platform registration.</p>}
      <Link href="/" className="inline-block py-3 text-sm font-medium text-teal-900 underline">Back to Discover</Link>
    </div>
  );
}
