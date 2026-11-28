// Admin-triggered survey reminder SMS (Pending tab / Remind pending).
// Auth: caller JWT must be an admin (same pattern as send-email).
// Secrets: SEMAPHORE_API_KEY, SEMAPHORE_SENDER_NAME, SMS_MODE=live|semaphore.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  sendSemaphoreSms,
  toSemaphoreNumber,
} from "../_shared/semaphore_sms.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_RECIPIENTS = 100;

type Body = {
  surveyId?: string;
  userIds?: unknown;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const auth = await requireAdmin(req);
    if (!auth.ok) {
      return json({ error: auth.error }, auth.status);
    }

    const smsMode = (Deno.env.get("SMS_MODE") ?? "disabled").toLowerCase();
    if (smsMode !== "live" && smsMode !== "semaphore") {
      return json({
        ok: true,
        skipped: "sms_disabled",
        sent: 0,
        skippedNoMobile: 0,
        skippedOptedOut: 0,
        failures: [],
      });
    }

    const body = (await req.json()) as Body;
    const surveyId = (body.surveyId ?? "").trim();
    const userIds = normalizeUserIds(body.userIds);
    if (!surveyId) {
      return json({ error: "surveyId is required" }, 400);
    }
    if (userIds.length === 0) {
      return json({
        ok: true,
        sent: 0,
        skippedNoMobile: 0,
        skippedOptedOut: 0,
        failures: [],
      });
    }
    if (userIds.length > MAX_RECIPIENTS) {
      return json(
        { error: `At most ${MAX_RECIPIENTS} recipients per request` },
        400,
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
      return json({ error: "Supabase env is not configured" }, 500);
    }
    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: survey, error: surveyError } = await admin
      .from("surveys")
      .select("id, title, data, status")
      .eq("id", surveyId)
      .maybeSingle();
    if (surveyError || !survey) {
      return json({ error: "Survey not found" }, 404);
    }
    const isChed =
      ((survey.data as Record<string, unknown> | null)?.kind ?? "") ===
      "ched_gts_builtin";
    const message = isChed
      ? "AESS-USTP: Reminder — please complete your Graduate Tracer Study in the Alumni Portal (ustp-aess.web.app). Thank you."
      : "AESS-USTP: Reminder — please complete your alumni survey in the Alumni Portal (ustp-aess.web.app). Thank you.";

    let sent = 0;
    let skippedNoMobile = 0;
    let skippedOptedOut = 0;
    const failures: string[] = [];

    for (const userId of userIds) {
      try {
        const { data: assignment } = await admin
          .from("survey_assignments")
          .select("id, status")
          .eq("survey_id", surveyId)
          .eq("user_id", userId)
          .maybeSingle();
        if (
          !assignment ||
          assignment.status === "completed"
        ) {
          failures.push(`${userId}: not pending`);
          continue;
        }

        const { data: allowed } = await admin.rpc(
          "notification_channel_allowed",
          {
            p_user: userId,
            p_type: "survey",
            p_channel: "sms",
            p_priority: "normal",
          },
        );
        if (allowed === false) {
          skippedOptedOut++;
          await logDelivery(admin, {
            userId,
            mobile: null,
            status: "skipped",
            surveyId,
            sentBy: auth.userId,
            skippedReason: "sms_opt_out",
          });
          continue;
        }

        const { data: user } = await admin
          .from("users")
          .select("display_name, mobile_number, mobile_verified_at")
          .eq("id", userId)
          .maybeSingle();
        const mobile = (user?.mobile_number as string | null)?.trim() ?? "";
        const verified = user?.mobile_verified_at != null;
        const number = verified ? toSemaphoreNumber(mobile) : null;
        if (!number) {
          skippedNoMobile++;
          await logDelivery(admin, {
            userId,
            mobile: mobile || null,
            status: "skipped",
            surveyId,
            sentBy: auth.userId,
            skippedReason: "no_verified_mobile",
          });
          continue;
        }

        await sendSemaphoreSms(number, message);
        sent++;
        await logDelivery(admin, {
          userId,
          mobile,
          status: "sent",
          surveyId,
          sentBy: auth.userId,
        });
      } catch (e) {
        const err = e instanceof Error ? e.message : String(e);
        failures.push(`${userId}: ${err}`);
        await logDelivery(admin, {
          userId,
          mobile: null,
          status: "failed",
          surveyId,
          sentBy: auth.userId,
          error: err,
        });
      }
    }

    return json({
      ok: true,
      sent,
      skippedNoMobile,
      skippedOptedOut,
      failures,
    });
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
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

function normalizeUserIds(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const raw of value) {
    const id = String(raw ?? "").trim();
    if (!id || seen.has(id)) continue;
    seen.add(id);
    out.push(id);
  }
  return out;
}

async function logDelivery(
  admin: ReturnType<typeof createClient>,
  params: {
    userId: string;
    mobile: string | null;
    status: "sent" | "skipped" | "failed";
    surveyId: string;
    sentBy: string;
    skippedReason?: string;
    error?: string;
  },
) {
  try {
    const now = new Date().toISOString();
    await admin.from("notification_deliveries").insert({
      channel: "sms",
      user_id: params.userId,
      recipient: params.mobile ?? "",
      status: params.status,
      attempts: params.status === "skipped" ? 0 : 1,
      scheduled_at: now,
      sent_at: params.status === "sent" ? now : null,
      last_error: params.error ? params.error.slice(0, 500) : null,
      data: {
        kind: "admin_reminder",
        survey_id: params.surveyId,
        sent_by: params.sentBy,
        automated: false,
        ...(params.skippedReason
          ? { skipped_reason: params.skippedReason }
          : {}),
      },
    });
  } catch (error) {
    console.warn("send-survey-reminder-sms: delivery log failed", error);
  }
}

function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
