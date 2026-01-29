---
name: swagger-link
description: Swagger API 문서 직접 링크 생성. "swagger 링크", "API 문서 URL", "스웨거 링크 만들어줘" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "<controller-path:method | HTTP-METHOD /path | --guide> [--stage=beta|real] [--preview=ENV] [--base=BRANCH] [--spec=SPEC]"
allowed-tools: Bash, Read, Glob, Grep
---

# Swagger Link Generator

Controller 파일 또는 API endpoint를 기반으로 Swagger UI 직접 링크를 생성합니다.

**Arguments:** `$ARGUMENTS`

## 실행 방식

### 단일 링크 생성 (즉시 실행)
단순 URL 생성은 직접 실행합니다. Controller 파일과 메서드명을 지정하면 바로 링크를 생성합니다.

### 가이드 문서 생성 (백그라운드 권장)
`--guide` 모드는 여러 파일 분석이 필요하므로 Task 도구로 백그라운드 실행을 권장합니다.
변경된 모든 Controller를 분석하고, 새로 추가/수정된 API endpoint를 자동으로 찾아 FE 연동 가이드 문서를 생성합니다.

---

## 사용법

### 단일 링크 생성

```bash
# Controller 파일 + 메서드명
/swagger-link src/api/coupon-controller.ts:fetchMyCouponsV2

# Controller 파일 + 메서드명 + preview 환경
/swagger-link src/api/coupon-controller.ts:fetchMyCouponsV2 --preview=my-coupons-api

# HTTP Method + Path 직접 지정
/swagger-link GET /coupon/my-coupons/v2 --stage=beta --preview=my-coupons-api

# Admin API
/swagger-link src/admin-api/coupon-controller.ts:getCoupons

# Tasks API
/swagger-link src/tasks/chat-tasks-controller.ts:sendChatMessage
```

### 가이드 문서 생성 (--guide 모드)

```bash
# 기본 사용 (origin/master 기준 변경사항 분석)
/swagger-link --guide --preview=my-coupons-api

# 특정 base 브랜치 지정
/swagger-link --guide --base=origin/develop --preview=feature-branch

# 특정 spec만 분석
/swagger-link --guide --spec=likey-api --preview=my-coupons-api

# real 환경용 가이드
/swagger-link --guide --stage=real
```

---

## 옵션

| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `--stage` | `beta` | 환경 (beta, real) |
| `--preview` | - | Preview 환경 이름 (branch명 등) |
| `--guide` | - | FE 연동 가이드 문서 생성 모드 |
| `--base` | `origin/master` | 비교 기준 브랜치 (--guide 모드에서 사용) |
| `--spec` | - | 특정 spec만 분석 (likey-api, likey-admin-api, likey-tasks) |

---

## URL 구조

```
https://{host}/dev/spec/{spec}?preview={previewEnv}#{method}-{encodedPath}
```

### Host

| Stage | Host |
|-------|------|
| beta | `likey-beta.firebaseapp.com` |
| real | `likey.firebaseapp.com` |

### Spec 자동 추론

| Controller 경로 | Spec |
|-----------------|------|
| `src/api/` | `likey-api` |
| `src/admin-api/` | `likey-admin-api` |
| `src/tasks/` | `likey-tasks` |

### Path 인코딩 (RapiDoc 규칙)

RapiDoc은 hash 부분에서 특수문자를 `-`로 대체합니다:

```javascript
/[\s#:?&={}]/g  // 공백, #, :, ?, &, =, {, }
```

예시:
- `/coupon/{couponId}/cancel-reservation` -> `/coupon/-couponId-/cancel-reservation`
- `/user/{uid}` -> `/user/-uid-`

---

## 워크플로우 (단일 링크 생성)

### 1. 인자 파싱

```
1. --stage=VALUE -> stage (기본: beta)
2. --preview=VALUE -> previewEnv
3. 나머지 인자 분석:
   - "파일경로:메서드명" 형식 -> Controller 모드
   - "HTTP_METHOD /path" 형식 -> Direct 모드
```

### 2-A. Controller 모드 (파일:메서드)

#### Step 1: 파일 읽기 및 파싱

```bash
# Controller 파일 읽기
# 예: src/api/coupon-controller.ts:fetchMyCouponsV2
```

#### Step 2: @Route 데코레이터에서 base path 추출

```typescript
// @Route('coupon') -> basePath = '/coupon'
```

#### Step 3: 메서드의 HTTP 데코레이터 찾기

```typescript
// @Get('/my-coupons/v2') -> method = 'get', path = '/my-coupons/v2'
// @Post('/issue/{couponFamilyId}') -> method = 'post', path = '/issue/{couponFamilyId}'
// @Put, @Delete, @Patch 동일
```

#### Step 4: 전체 경로 조합

```
fullPath = basePath + methodPath
// '/coupon' + '/my-coupons/v2' = '/coupon/my-coupons/v2'
```

### 2-B. Direct 모드 (HTTP METHOD /path)

```
method = 'get' (소문자 변환)
path = '/coupon/my-coupons/v2'
```

Direct 모드에서 spec은 path로 추론하거나, 명시적으로 제공받아야 합니다.
`--spec=likey-api` 옵션으로 지정하거나, 제공되지 않으면 사용자에게 물어봅니다.

### 3. URL 생성

```javascript
function encodePathForRapiDoc(path) {
  return path.replace(/[\s#:?&={}]/g, '-');
}

function generateSwaggerUrl({stage, spec, method, path, previewEnv}) {
  const host = stage === 'real'
    ? 'likey.firebaseapp.com'
    : 'likey-beta.firebaseapp.com';

  const encodedPath = encodePathForRapiDoc(path);
  const hash = `${method.toLowerCase()}-${encodedPath}`;

  let url = `https://${host}/dev/spec/${spec}`;
  if (previewEnv) {
    url += `?preview=${previewEnv}`;
  }
  url += `#${hash}`;

  return url;
}
```

---

## 워크플로우 (--guide 모드)

`--guide` 모드는 git diff를 분석하여 변경된 API endpoint를 자동으로 찾고, FE 연동 가이드 문서를 생성합니다.

### Step 1: 변경된 Controller 파일 파악

```bash
git diff {base} --name-only | grep -E 'src/(api|admin-api|tasks)/.*-controller\.ts$'
```

기본 base는 `origin/master`입니다. `--base` 옵션으로 변경 가능합니다.

### Step 2: 각 Controller에서 변경된 API endpoint 추출

각 변경된 Controller 파일에 대해:

1. **git diff로 변경된 라인 파악**
   ```bash
   git diff {base} -- {controller-file}
   ```

2. **변경된 메서드 찾기**
   - 새로 추가된 `+` 라인에서 HTTP 데코레이터 패턴 검색
   - `@Get`, `@Post`, `@Put`, `@Delete`, `@Patch` 데코레이터 파싱

3. **메서드 컨텍스트 분석**
   - 변경된 데코레이터 근처의 메서드명 추출
   - `@Route` 데코레이터에서 base path 추출

### Step 3: 각 API 정보 수집

변경된 각 API에 대해 다음 정보를 추출:

1. **기본 정보**
   - HTTP Method (GET, POST, PUT, DELETE, PATCH)
   - Full Path (Route base + method path)

2. **JSDoc 주석 추출**
   ```typescript
   /**
    * 서버 주도 UI용 쿠폰 목록 조회 API.
    */
   @Get('/my-coupons/v2')
   async fetchMyCouponsV2(...)
   ```

3. **파라미터 정보 추출**
   - `@Query()` 파라미터
   - `@Path()` 파라미터
   - `@Body()` 파라미터

4. **Response 타입 추출**
   - 메서드 반환 타입에서 추출
   - `Promise<ResponseType>` 형식 파싱

5. **DTO 타입 정보** (import된 타입 파일에서)
   - Response DTO 구조
   - Request Body DTO 구조

### Step 4: Swagger 링크 생성

각 API에 대해 RapiDoc 인코딩 규칙을 적용하여 링크 생성.

### Step 5: FE 연동 가이드 문서 출력

Notion에 바로 붙여넣기 좋은 마크다운 형식으로 출력합니다.

---

## 출력 형식

### 단일 링크 생성 모드

```markdown
## Swagger Link

**API**: `{method.toUpperCase()} {path}`
**Spec**: `{spec}`
**Stage**: `{stage}`
{previewEnv가 있으면: **Preview**: `{previewEnv}`}

### URL

{생성된 URL}

### Markdown Link

```
[{method.toUpperCase()} {path}]({URL})
```

---

**팁**: URL을 복사하여 브라우저에서 열면 해당 API 문서로 바로 이동합니다.
```

### --guide 모드 출력 형식

```markdown
## FE 연동 가이드

> 분석 기준: `{base}` 브랜치 대비 변경사항
> Stage: `{stage}`
{previewEnv가 있으면: > Preview: `{previewEnv}`}

---

### 새로 추가된 API

#### GET `/coupon/my-coupons/v2`
[Swagger](https://likey-beta.firebaseapp.com/dev/spec/likey-api?preview=my-coupons-api#get-/coupon/my-coupons/v2)

서버 주도 UI용 쿠폰 목록 조회 API.

**Query Parameters:**
| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `status` | `string` | N | 쿠폰 상태 필터 |
| `targetUid` | `string` | N | 특정 크리에이터 필터 |

**Response:** `CouponItemCardDTO[]`

<details>
<summary>Response DTO 구조</summary>

```typescript
interface CouponItemCardDTO {
  couponId: string;
  title: string;
  // ... DTO 필드
}
```

</details>

---

#### POST `/coupon/{couponId}/cancel-reservation`
[Swagger](https://likey-beta.firebaseapp.com/dev/spec/likey-api?preview=my-coupons-api#post-/coupon/-couponId-/cancel-reservation)

예약된 쿠폰 취소 API.

**Path Parameters:**
| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `couponId` | `string` | Y | 취소할 쿠폰 ID |

**Response:** `UserSubscriptionCelebItem`

---

### 수정된 API

(변경된 기존 API가 있으면 여기에 표시)

---

### 요약

| Spec | 추가 | 수정 |
|------|------|------|
| likey-api | 2 | 0 |
| likey-admin-api | 0 | 0 |
| likey-tasks | 0 | 0 |
```

---

## 예시

### 예시 1: 단일 링크 생성

#### 입력

```
/swagger-link src/api/coupon-controller.ts:fetchMyCouponsV2 --preview=my-coupons-api
```

#### 출력

```markdown
## Swagger Link

**API**: `GET /coupon/my-coupons/v2`
**Spec**: `likey-api`
**Stage**: `beta`
**Preview**: `my-coupons-api`

### URL

https://likey-beta.firebaseapp.com/dev/spec/likey-api?preview=my-coupons-api#get-/coupon/my-coupons/v2

### Markdown Link

```
[GET /coupon/my-coupons/v2](https://likey-beta.firebaseapp.com/dev/spec/likey-api?preview=my-coupons-api#get-/coupon/my-coupons/v2)
```
```

### 예시 2: 가이드 문서 생성

#### 입력

```
/swagger-link --guide --preview=my-coupons-api
```

#### 출력

```markdown
## FE 연동 가이드

> 분석 기준: `origin/master` 브랜치 대비 변경사항
> Stage: `beta`
> Preview: `my-coupons-api`

---

### 새로 추가된 API

#### GET `/coupon/my-coupons/v2`
[Swagger](https://likey-beta.firebaseapp.com/dev/spec/likey-api?preview=my-coupons-api#get-/coupon/my-coupons/v2)

서버 주도 UI용 쿠폰 목록 조회 API.

**Query Parameters:**
| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `status` | `MyCouponStatus` | N | 쿠폰 상태 필터 |
| `targetUid` | `string` | N | 특정 크리에이터 필터 |

**Response:** `MyCouponsResponse`

---

#### POST `/coupon/{couponId}/cancel-reservation`
[Swagger](https://likey-beta.firebaseapp.com/dev/spec/likey-api?preview=my-coupons-api#post-/coupon/-couponId-/cancel-reservation)

예약된 쿠폰 취소 API.

**Path Parameters:**
| 이름 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `couponId` | `string` | Y | 취소할 쿠폰 ID |

**Response:** `UserSubscriptionCelebItem`

---

### 요약

| Spec | 추가 | 수정 |
|------|------|------|
| likey-api | 2 | 0 |
```

---

## --guide 모드 상세 파싱 규칙

### HTTP 데코레이터 패턴

```typescript
// 지원하는 데코레이터
@Get('path')
@Get('/path')
@Post('path')
@Post('/path')
@Put('path')
@Delete('path')
@Patch('path')

// 경로 없는 경우 (루트)
@Get()
@Post()
```

### 파라미터 데코레이터 패턴

```typescript
// Query 파라미터
@Query() status?: MyCouponStatus
@Query('customName') param?: string

// Path 파라미터
@Path() couponId: string
@Path('id') couponId: string

// Body 파라미터
@Body() body: CreateCouponRequest
```

### JSDoc 주석 추출

메서드 바로 위의 `/** ... */` 블록에서 첫 번째 줄(description)을 추출합니다.

```typescript
/**
 * 서버 주도 UI용 쿠폰 목록 조회 API.     <- 이 줄을 추출
 * @param status 쿠폰 상태 필터
 */
@Get('/my-coupons/v2')
async fetchMyCouponsV2(...)
```

### DTO 타입 추적

Response 타입이 import된 경우, 해당 파일에서 interface/type 정의를 찾아 표시합니다.

```typescript
// Controller에서
import {MyCouponsResponse} from '@likey/coupon/coupon-dto.js';

// coupon-dto.ts에서 타입 정의 추출
export interface MyCouponsResponse {
  items: CouponItemCardDTO[];
  // ...
}
```

---

## 주의사항

- Controller 파일 경로는 프로젝트 루트 기준 상대 경로 또는 절대 경로
- 메서드명은 대소문자 구분 (정확히 일치해야 함)
- Preview 환경 이름은 git branch명 또는 preview 배포 환경명
- Path parameter의 `{}`는 RapiDoc에서 `-`로 변환됨
- `--guide` 모드는 git diff 결과에 의존하므로, 로컬 변경사항이 커밋되어 있어야 정확한 결과를 얻을 수 있음
- `--guide` 모드에서 staged되지 않은 변경사항도 포함하려면 먼저 `git add`를 실행

---

## 에러 처리

### 단일 링크 생성 모드

- **파일을 찾을 수 없음**: 경로 확인 필요
- **메서드를 찾을 수 없음**: 메서드명 대소문자 확인
- **HTTP 데코레이터 없음**: tsoa 데코레이터 확인

### --guide 모드

- **변경된 Controller가 없음**: base 브랜치 확인 또는 다른 브랜치 지정
- **파싱 실패**: 비정상적인 코드 포맷일 수 있음, 수동으로 확인 필요
