# AmigosNearMe — 플랫폼 기획서 (Master Spec)

> **작성일**: 2026-07-03 | **최종 수정**: 2026-07-03 (v3 — 과금 정책·플랜 변경·크레딧 패키지·계정 정책 반영)
> **목적**: 전체 기획의 단일 진실 공급원(Single Source of Truth). 구현 전 반드시 이 문서를 기준으로 논리 검증 후 진행.

---

## 1. 플랫폼 개요

미국 내 스패니시/영어권 커뮤니티를 위한 **로컬 서비스 마켓플레이스**.
고객(Customer/Employer)이 서비스 업체(Business) 또는 개별 근로자(Worker)를 찾고 연락할 수 있다.

**사이트**: https://amigosnearme.com
**기술 스택**: HTML/JS 프론트엔드 + Supabase (DB, Auth, Edge Functions) + Netlify (호스팅) + Resend (이메일)

---

## 2. 사용자 유형 (User Types)

총 **4가지** 사용자 유형. 회원가입 시 `user_type`으로 구분.

```
┌──────────────────────────────────────────────────────────────────────┐
│  유형       │ 설명                              │ DB 테이블            │
├──────────────────────────────────────────────────────────────────────┤
│  Business   │ 서비스 제공 업체                   │ businesses           │
│             │ (청소, 배관, 조경, 건설 등)        │ is_worker = false    │
├──────────────────────────────────────────────────────────────────────┤
│  Worker     │ 개별 근로자 / 독립 계약자           │ businesses           │
│             │ (일용직, 프리랜서 등)               │ is_worker = true     │
├──────────────────────────────────────────────────────────────────────┤
│  Customer   │ 서비스 구매 고객                   │ auth.users           │
│             │ **Business에만** 연락              │ + customer_profiles  │
├──────────────────────────────────────────────────────────────────────┤
│  Employer   │ Worker 채용 회사/개인               │ auth.users           │
│             │ 크레딧 구매 후 Worker에 연락        │ + employer_profiles  │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.1 Business vs Worker 구분 규칙

- **회원가입 시 `user_type`이 최우선 기준**: `user_type='worker'`로 가입 → `is_worker = true` 자동 설정
- `user_type='business'`로 가입 → `is_worker = false` 자동 설정
- `categories` 기반 판단은 레거시 마이그레이션 용도로만 사용 (`'staffing'` 포함 시 `is_worker = true`)
- 두 유형은 같은 `businesses` 테이블 공유, `is_worker` 플래그로 분리
- 검색 시 `searchBusinesses({ isWorker: false })` / `searchBusinesses({ isWorker: true })`로 분리 조회

### 2.2 Customer / Employer 별도 프로필 테이블 필요 이유

현재 auth.users 메타데이터만 사용 중이나, 아래 데이터를 저장하려면 별도 테이블이 필요하다:
- **customer_profiles**: 리뷰 작성 자격(contact_log 기반), 즐겨찾기 목록
- **employer_profiles**: 크레딧 잔여량, 크레딧 구매 이력, 연락한 Worker 목록

> **구현 우선순위**: customer_profiles (Phase 2 — 리뷰·Soft Delete에 먼저 필요) → employer_profiles (Phase 3 — 크레딧 시스템)

---

## 3. 플랜 구조 및 과금

### 3.1 Business 플랜 (3단계) — 월정액 구독

> **과금 방식: 매월 반복 결제 (Monthly Recurring Subscription)**
> 결제 성공 시 연락 한도가 매 청구 주기마다 자동 갱신된다.
> 결제 실패 시 → Free 플랜으로 자동 다운그레이드.
> ※ 결제 실패 시 발송할 알림 이메일(강제 다운그레이드 통보)은 §7에 미정의 — Phase 5 결제 시스템 구현 시 이메일 시나리오 추가 예정.

| 플랜 | 가격 | 월 연락 한도 | 비고 |
|------|------|------------|------|
| Free | $0/월 | **3회** | 기본 제공 (구독 없음) |
| Basic | $29/월 | **10회** | 월정액 구독, 검증 배지 신청 가능 |
| Premium | $79/월 | **무제한** | 월정액 구독, Priority Score 자동 +10 (기본값에 가산, 다운그레이드 시 제거) |

**"연락 한도"의 정의**: **Business 전용 시스템** (Worker에는 적용되지 않음).
Customer가 Business에 WhatsApp 창을 실제로 열거나 문의 폼을 제출할 때마다 1회 소진.
한도 도달 시 신규 Customer는 해당 Business에 연락 불가.

> **Worker 플랜 적용 없음**: Worker는 `businesses` 테이블을 공유하지만 `plan` 컬럼 및 연락 한도 시스템은 적용되지 않는다. Worker 수익화 모델은 미정 (향후 기능).

> **Worker 연락은 별도 시스템**: Employer가 Worker에 연락할 때는 contacts_used_month가 아닌 **Employer 크레딧**이 차감된다 (§3.2 참조).

**월별 리셋**: **매월 1일** 자동으로 `contacts_used_month = 0` 초기화.
결제 시스템 구현 후 청구일 기준으로 변경 예정.

**플랜 변경 정책**:

| 변경 유형 | 적용 시점 | 허용 경로 |
|-----------|-----------|-----------|
| **업그레이드** (Free→Basic, Free→Premium, Basic→Premium) | 즉시 적용 | 항상 가능 |
| **다운그레이드** (Premium→Basic, Premium→Free, Basic→Free) | **다음 달 1일부터** 적용 (결제 시스템 구현 후 청구일 기준으로 변경 예정) | 항상 가능 |

- 다운그레이드 신청 즉시 **확정** — 별도 취소 버튼 없음 (아래 업그레이드 경로로만 철회 가능).
- 신청 후 현재 달은 기존 플랜·한도가 그대로 유지된다.
- 다운그레이드 예약 상태는 Dashboard에 표시: *"다음 달부터 Basic 플랜으로 변경 예정"*
- 다음 달 이후 마음이 바뀌면 언제든 업그레이드 가능 (즉시 적용). **업그레이드 시 `pending_plan = NULL`로 초기화** — 예약된 다운그레이드가 자동 취소된다.
- 한 번에 **한 단계씩 또는 Free까지** 다운그레이드 가능 (Premium → Basic, Basic → Free, Premium → Free 모두 허용).
- DB: `businesses.pending_plan` 컬럼에 예약 플랜 저장, 청구일에 `plan` 컬럼으로 반영 후 초기화.

### 3.2 Employer 크레딧 시스템 — 선불 충전형 (Pay-as-you-go)

> **과금 방식: 월정액 구독 없음. 크레딧 소진 시 선택적으로 충전.**
> Employer는 정기 결제가 없으며, 크레딧이 남아 있는 한 추가 비용이 발생하지 않는다.
> 크레딧은 만료되지 않고 사용할 때까지 영구 보존된다.

| 항목 | 내용 |
|------|------|
| 크레딧 패키지 | **$10 / 5크레딧** · **$20 / 15크레딧** (25% 절약) · **$30 / 30크레딧** (40% 절약) |
| 차감 시점 | Employer가 Worker의 WhatsApp 창을 실제로 열 때 |
| 잔여 0개 | 신규 연락 불가, 크레딧 충전 유도 (EM6 이메일) |
| 크레딧 유효기간 | **무기한** — 구매 후 사용할 때까지 영구 보존 |
| 월정액 없음 | 정기 결제 없음, 크레딧 충전은 항상 선택 사항 |
| DB 저장 위치 | `employer_profiles.credit_balance` (별도 테이블 — 아래 §9 참조) |

**Business vs Employer 과금 비교**:

| 구분 | Business | Employer |
|------|----------|----------|
| 결제 방식 | 월정액 구독 (반복 결제) | 선불 충전 (비정기, 선택) |
| 한도 갱신 | 매 청구 주기마다 자동 갱신 | 해당 없음 (크레딧 차감 방식) |
| 미결제 시 | Free 플랜으로 다운그레이드 | 크레딧 0개 → 연락 차단 |
| 크레딧 만료 | 해당 없음 | 없음 (무기한) |

**크레딧 구현 범위 구분**:
- ✅ **지금 구현 가능**: 차감 로직 (연락 시 credit_balance -= 1), 잔여 0 시 차단
- ⏳ **결제 게이트웨이 필요**: 크레딧 구매 (실제 카드 결제) — Stripe/Braintree 연동 후 가능

---

## 4. 연락 추적 시스템 (Contact Tracking) — 핵심 로직

### 4.1 카운트 시점 정의 (중요)

> **원칙**: 버튼 클릭 시점이 아니라, **WhatsApp 창이 실제로 열릴 때** 1회 카운트.

```javascript
// ✅ 올바른 순서
function openWhatsApp(bizId, phone, ...) {
  // 1. 한도 확인 (DB)
  if (used >= limit) {
    // 한도 초과 처리 (SB12, SB13)
    return;
  }
  // 2. WhatsApp 창 열기 — 이 시점에 카운트
  window.open('https://wa.me/' + phone + '?text=...', '_blank');
  // 3. 카운트 증가 (창이 열린 직후)
  trackContact('whatsapp', bizId);
}

// ❌ 잘못된 순서 (현재 구현)
// trackContact() → 나중에 window.open() — 창이 열리지 않아도 카운트됨
```

### 4.2 올바른 데이터 흐름 (WhatsApp)

> ※ **폼 문의(Form Inquiry) 흐름**은 §8.4 "폼 문의 버튼 접근 정책"을 참조. 한도 확인·카운트·이메일 트리거 원칙은 아래 WhatsApp 흐름과 동일.

```
방문자(비로그인 포함)가 profile.html에서 "Open WhatsApp" 버튼 클릭
※ 비로그인: actor_id = null로 기록. SB13 이메일 발송 생략. 나머지 흐름 동일.
        │
        ▼
[1] DB에서 현재 한도 확인
    GET businesses.contacts_used_month, plan → limit 계산
        │
        ├─ 한도 초과 ──────────────────────────────────────────┐
        │                                                      │
        │  → "No longer accepting requests" 모달 표시          │
        │  → contact_log INSERT (limit_hit = true)             │
        │  → SB12 이메일 (업체: "고객 연락 놓침")               │
        │  → SB13 이메일 (고객: "업체가 한도 초과")             │
        │       ※ 로그인 Customer(actor_id 존재)에게만 발송    │
        │         비로그인 시 모달 표시만, 이메일 없음           │
        │  → 종료 (카운트 증가 없음)                            │
        │                                                      ▼
        └─ 한도 이내 ──────────────────────────────────────────┐
                                                               │
           → window.open('https://wa.me/...') — 창 열림       │
           → trackContact('whatsapp', bizId) 호출              │
                    │                                          │
                    ▼                                          │
           [2] RPC: increment_contact_count                    │
               businesses.contacts_used_month += 1            │
           [3] contact_log INSERT (limit_hit = false)         │
           [4] SB6 이메일 (업체: "고객이 WhatsApp으로 연락")   │
           [5] 한도 근접/도달 확인                              │
               remaining = limit - contacts_used_month        │
               remaining == 1 → SB8 이메일 (경고)             │
               remaining == 0 → SB9 이메일 (한도 도달)        │
```

### 4.3 한도 확인 — DB만 사용 (localStorage 금지)

```javascript
// ✅ 올바른 방식 — DB에서 직접 읽기
const biz = await getBizById(bizId);  // profile.html: 페이지 로드 시 이미 보유
const PLAN_LIMITS = { free: 3, basic: 10, premium: Infinity };
const limit = PLAN_LIMITS[biz.plan];
const used  = biz.contacts_used_month;
const remaining = limit - used;

// ❌ 금지 — localStorage는 브라우저 로컬, 다른 기기/브라우저와 동기화 안 됨
// var used = localStorage.getItem('anm-sim-req-...');
```

### 4.4 Employer → Worker 연락 흐름

> **원칙**: Customer → Business 흐름과 동일하게, WhatsApp 창이 실제로 열릴 때 크레딧을 차감한다.

```
Employer가 worker-profile.html에서 "Open WhatsApp" 버튼 클릭
        │
        ▼
[1] DB에서 크레딧 잔여량 확인
    GET employer_profiles.credit_balance
        │
        ├─ 크레딧 0개 ─────────────────────────────────────────┐
        │                                                      │
        │  → "크레딧이 없습니다" 모달 표시                       │
        │  → EM6 이메일 (Employer: "크레딧 구매 필요")           │
        │  → 종료 (창 열기·차감 없음)                            │
        │                                                      ▼
        └─ 크레딧 1개 이상 ─────────────────────────────────────┐
                                                               │
           → window.open('https://wa.me/...') — 창 열림       │
                    │                                          │
                    ▼                                          │
           [2] employer_profiles.credit_balance -= 1          │
           [3] contact_log INSERT                              │
               { biz_id: worker_id, actor_id: employer_id,   │
                 channel: 'whatsapp', limit_hit: false }       │
           [4] W2 이메일 (Worker: "Employer가 연락함")         │
           [5] 잔여 크레딧 확인                                 │
               credit_balance == 1 → EM3 이메일 (경고)        │
               credit_balance == 0 → EM4 이메일 (소진)        │
```

### 4.5 월별 자동 리셋

GitHub Actions cron (매월 1일 00:00 ET) 또는 Supabase pg_cron으로 실행:
```sql
-- 리셋이 필요한 모든 업체를 한 번에 일괄 업데이트 (배치)
UPDATE businesses
SET    contacts_used_month  = 0,
       contacts_month_reset = CURRENT_DATE
WHERE  contacts_month_reset IS NULL                                                -- 신규 업체 (컬럼 미설정)
   OR  EXTRACT(YEAR  FROM contacts_month_reset) != EXTRACT(YEAR  FROM NOW())
   OR  EXTRACT(MONTH FROM contacts_month_reset) != EXTRACT(MONTH FROM NOW());
```

※ 결제 시스템 구현 후 청구일 기준으로 변경 예정.
※ **`pending_plan` 적용**: Phase 5 결제 시스템 구현 후, 이 cron에 아래 로직 추가 필요:
```sql
-- pending_plan이 있는 업체의 plan을 실제로 변경하고 초기화
UPDATE businesses
SET    plan         = pending_plan,
       pending_plan = NULL
WHERE  pending_plan IS NOT NULL;
```

---

## 5. 프로필 조회수 추적 (Page Views)

> **구현 가능 시점**: 지금 바로 구현 가능. `page_views` 테이블 추가 후 profile.html 로드 시 INSERT.

### 5.1 데이터 흐름

```
profile.html 로드 (bizId 있음)         → Business 조회수
worker-profile.html 로드 (bizId 있음)  → Worker 조회수
  → page_views INSERT { biz_id, viewer_id (nullable), viewed_at }
  → dashboard의 "Profile views" 타일: 이번 달 COUNT(*)
```

### 5.2 DB 테이블

```sql
CREATE TABLE page_views (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  biz_id     uuid        NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  viewer_id  uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  viewed_at  timestamptz DEFAULT now()
);
```

### 5.3 Dashboard 표시

- **이번 달 조회수**: `COUNT(*) WHERE biz_id = ? AND viewed_at >= 월 시작일`
- **중복 처리**: 동일 viewer_id + 동일 날짜 = 1회로 카운트 (선택적 적용)
  ※ viewer_id=null(비로그인) 행에는 중복 제거 적용 안 함 — null끼리 같은 사람으로 간주하지 않음

---

## 6. Customer 리뷰 시스템

### 6.1 리뷰 작성 자격

> **원칙**: 실제로 연락한 이력이 있는 사용자만, 연락한 대상에 한해 리뷰 작성 가능.

| 작성자 | 리뷰 대상 | 자격 확인 |
|--------|-----------|-----------|
| Customer | **Business만** | `contact_log`에 `biz_id = ? AND actor_id = 현재 사용자 AND limit_hit = false` 존재 여부 |
| Employer | **Worker만** | `contact_log`에 `biz_id = ? AND actor_id = 현재 사용자 AND limit_hit = false` 존재 여부 |
| Business / Worker | 리뷰 작성 불가 | — |

> ※ **Phase 의존성**: Phase 2 Step 4에서 리뷰를 구현할 시점에는 contact_log 컬럼명이 `customer_id`임 (`actor_id`로 변경은 Phase 3 Step 2). Phase 2 Step 4 구현 코드에서는 `customer_id`로 조회해야 하며, Phase 3 Step 2 마이그레이션 시 INSERT 코드와 함께 이 자격 확인 쿼리도 `actor_id`로 업데이트 필요.

```
비로그인 사용자    → 리뷰 작성 불가 (로그인 유도)
로그인 Customer   → contact_log 확인 → Business 리뷰만 작성 가능
로그인 Employer   → contact_log 확인 → Worker 리뷰만 작성 가능
  연락 이력 없음  → "리뷰를 작성하려면 먼저 연락하세요" 안내
  연락 이력 있음  → 리뷰 작성 가능 (대상당 1회만)
  이미 리뷰 있음  → 기존 리뷰 수정 가능 (7일 이내)
```

### 6.2 리뷰 내용

| 항목 | 규칙 |
|------|------|
| 별점 | 1~5점 필수 |
| 텍스트 | 선택 사항, 최대 500자 |
| 업체당 1회 | UNIQUE(biz_id, reviewer_id) |
| 수정 | 작성 후 7일 이내 수정 가능 |
| 삭제 | **하드 삭제** (DB에서 행 제거) — 본인 삭제 가능 / 관리자 삭제 가능. 삭제 후 `UNIQUE(biz_id, reviewer_id)` 제약 해제되므로 동일 업체 재리뷰 허용. |

### 6.3 리뷰 표시

- **profile.html**: Business 리뷰 표시 (Customer 작성)
- **worker-profile.html**: Worker 리뷰 표시 (Employer 작성)
- 공통: 평균 별점 + 총 리뷰 수 (헤더에 표시) / 리뷰 목록 (최신순, 페이지당 10개)
- 별점 1점 리뷰 작성 시 → AD2 이메일 (관리자 알림) — Business/Worker 모두 해당

### 6.4 리뷰 신고 및 모더레이션

- **신고 가능**: Customer, Employer (리뷰 작성 주체) / Business, Worker (자신에 대한 리뷰에 한해)
- 신고 시 → `reviews.flagged = true` + `reviews.flagged_at = NOW()` + AD3 이메일 (관리자 알림)
- Admin 모더레이션 탭에서 검토 후 삭제/유지 결정

### 6.5 이메일 연동

| 시나리오 | 트리거 |
|---------|--------|
| AD2 | 별점 1점 리뷰 작성 직후 |
| AD3 | 리뷰 신고 직후 |

---

## 7. 이메일 시나리오 전체 목록 (33개)

### 7.1 Service Business (SB1~SB14)

| 코드 | 트리거 | 수신자 | 제목 |
|------|--------|--------|------|
| SB1 | 업체 등록 완료 | 업체 이메일 | Welcome to AmigosNearMe |
| SB2 | 검증 배지 신청 | 업체 이메일 | Verified Badge request received |
| SB3 | 검증 배지 승인 | 업체 이메일 | ✅ Your Verified Badge is approved |
| SB4 | 검증 배지 거부 | 업체 이메일 | Verified Badge update — [reason] |
| SB5 | 플랜 업그레이드 | 업체 이메일 | Plan upgraded to {plan} |
| SB6 | WhatsApp 창 열림 (한도 이내) | 업체 이메일 | 📲 A customer tried to reach you |
| SB7 | 폼 문의 제출 (한도 이내) | 업체 이메일 | 📋 New inquiry for {service} |
| SB8 | 연락 한도 1개 남음 | 업체 이메일 | ⚠️ Contact limit almost reached |
| SB9 | 연락 한도 도달 (0개) | 업체 이메일 | 🚫 Monthly contact limit reached |
| SB10 | 계정 정지 | 업체 이메일 | Your account has been suspended |
| SB11 | 계정 삭제 | 업체 이메일 | Account deleted |
| SB12 | 한도 초과 상태에서 연락 시도 | 업체 이메일 | ⚠️ You missed a customer contact |
| SB13 | 한도 초과 상태에서 연락 시도 | **고객 이메일** | This business is not available |
| SB14 | 플랜 다운그레이드 확정 | 업체 이메일 | 📉 Your plan will change next month |

### 7.2 Worker (W1~W7)

| 코드 | 트리거 | 수신자 | 제목 |
|------|--------|--------|------|
| W1 | Worker 프로필 등록 완료 | Worker 이메일 | Your worker profile is live |
| W2 | Employer가 Worker에 연락 (WhatsApp, 한도 이내) | Worker 이메일 | 📲 An employer wants to hire you |
| W3 | Worker 프로필 정지 | Worker 이메일 | Your profile has been suspended |
| W4 | Worker 프로필 삭제 | Worker 이메일 | Worker profile deleted |
| W5 | Employer가 Worker에 Web Form 문의 제출 | Worker 이메일 | 📩 An employer sent you a message |
| W6 | Worker 프로필에 새 리뷰 게시 | Worker 이메일 | ⭐ You received a new review |
| W7 | Admin이 Worker 리뷰 삭제 | Worker 이메일 | A review on your profile was removed |

### 7.3 Customer (CU1, CU3, CU4)

> **CU2 결번**: 초기 설계 시 미사용으로 남겨진 번호. Edge Function 코드에도 정의된 적 없음. 번호 체계 유지를 위해 결번으로 보존.

| 코드 | 트리거 | 수신자 | 제목 |
|------|--------|--------|------|
| CU1 | 고객 회원가입 | 고객 이메일 | Welcome to AmigosNearMe |
| ~~CU2~~ | *(결번 — 미사용)* | — | — |
| CU3 | 문의 폼 제출 완료 | 고객 이메일 | Your inquiry was sent |
| CU4 | 계정 정지/삭제 | 고객 이메일 | Account {action} |

### 7.4 Employer (EM1~EM6)

| 코드 | 트리거 | 수신자 | 제목 |
|------|--------|--------|------|
| EM1 | Employer 가입 | Employer 이메일 | Welcome — Find Workers |
| EM2 | 크레딧 구매 완료 | Employer 이메일 | {n} contact credits added |
| EM3 | 크레딧 1개 남음 | Employer 이메일 | ⚠️ Only 1 contact credit remaining |
| EM4 | 크레딧 0개 | Employer 이메일 | 🚫 No contact credits remaining |
| EM5 | Employer 계정 정지/삭제 | Employer 이메일 | Employer account {action} |
| EM6 | 크레딧 없는 상태에서 연락 시도 | Employer 이메일 | You need credits to contact workers |

### 7.5 계정 보안 알림 (SEC1~SEC2) — 신규

| 코드 | 트리거 | 수신자 | 제목 |
|------|--------|--------|------|
| SEC1 | 비밀번호 변경 완료 | 해당 계정 이메일 | 🔒 Your password was changed |
| SEC2 | 비밀번호 재설정 요청 시 **항상** 발송 (이메일 내용: "본인이 아니라면 문의하세요") | 해당 계정 이메일 | 🔒 Password reset requested |

**SEC1 이메일 내용**:
- "Your AmigosNearMe password was successfully changed."
- "If you did not make this change, contact us immediately at hola@amigosnearme.com"
- 변경 일시 (UTC) 포함
- 모든 유형(Business, Worker, Customer, Employer)에 동일 적용

**구현 방법**:
- **SEC1** (비밀번호 변경 완료): `onAuthStateChange` 이벤트 중 `USER_UPDATED` 감지 → Edge Function 호출. Supabase가 비밀번호를 실제로 변경한 직후 발생하는 이벤트.
- **SEC2** (비밀번호 재설정 요청): `resetPasswordForEmail()` 호출 직후 (Supabase 내장 리셋 링크 이메일 발송과 동시에) Edge Function 호출. `PASSWORD_RECOVERY` 이벤트는 사용자가 리셋 링크를 클릭해 앱에 돌아온 시점에 발생하므로 SEC2 트리거로 사용 불가 — 이미 비밀번호 변경이 완료된 후가 되어 "본인이 아니라면 문의하세요" 알림의 보안 목적이 상실됨.

### 7.6 Admin 알림 (AD1~AD4)

| 코드 | 트리거 | 수신자 | 제목 |
|------|--------|--------|------|
| AD1 | 검증 배지 신청 수신 | hola@amigosnearme.com | [Admin] Verified Badge request |
| AD2 | 별점 1~2점 리뷰 게시 (Business 또는 Worker) | hola@amigosnearme.com | [Admin] ⭐ {n}-star review posted |
| AD3 | 스팸 의심 리뷰 신고 | hola@amigosnearme.com | [Admin] 🚨 Spam suspected |
| AD4 | 계정 취소 요청 | hola@amigosnearme.com | [Admin] Cancellation request |

---

### 7.7 리뷰 삭제 알림 정책

Admin이 리뷰를 삭제할 때 발송되는 이메일 수신자 정책:

| 리뷰 유형 | 리뷰이 (리뷰 대상) 알림 | 리뷰어 (리뷰 작성자) 알림 |
|---|---|---|
| Business 리뷰 (Customer → Business) | Business Owner → **SB17** | Customer → **CU4** |
| Worker 리뷰 (Employer → Worker) | Worker → **W7** | Employer → **없음 (의도적)** |

> **Employer 미통지 이유**: Employer가 리뷰어인 경우 플랫폼 정책상 리뷰 삭제 사실을 통지하지 않는 것으로 결정. `fetchOwnerEmails`가 `businesses` 테이블 기반으로 동작하여 `employer_profiles` 기반 Employer 이메일 조회가 안 되는 기술적 제약도 있으나, 정책적으로도 통지 불필요로 확정 (2026-07-20).

---

## 8. 화면별 기능 정의

### 8.1 search.html — 검색 결과 페이지

**접근**: 비로그인 포함 모두 접근 가능

| 기능 | 설명 |
|------|------|
| 카테고리 필터 | 청소, 배관, 조경 등 |
| 지역 필터 | 도시/카운티 기준 |
| 업체 카드 | 이름, 카테고리, 지역, 검증 배지, Insured 배지, 별점, WhatsApp 버튼 |
| WhatsApp 버튼 | profile.html로 이동 후 연락 (search.html에서 직접 카운트 안 함) |
| 정렬 | Recommended (priority_score 기준), Newest, Rating |

### 8.2 worker-search.html — Worker 검색·목록 페이지

**접근**: 비로그인 포함 모두 접근 가능 (주요 방문자: Employer)

| 기능 | 설명 |
|------|------|
| 카테고리 필터 | 일용직, 청소, 이삿짐 등 |
| 지역 필터 | 도시/카운티 기준 |
| Worker 카드 | 이름, 서비스, 지역, 검증 배지, 별점 |
| Worker 카드 클릭 | `worker-profile.html?id=...`로 이동 |
| 정렬 | Recommended (priority_score 기준), Newest, Rating |

> `searchBusinesses({ isWorker: true })`로 조회 — §8.1 search.html과 동일 함수, 파라미터만 다름

### 8.3 worker-profile.html — Worker 프로필 페이지

**접근**: 비로그인 포함 모두 접근 가능

| 기능 | 데이터 소스 | 상태 |
|------|------------|------|
| Worker 정보 표시 (이름, 서비스, 지역, 언어) | DB (businesses, is_worker=true) | ⚠️ 미구현 |
| 검증/보험 배지 | DB (verified_badge, insured) | ⚠️ 미구현 |
| WhatsApp 연락 버튼 | 로그인 상태·유형 확인 후 처리 (아래 참조) | ⚠️ 미구현 |
| 크레딧 부족 모달 | employer_profiles.credit_balance = 0 → EM6 | ⚠️ 미구현 |
| 리뷰 표시 (Employer→Worker) | DB (reviews) | ⚠️ 미구현 |
| 리뷰 작성 | contact_log 자격 확인 → reviews INSERT | ⚠️ 미구현 |
| 페이지 조회수 기록 | page_views INSERT | ⚠️ 미구현 |

**WhatsApp 버튼 접근 유형별 처리**:

| 방문자 유형 | WhatsApp 버튼 동작 |
|------------|------------------|
| 비로그인 | 버튼 클릭 → 로그인 페이지로 이동 |
| 로그인 Employer | 크레딧 잔여 확인 → 창 열기 → 차감 (§4.4 흐름) |
| 로그인 Customer / Business / Worker | 버튼 비활성화 + "Employers only" 안내 문구 표시 |

> **연락 순서 (Employer)**: 크레딧 잔여 확인(employer_profiles.credit_balance > 0) → `window.open()` WhatsApp → 크레딧 차감 + contact_log INSERT → EM 이메일 트리거

### 8.4 profile.html — 업체 프로필 페이지

**접근**: 비로그인 포함 모두 접근 가능

| 기능 | 데이터 소스 | 상태 |
|------|------------|------|
| 업체 정보 표시 | DB (businesses) | ✅ |
| 검증/보험 배지 | DB (verified_badge, insured) | ✅ |
| 영업시간, 결제수단, 언어 | DB (hours, payment_methods, languages) | ✅ |
| 서비스 선택 드롭다운 | DB (categories) | ✅ |
| WhatsApp 연락 버튼 | 방문자 유형 확인 후 처리 (아래 참조) | ⚠️ 카운트 순서 수정 필요 |
| 폼 문의 (WhatsApp 대체) | 비로그인 포함 제출 가능. 한도 확인 후 SB7(+CU3 로그인 시) 발송. contacts_used_month += 1 | ⚠️ 한도 확인 로직 미구현 |
| 한도 초과 모달 | DB 확인 → SB12 + SB13 | ⚠️ localStorage → DB 교체 필요 |
| 리뷰 표시 | DB (reviews) | ⚠️ 미구현 |
| 리뷰 작성 | contact_log 자격 확인 → reviews INSERT | ⚠️ 미구현 |
| 페이지 조회수 기록 | page_views INSERT | ⚠️ 미구현 |

**WhatsApp 버튼 접근 유형별 처리**:

| 방문자 유형 | WhatsApp 버튼 동작 |
|------------|------------------|
| 비로그인 | 한도 확인 → 창 열기 → 카운트 (actor_id = null, SB13 이메일 발송 불가) |
| 로그인 Customer | 한도 확인 → 창 열기 → 카운트 (§4.2 흐름) |
| 로그인 Employer / Business / Worker | 버튼 비활성화 + "Customers only" 안내 문구 표시 |

**폼 문의 버튼 접근 정책**:

> **주의**: 폼 제출도 contacts_used_month 1회 소진 (§3.1 정의). WhatsApp과 동일하게 한도 확인 → 제출 → 카운트 순서를 지켜야 한다.

| 방문자 유형 | 폼 문의 버튼 동작 |
|------------|----------------|
| 비로그인 | **한도 확인 → 한도 이내 시** 제출 가능. SB7(업체 알림) 발송. CU3 생략(이메일 없음). contacts_used_month += 1. contact_log INSERT(channel='form', actor_id=null). SB8/SB9 트리거 가능. 한도 초과 시 제출 차단 + SB12 발송(SB13은 비로그인이므로 생략) + **contact_log INSERT(channel='form', actor_id=null, limit_hit=true)**. |
| 로그인 Customer | **한도 확인 → 한도 이내 시** 제출 가능. SB7 + CU3 모두 발송. contacts_used_month += 1. contact_log INSERT(channel='form', actor_id=customer_id). SB8/SB9 트리거 가능. 한도 초과 시 제출 차단 + SB12 + SB13 + **contact_log INSERT(channel='form', actor_id=customer_id, limit_hit=true)**. |
| 로그인 Employer / Business / Worker | 버튼 비활성화 + "Customers only" 안내 문구 표시 |

### 8.5 dashboard.html — Business/Worker 대시보드

**접근**: 로그인한 Business/Worker만

> **Worker 접속 시 차이점**: Worker에는 플랜·연락 한도 시스템이 적용되지 않으므로(§3.1), 아래 UI 요소를 Worker에게는 **숨김 처리**한다:
> - Overview 상단 **플랜 배너** (contacts_used_month / 한도 표시 전체)
> - Financial Summary의 **My Plan 탭** 내 한도·플랜·결제 관련 항목 전체
>
> Worker에게는 대신 조회수·WhatsApp 클릭(Employer 연락 수)·별점 타일만 표시한다. 문의 타일(channel='form')은 worker-profile.html에 폼 문의 기능이 없으므로 Worker에게는 숨김. (`is_worker` 플래그로 분기)

#### Overview 지표

| 타일 | 표시 내용 | 데이터 소스 | 상태 | 대상 |
|------|----------|------------|------|------|
| 👁 프로필 조회수 | 이번 달 조회수 | DB (page_views) | ⚠️ 미구현 | Business + Worker |
| 💬 문의 | 이번 달 폼 문의 수 | DB (contact_log, channel='form', **limit_hit=false**) | ⚠️ 미구현 | **Business만** |
| 📱 WhatsApp 클릭 | 이번 달 WhatsApp 연락 횟수 — Business·Worker 공통: `contact_log WHERE biz_id=? AND channel='whatsapp' AND limit_hit=false COUNT` | DB (contact_log) | ⚠️ 미구현 (contact_log 구현 후 가능 — Phase 2 Step 2). **Phase 1 임시**: Business는 `contacts_used_month`를 임시 표시값으로 사용하다가 Phase 2 Step 2 contact_log 구현 후 전환 | Business + Worker |
| ⭐ 별점 | 평균 별점 | DB (reviews) | ⚠️ 미구현 | Business + Worker |

#### 플랜 배너 (Overview 상단) — 연락 한도 현황

| 표시 내용 | 데이터 소스 | 상태 |
|----------|------------|------|
| 현재 플랜명 (Free/Basic/Premium) | DB (businesses.plan) | ⚠️ localStorage → DB 교체 필요 |
| 이번 달 사용 횟수 / 허용 횟수 | DB (contacts_used_month / plan 한도) | ⚠️ localStorage → DB 교체 필요 |
| 잔여 연락 횟수 | plan 한도 - contacts_used_month | ⚠️ localStorage → DB 교체 필요 |
| 한도 근접 경고 (1개 남음) | DB 계산값 → 배너 색상 변경 (노란색) | ⚠️ 미구현 |
| 한도 초과 알림 (0개) | DB 계산값 → 배너 색상 변경 (빨간색) | ⚠️ localStorage → DB 교체 필요 |

> **원칙**: Business 본인이 자신의 잔여 한도를 대시보드에서 항상 확인할 수 있어야 한다.
> Admin만 볼 수 있는 것이 아니라 업체 본인이 먼저 인지하고 플랜 업그레이드를 결정해야 한다.

#### 재무 현황 (Financial Summary) — My Plan 탭

| 표시 내용 | 데이터 소스 | 상태 |
|----------|------------|------|
| 현재 플랜명 | DB (businesses.plan) | ✅ |
| 현재 플랜 월 요금 | Free: $0 / Basic: $29 / Premium: $79 | ✅ (하드코딩) |
| 이번 달 연락 사용 / 허용 | DB (contacts_used_month / plan 한도) | ⚠️ localStorage → DB 교체 필요 |
| 잔여 연락 횟수 | plan 한도 - contacts_used_month | ⚠️ 미구현 |
| 다음 결제일 | 가입일 기준 매월 갱신 | ⏳ 결제 시스템 구현 후 |
| 결제 이력 | 플랜 변경 날짜 + 금액 | ⏳ 결제 시스템 구현 후 |
| 플랜 업그레이드 버튼 | Basic/Premium 전환 | ⏳ 결제 시스템 구현 후 |
| 플랜 다운그레이드 버튼 | 한 단계 낮춤 또는 Free 전환 — 신청 즉시 확정, 다음 달 적용 | ⏳ 결제 시스템 구현 후 |
| 다운그레이드 예약 표시 | `pending_plan` 있을 때 *"다음 달부터 {pending_plan} 플랜으로 변경 예정"* | ⚠️ 미구현 |

### 8.6 employer-dashboard.html — Employer 대시보드 (신규)

**접근**: 로그인한 Employer만

#### 크레딧 한도 현황 (Overview 상단 배너)

| 표시 내용 | 데이터 소스 |
|----------|------------|
| 잔여 크레딧 수 | DB (employer_profiles.credit_balance) |
| 이번 달 사용한 크레딧 수 | DB (contact_log COUNT, 이번 달) |
| 크레딧 1개 남음 경고 (노란색 배너) | DB 계산값 |
| 크레딧 0개 알림 (빨간색 배너) | DB 계산값 |

> **원칙**: Employer 본인이 잔여 크레딧을 대시보드에서 항상 확인할 수 있어야 한다.

#### 활동 현황

| 섹션 | 표시 내용 | 데이터 소스 |
|------|----------|------------|
| 이번 달 연락한 Worker | Worker 이름, 연락 채널, 일시 | DB (contact_log) |
| 총 연락한 Worker 수 (누적) | 전체 contact_log COUNT | DB |

#### 재무 현황 (Financial Summary)

| 표시 내용 | 데이터 소스 | 상태 |
|----------|------------|------|
| 잔여 크레딧 | DB (employer_profiles.credit_balance) | ⚠️ 미구현 (테이블 신규) |
| 총 구매한 크레딧 (누적) | DB (credit_transactions SUM) | ⚠️ 미구현 |
| 총 지출 금액 (누적) | DB (credit_transactions SUM amount_usd) | ⚠️ 미구현 |
| 크레딧 구매 이력 | 날짜, 금액, 크레딧 수 | ⏳ 결제 시스템 구현 후 |
| 크레딧 구매 버튼 (3종 패키지) | $10/5회 · $20/15회 · $30/30회 — 결제 게이트웨이 | ⏳ 결제 시스템 구현 후 |

### 8.7 admin.html — 관리자 콘솔

**접근**: collegeessayboard@gmail.com 만 (JWT app_metadata.is_admin)

#### Businesses 탭

> `is_worker = false` 업체만 표시 (Worker는 아래 Workers 탭에서 별도 관리)

| 컬럼 | 데이터 |
|------|--------|
| 업체명 | trade_name / business_name |
| 플랜 | Free / Basic / Premium |
| 검증 상태 | Verified / Unverified |
| 별점 | 평균 별점 |
| 이번 달 연락 수 | contacts_used_month |
| 잔여 한도 | plan 한도 - contacts_used_month |
| 다운그레이드 예약 | pending_plan (있을 경우 표시) |
| Priority Score | 0~20 슬라이더 (관리자 설정 기본값. 실효 우선순위 = 기본값 + 10(Premium) 또는 기본값(Free/Basic)) |
| 상태 | Active / Suspended |
| 조치 버튼 | 정지 / 복구 |

#### Workers 탭 (신규)

> `is_worker = true` 레코드만 표시. 플랜·연락한도 시스템 미적용이므로 해당 컬럼 없음.

| 컬럼 | 데이터 |
|------|--------|
| 이름 | trade_name / business_name |
| 서비스 카테고리 | categories |
| 검증 상태 | Verified / Unverified |
| 별점 | 평균 별점 |
| Priority Score | 0~20 슬라이더 |
| 상태 | Active / Suspended |
| 조치 버튼 | 정지 / 복구 |

#### Moderation 탭

> flagged 리뷰(§6.4)를 Admin이 검토·처리하는 화면. AD3 이메일 수신 후 이 탭에서 조치.

| 컬럼 | 데이터 |
|------|--------|
| 리뷰 ID | reviews.id |
| 대상 (Business/Worker) | biz_id → trade_name |
| 작성자 유형 | Customer / Employer |
| 별점 | rating |
| 내용 | review_text |
| 신고 일시 | reviews.flagged_at |
| 조치 | 삭제 / 유지 버튼 |

#### Customers 탭 (신규)

| 컬럼 | 데이터 |
|------|--------|
| 이메일 | auth.users 이메일 |
| 이번 달 연락한 업체 수 | contact_log COUNT (이번 달, limit_hit=false) |
| 총 연락 횟수 (누적) | contact_log COUNT (전체) |
| 리뷰 작성 수 | reviews COUNT |
| 계정 상태 | Active / Suspended |
| 조치 버튼 | 정지 / 복구 |

#### Employers 탭 (신규)

| 컬럼 | 데이터 |
|------|--------|
| 이메일 | employer 이메일 |
| 잔여 크레딧 | credit_balance |
| 이번 달 연락한 Worker 수 | contact_log COUNT |
| 총 구매 크레딧 | credit_transactions SUM |
| 계정 상태 | Active / Suspended |
| 조치 버튼 | 정지 / 복구 |

#### Cancellation Requests 탭

> 탈퇴 신청(§12.4)을 관리자가 검토하고 처리하는 화면. AD4 수신 후 이 탭에서 조치.

| 컬럼 | 데이터 |
|------|--------|
| 신청자 이메일 | auth.users 이메일 |
| 유형 | user_type (business / worker / customer / employer) |
| 사유 | cancellation_requests.reason |
| 신청 일시 | created_at |
| 처리 상태 | 미처리 / 처리 완료 (resolved) |
| 조치 버튼 | 처리 완료 → ① 해당 테이블 `account_status = 'deleted'` (§12.3 Soft Delete) + ② `resolved = true` + ③ SB11/W4/CU4/EM5 해당 이메일 발송 |

#### 플랫폼 재무 현황 (Platform Analytics 탭)

| 지표 | 설명 |
|------|------|
| 총 Business 수 | 플랜별 분류 |
| Basic 수익 | Basic 업체 수 × $29 |
| Premium 수익 | Premium 업체 수 × $79 |
| 크레딧 수익 | Employer 크레딧 구매 합계 |
| 예상 MRR | 위 합산 |
| 이번 달 총 연락 수 | contact_log COUNT |

---

## 9. DB 테이블 전체 구조

### 9.1 businesses (핵심 테이블)

| 컬럼 | 타입 | 의미 |
|------|------|------|
| id | uuid PK | 고유 ID |
| owner_id | uuid FK → auth.users | 소유자 |
| business_name | text | 법인명 |
| trade_name | text | 영업명 |
| plan | text | free/basic/premium |
| is_worker | boolean | Worker 여부 |
| account_status | text | active/suspended/deleted |
| verified_badge | boolean | 검증 배지 승인 여부 |
| insured | boolean | 보험 가입 여부 |
| public_email | text | 연락용 이메일 |
| whatsapp_phone | text | WhatsApp 번호 |
| categories | text[] | 서비스 카테고리 |
| service_area | text | 서비스 지역 |
| languages | text[] | 지원 언어 |
| payment_methods | text[] | 결제 수단 |
| hours | jsonb | 영업시간 |
| description | text | 업체 설명 |
| contacts_used_month | integer | 이번 달 연락 횟수 |
| contacts_month_reset | date | 마지막 리셋 날짜 |
| pending_plan | text | 다운그레이드 예약 플랜 (null이면 예약 없음) |
| priority_score | integer | 검색 노출 우선순위 (0~20) |
| created_at | timestamptz | 등록일 |

> **제거**: `contact_balance` — Employer 크레딧은 employer_profiles 테이블로 이동. 현재 마이그레이션(20260702000002)에 해당 컬럼이 추가되어 있으므로 Phase 5에서 `ALTER TABLE businesses DROP COLUMN contact_balance` 마이그레이션 추가 필요.
> ※ `pending_plan` 컬럼은 현재 마이그레이션에 미포함. **Phase 5 Step 1** 구현 시 `ALTER TABLE businesses ADD COLUMN pending_plan text` 마이그레이션을 먼저 추가 필요. (Step 1의 업그레이드 처리 코드에서 `pending_plan = NULL`을 참조하므로, 컬럼이 없으면 오류 발생 — Step 2보다 먼저 추가해야 함)
> ※ `priority_score` 컬럼은 §10에서 Admin Priority Score 슬라이더가 ✅ 작동 중으로 표시되어 있으므로 DB에 이미 존재하는 것으로 간주. Phase 5 Step 4에서는 컬럼 추가 없이 검색 정렬 쿼리에 effective_score 계산 로직만 추가하면 됨. (만약 실제 DB에 컬럼이 없다면 Phase 4 완성 전에 `ALTER TABLE businesses ADD COLUMN priority_score integer DEFAULT 10` 마이그레이션 실행 필요)

### 9.2 customer_profiles (신규)

| 컬럼 | 타입 | 의미 |
|------|------|------|
| id | uuid PK | |
| owner_id | uuid FK → auth.users | Customer 계정 |
| account_status | text | active/suspended/deleted |
| created_at | timestamptz | |

> **용도**: 리뷰 작성 자격 확인(contact_log 기반), 향후 즐겨찾기 목록 저장
> **구현 우선순위**: employer_profiles보다 **먼저** 구현 (Phase 2 — 리뷰·Soft Delete에 필요)

### 9.3 employer_profiles (신규)

| 컬럼 | 타입 | 의미 |
|------|------|------|
| id | uuid PK | |
| owner_id | uuid FK → auth.users | Employer 계정 |
| credit_balance | integer DEFAULT 0 | 잔여 크레딧 |
| account_status | text | active/suspended/deleted |
| created_at | timestamptz | |

### 9.4 credit_transactions (신규)

| 컬럼 | 타입 | 의미 |
|------|------|------|
| id | uuid PK | |
| employer_id | uuid FK → employer_profiles | |
| amount_usd | numeric | 결제 금액 (예: 10.00) |
| credits_added | integer | 추가된 크레딧 수 (예: 5) |
| payment_ref | text | 결제 게이트웨이 트랜잭션 ID |
| created_at | timestamptz | |

### 9.5 contact_log

| 컬럼 | 타입 | 의미 |
|------|------|------|
| id | uuid PK | |
| biz_id | uuid FK → businesses | 대상 업체/Worker |
| actor_id | uuid FK → auth.users | 연락한 사람 (nullable) — Customer 또는 Employer |
| channel | text | 'whatsapp' \| 'form' |
| limit_hit | boolean | 한도 초과 상태에서의 시도 여부 |
| created_at | timestamptz | |

> ※ 현재 DB 컬럼명은 `customer_id` (Phase 3 Step 2 마이그레이션 후 `actor_id`로 변경 예정)
> ※ `limit_hit` 컬럼은 Business 월간 한도 초과 시도 기록용. Employer→Worker 연락 행(Phase 3 Step 3에서 INSERT)에서는 크레딧=0이면 연락 자체가 차단되어 contact_log에 기록되지 않으므로, Employer 행의 `limit_hit`은 항상 false.

### 9.6 page_views (신규)

| 컬럼 | 타입 | 의미 |
|------|------|------|
| id | uuid PK | |
| biz_id | uuid FK → businesses | 조회된 업체 |
| viewer_id | uuid FK → auth.users | 조회한 사람 (nullable, 비로그인 허용) |
| viewed_at | timestamptz DEFAULT now() | |

### 9.7 reviews

| 컬럼 | 타입 | 의미 |
|------|------|------|
| id | uuid PK | |
| biz_id | uuid FK → businesses | |
| reviewer_id | uuid FK → auth.users | |
| rating | integer (1~5) | |
| review_text | text | |
| flagged | boolean | 신고 여부 |
| flagged_at | timestamptz | 신고된 시점 (nullable) |
| created_at | timestamptz | |
| updated_at | timestamptz | 마지막 수정 일시 (감사 로그 — 수정 가능 여부는 `created_at` 기준으로 판단) |

UNIQUE(biz_id, reviewer_id) — 업체당 1회 리뷰
> 수정 가능 조건: `NOW() - created_at <= INTERVAL '7 days'`
> ※ `updated_at`, `flagged_at` 컬럼은 현재 마이그레이션(20260702000003)에 미포함. Phase 2 Step 4 리뷰 구현 시 아래 마이그레이션 추가 필요:
> ```sql
> ALTER TABLE reviews ADD COLUMN updated_at timestamptz;
> ALTER TABLE reviews ADD COLUMN flagged_at timestamptz;
> ```

### 9.8 verification_queue

| 컬럼 | 의미 |
|------|------|
| id | uuid PK |
| business_id | uuid FK → businesses |
| document_type | EIN, Business Permit 등 |
| document_url | 업로드된 파일 URL |
| status | pending/approved/rejected |
| admin_note | 거부 사유 |
| created_at | 신청 일시 |
| reviewed_at | 검토 일시 |

### 9.9 email_log (중복 발송 방지)

| 컬럼 | 타입 | 의미 |
|------|------|------|
| id | uuid PK | 고유 ID |
| scenario | text | SB6, AD1 등 |
| recipient | text | 수신자 이메일 |
| ref_id | uuid | 관련 레코드 ID |
| sent_at | timestamptz DEFAULT now() | 발송 일시 |
| is_voided | boolean DEFAULT false | 무효화 여부 (크레딧 재충전 시 EM3·EM4·EM6 이력 초기화에 사용) |

> ※ `is_voided` 컬럼은 현재 마이그레이션에 미포함. **Phase 3 Step 6** (EM3·EM4·EM6 구현) 전에 아래 마이그레이션을 먼저 실행해야 함:
> ```sql
> ALTER TABLE email_log ADD COLUMN is_voided boolean DEFAULT false;
> ```

> **사용 정책**:
> - 이메일 발송 성공 시 항상 INSERT (감사 로그 역할) — 행을 DELETE하지 않는다.
> - **중복 체크 대상 시나리오 (월 단위 dedup)**: **SB8·SB9·SB12·SB13** — 발송 전 `(scenario, recipient, ref_id)`로 조회하되, **이번 달 발송 이력만 확인** (`AND sent_at >= date_trunc('month', now())`). 매달 contacts_used_month 리셋 후 다음 달에 한도 근접/초과 시 재발송이 가능해야 하므로 월 단위 dedup 적용. (동시 요청 등 엣지 케이스도 함께 방지.)
> - **중복 체크 대상 시나리오 (크레딧 사이클 dedup)**: **EM3·EM4·EM6** — 크레딧 사이클 단위로 dedup 적용. EM2(크레딧 구매) 이메일 발송 성공 시, 해당 Employer의 `(EM3, recipient)` · `(EM4, recipient)` · `(EM6, recipient)` 이메일 로그를 `is_voided = true`로 업데이트하여 무효화한다. dedup 조회 시 `AND is_voided = false` 조건을 추가하므로, 무효화된 이전 이력은 중복 판정에서 제외되어 다음 소진 사이클에서 재발송된다. 감사 로그는 보존된다. ※ 근거: 크레딧은 달력 기준이 아닌 구매 사이클 기반이므로, 새 충전 = 새 사이클 시작. 같은 달 2회 충전·소진 시에도 매 사이클마다 경고 발송이 보장된다.
> - **중복 체크 없는 시나리오**: SB6·SB7·AD2·AD3 등 매 이벤트마다 발송이 맞는 시나리오는 체크 없이 INSERT만 수행.

### 9.10 cancellation_requests

| 컬럼 | 의미 |
|------|------|
| id | |
| user_id | uuid FK → auth.users (모든 유형 공통 — Business/Worker/Customer/Employer) |
| user_type | 'business' \| 'worker' \| 'customer' \| 'employer' |
| reason | 취소 사유 |
| created_at | |
| resolved | 처리 여부 |

> **변경**: 기존 `biz_id` → `user_id`로 일반화. 모든 사용자 유형의 탈퇴 요청을 단일 테이블에서 관리.
> ※ 현재 마이그레이션(20260702000002)은 `biz_id uuid REFERENCES businesses(id)`로 생성되어 있음. **Phase 2 Step 1에서** 아래 마이그레이션으로 스키마 교체 (§11 Phase 2 Step 1 참조):
> ```sql
> ALTER TABLE cancellation_requests
>   DROP COLUMN biz_id,
>   ADD COLUMN user_id   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
>   ADD COLUMN user_type text CHECK (user_type IN ('business','worker','customer','employer'));
> ```

---

## 10. 구현 현황 (정직한 평가)

### ✅ 완성 — 실제 작동

| 기능 |
|------|
| Supabase 인증 (회원가입/로그인/로그아웃) |
| Business 프로필 CRUD |
| Business 검색 (search.html) |
| 이메일 템플릿 30개 정의 완료 (Edge Function — SB1~SB13·W1~W4·CU1/CU3/CU4·EM1~EM6·AD1~AD4) ※ SB14·SEC1·SEC2 미정의 (총 33개 중 3개 제외) |
| Admin — Verification Queue (승인/거부) |
| Admin — Businesses 목록 (Priority Score, 정지, Contacts 컬럼) |
| 검증 배지, Insured 배지 표시 |

### ⚠️ 부분 구현 — 수정 필요

| 기능 | 문제 |
|------|------|
| Contact 한도 확인 (profile.html) | localStorage → DB 교체 필요 |
| 플랜 배너 (dashboard.html) | localStorage → DB 교체 필요 |
| WhatsApp 카운트 순서 | 버튼 클릭 시 → 창 열린 후로 순서 수정 필요 |
| trackContact() | DB 호출은 됨. 순서와 SB8/SB9 트리거 추가 필요 |
| SB6 이메일 트리거 (한도 이내 WhatsApp 연락 시 업체 알림) | 현재 호출 여부 미확인 — trackContact() 내 발송 로직 존재 여부 검증 필요 |
| SB10 / W3 이메일 트리거 (계정 정지 시 업체/Worker 알림) | 현재 호출 여부 미확인 — Admin 정지 버튼과 Edge Function 연결 여부 검증 필요 |

### ❌ 미구현 — 지금 구현 가능한 것

| 기능 | 비고 |
|------|------|
| SB8/SB9/SB12/SB13 이메일 실제 트리거 | 템플릿은 있음, 호출 로직 없음 |
| W2 이메일 실제 트리거 (Employer→Worker 연락 시 Worker 알림) | 템플릿은 있음, 호출 로직 없음 — Phase 3 Step 3에서 구현 |
| SB14 이메일 템플릿 + 트리거 | 템플릿 미정의, Phase 5에서 구현 |
| SEC1/SEC2 이메일 템플릿 + 트리거 | 템플릿 미정의, 비밀번호 변경·재설정 이벤트 감지 로직 없음 — Phase 2에서 구현 |
| 월별 contacts_used_month 자동 리셋 | DB 컬럼 있음, cron 없음 |
| 프로필 조회수 (page_views) | 테이블 생성 + profile.html INSERT |
| 리뷰 작성/표시 (profile.html) | DB 테이블 있음, UI 연동 없음 |
| contact_log 실제 기록 | RPC는 있음, INSERT 없음 |
| Admin — Employers 탭 | 신규 |
| Admin — Workers 탭 | 신규 (is_worker=true 대상 — 정지·복구·검증 배지 관리) |
| Admin — 잔여 한도 컬럼 | 계산값 추가 |
| customer_profiles 테이블 | 신규 — Phase 2에서 생성 (§9.2 참조) |
| employer_profiles 테이블 | 신규 |
| Employer 크레딧 차감 로직 | employer_profiles 생성 후 가능 |
| Dashboard — contact_log 기반 문의 탭 | contact_log 연동 필요 |
| worker-search.html + worker-profile.html | 신규 — Phase 3에서 구현 |
| employer-dashboard.html | 신규 — Phase 3 Step 7에서 구현 (employer_profiles 테이블 생성 후) |

### ❌ 미구현 — 결제 게이트웨이 필요 (추후)

| 기능 | 비고 |
|------|------|
| Business 플랜 업그레이드 결제 | Stripe/Braintree 필요 |
| Employer 크레딧 구매 결제 | Stripe/Braintree 필요 |
| 결제 이력 표시 | 결제 시스템 후 |

### ❌ 미구현 — 기타 추후

| 기능 | 비고 |
|------|------|
| 사진 업로드 | Supabase Storage 연동 필요 |
| Worker 전용 대시보드 분리 | Business 대시보드 공용 중 |
| Customer 계정 관리 페이지 | |

---

## 11. 우선순위 로드맵

### Phase 1 — Contact Tracking 완결

1. profile.html 한도 확인 → DB 기반으로 교체 (localStorage 제거)
2. WhatsApp 카운트 순서 수정 (창 열린 후 카운트)
3. 폼 문의(Form Inquiry)에 한도 확인 + 카운트 로직 추가 (§8.4 기준 — WhatsApp과 동일 흐름)
4. dashboard.html 플랜 배너 → DB 기반으로 교체
5. SB8 / SB9 이메일 실제 트리거 (한도 근접/도달 시 — WhatsApp·폼 모두)
6. SB12 / SB13 이메일 실제 트리거 (한도 초과 시도 시 — WhatsApp·폼 모두)
7. 월별 자동 리셋 (GitHub Actions cron)

### Phase 2 — 데이터 완성

1. page_views 테이블 + profile.html 조회수 기록
   + **customer_profiles 테이블 생성** (§9.2 기준 — Customer Soft Delete·리뷰·향후 즐겨찾기에 필요)
   + **기존 Customer 마이그레이션**: 테이블 생성 직후 Phase 1 기간에 가입한 Customer 레코드를 일괄 INSERT
   ```sql
   INSERT INTO customer_profiles (owner_id)
   SELECT id FROM auth.users
   WHERE raw_user_meta_data->>'user_type' = 'customer'
     AND id NOT IN (SELECT owner_id FROM customer_profiles);
   ```
   ※ 이 마이그레이션 없이 Phase 2 Step 4 리뷰 자격 확인 및 Soft Delete 로직을 구현하면 기존 Customer는 customer_profiles 조회 실패 → 리뷰 작성 불가
   + **신규 Customer 가입 시 customer_profiles row 자동 생성**: customer_profiles 테이블 생성과 동시에, 신규 Customer 회원가입 핸들러(CU1 이메일 트리거와 동일 지점)에 `customer_profiles INSERT { owner_id: new_user.id }` 로직을 추가해야 함. 이 로직이 없으면 이후 리뷰 자격 확인(Phase 2 Step 4) 시 customer_profiles 조회 실패.
   + cancellation_requests 테이블 스키마 교체 마이그레이션 (`biz_id → user_id/user_type` — §9.10 ALTER TABLE SQL)
2. contact_log 실제 기록 (Customer→Business WhatsApp/폼 클릭마다)
   — **한도 이내 성공 시(limit_hit=false)와 한도 초과 시도 시(limit_hit=true) 모두 INSERT** (§4.2 기준)
   ※ Employer→Worker contact_log INSERT는 Phase 3 Step 3에서 구현 (Phase 2 시점에는 employer_profiles 테이블 미존재)
   + **SB6 트리거 검증** (한도 이내 성공 시 Business 이메일 알림 — trackContact() 내 호출 여부 확인 및 미호출 시 구현)
3. dashboard Inquiries 탭 — contact_log 읽어서 표시
4. 리뷰 작성/표시 (profile.html — Customer→Business 리뷰만)
   ※ Employer→Worker 리뷰는 worker-profile.html이 Phase 3 Step 5에서 구축된 이후 → Phase 3 Step 5에서 함께 구현
5. Admin — Businesses 탭 잔여 한도 컬럼 추가
6. SEC1/SEC2 이메일 템플릿 Edge Function 추가 + 트리거 구현
   ※ **SEC1**: `onAuthStateChange` USER_UPDATED 이벤트 감지 → Edge Function 호출 (비밀번호 변경 완료 직후)
   ※ **SEC2**: `resetPasswordForEmail()` 호출 직후 Edge Function 호출 (재설정 *요청 시점* 보안 알림 — PASSWORD_RECOVERY 이벤트는 링크 클릭 후 발생하므로 사용 불가. §7.5 참조)

### Phase 3 — Employer 시스템

1. employer_profiles 테이블 생성 + EM1 이메일 트리거 (Employer 가입 완료 시)
   ※ **신규 Employer 가입 시 employer_profiles row 자동 생성**: 테이블 생성 후, 신규 Employer 회원가입 핸들러(EM1 이메일 트리거와 동일 지점)에 `employer_profiles INSERT { owner_id: new_user.id, credit_balance: 0 }` 로직을 추가해야 함. 이 로직이 없으면 Phase 3 Step 3 크레딧 차감 시 employer_profiles 조회 실패.
   + **기존 Employer 마이그레이션**: 테이블 생성 직후 Phase 1~2 기간에 가입한 Employer 레코드를 일괄 INSERT
   ```sql
   INSERT INTO employer_profiles (owner_id)
   SELECT id FROM auth.users
   WHERE raw_user_meta_data->>'user_type' = 'employer'
     AND id NOT IN (SELECT owner_id FROM employer_profiles);
   ```
   ※ 이 마이그레이션 없이 Phase 3 Step 3 크레딧 차감 로직을 구현하면 기존 Employer는 credit_balance 조회 실패 → Worker 연락 불가
2. contact_log.customer_id → actor_id 컬럼명 변경 마이그레이션 (§9.5 기준)
   ※ 아래 코드를 customer_id → actor_id로 함께 업데이트 필요:
     - Phase 2 Step 2에서 작성한 contact_log INSERT 코드
     - Phase 2 Step 4에서 작성한 리뷰 자격 확인 쿼리 (§6.1 참조)
3. Employer 크레딧 차감 로직 (Worker 연락 시) + contact_log INSERT (actor_id = employer_id)
   + **W2 이메일 트리거** (Worker: "Employer가 연락함" — §4.4 흐름 [4] 기준, contact_log INSERT 직후 발송)
   + Worker 대시보드 WhatsApp 클릭 타일 → `contact_log(biz_id=worker_id, channel='whatsapp', limit_hit=false) COUNT`로 표시 (§8.5 기준)
4. worker-search.html 구현 (Worker 목록 검색 — `searchBusinesses({ isWorker: true })`)
5. worker-profile.html 구현 (Worker 프로필 열람 + Employer WhatsApp 연락 + 비-Employer 접근 처리)
   + Employer→Worker 리뷰 작성/표시 (Phase 2 Step 4에서 이관)
   + page_views INSERT (worker-profile.html 로드 시 — §8.3 / §5.1 기준)
6. EM3 / EM4 / EM6 이메일 실제 트리거 (크레딧 경고·소진·차단 시)
   ※ **선행 마이그레이션 필수**: 구현 전 `ALTER TABLE email_log ADD COLUMN is_voided boolean DEFAULT false` 실행 (§9.9). dedup 조회 시 `AND is_voided = false` 조건을 반드시 포함해야 크레딧 재충전(Phase 5 Step 3) 후 재발송이 정상 동작함.
7. Employer 대시보드 (크레딧 현황, 연락 이력)
8. Admin — Employers 탭 신설
   ※ **EM5 트리거**: Admin 정지 버튼 클릭 시 `account_status = 'suspended'` 업데이트와 함께 EM5 이메일 발송 (§7.4 EM5 — {action}='suspended'). 삭제 처리는 Phase 4 Step 3 Cancellation Requests 탭에서 EM5 ({action}='deleted') 발송.
9. Admin — Workers 탭 신설 (is_worker=true 대상 — 정지·복구·검증 배지 관리)

### Phase 4 — Admin 완성

1. Admin — Platform Analytics (MRR, 연락 수 등)
   + **SB10/W3 트리거 검증** (Admin 정지 버튼 → Edge Function 연결 여부 확인 및 미연결 시 구현 — §10 "부분 구현" 참조)
2. Admin — Customers 탭 DB 연동
   ※ **CU4 트리거**: Admin 정지 버튼 클릭 시 `customer_profiles.account_status = 'suspended'` 업데이트와 함께 CU4 이메일 발송 (§7.3 CU4 — {action}='suspended'). 삭제 처리는 Phase 4 Step 3 Cancellation Requests 탭에서 CU4 ({action}='deleted') 발송.
3. 탈퇴 신청 UI — 각 대시보드 Settings 탭 "Request cancellation" 버튼 + cancellation_requests INSERT + AD4 이메일 트리거
   ※ Admin — Cancellation Requests 탭 처리 UI (§8.7) 함께 구현
   ※ Customer 탈퇴 신청 UI는 Customer 계정 관리 페이지(§10 "미구현 — 기타 추후") 구현 이후 가능 — Business/Worker/Employer 먼저 구현 후 Customer 페이지와 함께 추가

### Phase 5 — 결제 및 확장 (결제 게이트웨이 연동 후)

1. Business 플랜 업그레이드 결제 + SB5 이메일 트리거 (업그레이드 확정 시)
   ※ 업그레이드 처리 시 `pending_plan = NULL`로 초기화 — 예약된 다운그레이드 자동 취소 (§3.1 정책)
2. Business 플랜 다운그레이드 UI + pending_plan 저장 + SB14 이메일 트리거
   ※ 월별 cron(§4.5)에 `pending_plan → plan` 적용 SQL 추가 (Phase 5에서 함께 구현)
3. Employer 크레딧 구매 (3종 패키지) + EM2 이메일 트리거 (구매 완료 시)
   ※ **EM2 발송 성공 직후**: 해당 Employer의 `email_log` 중 `scenario IN ('EM3','EM4','EM6') AND recipient = employer_email AND is_voided = false` 행을 `is_voided = true`로 일괄 업데이트하여 dedup 초기화 — 다음 소진 사이클에서 EM3·EM4·EM6 재발송 보장 (§9.9 크레딧 사이클 dedup 정책)
4. Premium 플랜 Priority Score 실효값 로직 (§8.7 기준)
   - `priority_score` 컬럼은 DB에 이미 존재 (§9.1 참조) — 이 단계에서 컬럼 추가 없음
   - 검색 정렬 쿼리에 `effective_score = priority_score + (plan = 'premium' ? 10 : 0)` 계산 로직 추가
   - 업그레이드 시: plan = 'premium' → 정렬 시 자동으로 +10 반영
   - 다운그레이드 시: plan ≠ 'premium' → +10 제거 (priority_score 컬럼 자체는 유지)
5. 사진 업로드 (Supabase Storage)

---

## 12. 계정 정책 (Account Policies)

### 12.1 로그인 이메일 — 불변 (Immutable)

> **정책**: 회원가입 시 사용한 이메일 주소는 이후 변경 불가.

**이유**:
- 이메일은 계정 식별자(Primary Key 역할)
- 변경 허용 시 계정 도용, 리뷰 조작 등 보안 취약점 발생 가능
- Supabase Auth 이메일 변경은 기술적으로 가능하지만 AmigosNearMe 정책으로 차단

**구현 방법**:
- dashboard.html / employer-dashboard.html Settings 탭에서 이메일 필드 표시만 하고 수정 불가 처리 (`disabled`, readonly)
- 이메일 변경 시도 시 안내 문구 표시: "Email address cannot be changed. Contact support if you need assistance."
- Supabase RLS 또는 Edge Function에서 이메일 업데이트 요청 차단

**예외**: 계정 삭제 후 동일 이메일로 재가입은 허용. 단, Soft Delete(§12.3)로 DB 데이터(리뷰, 연락 이력 등)는 보존되나 새 계정은 신규 auth.users ID를 갖게 되어 기존 기록과 연결 불가.

### 12.2 비밀번호 변경

| 항목 | 규칙 |
|------|------|
| 변경 위치 | 각 대시보드 Settings 탭 |
| 변경 완료 시 | SEC1 이메일 즉시 발송 |
| 최소 길이 | 8자 이상 |
| 본인 확인 | 현재 비밀번호 입력 후 변경 가능 |
| 비밀번호 찾기 | 로그인 이메일로 재설정 링크 발송 (Supabase 기본 기능) |

### 12.3 삭제 방식 — 소프트 삭제 (Soft Delete)

> **정책**: DB 레코드를 실제로 삭제하지 않는다. `account_status = 'deleted'`로 변경 후 모든 검색·노출에서 제외.

| 유형 | 처리 |
|------|------|
| Business / Worker | `businesses.account_status = 'deleted'` → 검색 결과 제외, 프로필 비공개 |
| Customer | `customer_profiles.account_status = 'deleted'` |
| Employer | `employer_profiles.account_status = 'deleted'` |

> **검색 노출 정책 (active/suspended/deleted)**: search.html·worker-search.html 쿼리는 **`account_status = 'active'` 인 레코드만** 반환한다. `suspended` 및 `deleted` 상태 업체는 검색 결과에서 제외 — 정지된 업체에 고객이 연락을 시도하는 상황을 방지. 직접 URL로 profile.html에 접근하는 경우에도 `account_status ≠ 'active'` 이면 "This business is no longer available" 안내 표시 후 연락 버튼 비활성화.

- 관련 데이터(리뷰, 연락 이력 등) 보존 — 리뷰는 "Former business"로 익명 표시
- 관리자가 필요 시 복구 가능 (`account_status = 'active'`로 복원)
- 실제 auth.users 레코드 삭제는 관리자 수동 처리 (Supabase Dashboard)
- **삭제된 계정으로 로그인 시 프론트엔드 동작**: `account_status = 'deleted'` 상태인 Business/Worker가 dashboard.html에 접근하면 "Your account has been deleted. Contact support if this is a mistake." 안내 표시 후 추가 작업 차단. Employer는 employer-dashboard.html 진입 시 동일하게 account_status를 확인해 삭제 계정임을 안내. Customer는 계정 관리 페이지(§10 "미구현 — 기타 추후") 구현 시 동일 account_status 체크를 함께 추가.
  ※ auth.users 레코드가 남아 있는 한 로그인 자체는 막을 수 없으므로, 세션 유효 상태에서도 account_status 체크를 프론트엔드에서 반드시 수행해야 함.

### 12.4 계정 탈퇴 절차

| 항목 | 규칙 |
|------|------|
| 요청 방법 | Settings 탭 → "Request cancellation" |
| 처리 방식 | 즉시 삭제 아님. 관리자 검토 후 3영업일 내 처리 |
| 알림 | **요청 시**: AD4 이메일 (관리자 — 검토 시작 알림) / **처리 완료 시**: SB11/W4/CU4/EM5 이메일 (해당 사용자 — 삭제 확인 알림) |
| 유료 플랜 | 현재 결제 주기 종료 후 삭제 (결제 시스템 구현 후 적용) |
| 리뷰 데이터 | 탈퇴 후 리뷰는 "Former business"로 익명 보존 |
| **Employer 잔여 크레딧** | 탈퇴 시 잔여 크레딧 **환불 없이 소멸**. 탈퇴 신청 화면에서 잔여 크레딧 수를 표시해 사용자가 인지 후 진행하도록 안내. |
| **다운그레이드 예약 중 탈퇴** | `pending_plan` 무시, 탈퇴 처리 우선. 계정 삭제 후 플랜 변경은 무의미하므로 별도 처리 없음. |

---

## 13. 구현 전 체크리스트

구현 전 반드시 다음 질문에 답할 수 있어야 한다:

1. **데이터 소스**: 이 데이터는 DB에서 오는가, localStorage에서 오는가? (localStorage 사용 금지)
2. **단일 경로**: 같은 정보를 두 곳에서 읽고 있지 않은가?
3. **카운트 시점**: 버튼 클릭 시점인가, 창이 실제로 열린 시점인가?
4. **이메일 트리거**: 이 액션이 이메일을 발생시켜야 하는가? 어떤 시나리오 코드인가?
5. **한도 확인 순서 (Business)**: 한도 확인 → 창 열기 → 카운트 증가 순서를 지키는가?
5-1. **크레딧 확인 순서 (Employer)**: 크레딧 잔여 확인 → 창 열기 → 크레딧 차감 순서를 지키는가?
6. **본인 가시성**: 해당 데이터를 본인(Business/Employer) 대시보드에서 확인할 수 있는가?
7. **관리자 가시성**: Admin에서도 동일 데이터를 확인할 수 있는가?
8. **재무 가시성**: 수익/비용/한도와 관련 있다면 Financial 섹션에 표시되는가?
9. **계정 보안**: 이메일 변경 시도를 차단하는가? 비밀번호 변경 시 SEC1 이메일이 발송되는가?
10. **방문자 유형 처리**: 이 버튼/기능이 비로그인·Customer·Employer·Business·Worker 각각에 대해 올바르게 동작하는가? (허용 / 차단 / 기능 축소 여부 명시)
11. **account_status 필터**: 이 검색/조회 쿼리는 `account_status = 'active'` 인 레코드만 반환하는가? (§12.3 — suspended·deleted 업체는 검색 결과 및 profile.html 연락 버튼에서 제외)
12. **삭제 계정 대시보드 차단**: 이 대시보드 진입 시 `account_status = 'deleted'` 여부를 확인하는가? (§12.3 — 삭제된 계정으로 로그인한 사용자는 "account has been deleted" 안내 표시 후 추가 작업 차단)
13. **이메일 dedup 정책 확인**: 이 이메일 시나리오의 dedup 방식을 올바르게 적용했는가? (§9.9 — SB8·SB9·SB12·SB13: 월 단위 dedup `AND sent_at >= date_trunc('month', now())` / EM3·EM4·EM6: 크레딧 사이클 dedup `AND is_voided = false` / 기타: dedup 없음)
