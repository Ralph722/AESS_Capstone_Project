/** Semaphore PH SMS helpers for contact OTP and scheduled survey texts. */

export function toSemaphoreNumber(normalized: string): string | null {
  const v = normalized.trim();
  if (/^09\d{9}$/.test(v)) {
    return `63${v.slice(1)}`;
  }
  if (/^\+63\d{10}$/.test(v)) {
    return v.slice(1);
  }
  if (/^63\d{10}$/.test(v)) {
    return v;
  }
  return null;
}

/**
 * Sends one SMS via Semaphore. Do not start [message] with "TEST" —
 * Semaphore silently drops those.
 */
export async function sendSemaphoreSms(number: string, message: string) {
  const apiKey = Deno.env.get("SEMAPHORE_API_KEY")?.trim();
  const senderName = Deno.env.get("SEMAPHORE_SENDER_NAME")?.trim();
  if (!apiKey || !senderName) {
    throw new Error("Semaphore is not configured");
  }

  const body = new URLSearchParams({
    apikey: apiKey,
    number,
    message,
    sendername: senderName,
  });
  const response = await fetch("https://api.semaphore.co/api/v4/messages", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const text = await response.text();
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = text;
  }
  if (!response.ok) {
    console.error("semaphore: HTTP", response.status, parsed);
    throw new Error(`Semaphore HTTP ${response.status}`);
  }
  if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
    const err = parsed as { error?: unknown; message?: unknown };
    if (
      err.error != null ||
      (typeof err.message === "string" &&
        /invalid|error|fail/i.test(err.message))
    ) {
      console.error("semaphore: error body", parsed);
      throw new Error(String(err.error ?? err.message ?? "sms_failed"));
    }
  }
  if (Array.isArray(parsed) && parsed.length > 0) {
    const first = parsed[0] as { status?: string };
    const status = (first.status ?? "").toLowerCase();
    if (status === "failed" || status === "refunded") {
      console.error("semaphore: delivery", parsed);
      throw new Error(`Semaphore status ${first.status}`);
    }
  }
}
