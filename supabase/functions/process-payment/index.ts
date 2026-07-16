// AmigosNearMe — Supabase Edge Function: process-payment
// Braintree 결제 처리 + 플랜 업그레이드(SB5) + 크레딧 구매(EM2)
// 호출: supabase.functions.invoke('process-payment', { body: { action, ... } })

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
// @ts-ignore — npm: prefix is supported in Supabase Edge Functions (Deno + Node compat)
import braintree from 'npm:braintree';

const MERCHANT_ID  = Deno.env.get('BRAINTREE_MERCHANT_ID')!;
const PUBLIC_KEY   = Deno.env.get('BRAINTREE_PUBLIC_KEY')!;
const PRIVATE_KEY  = Deno.env.get('BRAINTREE_PRIVATE_KEY')!;
const BT_ENV       = Deno.env.get('BRAINTREE_ENV') ?? 'sandbox';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const PLAN_AMOUNTS: Record<string, string> = {
  basic:   '29.00',
  premium: '79.00',
};

const CREDIT_PACKAGES: Record<string, { credits: number; amount: string }> = {
  starter: { credits: 5,  amount: '10.00' },
  value:   { credits: 15, amount: '20.00' },
  pro:     { credits: 30, amount: '30.00' },
};

const gateway = new braintree.BraintreeGateway({
  environment: BT_ENV === 'production'
    ? braintree.Environment.Production
    : braintree.Environment.Sandbox,
  merchantId: MERCHANT_ID,
  publicKey:  PUBLIC_KEY,
  privateKey: PRIVATE_KEY,
});

const sb = createClient(SUPABASE_URL, SUPABASE_KEY);

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
    const body = await req.json();
    const { action } = body;

    // ── 1. 클라이언트 토큰 발급 ────────────────────────────────────
    if (action === 'client-token') {
      const { clientToken } = await gateway.clientToken.generate({});
      return json({ clientToken });
    }

    // ── 2. 결제 처리 + 플랜 업데이트 ──────────────────────────────
    if (action === 'checkout') {
      const { nonce, plan, biz_id, owner_email, owner_name, biz_name } = body;

      if (!nonce || !plan || !biz_id) {
        return json({ error: 'nonce, plan, biz_id are required' }, 400);
      }
      const amount = PLAN_AMOUNTS[plan as string];
      if (!amount) {
        return json({ error: `Invalid plan: ${plan}` }, 400);
      }

      // Braintree 결제
      const result = await gateway.transaction.sale({
        amount,
        paymentMethodNonce: nonce,
        options: { submitForSettlement: true },
      });

      if (!result.success) {
        const msg = result.transaction?.processorResponseText
          ?? result.message
          ?? 'Payment declined';
        console.error('[process-payment] Braintree declined:', msg);
        return json({ error: msg }, 402);
      }

      const txId = result.transaction.id;

      // DB 업데이트: plan 즉시 적용 + pending_plan 초기화 + contacts 리셋 (업그레이드 시)
      const { error: dbErr } = await sb
        .from('businesses')
        .update({ plan, pending_plan: null, contacts_used_month: 0 })
        .eq('id', biz_id);

      if (dbErr) {
        console.error('[process-payment] DB update failed:', dbErr.message);
        return json({ error: `DB update failed: ${dbErr.message}` }, 500);
      }

      // SB5 이메일 발송 (비차단) — businesses.languages[0] 으로 언어 감지
      if (owner_email) {
        const planLabel = (plan as string).charAt(0).toUpperCase() + (plan as string).slice(1);
        const { data: bizRow } = await sb
          .from('businesses')
          .select('languages')
          .eq('id', biz_id)
          .single();
        const lang = (bizRow?.languages?.[0] ?? 'es') === 'en' ? 'en' : 'es';
        sb.functions.invoke('send-email', {
          body: {
            scenario: 'SB5',
            to: owner_email,
            lang,
            data: {
              owner_name: owner_name || 'there',
              biz_name:   biz_name  || '',
              plan:       planLabel,
            },
            ref_id: biz_id,
          },
        }).catch((e: Error) => console.warn('[process-payment] SB5 email error:', e.message));
      }

      return json({ success: true, transaction_id: txId });
    }

    // ── 3. 크레딧 구매 ────────────────────────────────────────────
    if (action === 'buy-credits') {
      const { nonce, package_id, employer_id, owner_email, owner_name } = body;

      if (!nonce || !package_id || !employer_id) {
        return json({ error: 'nonce, package_id, employer_id are required' }, 400);
      }
      const pkg = CREDIT_PACKAGES[package_id as string];
      if (!pkg) {
        return json({ error: `Invalid package_id: ${package_id}` }, 400);
      }

      // Braintree 결제
      const result = await gateway.transaction.sale({
        amount: pkg.amount,
        paymentMethodNonce: nonce,
        options: { submitForSettlement: true },
      });

      if (!result.success) {
        const msg = result.transaction?.processorResponseText
          ?? result.message
          ?? 'Payment declined';
        console.error('[process-payment] buy-credits declined:', msg);
        return json({ error: msg }, 402);
      }

      const txId = result.transaction.id;

      // credit_balance 증가 (RPC로 atomic update)
      const { error: rpcErr } = await sb.rpc('increment_credit_balance', {
        p_employer_id: employer_id,
        p_amount: pkg.credits,
      });
      if (rpcErr) {
        console.error('[process-payment] credit_balance increment failed:', rpcErr.message);
        return json({ error: `Credit update failed: ${rpcErr.message}` }, 500);
      }

      // credit_transactions 기록
      const { error: txErr } = await sb
        .from('credit_transactions')
        .insert({
          employer_id,
          amount_usd: parseFloat(pkg.amount),
          credits_added: pkg.credits,
          payment_ref: txId,
        });
      if (txErr) {
        console.error('[process-payment] credit_transactions insert failed:', txErr.message);
        // 결제·잔액은 성공 — 로그만 남기고 계속
      }

      // EM3/EM4/EM6 dedup 초기화 — 크레딧 구매 시 이전 사이클의 경고 이메일 voided
      // 다음 소진 사이클에서 EM3/EM4/EM6 재발송 가능하도록 (§9.9 크레딧 사이클 dedup 정책)
      await sb.from('email_log')
        .update({ is_voided: true })
        .eq('recipient', owner_email)
        .in('scenario', ['EM3', 'EM4', 'EM6'])
        .eq('is_voided', false);

      // EM2 이메일 발송 (비차단)
      if (owner_email) {
        const { data: empRow } = await sb
          .from('employer_profiles')
          .select('preferred_lang')
          .eq('id', employer_id)
          .single();
        const lang = (empRow?.preferred_lang ?? 'es') === 'en' ? 'en' : 'es';
        sb.functions.invoke('send-email', {
          body: {
            scenario: 'EM2',
            to: owner_email,
            lang,
            data: {
              name:    owner_name || 'there',
              credits: pkg.credits,
            },
            ref_id: employer_id,
          },
        }).catch((e: Error) => console.warn('[process-payment] EM2 email error:', e.message));
      }

      return json({ success: true, transaction_id: txId, credits_added: pkg.credits });
    }

    return json({ error: 'Unknown action' }, 400);

  } catch (err) {
    console.error('[process-payment] Unhandled error:', err);
    return json({ error: (err as Error).message }, 500);
  }
});
