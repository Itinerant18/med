import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Types ────────────────────────────────────────────────────────────────

type EventType =
  | "followup_assigned"
  | "followup_completed"
  | "followup_reviewed"
  | "outside_visit_recorded"
  | "patient_status_changed"
  | "work_log_added";

interface PushPayload {
  event: EventType;
  recipientIds: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
}

const ALLOWED_EVENTS = new Set<EventType>([
  "followup_assigned",
  "followup_completed",
  "followup_reviewed",
  "outside_visit_recorded",
  "patient_status_changed",
  "work_log_added",
]);

// ── Constants ────────────────────────────────────────────────────────────

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PROJECT_ID = Deno.env.get("FCM_PROJECT_ID") ?? "";
const SA_JSON_RAW = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";

const FCM_ENDPOINT =
  `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`;
const OAUTH_ENDPOINT = "https://oauth2.googleapis.com/token";

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

// ── OAuth2 token exchange ────────────────────────────────────────────────

let _cachedToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  if (_cachedToken && Date.now() < _cachedToken.expiresAt) {
    return _cachedToken.token;
  }

  let sa: {
    client_email: string;
    private_key: string;
    private_key_id: string;
    client_id: string;
  };
  try {
    sa = JSON.parse(SA_JSON_RAW);
  } catch {
    throw new Error("FCM_SERVICE_ACCOUNT_JSON is not valid JSON");
  }

  if (!sa.client_email || !sa.private_key) {
    throw new Error(
      "FCM_SERVICE_ACCOUNT_JSON missing client_email or private_key"
    );
  }

  const now = Math.floor(Date.now() / 1000);
  const jwtHeader = { alg: "RS256", typ: "JWT", kid: sa.private_key_id };
  const jwtPayload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: OAUTH_ENDPOINT,
    exp: now + 3600,
    iat: now,
  };

  const b64 = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const headerB64 = b64(jwtHeader);
  const payloadB64 = b64(jwtPayload);
  const signingInput = `${headerB64}.${payloadB64}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput)
  );

  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const assertion = `${signingInput}.${signatureB64}`;

  const tokenResponse = await fetch(OAUTH_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!tokenResponse.ok) {
    const errText = await tokenResponse.text();
    throw new Error(`OAuth token exchange failed: ${errText}`);
  }

  const tokenData = await tokenResponse.json();
  const token = tokenData.access_token as string;
  const expiresIn = (tokenData.expires_in as number) || 3600;

  _cachedToken = { token, expiresAt: Date.now() + (expiresIn - 60) * 1000 };
  return token;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function normalizePayload(input: unknown): PushPayload {
  if (!isRecord(input)) {
    throw new ValidationError("Invalid JSON body");
  }

  const { event, recipientIds, title, body, data } = input;

  if (typeof event !== "string" || !ALLOWED_EVENTS.has(event as EventType)) {
    throw new ValidationError("Invalid event value");
  }

  if (
    !Array.isArray(recipientIds) ||
    recipientIds.length === 0 ||
    !recipientIds.every((id) => typeof id === "string" && id.trim().length > 0)
  ) {
    throw new ValidationError(
      "recipientIds must be a non-empty array of strings"
    );
  }

  if (typeof title !== "string" || title.trim().length === 0) {
    throw new ValidationError("Missing title");
  }

  if (typeof body !== "string" || body.trim().length === 0) {
    throw new ValidationError("Missing body");
  }

  if (data !== undefined && !isRecord(data)) {
    throw new ValidationError("data must be an object of string values");
  }

  const normalizedData: Record<string, string> | undefined = data
    ? Object.entries(data).reduce<Record<string, string>>((acc, [key, value]) => {
      if (typeof value !== "string") {
        throw new ValidationError("data values must be strings");
      }
      acc[key] = value;
      return acc;
    }, {})
    : undefined;

  return {
    event: event as EventType,
    recipientIds: [...new Set(recipientIds.map((id) => id.trim()))],
    title: title.trim(),
    body: body.trim(),
    data: normalizedData,
  };
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64Lines = pem
    .replace(/-----BEGIN [\w\s]+-----/, "")
    .replace(/-----END [\w\s]+-----/, "")
    .replace(/\s/g, "");
  const binaryStr = atob(b64Lines);
  const bytes = new Uint8Array(binaryStr.length);
  for (let i = 0; i < binaryStr.length; i++) {
    bytes[i] = binaryStr.charCodeAt(i);
  }
  return bytes.buffer;
}

// ── FCM sender ───────────────────────────────────────────────────────────

async function sendFcm(
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<{ ok: boolean; expired: boolean }> {
  const message: Record<string, unknown> = {
    token,
    notification: { title, body },
  };

  if (data && Object.keys(data).length > 0) {
    message.data = data;
  }

  const response = await fetch(FCM_ENDPOINT, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ message }),
  });

  if (response.ok) return { ok: true, expired: false };

  // 404 means the token is no longer valid (device unregistered)
  if (response.status === 404) return { ok: false, expired: true };

  // 400 / 401 may be transient — don't delete token
  const bodyText = await response.text();
  console.error(`FCM send error (${response.status}): ${bodyText}`);
  return { ok: false, expired: false };
}

// ── Handler ──────────────────────────────────────────────────────────────

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  if (!PROJECT_ID) {
    return json({ error: "FCM_PROJECT_ID not configured" }, 500);
  }
  if (!SA_JSON_RAW) {
    return json({ error: "FCM_SERVICE_ACCOUNT_JSON not configured" }, 500);
  }

  try {
    let rawBody: unknown;
    try {
      rawBody = await request.json();
    } catch {
      throw new ValidationError("Invalid JSON body");
    }

    const payload = normalizePayload(rawBody);

    // ── Fetch tokens ──
    const { data: doctors, error: fetchError } = await admin
      .from("doctors")
      .select("id, fcm_token")
      .in("id", payload.recipientIds)
      .not("fcm_token", "is", null);

    if (fetchError) {
      return json({ error: `DB query failed: ${fetchError.message}` }, 500);
    }

    const tokens: { id: string; token: string }[] = [];
    for (const doc of doctors ?? []) {
      const token = doc.fcm_token?.toString();
      const id = doc.id?.toString();
      if (id && token) tokens.push({ id, token });
    }

    if (tokens.length === 0) {
      return json({ sent: 0, failed: 0 });
    }

    // ── Send ──
    const accessToken = await getAccessToken();
    const fcmData = payload.data ?? {};
    fcmData["event"] = payload.event;

    const results = await Promise.allSettled(
      tokens.map((t) =>
        sendFcm(accessToken, t.token, payload.title, payload.body, fcmData)
      )
    );

    let sent = 0;
    let failed = 0;
    const expiredTokenIds: string[] = [];

    for (let i = 0; i < results.length; i++) {
      const result = results[i];
      if (result.status === "fulfilled") {
        if (result.value.ok) {
          sent++;
        } else {
          failed++;
          if (result.value.expired) {
            expiredTokenIds.push(tokens[i].id);
          }
        }
      } else {
        failed++;
      }
    }

    // ── Cleanup expired tokens ──
    if (expiredTokenIds.length > 0) {
      try {
        await admin
          .from("doctors")
          .update({ fcm_token: null })
          .in("id", expiredTokenIds);
      } catch (e) {
        console.error("Failed to clear expired tokens:", e);
      }
    }

    return json({ sent, failed });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    const status = error instanceof ValidationError ? 400 : 500;
    return json({ error: message }, status);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
