# Backend (likey-backend) 코드 리뷰 체크리스트

Node.js 22 + Express.js + tsoa 기반 백엔드 서비스 전용 체크리스트입니다.

---

## 1. 에러 핸들링

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 에러 패키지 | `@tpcint/api-errors` 패키지만 사용 (http-errors 등 금지) | 🔴 Critical |
| 4xx name 메타데이터 | 4xx 에러(`BadRequestError`, `NotFoundError` 등)에 `{name: 'ErrorName'}` 옵션 포함 | 🔴 Critical |
| 에러 메시지 (API) | `src/api/` 파일은 `t()` 함수로 번역 처리 | 🟠 Major |
| 에러 메시지 (Admin) | `src/admin-api/` 파일은 `t()` 없이 한국어 원문 | 🟠 Major |
| HTTP 상태 코드 맥락 | 에러 상황에 맞는 HTTP 상태 코드 사용 (예: 파라미터 검증 오류에 403 대신 400) | 🟡 Minor |

**HTTP 상태 코드 맥락 불일치 심각도 규칙:**
- 일반적인 상태 코드 맥락 불일치 (400 vs 403, 404 vs 400 등)는 **🟡 Minor**로 처리
- 단, 426(Upgrade Required), 429(Too Many Requests) 등 클라이언트가 상태 코드에 의존하여 특수 동작을 수행하는 경우는 **🟠 Major**로 처리

**주의: 4xx와 5xx 에러의 시그니처가 다릅니다**

```typescript
// ❌ 잘못된 예시 - 4xx에서 name 누락
throw new BadRequestError('에러 발생');
throw new NotFoundError();

// ✅ 올바른 예시 - 4xx (src/api/)
throw new BadRequestError(t('에러 메시지'), {name: 'InvalidRequest'});
throw new NotFoundError(t('사용자를 찾을 수 없습니다.'), {name: 'UserNotFound'});

// ✅ 올바른 예시 - 4xx (src/admin-api/)
throw new BadRequestError('유효하지 않은 요청입니다.', {name: 'InvalidRequest'});
throw new NotFoundError('사용자를 찾을 수 없습니다.', {name: 'UserNotFound'});

// ✅ 5xx 에러는 시그니처가 다름 — {name} opts 없음
throw new ServerError('InvalidRewardType');              // 첫 번째 인자 = name
throw new ServerError(caughtError, 'context message');   // 외부 에러 래핑
throw new InvalidStateError('unexpected state');          // name 고정 'InvalidState'
throw new CustomServerError('CustomName', {desc: '설명'}); // desc 필요 시
```

## 2. 계층 아키텍처

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 컨트롤러 역할 | 파라미터 검증, 서비스 호출, 응답 매핑만 수행 | 🟠 Major |
| Datastore 접근 | 컨트롤러에서 Model 클래스 직접 사용 금지 | 🔴 Critical |
| 비즈니스 로직 | `src/likey/` 아래 서비스 레이어에 위치 | 🟠 Major |

```
Controller (얇게) → Service (비즈니스 로직) → Repository/Model (데이터 접근)
```

## 3. 데코레이터

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| Tags | 모든 컨트롤러에 `@Tags` 데코레이터 존재 | 🔴 Critical |
| Security (API) | `src/api/` 컨트롤러에 `@Security` 데코레이터 | 🔴 Critical |
| Security (Admin) | `src/admin-api/` 컨트롤러에 `@Security('admin_api_token')` | 🔴 Critical |

## 4. Redis 캐싱

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 캐시 무효화 | Datastore 쓰기 후 `removeByKey()` 호출 확인 | 🟠 Major |
| 트랜잭션 콜백 | `tx.addCommitCb()` 내에서 캐시 무효화 | 🟠 Major |

```typescript
// ✅ 필수 패턴
tx.addCommitCb(async () => await redisShardManager.removeByKey('Prefix', key));
```

## 5. 코드 스타일

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| ES Modules | import 시 `.js` 확장자 필수 | 🟠 Major |
| const 우선 | `let` 대신 `const` 사용 권장 | 🟡 Minor |
| 로깅 | `console.log` 대신 `log.info/warn/error` 사용 | 🟠 Major |
| 날짜 라이브러리 | `dayjs` 사용 (`moment` 금지) | 🟠 Major |
| 유틸리티 | `es-toolkit` 사용 (`lodash` 금지) | 🟠 Major |
| Path Alias | `@/`, `@lib/`, `@likey/` 등 alias 사용 | 🟡 Minor |

```typescript
// ✅ 올바른 import
import {UserService} from '@likey/user/user-service.js';
import {log} from '@lib/logger.js';
```

## 6. 타입 안전성

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 타입 단언 | 불필요한 `as` 캐스팅 확인 | 🟠 Major |
| 반환 타입 | 선언된 반환 타입과 실제 반환값 일치 확인 | 🟠 Major |

```typescript
// ❌ 경고: 타입 안전성 침해 가능
const user = {uid} as UserItem;

// ✅ 권장: 명시적 타입 정의
const user: Pick<UserItem, 'uid'> = {uid};
```

## 7. 파라미터 검증

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| limit 검증 | 페이지네이션 limit 최대값 제한 | 🟡 Minor |
| undefined 처리 | 배열 destructuring에서 undefined 가능성 체크 | 🟠 Major |

```typescript
// ⚠️ uid가 undefined일 수 있음
const [uid] = getChannelUids(cid);
if (!uid) throw new BadRequestError(t('유효하지 않은 채널입니다.'), {name: 'InvalidChannel'});
```

## 8. 비즈니스 로직

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 데이터 무결성 | 매출/통계 계산 로직 정확성 (pending vs confirmed) | 🔴 Critical |
| 감사 로그 | 민감정보 접근 시 모든 항목 기록 확인 | 🟠 Major |
| 부분 실패 | 일부 데이터 조회 실패 시 전체 API 실패 방지 | 🟠 Major |
| 조건 분기 | 모든 케이스가 처리되었는지 확인 | 🟠 Major |

## 9. 보안

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 시크릿 | `SecretFetcher` 사용 (하드코딩 금지) | 🔴 Critical |
| 인젝션 | SQL/NoSQL 인젝션, 명령어 인젝션 취약점 | 🔴 Critical |
| 권한 체크 | 적절한 인증/인가 확인 | 🔴 Critical |

## 10. 대용량 처리

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 병렬 처리 | `Promise.all()` 사용 (독립적 작업) | 🟡 Minor |
| 동시성 제어 | `FixedSizeExecutor` 사용 (대량 작업) | 🟡 Minor |

---

## 리뷰 제외 대상

다음 파일/디렉토리는 리뷰 스킵:
- `locales/` - 번역 파일 (자동 생성)
- `po/` - 번역 소스
- `spec/*.yaml` - 자동 생성 스펙
- `src/gen/` - 자동 생성 라우트

---

## 자동 검사 패턴

```bash
# name 없는 4xx 에러 throw 확인 (5xx ServerError/InvalidStateError/CustomServerError는 시그니처가 달라 제외)
command gh pr diff {PR번호} | grep -n "throw new.*Error(" | grep -v "{name:" | grep -v "ServerError\|InvalidStateError\|NotImplementedError\|ServiceUnavailableError"

# import 확장자 누락 확인 (path alias)
command gh pr diff {PR번호} | grep -n "from '@" | grep -v "\\.js'"

# console.log 사용 확인
command gh pr diff {PR번호} | grep -n "console\\.log"

# http-errors 패키지 사용 확인
command gh pr diff {PR번호} | grep -n "from ['\"]http-errors['\"]"

# moment 사용 확인
command gh pr diff {PR번호} | grep -n "from ['\"]moment['\"]"

# lodash 사용 확인
command gh pr diff {PR번호} | grep -n "from ['\"]lodash['\"]"

# Datastore 모델 직접 import (Controller에서)
command gh pr diff {PR번호} | grep -n "import.*from.*@likey.*model"
```

---

## Admin API 특수 규칙

`src/admin-api/` 파일에 적용되는 추가 규칙:

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| Security | `@Security('admin_api_token')` 필수 | 🔴 Critical |
| userMap 응답 | `userMap` 직접 포함 금지 (클라이언트가 별도 조회) | 🟠 Major |
| 페이지네이션 | `startCursor`/`limit` 파라미터, `nextPageCursor` 반환 | 🟡 Minor |
| i18n | `t()` 함수 사용 금지 (한국어 원문 사용) | 🟠 Major |
