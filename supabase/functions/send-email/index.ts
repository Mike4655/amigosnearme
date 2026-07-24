// AmigosNearMe — Supabase Edge Function: send-email
// 모든 이메일 시나리오를 단일 함수에서 처리 (이중 언어: ES/EN)
// 호출: supabase.functions.invoke('send-email', { body: { scenario, data, lang? } })
// lang: 'es' (기본) | 'en'

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!;
const SUPABASE_URL   = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_KEY   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
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
    .eq('is_voided', false)
    .limit(1);
  return !!(data && data.length > 0);
}

async function logEmail(scenario: string, recipient: string, refId: string): Promise<void> {
  await sb.from('email_log').insert({ scenario, recipient, ref_id: refId });
}

// ── 시나리오별 이중 언어 템플릿 ───────────────────────────────
// lang: 'es' (기본) | 'en'
// Admin 시나리오(AD*)는 항상 영문
function templates(
  scenario: string,
  d: Record<string, string>,
  lang = 'es',
): { subject: string; html: string } | null {

  const es = lang !== 'en';

  switch (scenario) {

    // ══ Service Business ══════════════════════════════════════

    case 'SB1':
      return es ? {
        subject: `Bienvenido a AmigosNearMe — ${d.biz_name}`,
        html: `<p>Hola ${d.biz_name},</p>
<p>Tu negocio <strong>${d.biz_name}</strong> ya está activo y visible en AmigosNearMe.</p>
<p>Para obtener la <strong>Insignia Verificada</strong>, ve a tu <a href="https://amigosnearme.com/dashboard.html">panel de control</a> y envía tus documentos.</p>`,
      } : {
        subject: `Welcome to AmigosNearMe — ${d.biz_name}`,
        html: `<p>Hi ${d.biz_name},</p>
<p>Your business <strong>${d.biz_name}</strong> is now live and searchable on AmigosNearMe.</p>
<p>To get a <strong>Verified Badge</strong>, go to your <a href="https://amigosnearme.com/dashboard.html">dashboard</a> and submit your documents.</p>`,
      };

    case 'SB2':
      return es ? {
        subject: 'Solicitud de Insignia Verificada recibida — AmigosNearMe',
        html: `<p>Hola ${d.biz_name},</p>
<p>Recibimos tu solicitud de Insignia Verificada para <strong>${d.biz_name}</strong>. Revisaremos tus documentos en un plazo de 2 días hábiles.</p>`,
      } : {
        subject: 'Verified Badge request received — AmigosNearMe',
        html: `<p>Hi ${d.biz_name},</p>
<p>We received your Verified Badge request for <strong>${d.biz_name}</strong>. We'll review your documents within 2 business days.</p>`,
      };

    case 'SB3':
      return es ? {
        subject: '✅ Tu Insignia Verificada fue aprobada — AmigosNearMe',
        html: `<p>Hola ${d.biz_name},</p>
<p>¡Buenas noticias! <strong>${d.biz_name}</strong> recibió la <strong>✅ Insignia Verificada</strong>. Ya es visible en tu perfil.</p>`,
      } : {
        subject: '✅ Your Verified Badge is approved — AmigosNearMe',
        html: `<p>Hi ${d.biz_name},</p>
<p>Great news! <strong>${d.biz_name}</strong> has been awarded a <strong>✅ Verified Badge</strong>. It's now visible on your profile.</p>`,
      };

    case 'SB4':
      return es ? {
        subject: 'Actualización sobre tu Insignia Verificada — AmigosNearMe',
        html: `<p>Hola ${d.biz_name},</p>
<p>Tu solicitud de Insignia Verificada para <strong>${d.biz_name}</strong> no fue aprobada.</p>
<p><strong>Motivo:</strong> ${d.reason || 'Los documentos no pudieron ser verificados.'}</p>
<p>Puedes volver a enviarlos una vez que corrijas el problema.</p>`,
      } : {
        subject: 'Verified Badge update — AmigosNearMe',
        html: `<p>Hi ${d.biz_name},</p>
<p>Unfortunately, your Verified Badge request for <strong>${d.biz_name}</strong> was not approved.</p>
<p><strong>Reason:</strong> ${d.reason || 'Documents could not be verified.'}</p>
<p>You may resubmit after addressing the issue.</p>`,
      };

    case 'SB5':
      return es ? {
        subject: `Plan actualizado a ${d.plan} — AmigosNearMe`,
        html: `<p>Hola ${d.biz_name},</p>
<p>Tu plan para <strong>${d.biz_name}</strong> fue actualizado a <strong>${d.plan}</strong>. El cambio es efectivo de inmediato.</p>`,
      } : {
        subject: `Plan upgraded to ${d.plan} — AmigosNearMe`,
        html: `<p>Hi ${d.biz_name},</p>
<p>Your plan for <strong>${d.biz_name}</strong> has been upgraded to <strong>${d.plan}</strong>. Changes are effective immediately.</p>`,
      };

    case 'SB6':
      return es ? {
        subject: `📲 Un cliente intentó contactarte por WhatsApp — ${d.biz_name}`,
        html: `<p>Hola ${d.biz_name},</p>
<p>Un cliente encontró tu negocio en AmigosNearMe y abrió WhatsApp para contactarte.</p>
<p>Responde rápido — los negocios que contestan pronto consiguen más clientes.</p>
<p><a href="https://amigosnearme.com/dashboard.html">Ver mi panel →</a></p>`,
      } : {
        subject: `📲 A customer tried to reach you on WhatsApp — ${d.biz_name}`,
        html: `<p>Hi ${d.biz_name},</p>
<p>A customer found your listing on AmigosNearMe and opened WhatsApp to contact you.</p>
<p>Make sure to respond quickly — fast replies lead to more jobs.</p>
<p><a href="https://amigosnearme.com/dashboard.html">View your dashboard →</a></p>`,
      };

    case 'SB7':
      return es ? {
        subject: `📋 Nueva solicitud para ${d.biz_name} — AmigosNearMe`,
        html: `<p>Hola ${d.biz_name},</p>
<p>Tienes una nueva solicitud:</p>
<ul>
  <li><strong>Nombre:</strong> ${d.customer_name}</li>
  <li><strong>Teléfono:</strong> ${d.customer_phone}</li>
  <li><strong>Servicio:</strong> ${d.service}</li>
</ul>
<p>Contáctalo directamente o revísalo en tu <a href="https://amigosnearme.com/dashboard.html">panel de control</a>.</p>`,
      } : {
        subject: `📋 New inquiry for ${d.biz_name} — AmigosNearMe`,
        html: `<p>Hi ${d.biz_name},</p>
<p>You have a new inquiry:</p>
<ul>
  <li><strong>Name:</strong> ${d.customer_name}</li>
  <li><strong>Phone:</strong> ${d.customer_phone}</li>
  <li><strong>Service:</strong> ${d.service}</li>
</ul>
<p>Contact them directly or view it in your <a href="https://amigosnearme.com/dashboard.html">dashboard</a>.</p>`,
      };

    case 'SB8':
      return es ? {
        subject: `⚠️ Casi alcanzas tu límite de contactos — ${d.biz_name}`,
        html: `<p>Hola ${d.biz_name},</p>
<p>Tu plan <strong>${d.plan}</strong> para <strong>${d.biz_name}</strong> solo tiene <strong>${d.remaining} contacto(s) restante(s)</strong> este mes.</p>
<p><a href="https://amigosnearme.com/dashboard.html#plan">Actualiza tu plan para seguir recibiendo clientes →</a></p>`,
      } : {
        subject: `⚠️ Contact limit almost reached — ${d.biz_name}`,
        html: `<p>Hi ${d.biz_name},</p>
<p>Your <strong>${d.plan}</strong> plan for <strong>${d.biz_name}</strong> has <strong>${d.remaining} contact(s) remaining</strong> this month.</p>
<p><a href="https://amigosnearme.com/dashboard.html#plan">Upgrade now to keep receiving inquiries →</a></p>`,
      };

    case 'SB9':
      return es ? {
        subject: `🚫 Límite mensual de contactos alcanzado — ${d.biz_name}`,
        html: `<p>Hola ${d.biz_name},</p>
<p>Tu plan <strong>${d.plan}</strong> alcanzó el límite mensual de contactos. Los nuevos clientes no podrán contactarte hasta el próximo mes o hasta que actualices tu plan.</p>
<p><a href="https://amigosnearme.com/dashboard.html#plan">Actualizar para recibir contactos de inmediato →</a></p>`,
      } : {
        subject: `🚫 Monthly contact limit reached — ${d.biz_name}`,
        html: `<p>Hi ${d.biz_name},</p>
<p>Your <strong>${d.plan}</strong> plan has reached its monthly contact limit. New customers cannot reach you until next month or until you upgrade.</p>
<p><a href="https://amigosnearme.com/dashboard.html#plan">Upgrade to receive contacts immediately →</a></p>`,
      };

    case 'SB10':
      return es ? {
        subject: 'Tu cuenta ha sido suspendida — AmigosNearMe',
        html: `<p>Hola ${d.biz_name},</p>
<p>Tu cuenta para <strong>${d.biz_name}</strong> ha sido suspendida.</p>
<p><strong>Motivo:</strong> ${d.reason || 'Violación de los términos de servicio.'}</p>
<p>Contacta a soporte para apelar: <a href="mailto:support@amigosnearme.com">support@amigosnearme.com</a></p>`,
      } : {
        subject: 'Your account has been suspended — AmigosNearMe',
        html: `<p>Hi ${d.biz_name},</p>
<p>Your account for <strong>${d.biz_name}</strong> has been suspended.</p>
<p><strong>Reason:</strong> ${d.reason || 'Violation of terms of service.'}</p>
<p>Contact support to appeal: <a href="mailto:support@amigosnearme.com">support@amigosnearme.com</a></p>`,
      };

    case 'SB11':
      return es ? {
        subject: 'Cuenta eliminada — AmigosNearMe',
        html: `<p>Hola ${d.biz_name},</p>
<p>Tu cuenta para <strong>${d.biz_name}</strong> ha sido eliminada permanentemente según tu solicitud.</p>
<p>Gracias por usar AmigosNearMe.</p>`,
      } : {
        subject: 'Account deleted — AmigosNearMe',
        html: `<p>Hi ${d.biz_name},</p>
<p>Your account for <strong>${d.biz_name}</strong> has been permanently deleted as requested.</p>
<p>Thank you for using AmigosNearMe.</p>`,
      };

    case 'SB12':
      return es ? {
        subject: `⚠️ Perdiste un contacto de cliente — ${d.biz_name}`,
        html: `<p>Hola ${d.biz_name},</p>
<p>Un cliente intentó contactar a <strong>${d.biz_name}</strong>, pero no pudo porque los créditos de tu <strong>${d.plan || 'plan actual'}</strong> se han agotado.</p>
<p><a href="https://amigosnearme.com/dashboard.html#plan">Actualiza ahora para no perder más clientes →</a></p>`,
      } : {
        subject: `⚠️ You missed a customer contact — ${d.biz_name}`,
        html: `<p>Hi ${d.biz_name},</p>
<p>A customer tried to contact <strong>${d.biz_name}</strong> but could not because your <strong>${d.plan || 'current plan'}</strong> credits have been used up.</p>
<p><a href="https://amigosnearme.com/dashboard.html#plan">Upgrade now to avoid missing more →</a></p>`,
      };

    case 'SB13':
      return es ? {
        subject: 'Este negocio no acepta contactos en este momento',
        html: `<p>Hola ${d.name || 'ahí'},</p>
<p><strong>${d.biz_name}</strong> alcanzó su límite mensual de contactos en AmigosNearMe. Podrán recibir contactos nuevamente el próximo mes.</p>
<p><a href="https://amigosnearme.com/search.html">Buscar otros negocios →</a></p>`,
      } : {
        subject: 'This business is not accepting contacts right now',
        html: `<p>Hi ${d.name || 'there'},</p>
<p><strong>${d.biz_name}</strong> has reached its monthly contact limit on AmigosNearMe. They will be able to receive contacts again next month.</p>
<p><a href="https://amigosnearme.com/search.html">Find other businesses →</a></p>`,
      };

    // ── Step 2: Plan downgrade scheduled (SB14) ───────────────
    case 'SB14':
      return es ? {
        subject: `Cambio de plan programado — AmigosNearMe`,
        html: `<p>Hola ${d.biz_name},</p>
<p>Tu plan para <strong>${d.biz_name}</strong> cambiará a <strong>${d.plan}</strong> el <strong>${d.effective_date}</strong>.</p>
<p>Hasta esa fecha seguirás con tu plan actual. Puedes cancelar el cambio en cualquier momento desde tu <a href="https://amigosnearme.com/dashboard.html">panel de control</a>.</p>`,
      } : {
        subject: `Plan change scheduled — AmigosNearMe`,
        html: `<p>Hi ${d.biz_name},</p>
<p>Your plan for <strong>${d.biz_name}</strong> will change to <strong>${d.plan}</strong> on <strong>${d.effective_date}</strong>.</p>
<p>Until then, you'll keep your current plan. You can cancel this change anytime from your <a href="https://amigosnearme.com/dashboard.html">dashboard</a>.</p>`,
      };

    case 'SB16':
      return es ? {
        subject: `⭐ Nueva reseña en ${d.biz_name} — AmigosNearMe`,
        html: `<p>Hola ${d.biz_name},</p>
<p>Un cliente dejó una nueva reseña en tu perfil:</p>
<ul>
  <li><strong>Calificación:</strong> ${'★'.repeat(d.rating || 0)}${'☆'.repeat(5 - (d.rating || 0))} (${d.rating}/5)</li>
  <li><strong>Comentario:</strong> ${d.review_text || '(sin comentario)'}</li>
</ul>
<p>Si consideras que esta reseña viola nuestras políticas, puedes reportarla desde tu panel de control.</p>
<p><a href="https://amigosnearme.com/dashboard.html" style="display:inline-block;padding:10px 20px;background:#2d7a4f;color:#fff;border-radius:6px;text-decoration:none;font-weight:600">Ver en mi panel →</a></p>`,
      } : {
        subject: `⭐ New review on ${d.biz_name} — AmigosNearMe`,
        html: `<p>Hi ${d.biz_name},</p>
<p>A customer left a new review on your profile:</p>
<ul>
  <li><strong>Rating:</strong> ${'★'.repeat(d.rating || 0)}${'☆'.repeat(5 - (d.rating || 0))} (${d.rating}/5)</li>
  <li><strong>Comment:</strong> ${d.review_text || '(no comment)'}</li>
</ul>
<p>If you believe this review violates our policies, you can report it from your dashboard.</p>
<p><a href="https://amigosnearme.com/dashboard.html" style="display:inline-block;padding:10px 20px;background:#2d7a4f;color:#fff;border-radius:6px;text-decoration:none;font-weight:600">View in my dashboard →</a></p>`,
      };

    case 'SB17':
      return es ? {
        subject: `🗑️ Reseña eliminada en ${d.biz_name} — AmigosNearMe`,
        html: `<p>Hola ${d.biz_name},</p>
<p>Una reseña que reportaste ha sido revisada y <strong>eliminada</strong> por nuestro equipo de moderación.</p>
<ul>
  <li><strong>Calificación original:</strong> ${d.rating}/5</li>
  <li><strong>Motivo de eliminación:</strong> ${d.reason || 'Violación de políticas de la plataforma'}</li>
</ul>
<p>Gracias por ayudarnos a mantener la calidad de las reseñas en AmigosNearMe.</p>`,
      } : {
        subject: `🗑️ Review removed on ${d.biz_name} — AmigosNearMe`,
        html: `<p>Hi ${d.biz_name},</p>
<p>A review you reported has been reviewed and <strong>removed</strong> by our moderation team.</p>
<ul>
  <li><strong>Original rating:</strong> ${d.rating}/5</li>
  <li><strong>Reason for removal:</strong> ${d.reason || 'Violation of platform policies'}</li>
</ul>
<p>Thank you for helping us maintain the quality of reviews on AmigosNearMe.</p>`,
      };

    case 'SB15':
      return es ? {
        subject: `Verifica tu nuevo correo — AmigosNearMe`,
        html: `<p>Hola ${d.biz_name},</p>
<p>Recibimos una solicitud para cambiar el correo público de tu negocio a <strong>${d.new_email}</strong>.</p>
<p>Haz clic en el botón de abajo para confirmar este cambio:</p>
<p><a href="${d.verify_url}" style="display:inline-block;padding:10px 20px;background:#2d7a4f;color:#fff;border-radius:6px;text-decoration:none;font-weight:600">Verificar correo</a></p>
<p>Si no solicitaste este cambio, ignora este mensaje. Tu correo actual permanecerá sin cambios.</p>`,
      } : {
        subject: `Verify your new email — AmigosNearMe`,
        html: `<p>Hi ${d.biz_name},</p>
<p>We received a request to change your business public email to <strong>${d.new_email}</strong>.</p>
<p>Click the button below to confirm this change:</p>
<p><a href="${d.verify_url}" style="display:inline-block;padding:10px 20px;background:#2d7a4f;color:#fff;border-radius:6px;text-decoration:none;font-weight:600">Verify email</a></p>
<p>If you did not request this change, ignore this message. Your current email will remain unchanged.</p>`,
      };

    // ══ Worker ════════════════════════════════════════════════

    case 'W1':
      return es ? {
        subject: 'Tu perfil de trabajador está activo — AmigosNearMe',
        html: `<p>Hola ${d.worker_name},</p>
<p>Tu perfil ya está activo y visible para empresas que buscan trabajadores. Mantén tu WhatsApp activo para que los empleadores puedan contactarte.</p>`,
      } : {
        subject: 'Your worker profile is live — AmigosNearMe',
        html: `<p>Hi ${d.worker_name},</p>
<p>Your profile is now live and searchable by businesses looking for workers. Keep your WhatsApp active so employers can reach you.</p>`,
      };

    case 'W2':
      return es ? {
        subject: '📲 Un empleador quiere contratarte — AmigosNearMe',
        html: `<p>Hola ${d.worker_name},</p>
<p>Una empresa encontró tu perfil en AmigosNearMe y te está contactando por WhatsApp. ¡Revisa tus mensajes!</p>`,
      } : {
        subject: '📲 An employer wants to hire you — AmigosNearMe',
        html: `<p>Hi ${d.worker_name},</p>
<p>A business found your profile on AmigosNearMe and is reaching out to you via WhatsApp. Check your messages!</p>`,
      };

    case 'W5':
      return es ? {
        subject: '📩 Un empleador te ha enviado un mensaje — AmigosNearMe',
        html: `<p>Hola ${d.worker_name},</p>
<p>Un empleador encontró tu perfil en AmigosNearMe y te envió el siguiente mensaje:</p>
<blockquote style="border-left:3px solid #ccc;padding:8px 16px;margin:12px 0;color:#444">
  <p><strong>Nombre:</strong> ${d.sender_name || 'N/A'}</p>
  <p><strong>Teléfono:</strong> ${d.sender_phone || 'N/A'}</p>
  <p><strong>Mensaje:</strong> ${d.message || ''}</p>
</blockquote>
<p>Responde directamente a este empleador para coordinar los detalles.</p>`,
      } : {
        subject: '📩 An employer sent you a message — AmigosNearMe',
        html: `<p>Hi ${d.worker_name},</p>
<p>An employer found your profile on AmigosNearMe and sent you the following message:</p>
<blockquote style="border-left:3px solid #ccc;padding:8px 16px;margin:12px 0;color:#444">
  <p><strong>Name:</strong> ${d.sender_name || 'N/A'}</p>
  <p><strong>Phone:</strong> ${d.sender_phone || 'N/A'}</p>
  <p><strong>Message:</strong> ${d.message || ''}</p>
</blockquote>
<p>Reply directly to this employer to coordinate details.</p>`,
      };

    case 'W7':
      return es ? {
        subject: 'Una reseña en tu perfil fue eliminada — AmigosNearMe',
        html: `<p>Hola ${d.worker_name},</p>
<p>Una reseña en tu perfil de AmigosNearMe fue eliminada por nuestro equipo de moderación.</p>
<ul>
  <li><strong>Calificación eliminada:</strong> ${'★'.repeat(d.rating)}${'☆'.repeat(5 - d.rating)} (${d.rating}/5)</li>
  <li><strong>Motivo:</strong> ${d.reason}</li>
</ul>
<p>Si tienes preguntas, contáctanos en <a href="mailto:support@amigosnearme.com">support@amigosnearme.com</a>.</p>`,
      } : {
        subject: 'A review on your profile was removed — AmigosNearMe',
        html: `<p>Hi ${d.worker_name},</p>
<p>A review on your AmigosNearMe profile has been removed by our moderation team.</p>
<ul>
  <li><strong>Removed rating:</strong> ${'★'.repeat(d.rating)}${'☆'.repeat(5 - d.rating)} (${d.rating}/5)</li>
  <li><strong>Reason:</strong> ${d.reason}</li>
</ul>
<p>If you have questions, contact us at <a href="mailto:support@amigosnearme.com">support@amigosnearme.com</a>.</p>`,
      };

    case 'W3':
      return es ? {
        subject: 'Tu perfil de trabajador ha sido suspendido — AmigosNearMe',
        html: `<p>Hola ${d.worker_name},</p>
<p>Tu perfil ha sido suspendido. <strong>Motivo:</strong> ${d.reason || 'Violación de los términos de servicio.'}</p>
<p>Contacta a <a href="mailto:support@amigosnearme.com">support@amigosnearme.com</a> para apelar.</p>`,
      } : {
        subject: 'Your worker profile has been suspended — AmigosNearMe',
        html: `<p>Hi ${d.worker_name},</p>
<p>Your profile has been suspended. <strong>Reason:</strong> ${d.reason || 'Terms of service violation.'}</p>
<p>Contact <a href="mailto:support@amigosnearme.com">support@amigosnearme.com</a> to appeal.</p>`,
      };

    case 'W4':
      return es ? {
        subject: 'Perfil de trabajador eliminado — AmigosNearMe',
        html: `<p>Hola ${d.worker_name},</p><p>Tu perfil de trabajador ha sido eliminado según tu solicitud.</p>`,
      } : {
        subject: 'Worker profile deleted — AmigosNearMe',
        html: `<p>Hi ${d.worker_name},</p><p>Your worker profile has been deleted as requested.</p>`,
      };

    // ══ Customer ══════════════════════════════════════════════

    case 'CU1':
      return es ? {
        subject: 'Bienvenido a AmigosNearMe',
        html: `<p>Hola ${d.name},</p>
<p>Gracias por unirte a AmigosNearMe. Ya puedes buscar negocios y dejar reseñas.</p>
<p><a href="https://amigosnearme.com/search.html">Encuentra negocios cerca de ti →</a></p>`,
      } : {
        subject: 'Welcome to AmigosNearMe',
        html: `<p>Hi ${d.name},</p>
<p>Thanks for joining AmigosNearMe. You can now search businesses and leave reviews.</p>
<p><a href="https://amigosnearme.com/search.html">Find businesses near you →</a></p>`,
      };

    case 'CU3':
      return es ? {
        subject: 'Tu solicitud fue enviada — AmigosNearMe',
        html: `<p>Hola ${d.name || 'ahí'},</p>
<p>Tu solicitud de <strong>${d.service}</strong> fue enviada a <strong>${d.biz_name}</strong>. Te contactarán al número <strong>${d.customer_phone}</strong> en breve.</p>`,
      } : {
        subject: 'Your inquiry was sent — AmigosNearMe',
        html: `<p>Hi ${d.name || 'there'},</p>
<p>Your inquiry for <strong>${d.service}</strong> was sent to <strong>${d.biz_name}</strong>. They'll contact you at <strong>${d.customer_phone}</strong> shortly.</p>`,
      };

    case 'CU4':
      return {
        subject: `Account ${d.action} / Cuenta ${d.action} — AmigosNearMe`,
        html: `<p>Hi ${d.name || 'there'},</p>
<p>Your AmigosNearMe account has been <strong>${d.action}</strong>.</p>
${d.reason ? `<p><strong>Reason:</strong> ${d.reason}</p>` : ''}
<hr style="margin:24px 0;border:none;border-top:1px solid #eee">
<p>Hola ${d.name || 'ahí'},</p>
<p>Tu cuenta de AmigosNearMe ha sido <strong>${d.action}</strong>.</p>
${d.reason ? `<p><strong>Motivo:</strong> ${d.reason}</p>` : ''}`,
      };

    // ══ Employer ══════════════════════════════════════════════

    case 'EM1':
      return es ? {
        subject: 'Bienvenido a AmigosNearMe — Encuentra trabajadores',
        html: `<p>Hola ${d.name},</p>
<p>Tu cuenta de empleador está lista. Busca trabajadores disponibles y usa créditos de contacto para comunicarte por WhatsApp.</p>
<p><a href="https://amigosnearme.com/search.html?mode=workers">Buscar trabajadores →</a></p>`,
      } : {
        subject: 'Welcome to AmigosNearMe — Find Workers',
        html: `<p>Hi ${d.name},</p>
<p>Your employer account is ready. Search for available workers and use contact credits to reach them via WhatsApp.</p>
<p><a href="https://amigosnearme.com/search.html?mode=workers">Find workers →</a></p>`,
      };

    case 'EM2':
      return es ? {
        subject: `${d.credits} créditos de contacto agregados — AmigosNearMe`,
        html: `<p>Hola ${d.name},</p>
<p>Ahora tienes <strong>${d.credits} créditos de contacto</strong>. Úsalos para contactar trabajadores directamente por WhatsApp.</p>`,
      } : {
        subject: `${d.credits} contact credits added — AmigosNearMe`,
        html: `<p>Hi ${d.name},</p>
<p>You now have <strong>${d.credits} contact credits</strong>. Use them to reach workers directly on WhatsApp.</p>`,
      };

    case 'EM3':
      return es ? {
        subject: '⚠️ Solo te queda 1 crédito de contacto — AmigosNearMe',
        html: `<p>Hola ${d.name},</p>
<p>Te queda <strong>1 crédito de contacto</strong>. Compra más para seguir contratando trabajadores.</p>
<p><a href="https://amigosnearme.com/search.html?mode=workers">Comprar créditos →</a></p>`,
      } : {
        subject: '⚠️ Only 1 contact credit remaining — AmigosNearMe',
        html: `<p>Hi ${d.name},</p>
<p>You have <strong>1 contact credit</strong> left. Purchase more to keep hiring workers.</p>
<p><a href="https://amigosnearme.com/search.html?mode=workers">Buy credits →</a></p>`,
      };

    case 'EM4':
      return es ? {
        subject: '🚫 Sin créditos de contacto — AmigosNearMe',
        html: `<p>Hola ${d.name},</p>
<p>Usaste todos tus créditos de contacto. Compra un nuevo paquete para seguir contactando trabajadores.</p>
<p><a href="https://amigosnearme.com/search.html?mode=workers">Comprar créditos →</a></p>`,
      } : {
        subject: '🚫 No contact credits remaining — AmigosNearMe',
        html: `<p>Hi ${d.name},</p>
<p>You've used all your contact credits. Purchase a new package to continue contacting workers.</p>
<p><a href="https://amigosnearme.com/search.html?mode=workers">Buy credits →</a></p>`,
      };

    case 'EM5':
      return es ? {
        subject: `Cuenta de empleador ${d.action} — AmigosNearMe`,
        html: `<p>Hola ${d.name || 'ahí'},</p>
<p>Tu cuenta de empleador ha sido <strong>${d.action}</strong>.</p>
${d.reason ? `<p><strong>Motivo:</strong> ${d.reason}</p>` : ''}`,
      } : {
        subject: `Employer account ${d.action} — AmigosNearMe`,
        html: `<p>Hi ${d.name || 'there'},</p>
<p>Your employer account has been <strong>${d.action}</strong>.</p>
${d.reason ? `<p><strong>Reason:</strong> ${d.reason}</p>` : ''}`,
      };

    case 'EM7':
      return es ? {
        subject: 'Cuenta eliminada — AmigosNearMe',
        html: `<p>Hola ${d.name || 'ahí'},</p>
<p>Tu cuenta de empleador para <strong>${d.email || ''}</strong> ha sido eliminada permanentemente según tu solicitud.</p>
<p>Gracias por usar AmigosNearMe.</p>`,
      } : {
        subject: 'Account deleted — AmigosNearMe',
        html: `<p>Hi ${d.name || 'there'},</p>
<p>Your employer account for <strong>${d.email || ''}</strong> has been permanently deleted as requested.</p>
<p>Thank you for using AmigosNearMe.</p>`,
      };

    case 'EM6':
      return es ? {
        subject: 'Necesitas créditos para contactar este trabajador — AmigosNearMe',
        html: `<p>Hola ${d.name},</p>
<p>Intentaste contactar un trabajador pero no tienes créditos disponibles. Compra un paquete para continuar.</p>
<p><a href="https://amigosnearme.com/search.html?mode=workers">Comprar créditos →</a></p>`,
      } : {
        subject: 'You need credits to contact this worker — AmigosNearMe',
        html: `<p>Hi ${d.name},</p>
<p>You tried to contact a worker but have no credits left. Purchase a package to continue.</p>
<p><a href="https://amigosnearme.com/search.html?mode=workers">Buy credits →</a></p>`,
      };

    case 'SB_ZELLE_REQ':
      return es ? {
        subject: 'Recibimos tu solicitud de pago Zelle — AmigosNearMe',
        html: `<p>Hola ${d.biz_name || 'ahí'},</p>
<p>Recibimos tu solicitud de activación de plan <strong>${d.plan_name || ''}</strong> vía Zelle.</p>
<p>Nuestro equipo verificará tu pago y activará tu plan dentro de las próximas <strong>24 horas hábiles</strong>.</p>
<p>Si ya enviaste el pago a <strong>pagos@amigosnearme.com</strong>, no necesitas hacer nada más.</p>
<p>¿Preguntas? Contáctanos por <a href="https://wa.me/17862388827">WhatsApp +1 (786) 238-8827</a>.</p>`,
      } : {
        subject: 'We received your Zelle payment request — AmigosNearMe',
        html: `<p>Hi ${d.biz_name || 'there'},</p>
<p>We received your <strong>${d.plan_name || ''}</strong> plan activation request via Zelle.</p>
<p>Our team will verify your payment and activate your plan within <strong>24 business hours</strong>.</p>
<p>If you already sent the payment to <strong>pagos@amigosnearme.com</strong>, no further action is needed.</p>
<p>Questions? Contact us on <a href="https://wa.me/17862388827">WhatsApp +1 (786) 238-8827</a>.</p>`,
      };

    case 'ADMIN_ZELLE': {
      const payMethod = d.payment_method || 'Zelle';
      return {
        subject: `[Admin] ${payMethod} payment pending — ${d.biz_name} (${d.plan_name})`,
        html: `<p>A business has submitted a manual payment and is awaiting confirmation.</p>
<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse;font-size:14px">
  <tr><td><strong>Name</strong></td><td>${d.biz_name || '—'}</td></tr>
  <tr><td><strong>Email</strong></td><td>${d.owner_email || '—'}</td></tr>
  <tr><td><strong>Plan</strong></td><td>${d.plan_name || '—'}</td></tr>
  <tr><td><strong>Amount</strong></td><td>${d.amount || '—'}</td></tr>
  <tr><td><strong>Payment Method</strong></td><td>${payMethod}</td></tr>
  <tr><td><strong>Submitted</strong></td><td>${d.submitted_at || '—'}</td></tr>
</table>
<p style="margin-top:16px">Please verify the payment and confirm in the <a href="https://amigosnearme.com/admin.html">Admin console → Payment Pending</a>.</p>`,
      };
    }

    // ══ Admin (항상 영문) ══════════════════════════════════════

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
        subject: `[Admin] ⭐ ${d.rating}-star review posted — ${d.biz_name}`,
        html: `<p>A low-rating review was posted:</p>
<ul>
  <li><strong>Business:</strong> ${d.biz_name}</li>
  <li><strong>Rating:</strong> ${d.rating} / 5</li>
  <li><strong>Reviewer:</strong> ${d.reviewer_email || 'Anonymous'}</li>
  <li><strong>Review:</strong> "${d.review_text}"</li>
</ul>
<p><a href="https://amigosnearme.com/admin.html#reviews">Review in admin console →</a></p>`,
      };

    case 'W6':
      return es ? {
        subject: '⭐ Recibiste una nueva reseña — AmigosNearMe',
        html: `<p>Hola ${d.worker_name},</p>
<p>Alguien dejó una reseña en tu perfil de AmigosNearMe.</p>
<ul>
  <li><strong>Calificación:</strong> ${'★'.repeat(d.rating)}${'☆'.repeat(5 - d.rating)} (${d.rating}/5)</li>
  ${d.review_text ? `<li><strong>Comentario:</strong> "${d.review_text}"</li>` : ''}
</ul>
<p><a href="https://amigosnearme.com/worker-profile.html?id=${d.worker_id}">Ver mi perfil →</a></p>`,
      } : {
        subject: '⭐ You received a new review — AmigosNearMe',
        html: `<p>Hi ${d.worker_name},</p>
<p>Someone left a review on your AmigosNearMe profile.</p>
<ul>
  <li><strong>Rating:</strong> ${'★'.repeat(d.rating)}${'☆'.repeat(5 - d.rating)} (${d.rating}/5)</li>
  ${d.review_text ? `<li><strong>Comment:</strong> "${d.review_text}"</li>` : ''}
</ul>
<p><a href="https://amigosnearme.com/worker-profile.html?id=${d.worker_id}">View my profile →</a></p>`,
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

    // ══ Security ══════════════════════════════════════════════

    case 'SEC1':
      return es ? {
        subject: '🔒 Tu contraseña fue cambiada — AmigosNearMe',
        html: `<p>Hola,</p>
<p>Tu contraseña de AmigosNearMe fue cambiada el <strong>${d.changed_at || new Date().toUTCString()}</strong>.</p>
<p>Si no realizaste este cambio, contáctanos de inmediato por <a href="https://wa.me/17862388827">WhatsApp +1 (786) 238-8827</a>.</p>`,
      } : {
        subject: '🔒 Your password was changed — AmigosNearMe',
        html: `<p>Hi,</p>
<p>Your AmigosNearMe password was successfully changed on <strong>${d.changed_at || new Date().toUTCString()}</strong>.</p>
<p>If you did not make this change, contact us immediately on <a href="https://wa.me/17862388827">WhatsApp +1 (786) 238-8827</a>.</p>`,
      };

    case 'SEC2':
      return es ? {
        subject: '🔒 Restablece tu contraseña — AmigosNearMe',
        html: `<p>Hola,</p>
<p>Recibimos una solicitud para restablecer la contraseña de tu cuenta de AmigosNearMe.</p>
${d.reset_link ? `<p style="margin:20px 0"><a href="${d.reset_link}" style="background:#C94F2B;color:#fff;padding:12px 24px;border-radius:6px;text-decoration:none;font-weight:600">Restablecer contraseña →</a></p>
<p style="font-size:12px;color:#888">Si el botón no funciona, copia y pega este enlace en tu navegador:<br>${d.reset_link}</p>` : ''}
<p>Si no solicitaste este cambio, puedes ignorar este correo. Tu contraseña no cambiará.</p>
<p>¿Necesitas ayuda? Contáctanos por <a href="https://wa.me/17862388827">WhatsApp +1 (786) 238-8827</a>.</p>`,
      } : {
        subject: '🔒 Reset your password — AmigosNearMe',
        html: `<p>Hi,</p>
<p>We received a request to reset the password for your AmigosNearMe account.</p>
${d.reset_link ? `<p style="margin:20px 0"><a href="${d.reset_link}" style="background:#C94F2B;color:#fff;padding:12px 24px;border-radius:6px;text-decoration:none;font-weight:600">Reset password →</a></p>
<p style="font-size:12px;color:#888">If the button doesn't work, copy and paste this link into your browser:<br>${d.reset_link}</p>` : ''}
<p>If you didn't request this, you can safely ignore this email. Your password won't change.</p>
<p>Need help? Contact us on <a href="https://wa.me/17862388827">WhatsApp +1 (786) 238-8827</a>.</p>`,
      };

    // ══ 7-Day Upgrade Nudge ════════════════════════════════════

    case 'B7':
      return es ? {
        subject: `Ya llevas 7 días — esto es lo que desbloquea el plan Basic — AmigosNearMe`,
        html: `<p>Hola ${d.biz_name || 'ahí'},</p>
<p>Llevas 7 días en AmigosNearMe. El plan Gratis te da 3 contactos de clientes al mes.</p>
<p><strong>Basic ($29/mes)</strong> te da 10 contactos y la insignia ⭐ Basic que genera más confianza.</p>
<p><a href="https://amigosnearme.com/dashboard.html#plan">Actualizar ahora →</a></p>`,
      } : {
        subject: `You've had 7 days — here's what Basic unlocks — AmigosNearMe`,
        html: `<p>Hi ${d.biz_name || 'there'},</p>
<p>It's been 7 days since you listed your business on AmigosNearMe. Free plan gives you 3 customer contacts per month.</p>
<p><strong>Basic ($29/mo)</strong> gives you 10 contacts and a ⭐ Basic badge that builds trust with customers.</p>
<p><a href="https://amigosnearme.com/dashboard.html#plan">Upgrade now →</a></p>`,
      };

    default:
      return null;
  }
}

// ── CORS 헤더 ──────────────────────────────────────────────────
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

// ── 메인 핸들러 ────────────────────────────────────────────────
serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const { scenario, data, to, ref_id, lang } = await req.json() as {
      scenario: string;
      data: Record<string, string>;
      to: string;
      ref_id?: string;
      lang?: string;       // 'es' | 'en' — 없으면 'es' 기본값
    };

    const isAdminScenario = ['AD1','AD2','AD3','AD4','ADMIN_ZELLE'].includes(scenario);

    // `to` 없고 ref_id가 UUID이면 auth.users에서 이메일 조회
    let resolvedTo = to;
    if (!resolvedTo && !isAdminScenario && ref_id) {
      const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (UUID_RE.test(ref_id)) {
        const { data: userRes } = await sb.auth.admin.getUserById(ref_id);
        if (userRes?.user?.email) resolvedTo = userRes.user.email;
      }
    }

    if (!scenario || (!resolvedTo && !isAdminScenario)) {
      return jsonResponse({ error: 'scenario and to are required' }, 400);
    }

    // 중복 발송 방지
    if (ref_id && await alreadySent(scenario, ref_id)) {
      return jsonResponse({ skipped: true, reason: 'already_sent' });
    }

    const recipient = isAdminScenario ? ADMIN_EMAIL : resolvedTo;

    // Admin은 항상 영문, 그 외는 전달된 lang 사용 (기본: 'es')
    const effectiveLang = isAdminScenario ? 'en' : (lang ?? 'es');

    const tmpl = templates(scenario, data, effectiveLang);
    if (!tmpl) {
      return jsonResponse({ error: `Unknown scenario: ${scenario}` }, 400);
    }

    await sendEmail(recipient, tmpl.subject, tmpl.html);
    if (ref_id) await logEmail(scenario, recipient, ref_id);

    return jsonResponse({ ok: true, scenario, to: recipient, lang: effectiveLang });

  } catch (err) {
    console.error('send-email error:', err);
    return jsonResponse({ error: String(err) }, 500);
  }
});
