import "server-only";

import { createHash, randomBytes } from "node:crypto";

const TOKEN_BYTES = 32;
const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/u;

/** Only the hash belongs in the database. Never log the bearer token. */
export function hashInvitationToken(token: string): string {
  if (!TOKEN_PATTERN.test(token)) {
    throw new Error("Invalid invitation token format.");
  }

  return createHash("sha256").update(token, "utf8").digest("hex");
}

/** Return the raw token once, for constructing the invitation URL server-side. */
export function createInvitationToken(): { token: string; tokenHash: string } {
  const token = randomBytes(TOKEN_BYTES).toString("base64url");
  return { token, tokenHash: hashInvitationToken(token) };
}
