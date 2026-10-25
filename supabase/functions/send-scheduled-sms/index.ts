// Automated survey SMS (week-1 reminder + closing-in-3-days). Invoked by
// pg_cron through public.scheduled_sms_dispatch with x-dispatch-secret
// (same PUSH_DISPATCH_SECRET as send-push / send-scheduled-emails).
//
// Selection: claim_scheduled_survey_sms / complete_scheduled_survey_sms.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  sendSemaphoreSms,
  toSemaphoreNumber,
} from "../_shared/semaphore_sms.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-dispatch-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DISPATCH_SECRET = Deno.env.get("PUSH_DISPATCH_SECRET") ?? "";
const BATCH = 20;

type ClaimedSms = {
  delivery_id: string;
  assignment_id: string;
  user_id: string;
  mobile: string;
  display_name: string;
  survey_id: string;
  survey_title: string;
  is_ched: boolean;
  close_at: string | null;
  kind: "week1" | "closing_3d";
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

  const smsMode = (Deno.env.get("SMS_MODE") ?? "disabled").toLowerCase();
  if (smsMode !== "live" && smsMode !== "semaphore") {
    return json({ ok: true, skipped: "sms_disabled", claimed: 0, sent: 0 });
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
    const { data, error } = await supabase.rpc("claim_scheduled_survey_sms", {
      p_limit: BATCH,
    });
    if (error) throw new Error(`claim failed: ${error.message}`);
    const claimed = (data ?? []) as ClaimedSms[];
    if (claimed.length === 0) {
      return json({ ok: true, claimed: 0, sent: 0, failed: 0 });
    }

    const results: { id: string; ok: boolean; error?: string }[] = [];
    for (const item of claimed) {
      try {
        const number = toSemaphoreNumber(item.mobile);
        if (!number) {
          throw new Error("invalid_mobile");
        }
        await sendSemaphoreSms(number, renderSms(item));
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
      "complete_scheduled_survey_sms",
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

function renderSms(item: ClaimedSms): string {
  // Keep under ~160 chars (1 Semaphore credit). Never start with TEST.
  if (item.kind === "closing_3d") {
    return item.is_ched
      ? "AESS-USTP: Your Graduate Tracer Study closes in 3 days. Please finish it in the Alumni Portal. Thank you."
      : "AESS-USTP: Your alumni survey closes in 3 days. Please finish it in the Alumni Portal. Thank you.";
  }
  return item.is_ched
    ? "AESS-USTP: Please complete your Graduate Tracer Study in the Alumni Portal (app or ustp-aess.web.app). Thank you."
    : "AESS-USTP: Please complete your alumni survey in the Alumni Portal (app or ustp-aess.web.app). Thank you.";
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
