// Shared AESS-USTP branded email rendering for Edge Functions.
// Brand: USTP navy #1A1851, gold #FCB315 (lib/core/constants/ustp_colors.dart).

export type BrandedEmailParams = {
  userName: string;
  title: string;
  message: string;
  actionUrl?: string | null;
  actionLabel?: string;
  deadlineText?: string | null;
};

export function gmailFrom(): { from: string; user: string; pass: string } {
  const gmailUser = Deno.env.get("GMAIL_USER");
  const gmailAppPassword = Deno.env.get("GMAIL_APP_PASSWORD");
  const senderName = Deno.env.get("GMAIL_SENDER_NAME") || "AESS-USTP";
  if (!gmailUser || !gmailAppPassword) {
    throw new Error(
      "Gmail SMTP is not configured (GMAIL_USER / GMAIL_APP_PASSWORD)",
    );
  }
  return {
    from: `"${senderName}" <${gmailUser}>`,
    user: gmailUser,
    pass: gmailAppPassword,
  };
}

export function brandedEmailText(params: BrandedEmailParams): string {
  return [
    `Hello ${params.userName},`,
    "",
    params.title,
    "",
    params.message,
    ...(params.deadlineText ? ["", params.deadlineText] : []),
    ...(params.actionUrl
      ? ["", `${params.actionLabel || "Open in AESS-USTP"}: ${params.actionUrl}`]
      : []),
    "",
    "—",
    "AESS-USTP · USTP Alumni Engagement and Support System",
    "You received this email because you are a registered USTP alumnus in AESS-USTP.",
  ].join("\n");
}

export function brandedEmailHtml(params: BrandedEmailParams): string {
  const navy = "#1A1851";
  const gold = "#FCB315";
  const ink = "#151515";
  const muted = "#6B7280";
  const messageHtml = escapeHtml(params.message).replaceAll("\n", "<br>");
  const deadlineHtml = params.deadlineText
    ? `<tr><td style="padding:0 32px 8px;">
         <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
           <tr><td style="background:#FFF7E0;border:1px solid ${gold};border-radius:8px;padding:12px 16px;font-size:14px;color:${ink};">
             <strong>Deadline:</strong> ${escapeHtml(params.deadlineText)}
           </td></tr>
         </table>
       </td></tr>`
    : "";
  const actionUrl = params.actionUrl ?? null;
  const ctaHtml = actionUrl
    ? `<tr><td style="padding:16px 32px 4px;">
         <table role="presentation" cellpadding="0" cellspacing="0">
           <tr><td style="background:${gold};border-radius:8px;">
             <a href="${escapeHtml(actionUrl)}" style="display:inline-block;padding:13px 28px;font-size:15px;font-weight:700;color:${navy};text-decoration:none;">
               ${escapeHtml(params.actionLabel || "Open in AESS-USTP")}
             </a>
           </td></tr>
         </table>
       </td></tr>
       <tr><td style="padding:8px 32px 0;font-size:12px;color:${muted};line-height:1.5;">
         If the button does not work, copy and paste this link into your browser:<br>
         <a href="${escapeHtml(actionUrl)}" style="color:${navy};word-break:break-all;">${escapeHtml(actionUrl)}</a>
       </td></tr>`
    : "";
  return `<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body style="margin:0;padding:0;background:#F4F6FA;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F4F6FA;padding:24px 12px;">
  <tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#FFFFFF;border:1px solid #E1E5EA;border-radius:12px;overflow:hidden;font-family:Arial,Helvetica,sans-serif;color:${ink};">
      <tr><td style="background:${navy};padding:20px 32px;">
        <div style="font-size:20px;font-weight:700;color:#FFFFFF;letter-spacing:0.5px;">AESS&#8209;USTP</div>
        <div style="font-size:12px;color:${gold};margin-top:2px;">USTP Alumni Engagement and Support System</div>
      </td></tr>
      <tr><td style="height:4px;background:${gold};font-size:0;line-height:0;">&nbsp;</td></tr>
      <tr><td style="padding:24px 32px 0;font-size:15px;line-height:1.6;">Hello ${escapeHtml(params.userName)},</td></tr>
      <tr><td style="padding:8px 32px 0;">
        <h1 style="margin:0;font-size:20px;line-height:1.35;color:${navy};">${escapeHtml(params.title)}</h1>
      </td></tr>
      <tr><td style="padding:12px 32px 8px;font-size:15px;line-height:1.6;">${messageHtml}</td></tr>
      ${deadlineHtml}
      ${ctaHtml}
      <tr><td style="padding:24px 32px 0;">
        <hr style="border:none;border-top:1px solid #E1E5EA;margin:0;">
      </td></tr>
      <tr><td style="padding:16px 32px 24px;font-size:12px;color:${muted};line-height:1.6;">
        You received this email because you are a registered USTP alumnus in AESS&#8209;USTP.
        The link above opens the official AESS&#8209;USTP portal, where you will be asked to sign in.<br><br>
        AESS&#8209;USTP &middot; University of Science and Technology of Southern Philippines
      </td></tr>
    </table>
  </td></tr>
</table>
</body>
</html>`;
}

export function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
