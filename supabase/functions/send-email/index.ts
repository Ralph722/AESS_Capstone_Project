import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.15";
import {
  brandedEmailHtml,
  brandedEmailText,
  gmailFrom,
} from "../_shared/branded_email.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Admin-only reminder email. Registration codes are sent by Supabase Auth.
type EmailRequest = {
  kind?: "reminder";
  toEmail?: string;
  userName?: string;
  title?: string;
  message?: string;
  actionUrl?: string;
  actionLabel?: string;
  deadlineText?: string;
  /// Notification type whose email preference is checked (default survey).
  preferenceType?: string;
};

// Only canonical AESS links may be rendered as the CTA button. Anything
// else is dropped (never rendered), so a caller can never turn this
// function into a generic phishing-mail relay.
const allowedActionHosts = new Set([
  "ustp-aess.web.app",
  "ustp-aess.firebaseapp.com",
]);

function safeActionUrl(value?: string): string | null {
  if (!value) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:") return null;
    if (!allowedActionHosts.has(url.hostname.toLowerCase())) return null;
    return url.toString();
  } catch {
    return null;
  }
}

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const authResult = await requireAdmin(req);
    if (!authResult.ok) {
      return json({ error: authResult.error }, authResult.status);
    }

    const body = (await req.json()) as EmailRequest;
    const toEmail = body.toEmail?.trim();
    const title = body.title?.trim();
    const message = body.message?.trim();

    if (body.kind !== "reminder") {
      return json({ error: "Invalid email kind" }, 400);
    }
    if (!toEmail || !emailPattern.test(toEmail)) {
      return json({ error: "Valid recipient email is required" }, 400);
    }
    if (!title || !message) {
      return json({ error: "Reminder title and message are required" }, 400);
    }

    // Respect the recipient's email preference for this category. The
    // in-app reminder (if any) is unaffected; Auth/verification codes
    // never pass through this function and are never opted out.
    const preferenceType = body.preferenceType === "announcement"
      ? "announcement"
      : "survey";
    if (await isEmailOptedOut(toEmail, preferenceType)) {
      await logEmailDelivery({
        toEmail,
        title,
        sentBy: authResult.userId,
        status: "skipped",
        preferenceType,
      });
      return json({ ok: true, skipped: true, reason: "email_opt_out" });
    }

    try {
      await sendWithGmailSmtp({
        toEmail,
        userName: body.userName?.trim() || "Alumni",
        title,
        message,
        actionUrl: safeActionUrl(body.actionUrl),
        actionLabel: body.actionLabel?.trim() || "Open in AESS-USTP",
        deadlineText: body.deadlineText?.trim() || null,
      });
    } catch (error) {
      await logEmailDelivery({
        toEmail,
        title,
        sentBy: authResult.userId,
        error: errorMessage(error),
        preferenceType,
      });
      throw error;
    }

    await logEmailDelivery({
      toEmail,
      title,
      sentBy: authResult.userId,
      preferenceType,
    });
    return json({ ok: true });
  } catch (error) {
    return json({ error: errorMessage(error) }, 500);
  }
});

async function requireAdmin(req: Request): Promise<
  | { ok: true; userId: string }
  | { ok: false; status: number; error: string }
> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const authHeader = req.headers.get("Authorization") ?? "";

  if (!supabaseUrl || !supabaseAnonKey) {
    return { ok: false, status: 500, error: "Supabase env is not configured" };
  }

  if (!authHeader.startsWith("Bearer ")) {
    return { ok: false, status: 401, error: "Authentication required" };
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData.user) {
    return { ok: false, status: 401, error: "Invalid session" };
  }

  const { data: userRow, error: roleError } = await supabase
    .from("users")
    .select("role")
    .eq("id", authData.user.id)
    .maybeSingle();

  if (roleError) {
    return { ok: false, status: 500, error: "Unable to verify user role" };
  }

  if (userRow?.role !== "admin") {
    return { ok: false, status: 403, error: "Admin role required" };
  }

  return { ok: true, userId: authData.user.id };
}

// One row per email in public.notification_deliveries (channel 'email').
// Logging problems never block or fail the send itself.
/// True when the recipient turned this category off in Notification
/// settings (notification_preferences.email). Unknown recipients and any
/// lookup failure default to sending — a reminder must not be lost
/// because a preference row could not be read.
async function isEmailOptedOut(
  toEmail: string,
  preferenceType: string,
): Promise<boolean> {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) return false;
    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false },
    });

    const { data: recipient } = await admin
      .from("users")
      .select("id")
      .eq("email", toEmail.toLowerCase())
      .maybeSingle();
    if (!recipient?.id) return false;

    const { data: prefs } = await admin
      .from("notification_preferences")
      .select("email")
      .eq("user_id", recipient.id)
      .maybeSingle();
    const map = (prefs?.email ?? {}) as Record<string, unknown>;
    const value = map[preferenceType];
    return value === false ||
      (typeof value === "string" && value.toLowerCase() === "false");
  } catch {
    return false;
  }
}

async function logEmailDelivery(params: {
  toEmail: string;
  title: string;
  sentBy: string;
  error?: string;
  status?: "skipped";
  preferenceType?: string;
}) {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) return;
    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false },
    });

    const { data: recipient } = await admin
      .from("users")
      .select("id")
      .eq("email", params.toEmail.toLowerCase())
      .maybeSingle();

    const now = new Date().toISOString();
    const status = params.status ??
      (params.error ? "failed" : "sent");
    await admin.from("notification_deliveries").insert({
      channel: "email",
      user_id: recipient?.id ?? null,
      recipient: params.toEmail,
      status,
      attempts: status === "skipped" ? 0 : 1,
      scheduled_at: now,
      sent_at: status === "sent" ? now : null,
      last_error: params.error ? params.error.slice(0, 500) : null,
      data: {
        kind: "reminder",
        title: params.title,
        sent_by: params.sentBy,
        preference_type: params.preferenceType ?? "survey",
        ...(status === "skipped" ? { skipped_reason: "email_opt_out" } : {}),
      },
    });
  } catch (error) {
    console.warn("send-email: delivery log failed", errorMessage(error));
  }
}

async function sendWithGmailSmtp(params: {
  toEmail: string;
  userName: string;
  title: string;
  message: string;
  actionUrl: string | null;
  actionLabel: string;
  deadlineText: string | null;
}) {
  const { from, user, pass } = gmailFrom();

  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: { user, pass },
  });

  await transporter.sendMail({
    from,
    to: params.toEmail,
    subject: params.title,
    text: brandedEmailText(params),
    html: brandedEmailHtml(params),
  });
}


function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}
