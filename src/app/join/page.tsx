import type { Metadata } from "next";
import { AccountPanel } from "@/components/account/account-panel";
export const metadata: Metadata = { title: "Join by invitation | Tarab Space", robots: { index: false, follow: false }, referrer: "no-referrer" };
export default function JoinPage() {
  return <div className="mx-auto max-w-2xl px-6 py-12"><h1 className="mb-5 font-serif text-4xl">A place for your music.</h1><p className="mb-8 leading-relaxed text-stone-600">Join through your personal invitation. Your inviter confirms your community identity; Tarab Space checks eligibility and keeps the invitation history.</p><AccountPanel joining /></div>;
}
