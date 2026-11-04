// Presentation fixtures only. Tags are illustrative, not Spotify metadata or
// clustering results. This module is not a database or integration contract.
export type DemoTrack = {
  id: string;
  title: string;
  artist: string;
  tags: readonly string[];
  artworkClassName: string;
};

export const demoTracks: readonly DemoTrack[] = [
  { id: "demo-1", title: "Nassam Alayna El Hawa", artist: "Fairuz", tags: ["Arabic", "Classics"], artworkClassName: "bg-teal-900 text-amber-100" },
  { id: "demo-2", title: "Qadduka Al Mayyas", artist: "Sabah Fakhri", tags: ["Tarab", "Classics"], artworkClassName: "bg-amber-200 text-amber-950" },
  { id: "demo-3", title: "Ya Mal Al Sham", artist: "Sabah Fakhri", tags: ["Tarab", "Arabic"], artworkClassName: "bg-orange-800 text-orange-100" },
  { id: "demo-4", title: "Bala Wala Shi", artist: "Ziad Rahbani", tags: ["Jazz", "Arabic"], artworkClassName: "bg-slate-700 text-slate-100" },
  { id: "demo-5", title: "Enta Omri", artist: "Umm Kulthum", tags: ["Tarab", "Classics"], artworkClassName: "bg-stone-800 text-amber-100" },
  { id: "demo-6", title: "Al Bint Al Shalabiya", artist: "Fairuz", tags: ["Folk", "Arabic"], artworkClassName: "bg-rose-200 text-rose-950" },
];
