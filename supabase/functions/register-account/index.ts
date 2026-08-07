import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type SignupRequest = {
  email?: string;
  password?: string;
  displayName?: string;
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
    const body = (await req.json()) as SignupRequest;
    const email = body.email?.trim().toLowerCase() ?? "";
    const password = body.password ?? "";
    const displayName = body.displayName?.trim() ?? "";

    if (!emailPattern.test(email)) {
      return json({ error: "Valid email is required" }, 400);
    }
    if (password.length < 6) {
      return json({ error: "Password must be at least 6 characters" }, 400);
    }

    const admin = createAdminClient();
    const existing = await findAuthUserByEmail(admin, email);

    if (existing) {
      const activelyRegistered = await isActivelyRegisteredAlumni(
        admin,
        existing.id,
      );
      if (activelyRegistered) {
        return json(
          {
            error: "An account already exists for this email.",
            code: "already_exists",
          },
          409,
        );
      }

      // Deleted/unlinked alumni or orphan Auth row: clear stale app data and
      // reset credentials so roster registration can complete cleanly.
      await purgeStaleAppUserData(admin, existing.id);

      const { error: updateError } = await admin.auth.admin.updateUserById(
        existing.id,
        {
          password,
          email_confirm: true,
          user_metadata: {
            ...(existing.user_metadata ?? {}),
            display_name: displayName ||
              existing.user_metadata?.display_name ||
              "",
          },
        },
      );
      if (updateError) {
        return json({ error: updateError.message }, 500);
      }

      return json({
        ok: true,
        recovered: true,
        userId: existing.id,
      });
    }

    const { data: created, error: createError } = await admin.auth.admin
      .createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { display_name: displayName },
      });

    if (createError || !created.user) {
      return json(
        { error: createError?.message ?? "Could not create account" },
        500,
      );
    }

    return json({
      ok: true,
      created: true,
      userId: created.user.id,
    });
  } catch (error) {
    return json(
      { error: error instanceof Error ? error.message : String(error) },
      500,
    );
  }
});

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

async function isActivelyRegisteredAlumni(
  admin: ReturnType<typeof createClient>,
  authUserId: string,
) {
  const { data: member, error } = await admin
    .from("alumni_members")
    .select("id")
    .eq("auth_uid", authUserId)
    .eq("is_registered_user", true)
    .eq("is_deactivated", false)
    .maybeSingle();
  if (error) throw error;
  return member != null;
}

async function purgeStaleAppUserData(
  admin: ReturnType<typeof createClient>,
  authUserId: string,
) {
  const now = new Date().toISOString();

  await admin
    .from("alumni_members")
    .update({
      auth_uid: null,
      is_registered_user: false,
      registered_email: null,
      updated_at: now,
    })
    .eq("auth_uid", authUserId);

  const userOwnedTables = [
    "employment_records",
    "survey_assignments",
    "survey_responses",
    "notifications",
    "user_notifications",
    "favorite_jobs",
    "feedback",
    "reminders",
    "event_comments",
    "event_replies",
  ] as const;

  for (const table of userOwnedTables) {
    const { error } = await admin.from(table).delete().eq("user_id", authUserId);
    if (error) {
      // Some tables may be absent in older schemas; ignore missing-table errors.
      if (!error.message.toLowerCase().includes("does not exist")) {
        throw error;
      }
    }
  }

  await admin.from("messages").delete().eq("sender_id", authUserId);
  await admin.from("messages").delete().eq("recipient_id", authUserId);

  await admin.from("forum_posts").delete().eq("author_uid", authUserId);
  await admin.from("forum_topics").delete().eq("author_uid", authUserId);
  await admin.from("users").delete().eq("id", authUserId);
}

async function findAuthUserByEmail(
  admin: ReturnType<typeof createClient>,
  email: string,
) {
  // Paginate — listUsers has no email filter in older API versions.
  let page = 1;
  const perPage = 200;
  while (page <= 20) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage });
    if (error) throw error;
    const users = data.users ?? [];
    const hit = users.find((u) => (u.email ?? "").toLowerCase() === email);
    if (hit) return hit;
    if (users.length < perPage) break;
    page += 1;
  }
  return null;
}

function json(data: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
