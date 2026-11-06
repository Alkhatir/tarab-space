import { z } from "zod";

export const invitationUsernameSchema = z.string().trim()
  .transform((value) => value.replace(/^\/?u\//iu, "").toLowerCase())
  .pipe(z.string().regex(/^[a-z0-9_-]{3,20}$/u, "Use a Reddit username with 3–20 letters, numbers, underscores, or hyphens."));
export const invitationTokenSchema = z.string().regex(/^[A-Za-z0-9_-]{43}$/u, "This invitation link is missing or malformed.");
export const accountCredentialsSchema = z.object({
  email: z.email("Enter a valid email address."),
  password: z.string().min(12, "Use a password with at least 12 characters.").max(128),
});
