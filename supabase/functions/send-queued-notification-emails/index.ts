// Sends queued event/job notification emails.
// Invoked by pg_cron via public.queued_notification_email_dispatch()
// with x-dispatch-secret (same PUSH_DISPATCH_SECRET as send-push).

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
    "authorization, x-client-info, apikey, content-type, x-dispatch-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DISPATCH_SECRET = Deno.env.get("PUSH_DISPATCH_SECRET") ?? "";
const ORIGIN = "https://ustp-aess.web.app";
const BATCH = 12;

type Claimed = {
  delivery_id: string;
  user_id: string;
  email: string;
  display_name: string;
  title: string;
  message: string;
  action_path: string;
  action_label: string;
  preference_type: string;
  kind: string;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
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

  try {
    const { data, error } = await supabase.rpc(
      "claim_queued_notification_emails",
      { p_limit: BATCH },
    );
    if (error) throw new Error(`claim failed: ${error.message}`);
    const claimed = (data ?? []) as Claimed[];
    if (claimed.length === 0) {
      return json({ ok: true, claimed: 0, sent: 0, failed: 0 });
    }

    const { from, user, pass } = gmailFrom();
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: { user, pass },
    });

    const results: { id: string; ok: boolean; error?: string }[] = [];
    for (const item of claimed) {
      try {
        const mail = renderMail(item);
        await transporter.sendMail({
          from,
          to: item.email,
          subject: mail.title,
          text: brandedEmailText(mail),
          html: brandedEmailHtml(mail),
        });
        results.push({ id: item.delivery_id, ok: true });
      } catch (e) {
        results.push({
          id: item.delivery_id,
          ok: false,
          error: e instanceof Error ? e.message : String(e),
        });
      }
    }

    const { error: completeError } = await supabase.rpc(
      "complete_queued_notification_emails",
      { p_results: results },
    );
    if (completeError) {
      throw new Error(`complete failed: ${completeError.message}`);
    }

    const sent = results.filter((r) => r.ok).length;
    return json({
      ok: true,
      claimed: claimed.length,
      sent,
      failed: results.length - sent,
    });
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});

function renderMail(item: Claimed) {
  const path = (item.action_path || "").replace(/^\/+/, "");
  const actionUrl = path ? `${ORIGIN}/${path}` : ORIGIN;
  const kind = item.kind || "";
  let deadlineText: string | null = null;
  if (kind === "job_deadline_3d") {
    deadlineText = "Application deadline in 3 days.";
  } else if (kind === "job_deadline_1d") {
    deadlineText = "Application deadline tomorrow.";
  } else if (kind === "reminder_1d") {
    deadlineText = "This event is tomorrow.";
  } else if (kind === "reminder_0d") {
    deadlineText = "This event is today.";
  }

  let message = item.message || "";
  if (kind === "job_recommended") {
    message = message.includes("matches your program")
      ? message
      : `${message}\n\nThis opportunity was matched to your program.`;
  }

  return {
    userName: item.display_name || "Alumni",
    title: item.title || "AESS-USTP update",
    message,
    actionUrl,
    actionLabel: item.action_label || "Open AESS-USTP",
    deadlineText,
  };
}

function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const safe = {
  equal(a: string, b: string): boolean {
    if (a.length !== b.length) return false;
    let out = 0;
    for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
    return out === 0;
  },
};
