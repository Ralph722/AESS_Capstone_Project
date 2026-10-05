// Sends queued push deliveries (public.notification_deliveries, channel 'push').
//
// Invoked by the database (pg_net) with the shared x-dispatch-secret header,
// never by the app. Provider credentials are Edge Function secrets:
//   PUSH_DISPATCH_SECRET   shared with Vault 'push_dispatch_secret'
//   VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY / VAPID_SUBJECT   Web Push
//   FCM_SERVICE_ACCOUNT    Firebase service account JSON (Android)
// A provider without credentials is skipped; the other keeps working.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

type Delivery = {
  delivery_id: string;
  notification_id: string;
  provider: "webpush" | "fcm";
  platform: string;
  token: string;
  subscription: webpush.PushSubscription | null;
  type: string;
  priority: string;
  title: string;
  body: string;
  route: string | null;
  attempts: number;
};

type Result = {
  id: string;
  ok: boolean;
  error?: string;
  retry?: boolean;
  skipped?: boolean;
  disable_token?: boolean;
};

const DISPATCH_SECRET = Deno.env.get("PUSH_DISPATCH_SECRET") ?? "";
const VAPID_PUBLIC_KEY = Deno.env.get("VAPID_PUBLIC_KEY") ?? "";
const VAPID_PRIVATE_KEY = Deno.env.get("VAPID_PRIVATE_KEY") ?? "";
const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") ??
  Deno.env.get("SUPABASE_URL") ?? "";
const FCM_SERVICE_ACCOUNT = Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "";

const TIME_BUDGET_MS = 25_000;
const BATCH = 100;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }
  const provided = req.headers.get("x-dispatch-secret") ?? "";
  if (!DISPATCH_SECRET || !safeEqual(provided, DISPATCH_SECRET)) {
    return json({ error: "Forbidden" }, 403);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return json({ error: "Supabase env is not configured" }, 500);
  }
  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const started = Date.now();
  let sent = 0;
  let failed = 0;

  try {
    while (Date.now() - started < TIME_BUDGET_MS) {
      const { data, error } = await supabase.rpc("claim_push_deliveries", {
        p_limit: BATCH,
      });
      if (error) throw new Error(`claim failed: ${error.message}`);
      const deliveries = (data ?? []) as Delivery[];
      if (deliveries.length === 0) break;

      const results = await Promise.all(deliveries.map(sendOne));
      sent += results.filter((r) => r.ok).length;
      failed += results.filter((r) => !r.ok).length;

      const { error: completeError } = await supabase.rpc(
        "complete_push_deliveries",
        { p_results: results },
      );
      if (completeError) {
        throw new Error(`complete failed: ${completeError.message}`);
      }
      if (deliveries.length < BATCH) break;
    }
    return json({ ok: true, sent, failed });
  } catch (error) {
    console.error("send-push", errorMessage(error));
    return json({ error: errorMessage(error), sent, failed }, 500);
  }
});

async function sendOne(d: Delivery): Promise<Result> {
  try {
    if (d.provider === "webpush") return await sendWebPush(d);
    if (d.provider === "fcm") return await sendFcm(d);
    return { id: d.delivery_id, ok: false, retry: false, error: "unknown provider" };
  } catch (error) {
    return { id: d.delivery_id, ok: false, retry: true, error: errorMessage(error) };
  }
}

function isHighPriority(priority: string) {
  return priority === "high" || priority === "urgent";
}

// ---------------------------------------------------------------------------
// Web Push (VAPID)
// ---------------------------------------------------------------------------
async function sendWebPush(d: Delivery): Promise<Result> {
  if (!VAPID_PUBLIC_KEY || !VAPID_PRIVATE_KEY || !VAPID_SUBJECT) {
    return {
      id: d.delivery_id,
      ok: false,
      retry: false,
      skipped: true,
      error: "Web Push is not configured",
    };
  }
  if (!d.subscription?.endpoint || !d.subscription.keys) {
    return { id: d.delivery_id, ok: false, disable_token: true, error: "invalid subscription" };
  }

  const payload = JSON.stringify({
    title: d.title,
    body: d.body,
    route: d.route ?? "",
    notificationId: d.notification_id,
    tag: d.notification_id,
  });

  try {
    await webpush.sendNotification(d.subscription, payload, {
      TTL: 60 * 60 * 24,
      urgency: isHighPriority(d.priority) ? "high" : "normal",
      vapidDetails: {
        subject: VAPID_SUBJECT,
        publicKey: VAPID_PUBLIC_KEY,
        privateKey: VAPID_PRIVATE_KEY,
      },
    });
    return { id: d.delivery_id, ok: true };
  } catch (error) {
    const status = (error as { statusCode?: number }).statusCode;
    const message = `web push ${status ?? ""} ${errorMessage(error)}`.trim();
    if (status === 404 || status === 410) {
      return { id: d.delivery_id, ok: false, disable_token: true, error: message };
    }
    const retry = status === undefined || status === 429 || status >= 500;
    return { id: d.delivery_id, ok: false, retry, error: message };
  }
}

// ---------------------------------------------------------------------------
// FCM HTTP v1 (Android)
// ---------------------------------------------------------------------------
type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

let serviceAccount: ServiceAccount | null | undefined;
let cachedAccessToken: { token: string; expiresAt: number } | null = null;

function loadServiceAccount(): ServiceAccount | null {
  if (serviceAccount !== undefined) return serviceAccount;
  try {
    // Accepts the raw JSON or the same JSON base64-encoded (easier to set).
    const text = FCM_SERVICE_ACCOUNT.trim().startsWith("{")
      ? FCM_SERVICE_ACCOUNT
      : new TextDecoder().decode(
        Uint8Array.from(atob(FCM_SERVICE_ACCOUNT.trim()), (c) => c.charCodeAt(0)),
      );
    const parsed = JSON.parse(text) as ServiceAccount;
    serviceAccount = parsed.project_id && parsed.client_email && parsed.private_key
      ? parsed
      : null;
  } catch {
    serviceAccount = null;
  }
  return serviceAccount;
}

async function sendFcm(d: Delivery): Promise<Result> {
  const sa = FCM_SERVICE_ACCOUNT ? loadServiceAccount() : null;
  if (!sa) {
    return {
      id: d.delivery_id,
      ok: false,
      retry: false,
      skipped: true,
      error: "FCM is not configured",
    };
  }

  const accessToken = await fcmAccessToken(sa);
  const high = isHighPriority(d.priority);
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: d.token,
          notification: { title: d.title, body: d.body },
          data: {
            route: d.route ?? "",
            notificationId: d.notification_id,
            type: d.type,
          },
          android: {
            priority: high ? "HIGH" : "NORMAL",
            ttl: "86400s",
            notification: {
              channel_id: "aess_notifications",
              tag: d.notification_id,
            },
          },
        },
      }),
    },
  );

  if (response.ok) return { id: d.delivery_id, ok: true };

  const text = await response.text();
  const message = `fcm ${response.status} ${text.slice(0, 300)}`;
  if (response.status === 401) cachedAccessToken = null;
  const unregistered = response.status === 404 ||
    text.includes("UNREGISTERED") ||
    text.includes("SENDER_ID_MISMATCH") ||
    (response.status === 400 && text.includes("registration token"));
  if (unregistered) {
    return { id: d.delivery_id, ok: false, disable_token: true, error: message };
  }
  const retry = response.status === 401 || response.status === 429 ||
    response.status >= 500;
  return { id: d.delivery_id, ok: false, retry, error: message };
}

async function fcmAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt - 60 > now) {
    return cachedAccessToken.token;
  }

  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64UrlJson(header)}.${base64UrlJson(claims)}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64UrlBytes(new Uint8Array(signature))}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`FCM auth failed: ${response.status}`);
  }
  const data = await response.json() as { access_token: string; expires_in: number };
  cachedAccessToken = {
    token: data.access_token,
    expiresAt: now + (data.expires_in ?? 3600),
  };
  return data.access_token;
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\\n/g, "")
    .replace(/\s+/g, "");
  const raw = atob(b64);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes.buffer;
}

function base64UrlJson(value: unknown) {
  return base64UrlBytes(new TextEncoder().encode(JSON.stringify(value)));
}

function base64UrlBytes(bytes: Uint8Array) {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// ---------------------------------------------------------------------------
function safeEqual(a: string, b: string) {
  const ea = new TextEncoder().encode(a);
  const eb = new TextEncoder().encode(b);
  let diff = ea.length ^ eb.length;
  const len = Math.max(ea.length, eb.length);
  for (let i = 0; i < len; i++) diff |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  return diff === 0;
}

function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}
