// AmigosNearMe — Supabase Edge Function: request-password-reset
// Admin API로 recovery 링크 생성 → send-email(SEC2)로 언어별 커스텀 이메일 발송
// Supabase 기본 reset 이메일을 대체 (영문 고정 문제 해결)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL      = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const SITE_URL          = Deno.env.get('SITE_URL') ?? 'https://amigosnearme.com';

const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  try {
    const { email, lang, origin } = await req.json();

    if (!email) return json({ error: 'email is required' }, 400);

    const resolvedLang = (lang === 'es') ? 'es' : 'en';
    const baseUrl      = origin || SITE_URL;
    const redirectTo   = `${baseUrl}/reset-password.html?lang=${resolvedLang}`;

    // Admin 클라이언트 (service role) — generateLink 사용을 위해 필요
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // recovery 링크 생성 (이메일 발송 없음)
    const { data, error } = await adminClient.auth.admin.generateLink({
      type: 'recovery',
      email,
      options: { redirectTo },
    });

    if (error) {
      // 계정이 없는 이메일이어도 보안상 성공 응답 (이메일 존재 여부 노출 방지)
      console.warn('[request-password-reset] generateLink error:', error.message);
      return json({ success: true });
    }

    const resetLink = data?.properties?.action_link;
    if (!resetLink) {
      console.warn('[request-password-reset] No action_link returned');
      return json({ success: true });
    }

    // SEC2 커스텀 이메일 발송 (reset link 포함)
    await adminClient.functions.invoke('send-email', {
      body: {
        scenario: 'SEC2',
        to: email,
        lang: resolvedLang,
        data: { reset_link: resetLink },
      },
    });

    return json({ success: true });

  } catch (err) {
    console.error('[request-password-reset] Unhandled error:', err);
    return json({ error: (err as Error).message }, 500);
  }
});
