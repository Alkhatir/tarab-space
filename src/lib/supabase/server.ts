import "server-only";

import { createClient } from "@supabase/supabase-js";
import { getIntegrationEnv } from "@/lib/env";

export function createSupabaseClient() {
  const env = getIntegrationEnv("supabase");

  return createClient(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false,
      },
    },
  );
}
