"use client";

import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

let client: SupabaseClient | undefined;

// Called by interactive account flows only. Unconfigured pages still render.
export function getBrowserSupabaseClient() {
  if (client) return client;
  const result = z.object({ url: z.url(), key: z.string().min(1) }).safeParse({
    url: process.env.NEXT_PUBLIC_SUPABASE_URL,
    key: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  });
  if (!result.success) throw new Error("Account access is not configured yet.");
  client = createClient(result.data.url, result.data.key, {
    auth: { detectSessionInUrl: false },
  });
  return client;
}
