"use client";

import { useId, useState } from "react";
import type { DemoTrack } from "@/lib/demo/tracks";
import { TrackCard } from "./track-card";

export function DiscoverLibrary({ tracks }: { tracks: readonly DemoTrack[] }) {
  const searchId = useId();
  const [query, setQuery] = useState("");
  const [selectedTag, setSelectedTag] = useState<string | null>(null);
  const tags = [...new Set(tracks.flatMap((track) => track.tags))].sort();
  const normalizedQuery = query.trim().toLocaleLowerCase();
  const visibleTracks = tracks.filter((track) =>
    (selectedTag === null || track.tags.includes(selectedTag)) &&
    `${track.title} ${track.artist} ${track.tags.join(" ")}`.toLocaleLowerCase().includes(normalizedQuery),
  );

  function resetFilters() {
    setQuery("");
    setSelectedTag(null);
  }

  return (
    <section aria-labelledby="discover-heading">
      <div className="flex flex-col justify-between gap-6 sm:flex-row sm:items-end">
        <div>
          <p className="text-xs font-bold uppercase tracking-[0.18em] text-teal-900">The listening room</p>
          <h2 id="discover-heading" className="mt-2 font-serif text-3xl sm:text-4xl">Discover music</h2>
          <p className="mt-3 text-sm leading-relaxed text-stone-600">An early selection to explore. Follow your curiosity.</p>
        </div>
        <div className="w-full sm:max-w-xs">
          <label htmlFor={searchId} className="mb-2 block text-sm font-medium">Search the selection</label>
          <input id={searchId} type="search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Track, artist, or tag" className="w-full rounded-xl border border-stone-300 bg-white px-4 py-3 text-base placeholder:text-stone-500" />
        </div>
      </div>
      <fieldset className="mt-8">
        <legend className="mb-3 text-sm font-medium">Explore by tag</legend>
        <div className="flex flex-wrap gap-2">
          {[null, ...tags].map((tag) => (
            <button key={tag ?? "all"} type="button" aria-pressed={selectedTag === tag} onClick={() => setSelectedTag(tag)} className="min-h-11 cursor-pointer rounded-full border border-stone-300 bg-white px-4 py-2 text-sm font-medium text-stone-700 hover:border-teal-800 aria-pressed:border-teal-950 aria-pressed:bg-teal-950 aria-pressed:text-white">
              {tag ?? "All music"}
            </button>
          ))}
        </div>
      </fieldset>
      <div className="my-6 flex min-h-8 flex-wrap items-center justify-between gap-3">
        <p role="status" aria-atomic="true" className="text-sm text-stone-600">{visibleTracks.length} {visibleTracks.length === 1 ? "track" : "tracks"}{selectedTag ? ` · ${selectedTag}` : ""}</p>
        {(query !== "" || selectedTag !== null) && <button type="button" onClick={resetFilters} className="min-h-11 cursor-pointer rounded px-2 text-sm font-medium text-teal-900 underline underline-offset-4">Clear filters</button>}
      </div>
      {visibleTracks.length > 0 ? (
        <ul className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {visibleTracks.map((track) => <li key={track.id}><TrackCard track={track} /></li>)}
        </ul>
      ) : (
        <div className="rounded-2xl border border-dashed border-stone-300 bg-white px-6 py-16 text-center">
          <h3 className="font-serif text-2xl">No tracks found</h3>
          <p className="mx-auto mt-3 max-w-md text-sm leading-relaxed text-stone-600">Try another track, artist, or tag, or clear the filters to browse the full selection.</p>
          <button type="button" onClick={resetFilters} className="mt-6 min-h-11 cursor-pointer rounded-full bg-teal-950 px-6 py-3 text-sm font-medium text-white hover:bg-teal-800">Show all music</button>
        </div>
      )}
    </section>
  );
}
