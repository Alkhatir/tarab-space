import type { DemoTrack } from "@/lib/demo/tracks";

export function TrackCard({ track }: { track: DemoTrack }) {
  const searchUrl = `https://open.spotify.com/search/${encodeURIComponent(`${track.title} ${track.artist}`)}`;

  return (
    <article className="flex h-full flex-col overflow-hidden rounded-2xl border border-stone-200 bg-white">
      <div aria-hidden="true" className={`relative flex h-44 items-center justify-center overflow-hidden ${track.artworkClassName}`}>
        <div className="absolute size-64 rounded-full border border-current opacity-15" />
        <div className="absolute size-48 rounded-full border border-current opacity-20" />
        <div className="absolute size-32 rounded-full border border-current opacity-25" />
        <span className="font-serif text-5xl italic">{track.artist.slice(0, 1)}</span>
        <span className="absolute bottom-3 left-4 text-[10px] font-bold uppercase tracking-[0.2em]">Tarab Space / Sample selection</span>
      </div>
      <div className="flex flex-1 flex-col p-5">
        <h3 className="text-lg font-semibold leading-snug">{track.title}</h3>
        <p className="mt-1 text-sm text-stone-600">{track.artist}</p>
        <ul aria-label="Illustrative tags" className="mb-6 mt-4 flex flex-wrap gap-2">
          {track.tags.map((tag) => <li key={tag} className="rounded-full bg-stone-100 px-3 py-1 text-xs font-medium text-stone-700">{tag}</li>)}
        </ul>
        <a href={searchUrl} target="_blank" rel="noopener noreferrer" className="mt-auto inline-flex items-center justify-between gap-3 rounded-md border-t border-stone-100 pt-4 text-sm font-medium text-teal-900 hover:underline">
          <span>Find on Spotify<span className="sr-only">: {track.title} by {track.artist} (opens in a new tab)</span></span>
          <span aria-hidden="true">↗</span>
        </a>
      </div>
    </article>
  );
}
