import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = { title: "About | Tarab Space" };

export default function AboutPage() {
  return (
    <div className="mx-auto max-w-3xl px-6 py-16 sm:py-24">
      <p className="text-xs font-bold uppercase tracking-[0.2em] text-teal-900">Our space, our soundtrack</p>
      <h1 className="mt-5 font-serif text-5xl tracking-tight">What does our community listen to?</h1>
      <div className="mt-8 space-y-5 text-lg leading-relaxed text-stone-700">
        <p>Tarab Space is a community-driven music space for r/syrian-social-space. The idea is simple: share the music you love and discover what others are listening to.</p>
        <p>From Syrian and Arabic traditions to sounds from everywhere else, there’s room for familiar favorites and unexpected discoveries.</p>
        <p>This is an early preview. The Discover page uses sample music and illustrative tags. Reddit sign-in, music submissions, and Spotify playlists are planned; they are not available yet.</p>
        <p className="text-sm">Tarab Space is an independent community project, not affiliated with Reddit or Spotify.</p>
      </div>
      <Link href="/" className="mt-10 inline-flex min-h-11 items-center rounded-full bg-teal-950 px-6 py-3 text-sm font-medium text-white hover:bg-teal-800">Explore the selection <span aria-hidden="true" className="ml-3">→</span></Link>
    </div>
  );
}
