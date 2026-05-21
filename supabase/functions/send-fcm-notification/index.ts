// Direct FCM dispatcher — accepts a single device token and sends the message
// via the FCM v1 HTTP API using a service-account OAuth2 bearer token.
//
// Expected body: { token: string, title: string, body: string, data?: Record<string, string> }
//
// Required secrets (set in Supabase Dashboard → Edge Functions → Secrets):
//   FCM_PROJECT_ID          — Firebase project ID (e.g. "mediflow-f1b78")
//   FCM_SERVICE_ACCOUNT_JSON — Full JSON content of the Firebase service account key

const PROJECT_ID = Deno.env.get("FCM_PROJECT_ID") ?? "";
const SA_JSON_RAW = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";

const FCM_ENDPOINT =
  `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`;
const OAUTH_ENDPOINT = "https://oauth2.googleapis.com/token";

// ── OAuth2 token cache ───────────────────────────────────────────────────

let _cachedToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  if (_cachedToken && Date.now() < _cachedToken.expiresAt) {
    return _cachedToken.token;
  }

  let sa: {
    client_email: string;
    private_key: string;
    private_key_id: string;
  };
  try {
    sa = JSON.parse(SA_JSON_RAW);
  } catch {
    throw new Error("FCM_SERVICE_ACCOUNT_JSON is not valid JSON");
  }

  if (!sa.client_email || !sa.private_key) {
    throw new Error(
      "FCM_SERVICE_ACCOUNT_JSON missing client_email or private_key",
    );
  }

  const now = Math.floor(Date.now() / 1000);
  const b64 = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const header = b64({ alg: "RS256", typ: "JWT", kid: sa.private_key_id });
  const payload = b64({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: OAUTH_ENDPOINT,
    exp: now + 3600,
    iat: now,
  });
  const signingInput = `${header}.${payload}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );

  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const tokenRes = await fetch(OAUTH_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${signingInput}.${sigB64}`,
    }),
  });

  if (!tokenRes.ok) {
    throw new Error(`OAuth token exchange failed: ${await tokenRes.text()}`);
  }

  const tokenData = await tokenRes.json();
  const token = tokenData.access_token as string;
  const expiresIn = (tokenData.expires_in as number) || 3600;
  _cachedToken = { token, expiresAt: Date.now() + (expiresIn - 60) * 1000 };
  return token;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN [\w\s]+-----/, "")
    .replace(/-----END [\w\s]+-----/, "")
    .replace(/\s/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

// ── Handler ──────────────────────────────────────────────────────────────

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  if (!PROJECT_ID) return json({ error: "FCM_PROJECT_ID not configured" }, 500);
  if (!SA_JSON_RAW) {
    return json({ error: "FCM_SERVICE_ACCOUNT_JSON not configured" }, 500);
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  if (
    typeof body !== "object" || body === null ||
    typeof (body as Record<string, unknown>)["token"] !== "string" ||
    typeof (body as Record<string, unknown>)["title"] !== "string" ||
    typeof (body as Record<string, unknown>)["body"] !== "string"
  ) {
    return json({ error: "Missing required fields: token, title, body" }, 400);
  }

  const { token, title, body: msgBody, data } = body as {
    token: string;
    title: string;
    body: string;
    data?: Record<string, string>;
  };

  try {
    const accessToken = await getAccessToken();

    const message: Record<string, unknown> = {
      token,
      notification: { title, body: msgBody },
    };
    if (data && Object.keys(data).length > 0) message.data = data;

    const fcmRes = await fetch(FCM_ENDPOINT, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message }),
    });

    if (fcmRes.ok) return json({ ok: true });

    const errText = await fcmRes.text();
    console.error(`FCM error (${fcmRes.status}): ${errText}`);
    return json({ ok: false, error: errText }, fcmRes.status);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error("send-fcm-notification error:", message);
    return json({ ok: false, error: message }, 500);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
