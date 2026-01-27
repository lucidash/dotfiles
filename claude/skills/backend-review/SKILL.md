---
name: backend-review
description: PR을 리뷰할 때, 코드 리뷰해달라고 할 때, PR 봐달라고 할 때, GitHub PR URL이 대화에 등장할 때, 이 PR 확인해달라고 할 때 사용. PR 번호나 URL을 보고 코드 리뷰가 필요한 상황에서 자동으로 활성화됩니다.
allowed-tools: Bash, Glob, Grep, Read, Task
---

# Backend PR 코드 리뷰

PR을 분석하고 코드 리뷰를 수행합니다.
- 전체 요약 코멘트 + 각 파일/라인별 인라인 코멘트를 함께 작성합니다.
- CLAUDE.md와 `.codex/review-guide.md` 규칙을 기반으로 검토합니다.

## 트리거 키워드

- "리뷰해줘", "코드 리뷰", "PR 봐줘"
- "이 PR 확인해줘", "리뷰 부탁"
- GitHub PR URL 감지: `github.com/.../pull/...`
- PR 번호와 함께 "확인", "검토" 언급

## 인자

- `$ARGUMENTS`: 다음 중 하나
  - PR 번호 (예: `6381`)
  - GitHub PR URL (예: `https://github.com/TPC-Internet/likey-backend/pull/6381`)
  - 생략 시 현재 브랜치의 PR

---

## 실행 순서

### 0. 인자 파싱

`$ARGUMENTS`에서 PR 번호 추출:

```
- URL인 경우: https://github.com/.../pull/6381 → 6381
- 숫자인 경우: 그대로 사용
- 비어있는 경우: 현재 브랜치의 PR 사용
```

### 1. PR 정보 조회

```bash
# PR 번호/URL이 주어진 경우 (gh는 URL도 직접 처리 가능)
command gh pr view {PR번호 또는 URL} --json number,title,body,files,additions,deletions,author,headRefName,baseRefName,headRefOid

# 인자가 없으면 현재 브랜치의 PR 조회
command gh pr view --json number,title,body,files,additions,deletions,author,headRefName,baseRefName,headRefOid
```

확인할 정보:
| 항목 | 내용 |
|------|------|
| author | PR 작성자 (리뷰 코멘트에 멘션할 대상) |
| title | PR 제목 |
| body | PR 설명 |
| files | 변경된 파일 목록 |
| additions/deletions | 변경 규모 |
| headRefOid | HEAD commit SHA (인라인 코멘트에 필요) |

### 2. 변경 내용 확인

```bash
command gh pr diff {PR번호}
```

diff를 분석하여 다음을 파악:
- 어떤 기능이 추가/수정되었는지
- 변경된 파일들의 역할
- 코드 변경의 의도

### 3. 리뷰 제외 대상 확인

다음 파일/디렉토리는 리뷰 스킵:
- `locales/` - 번역 파일 (자동 생성)
- `po/` - 번역 소스
- `spec/*.yaml` - 자동 생성 스펙
- `src/gen/` - 자동 생성 라우트

### 4. 관련 코드 탐색

변경된 코드를 이해하기 위해 필요시 추가 탐색:

- **기존 코드 확인**: 변경된 파일의 전체 컨텍스트 파악
- **관련 함수 검색**: 사용된 함수나 클래스의 정의 확인
- **유사 패턴 검색**: 코드베이스 내 유사한 구현 참고

### 5. 코드 리뷰 수행

변경된 파일 유형에 따라 해당하는 체크리스트를 적용합니다.

#### 5-A. 에러 핸들링 체크 (모든 TypeScript 파일)

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 에러 패키지 | `@tpcint/api-errors` 패키지만 사용 (http-errors 등 금지) | 🔴 Critical |
| name 메타데이터 | 모든 에러에 `{name: 'ErrorName'}` 옵션 포함 | 🔴 Critical |
| 에러 메시지 | Admin API는 `t()` 없이 한국어 원문 사용, 일반 API는 `t()` 함수 필수 | 🟠 Major |

```typescript
// 잘못된 예시 - name 누락
throw new BadRequestError('에러 발생');
throw new NotFoundError();

// 올바른 예시 - 일반 API (src/api/): t() 함수 필수
throw new BadRequestError(t('에러 메시지'), {name: 'InvalidRequest'});
throw new NotFoundError(t('사용자를 찾을 수 없습니다.'), {name: 'UserNotFound'});

// 올바른 예시 - Admin API (src/admin-api/): t() 없이 한국어 원문
throw new BadRequestError('유효하지 않은 요청입니다.', {name: 'InvalidRequest'});
throw new NotFoundError('사용자를 찾을 수 없습니다.', {name: 'UserNotFound'});
```

#### 5-B. 계층 아키텍처 체크 (Controller 파일)

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 컨트롤러 역할 | 파라미터 검증, 서비스 호출, 응답 매핑만 수행 | 🟠 Major |
| Datastore 접근 | 컨트롤러에서 Model 클래스 직접 사용 금지 | 🔴 Critical |
| 데코레이터 | `@Tags`, `@Security` 데코레이터 존재 확인 | 🔴 Critical |
| Admin API | `@Security('admin_api_token')` 사용 확인 | 🔴 Critical |

#### 5-C. 타입 안전성 체크

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 타입 단언 | 불필요한 `as` 캐스팅 확인 | 🟠 Major |
| 반환 타입 | 선언된 반환 타입과 실제 반환값 일치 확인 | 🟠 Major |

```typescript
// 경고: 타입 안전성 침해 가능
const user = {uid} as UserItem;

// 권장: 명시적 타입 정의
const user: Pick<UserItem, 'uid'> = {uid};
```

#### 5-D. 코드 스타일 체크

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| ES Modules | import 시 `.js` 확장자 필수 | 🟠 Major |
| const 우선 | `let` 대신 `const` 사용 권장 | 🟡 Minor |
| 로깅 | `console.log` 대신 `log.info/warn/error` 사용 | 🟠 Major |
| 날짜 라이브러리 | `dayjs` 사용 (`moment` 금지) | 🟠 Major |
| 유틸리티 | `es-toolkit` 사용 (`lodash` 금지) | 🟠 Major |

#### 5-E. Redis 캐싱 체크

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 캐시 무효화 | Datastore 쓰기 후 `removeByKey()` 호출 확인 | 🟠 Major |

```typescript
// 필수 패턴
tx.addCommitCb(async () => await redisShardManager.removeByKey('Prefix', key));
```

#### 5-F. 파라미터 검증 체크

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| limit 검증 | 최대값 제한 여부 확인 | 🟡 Minor |
| undefined 처리 | 배열 destructuring에서 undefined 가능성 체크 | 🟠 Major |

```typescript
const [uid] = getChannelUids(cid);  // uid가 undefined일 수 있음
if (!uid) throw new BadRequestError(...);  // 검증 필요
```

#### 5-G. 비즈니스 로직 체크

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 데이터 무결성 | 매출/통계 계산 로직 정확성 (pending vs confirmed) | 🔴 Critical |
| 감사 로그 | 민감정보 접근 시 모든 항목 기록 확인 | 🟠 Major |
| 부분 실패 | 일부 데이터 조회 실패 시 전체 API 실패 방지 | 🟠 Major |
| 조건 분기 | 모든 케이스가 처리되었는지 확인 | 🟠 Major |

#### 5-H. 보안 체크

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 시크릿 | `SecretFetcher` 사용 (하드코딩 금지) | 🔴 Critical |
| 인젝션 | SQL/NoSQL 인젝션, 명령어 인젝션 취약점 | 🔴 Critical |
| 권한 체크 | 적절한 인증/인가 확인 | 🔴 Critical |

### 6. 인라인 코멘트용 라인 번호 계산

피드백이 필요한 각 코드에 대해 **정확한 라인 번호**를 계산해야 합니다.

#### 라인 번호 계산 방법

1. **diff에서 해당 파일의 hunk 헤더 확인**:
   ```bash
   command gh pr diff {PR번호} | sed -n '/^+++ b\/{파일경로}/,/^diff --git/p' | grep "^@@"
   ```
   예: `@@ -150,18 +153,24 @@` → 새 파일에서 153번 라인부터 시작

2. **hunk 내에서 해당 코드의 위치 계산**:
   - 공백으로 시작하는 줄: 기존 코드 (라인 번호 증가)
   - `+`로 시작하는 줄: 새로 추가된 코드 (라인 번호 증가)
   - `-`로 시작하는 줄: 삭제된 코드 (라인 번호 증가 안 함)

3. **실제 라인 번호 계산**:
   - hunk 시작 라인 + (해당 줄까지의 공백/+ 줄 수 - 1)

### 7. 리뷰 코멘트 작성 (인라인 + 요약)

**GitHub API를 사용하여 전체 요약과 인라인 코멘트를 한 번에 작성합니다.**

```bash
command gh api repos/{owner}/{repo}/pulls/{PR번호}/reviews \
  -X POST \
  --input - << 'EOF'
{
  "commit_id": "{headRefOid}",
  "event": "COMMENT",
  "body": "## 코드 리뷰 요약\n\n@{author} 리뷰 확인 부탁드립니다!\n\n### 전체 요약\n{전체 요약 내용}\n\n### 리뷰 요약\n| 심각도 | 개수 |\n|--------|------|\n| 🔴 Critical | 0 |\n| 🟠 Major | 1 |\n| 🟡 Minor | 0 |\n| 💬 Comment | 2 |",
  "comments": [
    {
      "path": "src/path/to/file.ts",
      "line": 123,
      "side": "RIGHT",
      "body": "🔴 **Critical**: NotFoundError에 name 메타데이터 누락\n\n모든 에러는 `name` 옵션을 포함해야 합니다.\n\n```typescript\n// 현재\nthrow new NotFoundError();\n\n// 수정\nthrow new NotFoundError(undefined, {name: 'UserNotFound'});\n```"
    }
  ]
}
EOF
```

#### 인라인 코멘트 필드 설명
| 필드 | 설명 |
|------|------|
| `path` | 파일 경로 (repo root 기준) |
| `line` | 새 파일 기준 라인 번호 |
| `side` | `"RIGHT"` (새 코드) 또는 `"LEFT"` (삭제된 코드) |
| `body` | 코멘트 내용 (마크다운 지원) |

#### 심각도 레벨
| 레벨 | 설명 | 예시 |
|------|------|------|
| 🔴 Critical | 반드시 수정 필요 | name 누락, 보안 취약점, Datastore 직접 접근 |
| 🟠 Major | 수정 권장 | console.log, 캐시 무효화 누락, moment/lodash 사용 |
| 🟡 Minor | 개선 제안 | 주석 없음, let 사용, limit 검증 없음 |
| 💬 Comment | 질문 또는 의견 | 로직 확인, 의도 질문 |

---

## 출력 형식

```markdown
## PR #{번호} 코드 리뷰 완료

**제목**: {PR 제목}
**작성자**: @{author}
**변경**: +{additions} -{deletions} ({files}개 파일)

### 작성된 인라인 코멘트
| 파일 | 라인 | 심각도 | 내용 |
|------|------|--------|------|
| `src/path/to/file.ts` | 123 | 🔴 Critical | NotFoundError에 name 누락 |
| `src/another/file.ts` | 456 | 🟠 Major | console.log 사용 |

### 리뷰 요약
| 심각도 | 개수 |
|--------|------|
| 🔴 Critical | 1 |
| 🟠 Major | 1 |
| 🟡 Minor | 0 |
| 💬 Comment | 0 |

### 잘된 점
- {긍정적인 피드백}

### 리뷰 링크
{리뷰 HTML URL}
```

---

## 자동 검사 패턴

다음 검사는 grep으로 자동 수행:

```bash
# console.log 사용 확인
command gh pr diff {PR번호} | grep -n "console\\.log"

# moment 사용 확인
command gh pr diff {PR번호} | grep -n "from 'moment'"

# lodash 사용 확인
command gh pr diff {PR번호} | grep -n "from 'lodash'"

# name 없는 에러 throw 확인
command gh pr diff {PR번호} | grep -n "throw new.*Error(" | grep -v "{name:"

# import 확장자 누락 확인
command gh pr diff {PR번호} | grep -n "from '@" | grep -v "\\.js'"
```

---

## 트러블슈팅

### "Line could not be resolved" 에러
- 라인 번호가 diff 범위 내에 있어야 합니다
- hunk 헤더의 시작 라인 번호를 기준으로 계산했는지 확인하세요
- 새로 추가된 파일은 `side: "RIGHT"`를 사용하세요

### 인라인 코멘트가 안 보이는 경우
- `commit_id`가 정확한지 확인 (PR의 HEAD commit SHA)
- `path`가 정확한 파일 경로인지 확인 (앞에 `/` 없이)

---

## 주의사항

- 기존 코드의 문제점은 지적하되, PR 범위 외 수정은 별도 이슈로 제안
- 스타일 이슈는 기능 이슈보다 낮은 우선순위로 취급
- 자동 생성 파일은 리뷰 스킵
- PR 작성자에게 건설적이고 구체적인 피드백 제공
