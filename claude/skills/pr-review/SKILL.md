---
name: pr-review
description: PR을 리뷰할 때, 코드 리뷰해달라고 할 때, PR 봐달라고 할 때, GitHub PR URL이 대화에 등장할 때 사용. Repository를 자동 감지하여 프로젝트별 맞춤 리뷰 가이드를 적용합니다.
allowed-tools: Bash, Glob, Grep, Read, Task
---

# 통합 PR 코드 리뷰

PR을 분석하고 **Repository를 자동 감지**하여 프로젝트별 맞춤 코드 리뷰를 수행합니다.

## 지원 프로젝트

| Repository | 가이드 파일 | 설명 |
|------------|-------------|------|
| `likey-backend` | `guides/backend.md` | Node.js Express 백엔드 |
| `likey-admin-v2` | `guides/admin-v2.md` | Vue 3 어드민 프론트엔드 |
| `likey-web` | `guides/likey-web.md` | Nuxt.js 2 프론트엔드 |
| 기타 | `guides/common.md` | 공통 체크리스트만 적용 |

## 트리거 키워드

- "리뷰해줘", "코드 리뷰", "PR 봐줘"
- "이 PR 확인해줘", "리뷰 부탁"
- GitHub PR URL 감지: `github.com/.../pull/...`
- PR 번호와 함께 "확인", "검토" 언급

## 인자

- `$ARGUMENTS`: PR 대상 + 옵션 플래그
  - PR URL (예: `https://github.com/TPC-Internet/likey-backend/pull/6381`)
  - PR 번호 (예: `6381`) - 현재 디렉토리의 repo 기준
  - 생략 시 현재 브랜치의 PR
  - `--interactive` 또는 `-i`: 대화형 모드 (각 코멘트를 사용자에게 확인)
  - 예: `/pr-review 6381 -i`, `/pr-review https://...pull/6381 --interactive`

### 동작 모드

| 모드 | 플래그 | 동작 |
|------|--------|------|
| **일괄 게시** (기본) | 없음 | 모든 인라인 코멘트를 확인 없이 즉시 게시 |
| **대화형** | `--interactive`, `-i` | 각 코멘트를 사용자에게 보여주고 게시/건너뛰기 확인 |

---

## 실행 전략: 2인 1조 리뷰 (Subagent 위임)

Context window 보호와 리뷰 품질을 위해 **2인 1조 토론 방식**으로 리뷰합니다.
Reviewer A가 먼저 리뷰하면, Reviewer B가 비판적 사고로 각 지적의 합리성을 검증합니다.
A와 B는 총 3라운드 토론을 진행하고, 토론을 통과한 코멘트만 게시합니다.

| 단계 | 담당 | 작업 |
|------|------|------|
| 0. 인자 파싱 & Repo 감지 | 메인 에이전트 | PR 번호 추출, `--interactive` 감지, Repository 감지, 가이드 로딩 |
| 1. Reviewer A 초기 리뷰 | **Subagent A** | PR diff 분석, 코드 탐색, 체크리스트 리뷰, 라인 번호 계산 |
| 1.5. A-B 토론 (3라운드) | **Subagent B** | A의 각 지적을 비판적으로 검증, 3라운드 토론 후 합리적 코멘트만 통과 |
| 1.7. 코멘트 확인 (대화형만) | 메인 에이전트 | `--interactive` 시에만: 토론 통과 코멘트를 사용자에게 보여주고 승인/건너뛰기 확인 |
| 2. 리뷰 게시 | 메인 에이전트 | 기본: 통과 코멘트 전체 게시 / 대화형: **승인된** 코멘트만 게시 |

---

## 실행 순서

### 0. 인자 파싱 & Repository 감지 (메인 에이전트)

#### 플래그 파싱

`$ARGUMENTS`에서 `--interactive` 또는 `-i` 플래그를 감지합니다:

- `$ARGUMENTS`에 `--interactive` 또는 `-i`가 포함되어 있으면 → **대화형 모드**
- 그 외 → **일괄 게시 모드** (기본)

플래그를 제거한 나머지를 PR 대상으로 사용합니다.
예: `/pr-review 6381 -i` → PR 번호 `6381`, 대화형 모드

#### PR 정보 조회

```bash
# URL이 주어진 경우 - gh가 URL 직접 처리
command gh pr view {URL} --json number,title,body,files,additions,deletions,author,headRefName,baseRefName,headRefOid,url

# 번호만 주어진 경우
command gh pr view {번호} --json number,title,body,files,additions,deletions,author,headRefName,baseRefName,headRefOid,url

# 인자 없는 경우 - 현재 브랜치 PR
command gh pr view --json number,title,body,files,additions,deletions,author,headRefName,baseRefName,headRefOid,url
```

#### Repository 자동 감지

PR URL에서 repository 이름을 추출합니다:

```
https://github.com/TPC-Internet/likey-backend/pull/6381
                   └────────────┬────────────┘
                           owner/repo
```

**추출 방법**:
- PR 정보의 `url` 필드에서 파싱
- 또는 `command gh pr view --json baseRepository` 사용

```bash
# Repository 정보 확인
command gh pr view {PR} --json url | grep -oP '(?<=github.com/)[^/]+/[^/]+'
```

**Repository → 가이드 매핑**:

| Repository 이름 | 적용할 가이드 |
|-----------------|--------------|
| `likey-backend` | `guides/backend.md` + `guides/common.md` |
| `likey-admin-v2` | `guides/admin-v2.md` + `guides/common.md` |
| `likey-web` | `guides/likey-web.md` + `guides/common.md` |
| 기타 | `guides/common.md` 만 적용 |

#### 프로젝트별 가이드 로딩

감지된 repository에 따라 해당 가이드 파일을 Read 도구로 로딩합니다:

```
/Users/muzi/.claude/skills/pr-review/guides/backend.md
/Users/muzi/.claude/skills/pr-review/guides/admin-v2.md
/Users/muzi/.claude/skills/pr-review/guides/likey-web.md
/Users/muzi/.claude/skills/pr-review/guides/common.md
```

**중요**: 반드시 해당 가이드 파일을 읽고, 내용을 Subagent 프롬프트에 포함해야 합니다.

### 1. Reviewer A: 초기 리뷰 분석

`Task` tool (`subagent_type: general-purpose`)을 실행합니다. 이 Subagent가 **Reviewer A** 역할을 합니다.

**Subagent A 프롬프트에 반드시 포함할 내용:**

1. PR 번호, owner/repo
2. 로딩한 가이드 파일 내용 전체 (common.md + 프로젝트별 가이드)
3. 아래 "리뷰 제외 대상" 정보
4. 아래 "인라인 코멘트용 라인 번호 계산" 섹션
5. Subagent 반환 형식

**Subagent가 수행할 작업:**

1. **PR diff 조회**:
   ```bash
   command gh pr diff {PR번호}
   ```

2. **리뷰 제외 대상 필터링**

3. **관련 코드 탐색**: 변경된 파일의 전체 코드 읽기, 관련 함수/클래스 정의 탐색

4. **체크리스트 기반 리뷰 수행**: common.md 공통 체크리스트 + 프로젝트별 가이드 체크리스트

5. **자동 검사 패턴 실행** (가이드에 정의된 grep 패턴)

6. **인라인 코멘트 라인 번호 계산** (diff hunk 기반)

**Subagent 반환 형식 (반드시 이 JSON 구조로 응답 마지막에 포함):**

````
```json
{
  "pr": {
    "number": 6381,
    "title": "PR 제목",
    "author": "author-login",
    "headRefOid": "abc123...",
    "additions": 100,
    "deletions": 50,
    "fileCount": 5
  },
  "repository": "TPC-Internet/likey-backend",
  "guide": "backend",
  "summary": "전체 변경 요약 (마크다운)",
  "positives": ["잘된 점 1", "잘된 점 2"],
  "comments": [
    {
      "path": "src/path/to/file.ts",
      "line": 123,
      "side": "RIGHT",
      "severity": "🔴 Critical",
      "title": "짧은 제목",
      "body": "🔴 **Critical**: 상세 설명\n\n```typescript\n// 수정 제안\n```"
    }
  ],
  "counts": {
    "critical": 0,
    "major": 1,
    "minor": 0,
    "comment": 2
  }
}
```
````

### 1.5. Reviewer B: A-B 토론 (3라운드)

Reviewer A의 결과를 받아 **Reviewer B** (별도 Subagent)가 비판적 검증을 수행합니다.

**코멘트가 0개인 경우**: 이 단계를 스킵하고 요약만 게시합니다.

`Task` tool (`subagent_type: general-purpose`)로 새 Subagent를 실행합니다.

**Subagent B 프롬프트에 반드시 포함할 내용:**

1. PR 번호, owner/repo, PR diff (또는 diff 조회 명령어)
2. 로딩한 가이드 파일 내용 전체 (common.md + 프로젝트별 가이드)
3. **Reviewer A의 전체 결과 JSON** (comments 배열 포함)
4. 아래 토론 규칙 및 반환 형식

**Subagent B의 역할과 토론 규칙:**

Subagent B는 내부적으로 **Reviewer A (제안자)** 와 **Reviewer B (검증자)** 두 역할을 번갈아 수행하며 3라운드 토론을 진행합니다.

#### 토론 프로세스

Reviewer A의 각 코멘트에 대해 다음 3라운드를 진행합니다:

**라운드 1 - B의 비판적 검증:**
- 이 지적이 실제로 문제인가? False positive가 아닌가?
- PR 코드를 직접 확인하여 A의 주장이 사실에 기반하는가?
- 지적의 심각도가 적절한가? (과장되었거나 과소평가되었는가?)
- PR 범위 내의 변경사항에 대한 지적인가?
- 실질적인 개선이 되는 제안인가, 단순한 취향 차이인가?

**라운드 2 - A의 반론 및 B의 재검토:**
- A의 입장에서 반론: 왜 이 지적이 유효한지 근거 제시
- B의 재검토: A의 반론을 고려하여 입장 수정 또는 유지
- 필요시 관련 코드를 추가로 탐색하여 사실 확인

**라운드 3 - 최종 합의:**
- 각 코멘트에 대해 최종 판정: **통과(PASS)** 또는 **탈락(DROP)**
- 통과한 코멘트는 토론 과정에서 개선된 내용으로 body 업데이트 가능
- 탈락 사유를 간결하게 기록

#### 판정 기준

**통과 (PASS)** - 다음 중 하나 이상:
- 실제 버그 또는 런타임 오류를 유발할 수 있는 문제
- 보안 취약점
- 가이드라인에 명확히 위반되는 사항 (근거 있음)
- 동작 변경이 의도된 것인지 확인이 필요한 합리적 질문
- 구체적이고 실행 가능한 개선 제안

**탈락 (DROP)** - 다음 중 하나 이상:
- False positive (코드를 다시 확인하면 문제 없음)
- 단순 취향/스타일 차이 (가이드에 명시되지 않은 선호)
- PR 범위 밖의 기존 코드에 대한 지적
- 너무 사소하여 리뷰 노이즈가 되는 지적
- 근거 없는 추측성 우려 (실제 문제 재현 불가)

#### Subagent B 반환 형식

````
```json
{
  "debate": {
    "totalFromA": 4,
    "passed": 2,
    "dropped": 2,
    "rounds": [
      {
        "commentIndex": 0,
        "commentTitle": "A의 원래 코멘트 제목",
        "verdict": "PASS",
        "round1_critique": "B의 비판 요약 (1-2문장)",
        "round2_rebuttal": "A의 반론 + B의 재검토 요약 (1-2문장)",
        "round3_conclusion": "최종 합의 (1문장)",
        "finalBody": "토론 후 개선된 코멘트 본문 (PASS인 경우만)"
      },
      {
        "commentIndex": 1,
        "commentTitle": "A의 원래 코멘트 제목",
        "verdict": "DROP",
        "round1_critique": "B의 비판 요약",
        "round2_rebuttal": "A의 반론 + B의 재검토 요약",
        "round3_conclusion": "탈락 사유"
      }
    ]
  },
  "passedComments": [
    {
      "path": "src/path/to/file.ts",
      "line": 123,
      "side": "RIGHT",
      "severity": "🟠 Major",
      "title": "짧은 제목",
      "body": "토론 후 개선된 코멘트 본문"
    }
  ],
  "summary": "A의 원본 summary 유지 또는 보완",
  "positives": ["A의 원본 positives 유지 또는 보완"],
  "counts": {
    "critical": 0,
    "major": 1,
    "minor": 0,
    "comment": 0
  }
}
```
````

**메인 에이전트는 Subagent B의 결과에서:**
- `passedComments` 배열을 최종 코멘트 목록으로 사용
- `debate.rounds`를 최종 출력의 토론 결과 섹션에 표시

### 1.7. 코멘트 확인 - 대화형 모드만 (메인 에이전트)

토론을 통과한 `passedComments` 배열을 처리합니다.

**통과 코멘트가 0개인 경우**: 이 단계를 스킵하고 요약만 게시합니다.

#### 일괄 게시 모드 (기본)

`--interactive` 플래그가 없으면 **통과 코멘트를 확인 없이 바로 게시**합니다.
단계 2로 즉시 진행하여 전체 통과 코멘트를 게시합니다.

#### 대화형 모드 (`--interactive` / `-i`)

각 통과 코멘트에 대해 `AskUserQuestion`을 호출하여 사용자 확인을 받습니다:

- markdown preview에 파일 경로, 라인, 심각도, 코멘트 본문, **토론 요약**을 표시
- 선택지:
  - **게시** (Recommended): 이 코멘트를 그대로 게시
  - **건너뛰기**: 이 코멘트를 게시하지 않음
  - **나머지 모두 게시**: 현재 코멘트 포함, 이후 코멘트를 모두 승인 (빠른 진행용)
  - Other: 사용자가 코멘트 내용을 직접 수정하여 입력 → 수정된 내용으로 게시

```
AskUserQuestion 호출 예시:

question: "이 코멘트를 게시할까요? (N/M건)"
header: "리뷰 코멘트"
options:
  - label: "게시 (Recommended)"
    description: "이 코멘트를 그대로 게시합니다"
    markdown: |
      **파일**: `src/path/to/file.ts` L123
      **심각도**: 🔴 Critical
      **토론 결과**: PASS (3라운드 합의)

      > **B의 검증**: 실제로 런타임 에러 가능성 확인됨
      > **최종 합의**: A의 지적이 유효, 수정 필요

      ---

      🔴 **Critical**: NotFoundError에 name 메타데이터 누락

      모든 에러는 `name` 옵션을 포함해야 합니다.

      ```typescript
      // 수정 제안
      throw new NotFoundError(undefined, {name: 'UserNotFound'});
      ```
  - label: "건너뛰기"
    description: "이 코멘트를 게시하지 않습니다"
  - label: "나머지 모두 게시"
    description: "현재 코멘트 포함, 남은 코멘트를 모두 게시합니다"
```

**처리 로직:**
- "게시" 선택 → 승인 목록에 추가, 다음 코멘트로 진행
- "건너뛰기" 선택 → 건너뛴 목록에 추가, 다음 코멘트로 진행
- "나머지 모두 게시" 선택 → 현재 코멘트 포함 나머지 모두 승인 목록에 추가, 루프 종료
- Other (사용자 수정) → 코멘트의 body를 사용자 입력으로 교체하여 승인 목록에 추가

### 2. 리뷰 게시 (메인 에이전트)

Subagent B 결과의 `passedComments`를 파싱하여 GitHub API로 리뷰를 게시합니다.

- **일괄 게시 모드** (기본): `passedComments` 배열의 **모든 코멘트**를 게시
- **대화형 모드** (`-i`): 단계 1.7에서 **승인된 코멘트만** 게시

#### 게시할 코멘트가 없는 경우 (토론에서 전부 탈락 또는 대화형에서 전부 건너뜀)

코멘트가 없는 경우 = 지적할 사항 없음이므로, 요약 리뷰 게시와 함께 **자동으로 APPROVE** 처리합니다:

1. `event: "APPROVE"`로 요약 리뷰 게시 (인라인 코멘트 없이)
2. 별도의 `gh pr review --approve` 불필요

```bash
# 모든 코멘트 건너뛴 경우 - APPROVE로 게시
command gh api repos/{owner}/{repo}/pulls/{PR번호}/reviews \
  -X POST \
  --input - << 'EOF'
{
  "commit_id": "{headRefOid}",
  "event": "APPROVE",
  "body": "## 코드 리뷰 요약\n\n..."
}
EOF
```

PR URL에서 owner/repo를 추출하여 사용:

```bash
command gh api repos/{owner}/{repo}/pulls/{PR번호}/reviews \
  -X POST \
  --input - << 'EOF'
{
  "commit_id": "{headRefOid}",
  "event": "COMMENT",
  "body": "## 코드 리뷰 요약\n\n@{author} 리뷰 확인 부탁드립니다!\n\n### 감지된 프로젝트\n**{repository}** - {가이드 설명}\n\n### 전체 요약\n{전체 요약 내용}\n\n### 리뷰 통계\n| 심각도 | 개수 |\n|--------|------|\n| 🔴 Critical | 0 |\n| 🟠 Major | 1 |\n| 🟡 Minor | 0 |\n| 💬 Comment | 2 |",
  "comments": [
    {
      "path": "src/path/to/file.ts",
      "line": 123,
      "side": "RIGHT",
      "body": "🔴 **Critical**: 문제 설명\n\n```typescript\n// 수정 제안\n```"
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

---

## 심각도 레벨 (공통)

| 레벨 | 설명 | 예시 |
|------|------|------|
| 🔴 Critical | 반드시 수정 필요 | 보안 취약점, 버그 유발, 잘못된 API 사용 |
| 🟠 Major | 수정 권장 | 가이드라인 위반, deprecated API 사용 |
| 🟡 Minor | 개선 제안 | 코드 스타일, 성능 최적화 |
| 💬 Comment | 질문 또는 의견 | 로직 확인, 의도 질문 |

---

## 출력 형식

```markdown
## PR #{번호} 코드 리뷰 완료

**제목**: {PR 제목}
**작성자**: @{author}
**Repository**: {owner}/{repo}
**적용 가이드**: {프로젝트 가이드 이름}
**변경**: +{additions} -{deletions} ({files}개 파일)

### A-B 토론 결과
| # | 코멘트 | A의 주장 | B의 검증 | 판정 |
|---|--------|----------|----------|------|
| 1 | 문제 설명 | 유효한 버그 | 확인됨, 동의 | PASS |
| 2 | 스타일 제안 | 가이드 위반 | 가이드에 명시 없음 | DROP |

- Reviewer A 제안: N건
- 토론 통과: M건
- 탈락: K건

### 게시 결과
- 모드: {일괄 게시 | 대화형}
- 게시: N건
- 건너뜀: M건 (대화형 모드에서만 표시)

### 작성된 인라인 코멘트
| 파일 | 라인 | 심각도 | 내용 |
|------|------|--------|------|
| `src/path/to/file.ts` | 123 | 🔴 Critical | 문제 설명 |
| `src/another/file.ts` | 456 | 🟠 Major | 문제 설명 |

### 리뷰 요약 (토론 통과 기준)
| 심각도 | 개수 |
|--------|------|
| 🔴 Critical | 1 |
| 🟠 Major | 1 |
| 🟡 Minor | 0 |
| 💬 Comment | 0 |

### 잘된 점
- {긍정적인 피드백}

### 리뷰 링크
{GitHub 리뷰 URL}
```

---

## 리뷰 제외 대상 (Subagent 참조용)

**공통 제외**:
- 자동 생성 파일
- 번역 파일

**Backend 제외**:
- `locales/` - 번역 파일
- `po/` - 번역 소스
- `spec/*.yaml` - 자동 생성 스펙
- `src/gen/` - 자동 생성 라우트

**Admin V2 제외**:
- `src/api/` - 자동 생성 API 타입
- `auto-imports.d.ts`, `components.d.ts`

**likey-web 제외**:
- `models/spec/likey-api.ts` - 백엔드 OpenAPI 스펙에서 자동 생성
- `locales/*.json` - Lokalise에서 자동 동기화

---

## 인라인 코멘트용 라인 번호 계산 (Subagent 참조용)

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

---

## 트러블슈팅

### Repository 감지 실패
- PR URL이 없는 경우: 현재 디렉토리의 git remote 확인
- `git remote get-url origin`으로 repo 추론

### "Line could not be resolved" 에러
- 라인 번호가 diff 범위 내에 있어야 합니다
- hunk 헤더의 시작 라인 번호를 기준으로 계산했는지 확인
- 새로 추가된 파일은 `side: "RIGHT"`를 사용

### 인라인 코멘트가 안 보이는 경우
- `commit_id`가 정확한지 확인 (PR의 HEAD commit SHA)
- `path`가 정확한 파일 경로인지 확인 (앞에 `/` 없이)

---

## 패턴 분석 연동 (Confirm 필수)

리뷰 중 "이 패턴이 프로젝트에서 어떻게 사용되는지" 확인이 필요할 때, **사용자 확인 후** `analyze-repo-patterns` 스킬을 sub agent로 호출합니다.

### 호출 시점

- 코드에서 여러 방식이 혼재되어 있을 때 (예: `ConfirmDialog ref` vs `useConfirmDialog`)
- 프로젝트 표준 패턴이 불확실할 때
- 리뷰 코멘트에 참고 PR을 첨부하고 싶을 때
- 새로운 패턴/라이브러리가 도입된 경우

### 1단계: 사용자 확인 (AskUserQuestion)

패턴 분석이 필요하다고 판단되면, **먼저 사용자에게 확인**합니다:

```json
{
  "questions": [{
    "question": "'{패턴명}' 패턴의 프로젝트 사용례를 분석할까요?",
    "header": "패턴 분석",
    "options": [
      {"label": "분석 실행", "description": "최근 PR과 코드베이스에서 사용례 확인"},
      {"label": "건너뛰기", "description": "분석 없이 리뷰 계속 진행"}
    ],
    "multiSelect": false
  }]
}
```

**여러 패턴이 의심될 때**:

```json
{
  "questions": [{
    "question": "다음 패턴들의 프로젝트 사용례를 분석할까요?",
    "header": "패턴 분석",
    "options": [
      {"label": "useDialog", "description": "다이얼로그 composable 패턴"},
      {"label": "notifyError", "description": "에러 처리 패턴"},
      {"label": "전체 분석", "description": "위 패턴 모두 분석"},
      {"label": "건너뛰기", "description": "분석 없이 진행"}
    ],
    "multiSelect": true
  }]
}
```

### 2단계: 조건부 실행

- **"분석 실행"** 선택 시 → Task 도구로 패턴 분석 실행
- **"건너뛰기"** 선택 시 → 분석 없이 리뷰 계속

### 3단계: 호출 방법 (승인된 경우만)

```
Task 도구 사용:
- subagent_type: "Explore"
- prompt: |
    analyze-repo-patterns 스킬을 실행하여 '{패턴}' 패턴을 분석해줘.
    - 현재 코드베이스에서 사용 현황
    - 최근 머지된 PR에서의 사용례
    - 권장 패턴 및 참고 PR 링크
```

### 예시 흐름

```
[pr-review 진행 중...]

Claude: PR에서 `useDialog` 대신 `ref<InstanceType<typeof ConfirmDialog>>`
        방식을 사용하고 있네요.

        ┌─────────────────────────────────────────┐
        │ 'useDialog' 패턴의 프로젝트 사용례를    │
        │ 분석할까요?                              │
        │                                          │
        │  [분석 실행]  [건너뛰기]                │
        └─────────────────────────────────────────┘

User: [분석 실행] 클릭

Claude: [analyze-repo-patterns 실행...]

        분석 결과, 프로젝트에서는 useDialog composable이
        87개 파일에서 사용 중이고, ref 방식은 레거시 3개만
        남아있습니다.

        [리뷰 코멘트 작성 계속...]
```

결과를 받아 리뷰 코멘트에 반영:
- "최근 PR #1091, #1088에서는 `useConfirmDialog()` 사용"
- "권장: composable 방식으로 변경"

---

## 주의사항

- 기존 코드의 문제점은 지적하되, PR 범위 외 수정은 별도 이슈로 제안
- 스타일 이슈는 기능 이슈보다 낮은 우선순위로 취급
- 자동 생성 파일은 리뷰 스킵
- PR 작성자에게 건설적이고 구체적인 피드백 제공
- **반드시 해당 프로젝트의 가이드 파일을 읽고 체크리스트를 적용할 것**
- **패턴 확인이 필요하면 analyze-repo-patterns 스킬을 sub agent로 호출할 것**
