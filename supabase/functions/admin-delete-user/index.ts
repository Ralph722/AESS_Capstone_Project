import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type DeleteRequest = {
  memberId?: string;
  authUid?: string;
  fullName?: string;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const requester = await requireAdmin(req);
    const body = (await req.json()) as DeleteRequest;
    const authUid = body.authUid?.trim() ?? "";
    const memberId = body.memberId?.trim() ?? "";

    if (authUid.isEmpty) {
      return json({ error: "authUid is required" }, 400);
    }

    const admin = createAdminClient();
    const affectedSurveyIds = await collectAffectedSurveyIds(admin, authUid);

    if (memberId.isNotEmpty) {
      await admin.from("alumni_members").delete().eq("id", memberId);
    } else {
      await admin.from("alumni_members").delete().eq("auth_uid", authUid);
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(authUid);
    if (deleteError) {
      return json({ error: deleteError.message }, 500);
    }

    await reconcileSurveyCounts(admin, affectedSurveyIds);

    return json({
      ok: true,
      deletedUserId: authUid,
      requesterId: requester.id,
    });
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});

async function requireAdmin(req: Request) {
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const authHeader = req.headers.get("Authorization");

  if (!url || !anonKey) {
    throw new Error("Supabase anon env is not configured");
  }
  if (!authHeader) {
    throw new Error("Missing authorization header");
  }

  const client = createClient(url, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: authHeader } },
  });

  const { data: authData, error: authError } = await client.auth.getUser();
  if (authError || !authData.user) {
    throw new Error(authError?.message ?? "Not authenticated");
  }

  const { data: profile, error: profileError } = await client
    .from("users")
    .select("id, role")
    .eq("id", authData.user.id)
    .maybeSingle();

  if (profileError) {
    throw new Error(profileError.message);
  }
  if (!profile || profile.role !== "admin") {
    throw new Error("Admin access required");
  }

  return authData.user;
}

function createAdminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    throw new Error("Supabase admin env is not configured");
  }
  return createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

async function collectAffectedSurveyIds(
  admin: ReturnType<typeof createClient>,
  authUid: string,
) {
  const ids = new Set<string>();

  const { data: assignments, error: assignmentError } = await admin
    .from("survey_assignments")
    .select("survey_id")
    .eq("user_id", authUid);
  if (assignmentError) throw assignmentError;

  const { data: responses, error: responseError } = await admin
    .from("survey_responses")
    .select("survey_id")
    .eq("user_id", authUid);
  if (responseError) throw responseError;

  for (const row of assignments ?? []) {
    const surveyId = row.survey_id?.toString() ?? "";
    if (surveyId) ids.add(surveyId);
  }
  for (const row of responses ?? []) {
    const surveyId = row.survey_id?.toString() ?? "";
    if (surveyId) ids.add(surveyId);
  }

  return [...ids];
}

async function reconcileSurveyCounts(
  admin: ReturnType<typeof createClient>,
  surveyIds: string[],
) {
  for (const surveyId of surveyIds) {
    const { data: assignments, error: assignmentError } = await admin
      .from("survey_assignments")
      .select("id")
      .eq("survey_id", surveyId);
    if (assignmentError) throw assignmentError;

    const { data: responses, error: responseError } = await admin
      .from("survey_responses")
      .select("id")
      .eq("survey_id", surveyId)
      .eq("status", "submitted");
    if (responseError) throw responseError;

    const { error: updateError } = await admin.from("surveys").update({
      assignment_count: assignments?.length ?? 0,
      response_count: responses?.length ?? 0,
      updated_at: new Date().toISOString(),
    }).eq("id", surveyId);
    if (updateError) throw updateError;
  }
}

function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
