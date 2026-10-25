// Contact verification codes for the tracer (Q3 email, Q5 mobile) and
// Profile information.
//
//   { action: "send",        channel: "email" | "mobile", target }
//   { action: "verify",      channel: "email" | "mobile", target, code }
//   { action: "apply_email", target }  // email only: becomes the login email
//
// Email codes go out through the same Gmail SMTP account as send-email.
// After verify, apply_email changes auth.users.email (login), then saves
// contact_email / roster emails. Mobile still uses apply_verified_contact
// from the app.
//
// SMS_MODE:
//   - unset / disabled / anything else → mobile send returns sms_unavailable
//   - "mock" → local/demo only; OTP returned as demoCode; method = mock
//   - "live" or "semaphore" → Semaphore SMS; method = sms; never echo OTP
// Never default production to mock.
//
// Secrets for live SMS: SEMAPHORE_API_KEY, SEMAPHORE_SENDER_NAME.
// Codes are stored only as an HMAC. Limits live in
// contact_verification_start/check.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  createClient,
  type SupabaseClient,
  type User,
} from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.15";
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

const CODE_LENGTH = 6;
const MAX_TARGET = 254;
const REAUTH_WINDOW_MS = 24 * 60 * 60 * 1000;

type Channel = "email" | "mobile";
type VerifyRequest = {
  action?: string;
  channel?: string;
  target?: string;
  code?: string;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json({ error: "server_not_configured" }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "not_signed_in" }, 401);
  }
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser();
  const user = authData?.user;
  if (authError || !user) {
    return json({ error: "not_signed_in" }, 401);
  }
  const { data: active, error: activeError } = await userClient.rpc(
    "caller_is_active",
  );
  if (activeError) {
    return json({ error: "server_error" }, 500);
  }
  if (active !== true) {
    return json({ error: "inactive_account" }, 403);
  }

  let body: VerifyRequest;
  try {
    body = (await req.json()) as VerifyRequest;
  } catch {
    return json({ error: "invalid_input" }, 400);
  }
  const action = body.action;
  const target = (body.target ?? "").trim();

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });
  const secret = Deno.env.get("CONTACT_OTP_SECRET") || serviceKey;

  if (action === "apply_email") {
    if (!target || target.length > MAX_TARGET) {
      return json({ error: "invalid_input" }, 400);
    }
    return await applyEmail(admin, user, target);
  }

  const channel = body.channel;
  if (
    (action !== "send" && action !== "verify") ||
    (channel !== "email" && channel !== "mobile") ||
    !target ||
    target.length > MAX_TARGET
  ) {
    return json({ error: "invalid_input" }, 400);
  }

  if (action === "send") {
    return await sendCode(admin, secret, user.id, channel, target);
  }

  const code = (body.code ?? "").replace(/\D/g, "");
  if (code.length !== CODE_LENGTH) {
    return json({ error: "invalid_code" }, 400);
  }
  return await verifyCode(admin, secret, user.id, channel, target, code);
});

function smsModeEnabled(mode: string) {
  return mode === "mock" || mode === "live" || mode === "semaphore";
}

function smsMethod(mode: string): "mock" | "sms" {
  return mode === "mock" ? "mock" : "sms";
}

async function sendCode(
  admin: SupabaseClient,
  secret: string,
  userId: string,
  channel: Channel,
  target: string,
) {
  // Fail closed unless SMS_MODE is explicitly mock or live/semaphore.
  const smsMode = (Deno.env.get("SMS_MODE") ?? "disabled").toLowerCase();
  if (channel === "mobile" && !smsModeEnabled(smsMode)) {
    return json({ error: "sms_unavailable" }, 503);
  }
  const method = channel === "email" ? "email" : smsMethod(smsMode);

  if (channel === "email") {
    const { data: taken, error: takenError } = await admin.rpc(
      "contact_email_taken",
      { p_email: target, p_except_user_id: userId },
    );
    if (takenError) {
      console.error("contact-verify: taken check failed", takenError.message);
      return json({ error: "server_error" }, 500);
    }
    if (taken === true) {
      return json({ error: "email_in_use" }, 409);
    }
  }

  const code = randomCode();
  const codeHash = await hashCode(secret, userId, channel, code);
  const { data, error } = await admin.rpc("contact_verification_start", {
    p_user_id: userId,
    p_channel: channel,
    p_target: target,
    p_code_hash: codeHash,
    p_method: method,
  });
  if (error || !data) {
    console.error("contact-verify: start failed", error?.message);
    return json({ error: "server_error" }, 500);
  }
  const started = data as {
    ok: boolean;
    error?: string;
    retryAfter?: number;
    id?: string;
    target?: string;
    expiresAt?: string;
    resendAfter?: number;
  };
  if (!started.ok) {
    const status = started.error === "cooldown" ||
        started.error === "too_many_requests"
      ? 429
      : started.error === "inactive_account"
      ? 403
      : 400;
    return json(
      { error: started.error, retryAfter: started.retryAfter ?? null },
      status,
    );
  }

  const normalized = started.target ?? target;
  const result: Record<string, unknown> = {
    ok: true,
    channel,
    target: normalized,
    method,
    expiresAt: started.expiresAt,
    resendAfter: started.resendAfter ?? 60,
  };

  if (channel === "email") {
    try {
      await sendVerificationEmail(
        normalized,
        code,
        await displayName(admin, userId),
      );
    } catch (error) {
      console.error("contact-verify: email failed", errorMessage(error));
      await admin.rpc("contact_verification_cancel", {
        p_user_id: userId,
        p_id: started.id,
      });
      return json({ error: "email_failed" }, 502);
    }
  } else if (smsMode === "mock") {
    // Local/demo only — never attach the OTP when SMS is live or unset.
    result.demoCode = code;
  } else {
    const semaphoreNumber = toSemaphoreNumber(normalized);
    if (!semaphoreNumber) {
      await admin.rpc("contact_verification_cancel", {
        p_user_id: userId,
        p_id: started.id,
      });
      return json({ error: "sms_ph_only" }, 400);
    }
    try {
      // Do not start the body with "TEST" — Semaphore silently drops those.
      await sendSemaphoreSms(
        semaphoreNumber,
        `Your AESS-USTP verification code is ${code}. ` +
          `Valid for 10 minutes. Do not share this code.`,
      );
    } catch (error) {
      console.error("contact-verify: SMS failed", errorMessage(error));
      await admin.rpc("contact_verification_cancel", {
        p_user_id: userId,
        p_id: started.id,
      });
      return json({ error: "sms_failed" }, 502);
    }
  }
  return json(result);
}

async function verifyCode(
  admin: SupabaseClient,
  secret: string,
  userId: string,
  channel: Channel,
  target: string,
  code: string,
) {
  const codeHash = await hashCode(secret, userId, channel, code);
  const { data, error } = await admin.rpc("contact_verification_check", {
    p_user_id: userId,
    p_channel: channel,
    p_target: target,
    p_code_hash: codeHash,
  });
  if (error || !data) {
    console.error("contact-verify: check failed", error?.message);
    return json({ error: "server_error" }, 500);
  }
  const checked = data as {
    ok: boolean;
    error?: string;
    attemptsLeft?: number;
    target?: string;
    method?: string;
  };
  if (!checked.ok) {
    return json(
      { error: checked.error, attemptsLeft: checked.attemptsLeft ?? null },
      checked.error === "too_many_attempts" ? 429 : 400,
    );
  }
  return json({
    ok: true,
    channel,
    target: checked.target,
    method: checked.method,
  });
}

async function applyEmail(
  admin: SupabaseClient,
  user: User,
  target: string,
) {
  if (!hasRecentSignIn(user)) {
    return json({ error: "reauth_required" }, 401);
  }

  const { data: taken, error: takenError } = await admin.rpc(
    "contact_email_taken",
    { p_email: target, p_except_user_id: user.id },
  );
  if (takenError) {
    console.error("contact-verify: taken check failed", takenError.message);
    return json({ error: "server_error" }, 500);
  }
  if (taken === true) {
    return json({ error: "email_in_use" }, 409);
  }

  const { data: normalizedRows, error: normError } = await admin.rpc(
    "contact_normalize_target",
    { p_channel: "email", p_value: target },
  );
  if (normError) {
    console.error("contact-verify: normalize failed", normError.message);
    return json({ error: "server_error" }, 500);
  }
  const normalized = (normalizedRows as string | null) ?? null;
  if (!normalized) {
    return json({ error: "invalid_target" }, 400);
  }

  // Confirm a fresh, unused verification before touching Auth.
  const since = new Date(Date.now() - 30 * 60 * 1000).toISOString();
  const { data: pending, error: pendingError } = await admin
    .from("contact_verifications")
    .select("id")
    .eq("user_id", user.id)
    .eq("channel", "email")
    .eq("target", normalized)
    .not("verified_at", "is", null)
    .is("consumed_at", null)
    .gte("verified_at", since)
    .order("verified_at", { ascending: false })
    .limit(1);
  if (pendingError) {
    console.error("contact-verify: pending check failed", pendingError.message);
    return json({ error: "server_error" }, 500);
  }
  if (!pending?.length) {
    return json({ error: "not_verified" }, 400);
  }

  const oldEmail = (user.email ?? "").trim().toLowerCase();
  const loginChanged = oldEmail !== "" && oldEmail !== normalized;

  if (loginChanged) {
    const { error: updateError } = await admin.auth.admin.updateUserById(
      user.id,
      { email: normalized, email_confirm: true },
    );
    if (updateError) {
      console.error(
        "contact-verify: auth email update failed",
        updateError.message,
      );
      const msg = updateError.message.toLowerCase();
      if (msg.includes("already") || msg.includes("registered")) {
        return json({ error: "email_in_use" }, 409);
      }
      return json({ error: "login_email_failed" }, 502);
    }
  }

  const { data: applied, error: applyError } = await admin.rpc(
    "service_apply_verified_contact",
    {
      p_user_id: user.id,
      p_channel: "email",
      p_target: normalized,
    },
  );
  if (applyError || !applied) {
    console.error(
      "contact-verify: apply after auth failed",
      applyError?.message,
    );
    // Auth may already have changed; do not roll it back here. The alumnus
    // can retry apply_email after verifying again if contact lagged.
    return json({ error: "apply_failed", detail: applyError?.message }, 502);
  }

  const name = await displayName(admin, user.id);
  if (loginChanged && oldEmail) {
    try {
      await sendLoginChangedNotice(oldEmail, normalized, name);
    } catch (error) {
      console.error(
        "contact-verify: old-email notice failed",
        errorMessage(error),
      );
    }
  }

  try {
    await admin.from("audit_logs").insert({
      user_id: user.id,
      action: "LOGIN_EMAIL_CHANGE",
      entity_type: "User",
      entity_id: user.id,
      details: {
        description: loginChanged
          ? `Login email changed from ${oldEmail} to ${normalized}`
          : `Contact email confirmed: ${normalized}`,
        status: "SUCCESS",
        userRole: "user",
        changes: {
          from: oldEmail || null,
          to: normalized,
          loginChanged,
        },
      },
    });
  } catch (error) {
    console.error("contact-verify: audit failed", errorMessage(error));
  }

  return json({
    ok: true,
    channel: "email",
    target: normalized,
    loginChanged,
    previousEmail: loginChanged ? oldEmail : null,
  });
}

function hasRecentSignIn(user: User) {
  const raw = user.last_sign_in_at;
  if (!raw) return false;
  const at = Date.parse(raw);
  if (Number.isNaN(at)) return false;
  return Date.now() - at <= REAUTH_WINDOW_MS;
}

function randomCode() {
  const values = new Uint32Array(1);
  crypto.getRandomValues(values);
  return String(values[0] % 10 ** CODE_LENGTH).padStart(CODE_LENGTH, "0");
}

async function hashCode(
  secret: string,
  userId: string,
  channel: Channel,
  code: string,
) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${userId}:${channel}:${code}`),
  );
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function displayName(admin: SupabaseClient, userId: string) {
  const { data } = await admin
    .from("users")
    .select("display_name")
    .eq("id", userId)
    .maybeSingle();
  const name = (data?.display_name as string | undefined)?.trim();
  return name || "Alumni";
}

function mailTransport() {
  const gmailUser = Deno.env.get("GMAIL_USER");
  const gmailAppPassword = Deno.env.get("GMAIL_APP_PASSWORD");
  const senderName = Deno.env.get("GMAIL_SENDER_NAME") || "AESS-USTP";
  if (!gmailUser || !gmailAppPassword) {
    throw new Error("Gmail SMTP is not configured");
  }
  return {
    from: `"${senderName}" <${gmailUser}>`,
    transporter: nodemailer.createTransport({
      service: "gmail",
      auth: { user: gmailUser, pass: gmailAppPassword },
    }),
  };
}

async function sendVerificationEmail(
  toEmail: string,
  code: string,
  userName: string,
) {
  const { from, transporter } = mailTransport();
  const subject = `${code} is your AESS-USTP verification code`;
  const text = [
    `Hello ${userName},`,
    "",
    "You asked to use this address as your email in AESS-USTP.",
    `Your code is ${code}. It expires in 10 minutes.`,
    "",
    "Enter it on the verification screen to finish. After that, this address",
    "becomes the email you sign in with. Your password stays the same.",
    "",
    "Don't share this code. The alumni office will never ask for it.",
    "If you didn't ask for this code, you can ignore this email; nothing will change.",
    "",
    "—",
    "AESS-USTP · USTP Alumni Engagement and Support System",
  ].join("\n");
  const html = `
    <div style="font-family:Arial,Helvetica,sans-serif;color:#151515;max-width:480px;margin:0 auto;">
      <div style="background:#1A1851;padding:16px 24px;border-radius:12px 12px 0 0;">
        <div style="font-size:18px;font-weight:700;color:#FFFFFF;">AESS&#8209;USTP</div>
        <div style="font-size:11px;color:#FCB315;">USTP Alumni Engagement and Support System</div>
      </div>
      <div style="border:1px solid #E1E5EA;border-top:none;border-radius:0 0 12px 12px;padding:20px 24px;">
        <p style="margin:0 0 12px;">Hello ${escapeHtml(userName)},</p>
        <p style="margin:0 0 12px;line-height:1.5;">You asked to use this address as your email in AESS&#8209;USTP. Your code is:</p>
        <p style="font-size:28px;font-weight:700;letter-spacing:6px;color:#1A1851;margin:0 0 12px;">${code}</p>
        <p style="margin:0 0 12px;line-height:1.5;">It expires in 10 minutes. Enter it on the verification screen to finish. After that, this address becomes the email you sign in with. Your password stays the same.</p>
        <p style="margin:0;color:#6B7280;font-size:13px;line-height:1.5;">Don't share this code. The alumni office will never ask for it.<br>
        If you didn't ask for this code, you can ignore this email; nothing will change.</p>
      </div>
    </div>
  `;
  await transporter.sendMail({ from, to: toEmail, subject, text, html });
}

async function sendLoginChangedNotice(
  oldEmail: string,
  newEmail: string,
  userName: string,
) {
  const { from, transporter } = mailTransport();
  const subject = "Your AESS-USTP sign-in email was changed";
  const text = [
    `Hello ${userName},`,
    "",
    "The sign-in email for your AESS-USTP account was changed.",
    `Previous: ${oldEmail}`,
    `New: ${newEmail}`,
    "",
    "From now on, sign in with the new address. Your password is unchanged.",
    "If you did not make this change, contact the alumni office right away.",
    "",
    "—",
    "AESS-USTP · USTP Alumni Engagement and Support System",
  ].join("\n");
  const html = `
    <div style="font-family:Arial,Helvetica,sans-serif;color:#151515;max-width:480px;margin:0 auto;">
      <div style="background:#1A1851;padding:16px 24px;border-radius:12px 12px 0 0;">
        <div style="font-size:18px;font-weight:700;color:#FFFFFF;">AESS&#8209;USTP</div>
        <div style="font-size:11px;color:#FCB315;">USTP Alumni Engagement and Support System</div>
      </div>
      <div style="border:1px solid #E1E5EA;border-top:none;border-radius:0 0 12px 12px;padding:20px 24px;">
        <p style="margin:0 0 12px;">Hello ${escapeHtml(userName)},</p>
        <p style="margin:0 0 12px;line-height:1.5;">The sign-in email for your AESS&#8209;USTP account was changed.</p>
        <p style="margin:0 0 12px;line-height:1.5;">Previous: <strong>${escapeHtml(oldEmail)}</strong><br>
        New: <strong>${escapeHtml(newEmail)}</strong></p>
        <p style="margin:0 0 12px;line-height:1.5;">From now on, sign in with the new address. Your password is unchanged.</p>
        <p style="margin:0;color:#6B7280;font-size:13px;line-height:1.5;">If you did not make this change, contact the alumni office right away.</p>
      </div>
    </div>
  `;
  await transporter.sendMail({ from, to: oldEmail, subject, text, html });
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
