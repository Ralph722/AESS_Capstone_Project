// Automated survey emails (assignment notice, weekly reminder, closing
// warning). Invoked hourly by pg_cron through pg_net
// (public.scheduled_email_dispatch) with the shared x-dispatch-secret
// header — the same PUSH_DISPATCH_SECRET that guards send-push.
//
// All selection rules (who is due, caps, dedupe) live in SQL:
//   claim_scheduled_survey_emails(p_limit)
//   complete_scheduled_survey_emails(p_results)
// This function only renders and sends what the claim returns.

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
// Keep small enough that SMTP send + complete finishes inside the
// scheduled_email_dispatch pg_net timeout (55s).
const BATCH = 12;

type ClaimedEmail = {
  delivery_id: string;
  assignment_id: string;
  user_id: string;
  email: string;
  display_name: string;
  survey_id: string;
  survey_title: string;
  is_ched: boolean;
  close_at: string | null;
  kind: "assigned" | "weekly" | "closing_1d" | "closing_3d";
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
      "claim_scheduled_survey_emails",
      { p_limit: BATCH },
    );
    if (error) throw new Error(`claim failed: ${error.message}`);
    const claimed = (data ?? []) as ClaimedEmail[];
    if (claimed.length === 0) {
      return json({ ok: true, claimed: 0, sent: 0, failed: 0 });
    }

    const { from, user, pass } = gmailFrom();
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: { user, pass },
    });

    const results: { id: string; ok: boolean; error?: string }[] = [];
    // Sequential: Gmail SMTP is happiest without parallel bursts, and the
    // batch cap keeps us far under the daily sending limit.
    for (const item of claimed) {
      try {
        const mail = renderEmail(item);
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
      "complete_scheduled_survey_emails",
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

function renderEmail(item: ClaimedEmail) {
  const title = item.survey_title.trim() || "USTP alumni survey";
  const actionUrl = `${ORIGIN}/${item.is_ched ? "tracer" : "surveys"}/${item.survey_id}`;
  const actionLabel = item.is_ched
    ? "Answer the tracer study"
    : "Answer the survey";
  const deadlineText = item.close_at
    ? `Please respond on or before ${formatManilaDate(item.close_at)}.`
    : null;

  switch (item.kind) {
    case "assigned":
      return {
        userName: item.display_name,
        title: item.is_ched
          ? "Please complete the Graduate Tracer Study"
          : `New survey: ${title}`,
        message: item.is_ched
          ? "You have been assigned the CHED Graduate Tracer Study. " +
            "Your responses help USTP improve its programs and services " +
            "for future graduates. It only takes a few minutes to complete."
          : `You have been assigned a new USTP alumni survey: "${title}". ` +
            "Your feedback helps USTP improve its programs and services.",
        actionUrl,
        actionLabel,
        deadlineText,
      };
    case "closing_1d":
    case "closing_3d": {
      const when = item.kind === "closing_1d" ? "tomorrow" : "in 3 days";
      return {
        userName: item.display_name,
        title: `Survey closing ${when}: ${title}`,
        message:
          `This is a final reminder that "${title}" closes ${when} and ` +
          "your response has not been received yet. Please take a few " +
          "minutes to complete it before the deadline.",
        actionUrl,
        actionLabel,
        deadlineText,
      };
    }
    default:
      return {
        userName: item.display_name,
        title: `Reminder: ${title}`,
        message: item.is_ched
          ? "This is a friendly reminder to complete the Graduate Tracer " +
            "Study. Your responses help USTP improve its programs and " +
            "services for future graduates."
          : `This is a friendly reminder to complete the USTP alumni ` +
            `survey "${title}". Your feedback helps USTP improve its ` +
            "programs and services.",
        actionUrl,
        actionLabel,
        deadlineText,
      };
  }
}

function formatManilaDate(iso: string): string {
  return new Intl.DateTimeFormat("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric",
    timeZone: "Asia/Manila",
  }).format(new Date(iso));
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
