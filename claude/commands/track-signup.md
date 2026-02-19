# Track Signup - 유저 가입 경로 추적

특정 유저의 실제 가입 경로를 GCP Cloud Run 로그 기반으로 추적합니다. utm_source가 `other_link`로 기록된 경우에도 실제 최초 랜딩 페이지, Referer, User Agent를 통해 진짜 유입 경로를 파악할 수 있습니다.

## 인자 (Arguments)

```
/track-signup 4573620769849344                    # uid로 추적 (기본: likey-real)
/track-signup 4573620769849344 likey-beta          # 특정 GCP 프로젝트 지정
/track-signup 4573620769849344 likey-real 2d        # freshness 지정 (기본: 1d)
```

- **첫 번째 인자** (필수): 유저 UID
- **두 번째 인자** (선택): GCP 프로젝트 ID (기본: `likey-real`)
- **세 번째 인자** (선택): 로그 조회 기간 freshness (기본: Step 0에서 `createdAt` 기반 자동 계산, 명시 시 override)

---

## GCP 프로젝트 정보

| 환경 | Project ID | 비고 |
|------|-----------|------|
| Production | `likey-real` | 기본값 |
| Beta | `likey-beta` | 테스트 환경 |

## Cloud Run 서비스 정보

| 서비스 | 역할 |
|--------|------|
| `api` | 백엔드 API (가입 요청 처리, jsonPayload 로그) |
| `web` | 프론트엔드 SSR (초기 페이지 랜딩, httpRequest 로그) |
| `www` | 리다이렉트 서비스 |

---

## 실행 순서

### Step 0: likey-admin MCP로 유저 기본 정보 조회

가장 먼저 `mcp__likey-admin__get_user` 도구로 유저 상세 정보를 조회합니다.

```
mcp__likey-admin__get_user({ uidOrUsername: "{{USER_UID}}" })
```

**확인 사항:**
- `createdAt`: 가입 일시 (이후 로그 조회 시 timestamp 범위의 기준)
- `username`, `displayName`: 유저 식별
- `country`, `locale`: 국가/언어 정보
- `userType`: 일반/크리에이터 여부
- `signUpStatus`: 가입 완료 여부

**freshness 자동 계산:**
- `createdAt`과 현재 시각의 차이를 계산하여 `--freshness` 값을 자동 설정
- 예: 오늘 가입 → `1d`, 3일 전 가입 → `4d`
- Cloud Logging 보존 기간(기본 30일)을 초과하면 로그 조회 불가 안내

### Step 1: 유저 UID로 API 로그에서 deviceId 확보

유저 UID가 포함된 API 로그를 검색하여 `requestDevice.deviceId`를 추출합니다.

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND (resource.labels.service_name="api") AND "{{USER_UID}}"' \
  --project={{PROJECT_ID}} --limit=10 --format=json --freshness={{FRESHNESS}}
```

- `jsonPayload.requestDevice.deviceId` 값을 추출
- `jsonPayload.requestIp` 값도 함께 추출

### Step 2: deviceId로 가입 시점 로그 확인

deviceId를 사용하여 signup 관련 로그를 조회합니다.

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="api" AND jsonPayload.requestDevice.deviceId="{{DEVICE_ID}}" AND jsonPayload.message=~"(signup|sign-up|register|signUp|createUser|adjustUtm)"' \
  --project={{PROJECT_ID}} --limit=50 --format=json --freshness={{FRESHNESS}}
```

**확인 사항:**
- `signup, allocated uid` 로그에서 가입 시각 확인
- `[createAccount] signup, committed` 로그로 가입 완료 확인
- 가입 방식 파악: email/phone/SNS

### Step 3: deviceId로 가입 전후 전체 API 로그 조회 (시간순)

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="api" AND jsonPayload.requestDevice.deviceId="{{DEVICE_ID}}" AND timestamp<="{{SIGNUP_TIMESTAMP}}"' \
  --project={{PROJECT_ID}} --limit=100 --format=json --freshness={{FRESHNESS}}
```

**결과를 시간순(reverse)으로 정렬하여 분석:**
- 가입 전 최초 API 호출 확인
- 이메일 인증, 전화 인증 등 가입 플로우 추적
- `requestIp` 값 확보

### Step 4: IP 주소로 web/www 서비스에서 최초 랜딩 페이지 확인

가입 시점 전후 10분 범위로 web/www 서비스의 httpRequest 로그를 조회합니다.

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND (resource.labels.service_name="web" OR resource.labels.service_name="www") AND httpRequest.remoteIp="{{IP_ADDRESS}}" AND timestamp>="{{SIGNUP_TIME_MINUS_10MIN}}" AND timestamp<="{{SIGNUP_TIME_PLUS_5MIN}}"' \
  --project={{PROJECT_ID}} --limit=50 --format=json --freshness={{FRESHNESS}}
```

**핵심 추출 정보:**
- `httpRequest.requestUrl`: 최초 랜딩 URL
- `httpRequest.referer`: 유입 출처 (예: `https://t.co/`, `https://www.google.com/`)
- `httpRequest.userAgent`: 브라우저/앱 정보 (Twitter in-app, Safari, Chrome 등)
- `httpRequest.status`: 응답 코드 (302 리다이렉트 등)

### Step 5: 가입 API 엔드포인트 확인

```bash
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="api" AND httpRequest.remoteIp="{{IP_ADDRESS}}" AND (httpRequest.requestUrl=~"auth" OR httpRequest.requestUrl=~"signup") AND timestamp>="{{SIGNUP_TIME_MINUS_5MIN}}" AND timestamp<="{{SIGNUP_TIME_PLUS_1MIN}}"' \
  --project={{PROJECT_ID}} --limit=50 --format=json --freshness={{FRESHNESS}}
```

**확인 사항:**
- `POST /api/auth/signup/email` → 이메일 가입
- `POST /api/auth/signup/phone` → 전화번호 가입
- `POST /api/auth/sns/*` → SNS 가입 (Google, Apple, Twitter 등)

### Step 6: 분석 결과 정리

아래 형식으로 분석 결과를 보고합니다:

```
## 유저 {{USER_UID}} 가입 경로 분석

### 기본 정보
- **가입 시각**: (UTC)
- **가입 방식**: 이메일/전화/SNS
- **Device ID**:
- **IP**:
- **User Agent**:

### 유입 경로
- **최초 랜딩 URL**:
- **Referer**: (유입 출처)
- **실제 유입 채널**: Twitter / Google / Direct / 기타

### 타임라인
| 시각 | 이벤트 | 상세 |
|------|--------|------|
| ... | 최초 랜딩 | URL, Referer, UA |
| ... | 리다이렉트 | ... |
| ... | 가입 완료 | ... |

### utm_source 분석
- **기록된 utm_source**: (실제 DB에 저장된 값)
- **실제 유입 경로**: (로그 기반 분석 결과)
- **불일치 원인**: (있는 경우 설명)
```

---

## 주의사항

- gcloud 로그 조회는 **freshness** 기간 내의 로그만 검색 가능합니다. 오래된 가입은 조회 불가
- **IP 기반 web 로그 매칭**은 동일 IP를 사용하는 다른 유저의 요청이 포함될 수 있으므로, User Agent와 시간대를 교차 검증해야 합니다
- Twitter 인앱 브라우저 → Safari 전환 등 **브라우저 전환 시 deviceId가 동일하지만 UA가 변경**되는 패턴에 주의
- web 서비스의 httpRequest 로그에는 `jsonPayload.requestDevice.deviceId`가 없으므로, **IP + 시간대 + UA** 조합으로 매칭합니다
- 로그 결과 파싱 시 `python3 -c` 인라인 스크립트를 활용하면 JSON 파싱이 편리합니다
