// AmigosNearMe — Supabase Edge Function: send-email
// 모든 이메일 시나리오를 단일 함수에서 처리
// 호출: supabase.functions.invoke('send-email', { body: { scenario, data } })

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!;
const SUPABASE_URL   = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_KEY   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
// 도메인 인증 후 noreply@amigosnearme.com 으로 변경
const FROM_EMAIL     = Deno.env.get('FROM_EMAIL') ?? 'AmigosNearMe <onboarding@resend.dev>';
const ADMIN_EMAIL    = Deno.env.get('ADMIN_EMAIL') ?? 'admin@amigosnearme.com';

const sb = createClient(SUPABASE_URL, SUPABASE_KEY);

// ── 이메일 발송 (Resend) ───────────────────────────────────────
async function sendEmail(to: string, subject: string, html: string): Promise<void> {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from: FROM_EMAIL, to, subject, html }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Resend error: ${err}`);
  }
}

// ── 발송 로그 (중복 방지) ──────────────────────────────────────
async function alreadySent(scenario: string, refId: string): Promise<boolean> {
  const { data } = await sb
    .from('email_log')
    .select('id')
    .eq('scenario', scenario)
    .eq('ref_id', refId)
    .limit(1);
  return !!(data && data.length > 0);
}

async function logEmail(scenario: string, recipient: string, refId: string): Promise<void> {
  await sb.from('email_log').insert({ scenario, recipient, ref_id: refId });
}

// ── 시나리오별 이메일 빌더 ─────────────────────────────────────
function templates(scenario: string, d: Record<string, string>): { subject: string; html: string } | null {
  switch (scenario) {

    // ── Service Business ───────────────────────────────────────
    case 'SB1':
      return {
        subject: `Welcome to AmigosNearMe — ${d.biz_name}`,
        html: `<p>Hi ${d.owner_name},</p>
<p>Your business <strong>${d.biz_name}</strong> is now live and searchable on AmigosNearMe.</p>
<p>To get a <strong>Verified Badge</strong>, go to your <a href="https://amigosnearme.com/dashboard.html">dashboard</a> and submit your documents.</p>`,
      };

    case 'SB2':
      return {
        subject: 'Verified Badge request received — AmigosNearMe',
        html: `<p>Hi ${d.owner_name},</p>
<p>We received your Verified Badge request for <strong>${d.biz_name}</strong>. We'll review your documents within 2 business days.</p>`,
      };

    case 'SB3':
      return {
        subject: '✅ Your Verified Badge is approved — AmigosNearMe',
        html: `<p>Hi ${d.owner_name},</p>
<p>Great news! <strong>${d.biz_name}</strong> has been awarded a <strong>✅ Verified Badge</strong>. It's now visible on your profile.</p>`,
      };

    case 'SB4':
      return {
        subject: 'Verified Badge update — AmigosNearMe',
        html: `<p>Hi ${d.owner_name},</p>
<p>Unfortunately, your Verified Badge request for <strong>${d.biz_name}</strong> was not approved.</p>
<p><strong>Reason:</strong> ${d.reason || 'Documents could not be verified.'}</p>
<p>You may resubmit after addressing the issue.</p>`,
      };

    case 'SB5':
      return {
        subject: `Plan upgraded to ${d.plan} — AmigosNearMe`,
        html: `<p>Hi ${d.owner_name},</p>
<p>Your plan for <strong>${d.biz_name}</strong> has been upgraded to <strong>${d.plan}</strong>. Changes are effective immediately.</p>`,
      };

    case 'SB6':
      return {
        subject: `📲 A customer tried to reach you on WhatsApp — ${d.biz_name}`,
        html: `<p>Hi ${d.owner_name},</p>
<p>A customer found your listing on AmigosNearMe and opened WhatsApp to contact you.</p>
<p>Make sure to respond quickly — fast replies lead to more jobs.</p>
<p><a href="https://amigosnearme.com/dashboard.html">View your dashboard →</a></p>`,
      };

    case 'SB7':
      return {
        subject: `📋 New inquiry for ${d.biz_name} — AmigosNearMe`,
        html: `<p>Hi ${d.owner_name},</p>
<p>You have a new inquiry:</p>
<ul>
  <li><strong>Name:</strong> ${d.customer_name}</li>
  <li><strong>Phone:</strong> ${d.customer_phone}</li>
  <li><strong>Service:</strong> ${d.service}</li>
</ul>
<p>Contact them directly or view it in your <a href="https://amigosnearme.com/dashboard.html">dashboard</a>.</p>`,
      };

    case 'SB8':
      return {
        subject: `⚠️ Contact limit almost reached — ${d.biz_name}`,
        html: `<p>Hi ${d.owner_name},</p>
<p>Your <strong>${d.plan}</strong> plan for <strong>${d.biz_name}</strong> has <strong>${d.remaining} contact(s) remaining</strong> this month.</p>
<p><a href="https://amigosnearme.com/dashboard.html#plan">Upgrade now to keep receiving inquiries →</a></p>`,
      };

    case 'SB9':
      return {
        subject: `🚫 Monthly contact limit reached — ${d.biz_name}`,
        html: `<p>Hi ${d.owner_name},</p>
<p>Your <strong>${d.plan}</strong> plan has reached its monthly contact limit. New customers cannot reach you until next month or until you upgrade.</p>
<p><a href="https://amigosnearme.com/dashboard.html#plan">Upgrade to receive contacts immediately →</a></p>`,
      };

    case 'SB10':
      return {
        subject: 'Your account has been suspended — AmigosNearMe',
        html: `<p>Hi ${d.owner_name},</p>
<p>Your account for <strong>${d.biz_name}</strong> has been suspended.</p>
<p><strong>Reason:</strong> ${d.reason || 'Violation of terms of service.'}</p>
<p>Contact support to appeal: <a href="mailto:support@amigosnearme.com">support@amigosnearme.com</a></p>`,
      };

    case 'SB11':
      return {
        subject: 'Account deleted — AmigosNearMe',
        html: `<p>Hi ${d.owner_name},</p>
<p>Your account for <strong>${d.biz_name}</strong> has been permanently deleted as requested.</p>
<p>Thank you for using AmigosNearMe.</p>`,
      };

    case 'SB12':
      return {
        subject: `⚠️ You missed a customer contact — ${d.biz_name}`,
        html: `<p>Hi ${d.owner_name},</p>
<p>A customer tried to contact <strong>${d.biz_name}</strong> but could not because your monthly limit is reached.</p>
<p><a href="https://amigosnearme.com/dashboard.html#plan">Upgrade now to avoid missing more →</a></p>`,
      };

    case 'SB13':
      return {
        subject: `This business is not accepting contacts right now`,
        html: `<p>Hi,</p>
<p><strong>${d.biz_name}</strong> has reached its monthly contact limit on AmigosNearMe. They will be able to receive contacts again next month.</p>
<p><a href="https://amigosnearme.com/search.html">Find other businesses →</a></p>`,
      };

    // ── Worker ─────────────────────────────────────────────────
    case 'W1':
      return {
        subject: 'Your worker profile is live — AmigosNearMe',
        html: `<p>Hi ${d.worker_name},</p>
<p>Your profile is now live and searchable by businesses looking for workers. Keep your WhatsApp active so employers can reach you.</p>`,
      };

    case 'W2':
      return {
        subject: '📲 An employer wants to hire you — AmigosNearMe',
        html: `<p>Hi ${d.worker_name},</p>
<p>A business found your profile on AmigosNearMe and is reaching out to you via WhatsApp. Check your messages!</p>`,
      };

    case 'W3':
      return {
        subject: 'Your worker profile has been suspended — AmigosNearMe',
        html: `<p>Hi ${d.worker_name},</p>
<p>Your profile has been suspended. <strong>Reason:</strong> ${d.reason || 'Terms of service violation.'}</p>
<p>Contact <a href="mailto:support@amigosnearme.com">support@amigosnearme.com</a> to appeal.</p>`,
      };

    case 'W4':
      return {
        subject: 'Worker profile deleted — AmigosNearMe',
        html: `<p>Hi ${d.worker_name},</p><p>Your worker profile has been deleted as requested.</p>`,
      };

    // ── Customer ───────────────────────────────────────────────
    case 'CU1':
      return {
        subject: 'Welcome to AmigosNearMe',
        html: `<p>Hi ${d.name},</p>
<p>Thanks for joining AmigosNearMe. You can now search businesses and leave reviews.</p>
<p><a href="https://amigosnearme.com/search.html">Find businesses near you →</a></p>`,
      };

    case 'CU3':
      return {
        subject: 'Your inquiry was sent — AmigosNearMe',
        html: `<p>Hi ${d.name || 'there'},</p>
<p>Your inquiry for <strong>${d.service}</strong> was sent to <strong>${d.biz_name}</strong>. They'll contact you at <strong>${d.customer_phone}</strong> shortly.</p>`,
      };

    case 'CU4':
      return {
        subject: `Account ${d.action} — AmigosNearMe`,
        html: `<p>Hi ${d.name},</p>
<p>Your AmigosNearMe account has been <strong>${d.action}</strong>.</p>
${d.reason ? `<p><strong>Reason:</strong> ${d.reason}</p>` : ''}`,
      };

    // ── Employer ───────────────────────────────────────────────
    case 'EM1':
      return {
        subject: 'Welcome to AmigosNearMe — Find Workers',
        html: `<p>Hi ${d.name},</p>
<p>Your employer account is ready. Search for available workers and use contact credits to reach them via WhatsApp.</p>
<p><a href="https://amigosnearme.com/search.html?mode=workers">Find workers →</a></p>`,
      };

    case 'EM2':
      return {
        subject: `${d.credits} contact credits added — AmigosNearMe`,
        html: `<p>Hi ${d.name},</p>
<p>You now have <strong>${d.credits} contact credits</strong>. Use them to reach workers directly on WhatsApp.</p>`,
      };

    case 'EM3':
      return {
        subject: '⚠️ Only 1 contact credit remaining — AmigosNearMe',
        html: `<p>Hi ${d.name},</p>
<p>You have <strong>1 contact credit</strong> left. Purchase more to keep hiring workers.</p>
<p><a href="https://amigosnearme.com/search.html?mode=workers">Buy credits →</a></p>`,
      };

    case 'EM4':
      return {
        subject: '🚫 No contact credits remaining — AmigosNearMe',
        html: `<p>Hi ${d.name},</p>
<p>You've used all your contact credits. Purchase a new package to continue contacting workers.</p>
<p><a href="https://amigosnearme.com/search.html?mode=workers">Buy credits →</a></p>`,
      };

    case 'EM5':
      return {
        subject: `Employer account ${d.action} — AmigosNearMe`,
        html: `<p>Hi ${d.name},</p>
<p>Your employer account has been <strong>${d.action}</strong>.</p>
${d.reason ? `<p><strong>Reason:</strong> ${d.reason}</p>` : ''}`,
      };

    case 'EM6':
      return {
        subject: 'You need credits to contact this worker — AmigosNearMe',
        html: `<p>Hi ${d.name},</p>
<p>You tried to contact a worker but have no credits left. Purchase a package to continue.</p>
<p><a href="https://amigosnearme.com/search.html?mode=workers">Buy credits →</a></p>`,
      };

    // ── Admin ──────────────────────────────────────────────────
    case 'AD1':
      return {
        subject: `[Admin] Verified Badge request — ${d.biz_name}`,
        html: `<p>New Verified Badge request:</p>
<ul>
  <li><strong>Business:</strong> ${d.biz_name}</li>
  <li><strong>Owner:</strong> ${d.owner_email}</li>
  <li><strong>Submitted:</strong> ${d.submitted_at}</li>
</ul>
<p><a href="https://amigosnearme.com/admin.html#verification">Review in admin console →</a></p>`,
      };

    case 'AD2':
      return {
        subject: `[Admin] ⭐ 1-star review posted — ${d.biz_name}`,
        html: `<p>A 1-star review was posted:</p>
<ul>
  <li><strong>Business:</strong> ${d.biz_name}</li>
  <li><strong>Reviewer:</strong> ${d.reviewer_email || 'Anonymous'}</li>
  <li><strong>Review:</strong> "${d.review_text}"</li>
</ul>
<p><a href="https://amigosnearme.com/admin.html#reviews">Review in admin console →</a></p>`,
      };

    case 'AD3':
      return {
        subject: `[Admin] 🚨 Spam suspected in review — ${d.biz_name}`,
        html: `<p>A review contains a link, email, or phone number:</p>
<ul>
  <li><strong>Business:</strong> ${d.biz_name}</li>
  <li><strong>Review:</strong> "${d.review_text}"</li>
  <li><strong>Detected:</strong> ${d.detected}</li>
</ul>
<p><a href="https://amigosnearme.com/admin.html#reviews">Review in admin console →</a></p>`,
      };

    case 'AD4':
      return {
        subject: `[Admin] Cancellation request — ${d.biz_name}`,
        html: `<p>A business has requested account cancellation:</p>
<ul>
  <li><strong>Business:</strong> ${d.biz_name}</li>
  <li><strong>Reason:</strong> ${d.reason || 'Not provided'}</li>
</ul>
<p><a href="https://amigosnearme.com/admin.html#cancellations">Review in admin console →</a></p>`,
      };

    default:
      return null;
  }
}

// ── 메인 핸들러 ────────────────────────────────────────────────
serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  try {
    const { scenario, data, to, ref_id } = await req.json() as {
      scenario: string;
      data: Record<string, string>;
      to: string;
      ref_id?: string;
    };

    const isAdminScenario = ['AD1','AD2','AD3','AD4'].includes(scenario);

    if (!scenario || (!to && !isAdminScenario)) {
      return new Response(JSON.stringify({ error: 'scenario and to are required' }), { status: 400 });
    }

    // 중복 발송 방지 (ref_id 있을 때만)
    if (ref_id && await alreadySent(scenario, ref_id)) {
      return new Response(JSON.stringify({ skipped: true, reason: 'already_sent' }), { status: 200 });
    }

    // Admin 알림은 수신자를 ADMIN_EMAIL로 고정
    const recipient = isAdminScenario ? ADMIN_EMAIL : to;

    const tmpl = templates(scenario, data);
    if (!tmpl) {
      return new Response(JSON.stringify({ error: `Unknown scenario: ${scenario}` }), { status: 400 });
    }

    await sendEmail(recipient, tmpl.subject, tmpl.html);
    if (ref_id) await logEmail(scenario, recipient, ref_id);

    return new Response(JSON.stringify({ ok: true, scenario, to: recipient }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });

  } catch (err) {
    console.error('send-email error:', err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
