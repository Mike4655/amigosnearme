// =============================================
// AmigosNearMe — Supabase Client (supabase-client.js)
// 모든 페이지에서 공통으로 사용하는 인증/DB 모듈
// =============================================

const SUPABASE_URL = 'https://itlcbqecqmenfolexkuj.supabase.co';
const SUPABASE_KEY = 'sb_publishable_2-VOhM33bU5T6F9eMNV7iw_GcVXyWPQ';

// Supabase JS v2 CDN 로드 후 초기화
let _supabase = null;

function getSupabase() {
  if (!_supabase) {
    _supabase = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
  }
  return _supabase;
}

// =============================================
// AUTH — 회원가입
// =============================================
async function signUp({ email, password, userType, businessName }) {
  const sb = getSupabase();
  const { data, error } = await sb.auth.signUp({
    email,
    password,
    options: {
      data: {
        user_type: userType,       // 'business' | 'worker' | 'customer'
        business_name: businessName || ''
      }
    }
  });
  if (error) throw error;
  return data;
}

// =============================================
// AUTH — 로그인
// =============================================
async function signIn({ email, password }) {
  const sb = getSupabase();
  const { data, error } = await sb.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

// =============================================
// AUTH — 로그아웃
// =============================================
async function signOut() {
  const sb = getSupabase();
  const { error } = await sb.auth.signOut();
  if (error) throw error;
}

// =============================================
// AUTH — 현재 세션/유저 가져오기
// =============================================
async function getSession() {
  const sb = getSupabase();
  const { data: { session } } = await sb.auth.getSession();
  return session;
}

async function getCurrentUser() {
  const sb = getSupabase();
  const { data: { user } } = await sb.auth.getUser();
  return user;
}

// =============================================
// AUTH — 세션 변경 리스너
// =============================================
function onAuthChange(callback) {
  const sb = getSupabase();
  sb.auth.onAuthStateChange((_event, session) => {
    callback(session);
  });
}

// =============================================
// DB — 업체 프로필 가져오기
// =============================================
async function getMyBusiness() {
  const sb = getSupabase();
  const user = await getCurrentUser();
  if (!user) return null;

  const { data, error } = await sb
    .from('businesses')
    .select('*')
    .eq('owner_id', user.id)
    .single();

  if (error && error.code !== 'PGRST116') throw error;
  return data;
}

// =============================================
// DB — 업체 프로필 생성
// =============================================
async function createBusiness({ businessName, tradeName, plan = 'free' }) {
  const sb = getSupabase();
  const user = await getCurrentUser();
  if (!user) throw new Error('Not authenticated');

  const { data, error } = await sb
    .from('businesses')
    .insert({
      owner_id: user.id,
      business_name: businessName,
      trade_name: tradeName || '',
      plan
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

// =============================================
// DB — 업체 프로필 업데이트
// =============================================
async function updateBusiness(updates) {
  const sb = getSupabase();
  const user = await getCurrentUser();
  if (!user) throw new Error('Not authenticated');

  const { data, error } = await sb
    .from('businesses')
    .update(updates)
    .eq('owner_id', user.id)
    .select()
    .single();

  if (error) throw error;
  return data;
}

// =============================================
// DB — 비즈니스 목록 (검색용, 공개)
// =============================================
async function searchBusinesses({ category, query, limit = 20 } = {}) {
  const sb = getSupabase();
  let q = sb
    .from('businesses')
    .select('*')
    .eq('verified', true)
    .limit(limit);

  if (category) q = q.contains('categories', [category]);
  if (query) q = q.ilike('business_name', `%${query}%`);

  const { data, error } = await q;
  if (error) throw error;
  return data;
}

// =============================================
// HELPER — userType 판별
// =============================================
async function getUserType() {
  const user = await getCurrentUser();
  if (!user) return null;
  return user.user_metadata?.user_type || 'customer';
}

// =============================================
// HELPER — 로그인 상태 확인 후 리디렉션
// =============================================
async function requireAuth(redirectTo = 'login.html') {
  const session = await getSession();
  if (!session) {
    window.location.href = redirectTo;
    return false;
  }
  return true;
}

async function redirectIfLoggedIn(redirectTo = 'dashboard.html') {
  const session = await getSession();
  if (session) {
    const userType = await getUserType();
    if (userType === 'business') {
      window.location.href = 'dashboard.html';
    } else {
      window.location.href = redirectTo;
    }
    return true;
  }
  return false;
}
