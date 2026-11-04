import { z } from "zod";

// UI limits, not database constraints. Reuse validation server-side when saving
// is implemented; client validation alone is never an authorization boundary.
export const MAX_TAGS = 12;
export const MAX_TAG_LENGTH = 40;

export function normalizeTag(value: string) {
  return value.normalize("NFKC").trim().replace(/\s+/gu, " ");
}

export const tagSchema = z.string().transform(normalizeTag).pipe(
  z.string().min(1, "Tags cannot be blank.").max(MAX_TAG_LENGTH, `Keep each tag within ${MAX_TAG_LENGTH} characters.`),
);

export const tagsSchema = z.array(tagSchema)
  .max(MAX_TAGS, `Use up to ${MAX_TAGS} tags.`)
  .refine(
    (tags) => new Set(tags.map((tag) => tag.toLowerCase())).size === tags.length,
    "Each tag must be unique (ignoring capitalization and extra spaces).",
  );

export const trackInputSchema = z.string().trim()
  .min(1, "Enter a Spotify track URL, song title, or artist name.")
  .max(500, "Keep your search within 500 characters.")
  .transform((value, context) => {
    const looksLikeUrl = /(^[a-z][a-z\d+.-]*:|^www\.|^open\.spotify\.com)/iu.test(value);
    if (!looksLikeUrl) return { kind: "search" as const, query: value };

    try {
      const url = new URL(value);
      const match = /^\/(?:intl-[a-z]{2}\/)?track\/([a-zA-Z0-9]{22})\/?$/u.exec(url.pathname);
      if (url.protocol !== "https:" || url.hostname !== "open.spotify.com" ||
          url.port !== "" || url.username !== "" || url.password !== "" || !match) {
        throw new Error("Invalid track URL");
      }
      return { kind: "url" as const, trackId: match[1] };
    } catch {
      context.addIssue({ code: "custom", message: "Use a full Spotify track URL: https://open.spotify.com/track/… Albums, artists, playlists, and shortened links are not supported yet." });
      return z.NEVER;
    }
  });
