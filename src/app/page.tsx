import { DiscoverLibrary } from "@/components/discover/discover-library";
import { demoTracks } from "@/lib/demo/tracks";

export default function Home() {
  return (
    <>
      <section className="border-b border-stone-200 bg-[#eeeadd]">
        <div className="mx-auto grid max-w-6xl gap-8 px-6 py-14 sm:py-20 md:grid-cols-[1fr_auto] md:items-end">
          <div className="max-w-2xl">
            <p className="text-xs font-bold uppercase tracking-[0.2em] text-teal-900">A shared taste. A growing collection.</p>
            <h1 className="mt-5 font-serif text-5xl leading-tight tracking-tight sm:text-7xl">Good music.<br />Better together.</h1>
            <p className="mt-6 max-w-lg text-lg leading-relaxed text-stone-700">A music space for r/syrian-social-space. Explore familiar sounds, find something unexpected, and make room for your next favorite.</p>
          </div>
          <div aria-hidden="true" className="hidden size-44 items-center justify-center rounded-full border-[18px] border-teal-950 bg-teal-900 md:flex">
            <div className="flex size-24 items-center justify-center rounded-full border-[12px] border-teal-800 bg-amber-200 font-serif text-2xl text-teal-950">طرب</div>
          </div>
        </div>
      </section>
      <div className="mx-auto max-w-6xl px-6 py-10 sm:py-14">
        <div className="mb-10 rounded-xl border border-amber-900/15 bg-amber-50 px-5 py-4 text-sm leading-relaxed text-stone-700">
          <strong className="text-stone-900">A little preview of what’s to come.</strong>{" "}
          You’re browsing sample music with illustrative tags, not community submissions. Sign-in, submissions, and playlists are coming later.
        </div>
        <DiscoverLibrary tracks={demoTracks} />
      </div>
    </>
  );
}
