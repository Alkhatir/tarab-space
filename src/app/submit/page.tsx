import type { Metadata } from "next";
import { SubmissionPreview } from "@/components/submission/submission-preview";
import { demoTracks } from "@/lib/demo/tracks";

export const metadata: Metadata = { title: "Share music | Tarab Space" };

export default function SubmitPage() {
  return (
    <div className="mx-auto max-w-3xl px-6 py-12 sm:py-16">
      <p className="text-xs font-bold uppercase tracking-[0.2em] text-teal-900">Your next shared favorite</p>
      <h1 className="mt-4 font-serif text-5xl tracking-tight">Share a little music.</h1>
      <p className="mt-5 text-lg leading-relaxed text-stone-700">Find a recording, make its tags your own, and preview your contribution.</p>
      <aside aria-label="Preview limitations" className="my-8 rounded-xl border border-amber-900/15 bg-amber-50 p-5 text-sm leading-relaxed text-stone-700">
        <strong>Submission preview only.</strong> All recordings and suggested tags below are samples. Nothing is saved or added to a playlist. Spotify lookup, authentication, and duplicate checks will be connected later.
      </aside>
      <SubmissionPreview tracks={demoTracks} />
    </div>
  );
}
