import type { Metadata } from "next";
import { AccountPanel } from "@/components/account/account-panel";
export const metadata: Metadata = { title: "Account | Tarab Space", robots: { index: false, follow: false } };
export default function AccountPage() {
  return <div className="mx-auto max-w-2xl px-6 py-12"><h1 className="mb-5 font-serif text-4xl">Your community account</h1><p className="mb-8 leading-relaxed text-stone-600">Sign in with email and password to manage your invitations. This requires the invitation database migration and configured Supabase email authentication.</p><AccountPanel /></div>;
}
