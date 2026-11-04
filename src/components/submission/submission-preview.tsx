"use client";

import { useId, useRef, useState, type FormEvent } from "react";
import type { DemoTrack } from "@/lib/demo/tracks";
import { tagsSchema, trackInputSchema } from "@/lib/submissions/validation";
import { TagEditor } from "./tag-editor";

function RecordingDraft({ track }: { track: DemoTrack }) {
  const [tags, setTags] = useState<string[]>([...track.tags]);
  const [review, setReview] = useState<string[] | null>(null);
  const [error, setError] = useState("");
  const [pendingTag, setPendingTag] = useState("");
  const reviewHeading = useRef<HTMLHeadingElement>(null);
  const errorMessage = useRef<HTMLParagraphElement>(null);

  function reviewDraft(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pendingTag.trim()) {
      setError("Add your new tag or clear its input before reviewing the draft.");
      setReview(null);
      requestAnimationFrame(() => errorMessage.current?.focus());
      return;
    }
    const result = tagsSchema.safeParse(tags);
    if (!result.success) {
      setError(result.error.issues[0].message);
      setReview(null);
      requestAnimationFrame(() => errorMessage.current?.focus());
      return;
    }
    setError("");
    setReview(result.data);
    requestAnimationFrame(() => reviewHeading.current?.focus());
  }

  return (
    <section aria-labelledby="recording-heading" className="rounded-2xl border border-stone-200 bg-white p-5 sm:p-8">
      <p className="text-xs font-bold uppercase tracking-[0.18em] text-teal-900">2 · Personalize your draft</p>
      <h2 id="recording-heading" className="mt-3 font-serif text-3xl">Your selected recording</h2>
      <dl className="mt-6 grid gap-5 border-b border-stone-200 pb-6 sm:grid-cols-2">
        <div><dt className="text-sm text-stone-600">Title</dt><dd className="mt-1 font-semibold">{track.title}</dd></div>
        <div><dt className="text-sm text-stone-600">Artist</dt><dd className="mt-1 font-semibold">{track.artist}</dd></div>
      </dl>
      <p className="mt-3 text-sm text-stone-600">Sample metadata · No Spotify lookup has been performed.</p>
      <form onSubmit={reviewDraft} noValidate>
        <TagEditor initialTags={track.tags} onPendingChange={(value) => { setPendingTag(value); setReview(null); setError(""); }} onChange={(updated) => { setTags(updated); setReview(null); setError(""); }} />
        {error && <p ref={errorMessage} tabIndex={-1} role="alert" className="mt-5 rounded-lg bg-red-50 p-4 text-sm text-red-800">{error}</p>}
        <button type="submit" className="mt-8 min-h-11 cursor-pointer rounded-full bg-teal-950 px-6 py-3 text-sm font-medium text-white hover:bg-teal-800">Review sample draft</button>
      </form>
      {review !== null && (
        <section aria-labelledby="review-heading" className="mt-8 rounded-xl border border-teal-900/20 bg-teal-50 p-5">
          <h3 id="review-heading" ref={reviewHeading} tabIndex={-1} className="text-lg font-semibold">Draft preview — not submitted</h3>
          <p className="mt-3 font-medium">{track.title} · {track.artist}</p>
          {review.length > 0 ? <ul aria-label="Your draft tags" className="mt-4 flex flex-wrap gap-2">{review.map((tag) => <li key={tag} className="min-w-0 max-w-full break-words rounded-full bg-white px-3 py-1 text-sm text-teal-950">{tag}</li>)}</ul> : <p className="mt-3 text-sm">No tags selected.</p>}
          <p id="saving-unavailable" className="mt-4 text-sm leading-relaxed text-stone-700">Saving and duplicate checks are not connected yet. This draft only exists on this page and disappears when you leave or reload.</p>
          <button type="button" disabled aria-describedby="saving-unavailable" className="mt-5 min-h-11 cursor-not-allowed rounded-full bg-stone-200 px-5 py-3 text-sm font-medium text-stone-600">Submit track · Coming soon</button>
        </section>
      )}
    </section>
  );
}

export function SubmissionPreview({ tracks }: { tracks: readonly DemoTrack[] }) {
  const id = useId();
  const [input, setInput] = useState("");
  const [search, setSearch] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [selected, setSelected] = useState<DemoTrack | null>(null);
  const draftContainer = useRef<HTMLDivElement>(null);
  const results = tracks.filter((track) => `${track.title} ${track.artist}`.toLowerCase().includes(search.toLowerCase()));

  function findTrack(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const result = trackInputSchema.safeParse(input);
    setError("");
    setNotice("");
    if (!result.success) {
      setError(result.error.issues[0].message);
      return;
    }
    if (result.data.kind === "url") {
      setNotice("That looks like a Spotify track URL. Live lookup is coming soon; no metadata was fetched. Choose a sample recording below to try the tag editor.");
      setSearch("");
    } else {
      setSearch(result.data.query);
    }
  }

  return (
    <div className="space-y-8">
      <section aria-labelledby="find-heading" className="rounded-2xl border border-stone-200 bg-white p-5 sm:p-8">
        <p className="text-xs font-bold uppercase tracking-[0.18em] text-teal-900">1 · Find a recording</p>
        <h2 id="find-heading" className="mt-3 font-serif text-3xl">What’s on your mind?</h2>
        <form onSubmit={findTrack} className="mt-6" noValidate>
          <label htmlFor={`${id}-input`} className="mb-2 block text-sm font-medium">Spotify track URL, song title, or artist</label>
          <div className="flex flex-col gap-3 sm:flex-row">
            <input id={`${id}-input`} type="text" maxLength={500} value={input} onChange={(event) => { setInput(event.target.value); setError(""); setNotice(""); }} aria-invalid={error ? true : undefined} aria-describedby={`${id}-help${error ? ` ${id}-error` : ""}`} placeholder="Try Fairuz or paste a Spotify track URL" className="min-w-0 flex-1 rounded-lg border border-stone-300 px-4 py-3 text-base" />
            <button type="submit" className="min-h-11 cursor-pointer rounded-lg bg-teal-950 px-5 py-3 text-sm font-medium text-white hover:bg-teal-800">Find sample tracks</button>
          </div>
          <p id={`${id}-help`} className="mt-3 text-sm leading-relaxed text-stone-600">Search only checks our sample selection. URLs are validated locally; live Spotify search and metadata are not connected.</p>
          {error && <p id={`${id}-error`} role="alert" className="mt-3 text-sm text-red-800">{error}</p>}
        </form>
        {notice && <p role="status" className="mt-4 rounded-lg bg-amber-50 p-4 text-sm leading-relaxed text-stone-700">{notice}</p>}
        <div className="mb-4 mt-8 flex flex-wrap items-center justify-between gap-3">
          <h3 className="font-semibold">Sample recordings</h3>
          <p role="status" className="min-w-0 max-w-full break-words text-sm text-stone-600">{results.length} {results.length === 1 ? "match" : "matches"}{search ? ` for “${search}”` : ""}</p>
        </div>
        {results.length ? (
          <ul className="space-y-3">
            {results.map((track) => (
              <li key={track.id}>
                <button type="button" aria-pressed={selected?.id === track.id} onClick={() => { if (selected?.id === track.id) return; setSelected(track); requestAnimationFrame(() => draftContainer.current?.focus()); }} className="flex min-h-16 w-full cursor-pointer items-center justify-between gap-4 rounded-xl border border-stone-200 px-4 py-4 text-left hover:border-teal-800 aria-pressed:border-teal-900 aria-pressed:bg-teal-50">
                  <span className="min-w-0"><span className="block font-medium">{track.title}</span><span className="mt-1 block text-sm text-stone-600">{track.artist}</span></span>
                  <span className="shrink-0 text-sm font-medium text-teal-900">{selected?.id === track.id ? "Selected" : "Select"}</span>
                </button>
              </li>
            ))}
          </ul>
        ) : (
          <div className="rounded-xl border border-dashed border-stone-300 p-6 text-center">
            <p className="font-medium">No sample recordings found</p>
            <p className="mt-2 text-sm text-stone-600">Try Fairuz or Sabah Fakhri, or browse all samples.</p>
          </div>
        )}
        {search && <button type="button" onClick={() => { setInput(""); setSearch(""); setError(""); setNotice(""); }} className="mt-4 min-h-11 cursor-pointer rounded px-2 text-sm font-medium text-teal-900 underline underline-offset-4">Browse all samples</button>}
      </section>
      {selected ? <div ref={draftContainer} tabIndex={-1} aria-label="Selected recording draft"><p className="mb-4 px-2 text-sm text-stone-600">Selecting a different recording replaces this local draft.</p><RecordingDraft key={selected.id} track={selected} /></div> : <p className="px-2 text-sm leading-relaxed text-stone-600">Select a sample recording to preview its metadata and personalize its tags.</p>}
    </div>
  );
}
