import "server-only";

import { z } from "zod";

const requiredString = z.string().trim().min(1);
const requiredUrl = z.url();

const schemas = {
  supabase: z.object({
    NEXT_PUBLIC_SUPABASE_URL: requiredUrl,
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: requiredString,
  }),
  reddit: z.object({
    REDDIT_CLIENT_ID: requiredString,
    REDDIT_CLIENT_SECRET: requiredString,
    REDDIT_REDIRECT_URI: requiredUrl,
  }),
  spotify: z.object({
    SPOTIFY_CLIENT_ID: requiredString,
    SPOTIFY_CLIENT_SECRET: requiredString,
    SPOTIFY_REDIRECT_URI: requiredUrl,
  }),
  session: z.object({
    SESSION_SECRET: z.string().min(32),
  }),
};

type Integration = keyof typeof schemas;

// Validate only at the integration boundary, never during module import.
export function getIntegrationEnv<T extends Integration>(
  integration: T,
): z.infer<(typeof schemas)[T]> {
  const result = schemas[integration].safeParse(process.env);

  if (!result.success) {
    const variables = result.error.issues
      .map((issue) => issue.path.join("."))
      .join(", ");
    throw new Error(
      `Missing or invalid ${integration} configuration: ${variables}. Set these variables in .env.local (see .env.example).`,
    );
  }

  return result.data as z.infer<(typeof schemas)[T]>;
}
