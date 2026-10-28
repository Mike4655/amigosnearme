// AmigosNearMe — Supabase Edge Function: auto-confirm-worker
// Worker 가입 직후 이메일 인증을 자동 완료시킨다 (business/employer는 수동 인증 유지)
// 호출: supabase.functions.invoke('auto-confirm-worker', { body: { user_id, email } })

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL          = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_KEY  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { user_id, email } = await req.json();

    if (!user_id || !email) {
      return new Response(JSON.stringify({ error: 'user_id and email are required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Service Role 클라이언트 (Admin API 사용)
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false }
    });

    // businesses 테이블에서 is_worker 확인 (보안: worker만 자동 인증)
    const { data: bizData } = await adminClient
      .from('businesses')
      .select('is_worker')
      .eq('owner_id', user_id)
      .single();

    // is_worker가 아니면 거부 (business/employer는 수동 이메일 인증 유지)
    if (!bizData || !bizData.is_worker) {
      return new Response(JSON.stringify({ error: 'Not a worker account' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Admin API로 이메일 자동 인증 완료
    const { error } = await adminClient.auth.admin.updateUserById(user_id, {
      email_confirm: true,
    });

    if (error) {
      console.error('auto-confirm error:', error);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log(`✅ Worker email auto-confirmed: ${email} (${user_id})`);
    return new Response(JSON.stringify({ success: true }), {
      status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (err) {
    console.error('auto-confirm-worker error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
