import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.15";

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
};

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

    try {
      await sendWithGmailSmtp({
        toEmail,
        userName: body.userName?.trim() || "Alumni",
        title,
        message,
      });
    } catch (error) {
      await logEmailDelivery({
        toEmail,
        title,
        sentBy: authResult.userId,
        error: errorMessage(error),
      });
      throw error;
    }

    await logEmailDelivery({ toEmail, title, sentBy: authResult.userId });
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
async function logEmailDelivery(params: {
  toEmail: string;
  title: string;
  sentBy: string;
  error?: string;
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
    await admin.from("notification_deliveries").insert({
      channel: "email",
      user_id: recipient?.id ?? null,
      recipient: params.toEmail,
      status: params.error ? "failed" : "sent",
      attempts: 1,
      scheduled_at: now,
      sent_at: params.error ? null : now,
      last_error: params.error ? params.error.slice(0, 500) : null,
      data: { kind: "reminder", title: params.title, sent_by: params.sentBy },
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
}) {
  const gmailUser = Deno.env.get("GMAIL_USER");
  const gmailAppPassword = Deno.env.get("GMAIL_APP_PASSWORD");
  const senderName = Deno.env.get("GMAIL_SENDER_NAME") || "Alumni System";

  if (!gmailUser || !gmailAppPassword) {
    throw new Error("Gmail SMTP is not configured (GMAIL_USER / GMAIL_APP_PASSWORD)");
  }

  const subject = params.title;
  const html = reminderHtml(params.userName, params.title, params.message);
  const text = `Hello ${params.userName},\n\n${params.message}`;

  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: gmailUser,
      pass: gmailAppPassword,
    },
  });

  await transporter.sendMail({
    from: `"${senderName}" <${gmailUser}>`,
    to: params.toEmail,
    subject,
    text,
    html,
  });
}

function reminderHtml(userName: string, title: string, message: string) {
  return `
    <p>Hello ${escapeHtml(userName)},</p>
    <h2>${escapeHtml(title)}</h2>
    <p>${escapeHtml(message).replaceAll("\n", "<br>")}</p>
  `;
}

function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function escapeHtml(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}
