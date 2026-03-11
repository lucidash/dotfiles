---
name: resolve-review
description: PR 리뷰 피드백을 처리합니다. "리뷰 반영해줘", "피드백 처리해줘", "change request 해결해줘" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "[-i | --interactive] [PR번호 또는 URL 또는 silent review 파일 경로]"
allowed-tools: Bash, Glob, Grep, Read, Edit, Write, AskUserQuestion
---

# PR Review Resolver

PR의 리뷰 코멘트를 분석하고 처리합니다.

**Arguments:** `$ARGUMENTS`

## 모드 선택

Arguments에서 옵션을 파싱합니다:

- `--interactive` 또는 `-i`: **Interactive Mode** - 각 코멘트를 하나씩 확인
- 옵션 없음: **Batch Mode** - 모든 코멘트를 한번에 처리
- **Silent Review 파일 경로** (예: `/tmp/pr-review-6381.md`): **Silent Mode** - `pr-review --silent`로 생성된 파일을 읽어 GitHub 흔적 없이 코드만 수정

### Silent Mode 감지

다음 중 하나라도 해당하면 Silent Mode로 진입합니다:

1. `$ARGUMENTS`에 `/tmp/pr-review-*.md` 파일 경로가 명시된 경우
2. **같은 대화에서 `pr-review --silent`가 실행되어 파일이 생성된 경우** — 인자 없이 `/resolve-review`만 호출해도 해당 파일을 자동으로 사용

자동 감지 시 터미널에 사용할 파일 경로를 표시합니다:
```
Silent Review 파일 감지: /tmp/pr-review-6381.md
```

---

## 공통: PR 정보 조회

### 1. 레포 및 PR 자동 감지

```bash
# 현재 레포 정보
repo=$(command gh repo view --json nameWithOwner --jq '.nameWithOwner')
owner=$(echo $repo | cut -d'/' -f1)
repo_name=$(echo $repo | cut -d'/' -f2)

# PR 번호 (인자가 없으면 현재 브랜치에서 감지)
pr_number=$(command gh pr view --json number --jq '.number')
```

### 2. 프로젝트 가이드 문서 참조

```bash
# CLAUDE.md 조회 (main 브랜치)
command gh api repos/{owner}/{repo}/contents/CLAUDE.md?ref=main \
  --jq '.content' | base64 -d
```

### 3. 리뷰 코멘트 조회

```bash
# 리뷰 스레드 조회 (GraphQL - resolved 상태 포함)
command gh api graphql -f query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          path
          line
          comments(first: 10) {
            nodes {
              id
              body
              author { login }
            }
          }
        }
      }
    }
  }
}' -f owner={owner} -f repo={repo} -F pr={pr_number}
```

### 4. 코멘트 분류

Priority 순으로 정렬:
- **P1 (Critical)**: 버그, 보안 이슈, 런타임 오류
- **P2 (Major)**: 컨벤션 위반, 성능 이슈
- **P3 (Minor)**: 코드 스타일, 가독성
- **P4 (Info)**: 참고사항, 질문

---

## Batch Mode (기본)

모든 코멘트를 Priority 순서로 일괄 처리:

1. 해당 파일 읽기
2. 코멘트 내용에 따라 코드 수정
3. 수정 완료 후 다음 코멘트로

### 코드 수정 및 커밋

```bash
# 1. 코드 수정 (Edit 도구 사용)

# 2. 타입 체크 및 린트
npm run check && npm run lint

# 3. 커밋 및 푸시
git add {modified_files}
git commit -m "fix: 리뷰 피드백 반영 - {간략 설명}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
git push
```

### 결과 요약

```markdown
## 리뷰 처리 결과

### 처리된 코멘트
| Priority | 파일 | 변경 내용 |
|----------|------|-----------|
| P2 | src/foo.ts:42 | moment → dayjs 교체 |

### 변경된 파일
- src/foo.ts

### 다음 단계
1. `npm run build` (필요시)
2. `npm run lint:prod`
```

---

## Interactive Mode (`-i`, `--interactive`)

각 코멘트를 하나씩 확인하며 처리합니다.

### 각 코멘트 표시 형식

```markdown
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## [1/12] @{reviewer} - {priority}
**파일:** `{path}:{line}`
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{comment body}

### 제안 코드 (있는 경우)
```diff
- old code
+ new code
```
```

### 선택지 제공

**AskUserQuestion 도구**를 사용하여 선택지 제공:

| 옵션 | 설명 |
|------|------|
| **적용** | 제안된 변경사항 그대로 적용 |
| **수정 적용** | 의도를 반영하여 적절히 수정 후 적용 |
| **스킵** | 이 코멘트 건너뛰기 |
| **모두 적용** | 남은 모든 코멘트 Batch로 자동 적용 |
| **종료** | 처리 중단하고 요약 보기 |

### 선택에 따른 처리

#### 적용 (Apply)
- 제안된 코드 변경이 있으면 해당 파일의 해당 라인을 수정
- Edit 도구를 사용하여 정확한 위치에 변경 적용

#### 수정 적용 (Modify & Apply)
- 해당 파일의 관련 코드를 읽어서 컨텍스트 파악
- 코멘트 의도를 반영하여 적절한 수정안 제안
- 적용 후 다음 코멘트로

#### 스킵 (Skip)
- 해당 코멘트를 "skipped" 목록에 추가
- 다음 코멘트로 진행

#### 모두 적용 (Apply All)
- Interactive 모드 종료
- 남은 코멘트를 Batch 모드로 자동 처리

#### 종료 (Exit)
- 현재까지의 처리 결과 요약
- 남은 코멘트 목록 표시

### 진행 상황 표시

```
[=====>    ] 5/12 완료 | 적용: 3 | 스킵: 1 | 수정: 1
```

### 최종 요약

```markdown
## Interactive Review 완료

### 처리 결과
- 적용: 5개
- 수정 적용: 2개
- 스킵: 3개
- 미처리: 2개

### 변경된 파일
1. src/foo.ts (2 changes)
2. src/bar.ts (1 change)

### 빌드 확인 필요
npm run build && npm run lint:prod
```

---

## 코멘트 답글 달기 (필수!)

> ⚠️ **중요**: 모든 리뷰 코멘트에는 반드시 답글을 달아야 합니다!
> - 반영한 경우: 무엇을 어떻게 수정했는지 답글 + resolve
> - 반영하지 않은 경우: **반드시** 그 이유를 답글로 설명 (resolve 하지 않음)

### GraphQL Mutation 사용 (REST API는 ID 호환 문제로 사용 불가)

> **주의**: GraphQL 멀티라인 쿼리 + 변수 조합은 `gh api graphql`에서 파싱 에러 발생 가능.
> 안정적인 방법으로 `gh pr comment`를 사용하거나, 한 줄 쿼리로 작성.

```bash
# 방법 1: gh pr comment 사용 (권장 - 가장 안정적)
command gh pr comment {PR_NUMBER} --repo {OWNER}/{REPO} --body "리뷰 피드백 반영 완료: {변경 내용 요약}"

# 방법 2: GraphQL 한 줄 쿼리 (변수 없이 직접 값 삽입)
command gh api graphql -f query='mutation { addPullRequestReviewThreadReply(input: {body: "수정했습니다.", pullRequestReviewThreadId: "{THREAD_ID}"}) { comment { id } } }'
```

**참고**: `THREAD_ID`는 리뷰 스레드 조회 시 반환되는 `id` 필드 값 (예: `PRRT_kwDOI5PQj85sJRaA`)

## 스레드 Resolve

```bash
# 변수 없이 직접 threadId 삽입 (안정적)
command gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "{THREAD_ID}"}) { thread { isResolved } } }'
```

```bash
# 반영하지 않는 경우 → 반드시 사유 답글 (resolve 하지 않음!)
command gh api graphql -f query='
mutation($body: String!, $threadId: ID!) {
  addPullRequestReviewThreadReply(input: {
    body: $body,
    pullRequestReviewThreadId: $threadId
  }) {
    comment { id }
  }
}' -f body="반영하지 않습니다. {구체적인 사유}" -f threadId="{THREAD_ID}"
```

**주의사항**:
- Thread ID는 `PRRT_` 접두사로 시작하는 GraphQL ID 사용
- REST API의 `/pulls/comments/{id}/replies`는 GraphQL ID와 호환되지 않음
- 반영하지 않는 리뷰에 답글 없이 넘어가면 안 됨!

## API 타입 하드코딩 리뷰 처리 (노션 추적)

API 응답 타입 하드코딩 리뷰가 나왔는데 `npm run update-spec`으로 해결되지 않는 경우 (서버 PR이 아직 main에 미머지), 노션을 통해 서버 PR을 추적하여 스펙을 업데이트합니다.

### 추적 흐름

```
PR 제목의 [LK-XXXX] → 노션 검색 → Tasks relation → 개발작업
→ 과제 relation → 상위 개발과제 → 작업 relation → 서버 작업
→ PR Link → 서버 PR 번호
```

### 단계별 실행

```bash
# 1. npm run update-spec 먼저 시도 (main 브랜치 기준)
npm run update-spec
# → 스펙에 엔드포인트가 있으면 바로 타입 교체

# 2. 없으면: PR 제목에서 LK-ID 추출 후 노션 검색
# mcp__tpc-notion__API-post-search로 "LK-XXXX" 검색

# 3. 검색 결과에서 Tasks relation ID 추출
# → mcp__tpc-notion__API-retrieve-a-page로 개발작업 조회

# 4. 개발작업의 "과제" relation → 상위 개발과제 조회
# → 개발과제의 "작업" relation에서 서버 파트 작업 찾기 (파트: "Server")

# 5. 서버 작업의 "PR Link" rollup에서 PR 번호 추출 (예: #6721)

# 6. 서버 PR 기반 스펙 업데이트
./tools/gen-admin-api-types.sh -p {서버PR번호}
```

### 주의사항
- `npm run update-spec`은 main 브랜치 기준이므로 미머지 서버 PR의 새 엔드포인트는 포함되지 않음
- `-p` 옵션은 해당 PR의 브랜치에서 스펙을 가져옴
- 스펙 업데이트 시 이 PR과 무관한 변경도 포함될 수 있으므로 diff 확인 필요
- 서버 PR에도 스펙이 없으면 서버 작업 완료까지 대기 (답글로 사유 설명)

---

## 자동 Resolve 대상

CI에서 검증되는 항목은 자동 resolve:
- `locales/*.json` 파일의 번역 문자열 누락 (Lokalise 관리)
- 린트/포맷팅 관련 (CI에서 자동 수정)

## 패턴 분석 연동 (Confirm 필수)

리뷰 피드백 반영 중 프로젝트 패턴이 불확실할 때, **사용자 확인 후** `analyze-repo-patterns` 스킬을 호출합니다.

### 호출 시점

- 리뷰어가 "프로젝트 패턴을 따르라"고 했는데 어떤 패턴인지 불확실할 때
- 수정 방향이 여러 가지일 때 프로젝트 표준 확인 필요
- 반박 시 근거 자료가 필요할 때

### 1단계: 사용자 확인 (AskUserQuestion)

패턴 확인이 필요하다고 판단되면, **먼저 사용자에게 확인**합니다:

```json
{
  "questions": [{
    "question": "'{패턴명}' 패턴의 프로젝트 사용례를 확인할까요?",
    "header": "패턴 확인",
    "options": [
      {"label": "확인", "description": "프로젝트 내 사용례와 최근 PR 분석"},
      {"label": "건너뛰기", "description": "확인 없이 진행"}
    ],
    "multiSelect": false
  }]
}
```

### 2단계: 조건부 실행

- **"확인"** 선택 시 → Task 도구로 패턴 분석 실행
- **"건너뛰기"** 선택 시 → 분석 없이 피드백 처리 계속

### 3단계: 호출 방법 (승인된 경우만)

```
Task 도구 사용:
- subagent_type: "Explore"
- prompt: |
    analyze-repo-patterns 스킬을 실행하여 '{패턴}' 패턴을 분석해줘.
    - 현재 코드베이스에서 사용 현황
    - 최근 머지된 PR에서의 사용례
    - 권장 패턴 결론
```

### 예시 흐름

```
[resolve-review 진행 중...]

리뷰어 코멘트: "이 부분은 프로젝트 패턴에 맞게 수정해주세요"

Claude: 리뷰어가 프로젝트 패턴을 따르라고 했는데,
        정확한 패턴을 확인하면 좋을 것 같습니다.

        ┌─────────────────────────────────────────┐
        │ 'useDialog' 패턴의 프로젝트 사용례를    │
        │ 확인할까요?                              │
        │                                          │
        │  [확인]  [건너뛰기]                     │
        └─────────────────────────────────────────┘

User: [확인] 클릭

Claude: [analyze-repo-patterns 실행...]

        분석 결과: useDialog composable이 권장됩니다.
        최근 PR #1091에서도 동일한 방식 사용.

        [해당 패턴으로 코드 수정...]
```

### 반박 시 활용

분석 결과 기존 코드가 이미 프로젝트 패턴을 따르고 있다면, 근거와 함께 답글:

```bash
command gh api graphql -f query='
mutation($body: String!, $threadId: ID!) {
  addPullRequestReviewThreadReply(input: {
    body: $body,
    pullRequestReviewThreadId: $threadId
  }) {
    comment { id }
  }
}' -f body="분석 결과 현재 구현이 프로젝트 패턴과 일치합니다.
- 동일 패턴 사용 파일: 45개
- 참고 PR: #1091, #1088
기존 방식을 유지합니다." -f threadId="{THREAD_ID}"
```

---

## 주의사항

- CLAUDE.md의 컨벤션을 우선 따름
- 프로젝트 전반의 기존 패턴 확인 후 일관성 유지
- 수정 전 반드시 타입 체크/린트 통과 확인
- **패턴 확인이 필요하면 analyze-repo-patterns 스킬을 호출할 것 (사용자 confirm 필수)**

### ⚠️ 리뷰 답글 필수 규칙

| 상황 | 필수 행동 |
|------|----------|
| 제안 수락/반영 | 답글 달기 ("수정했습니다. {내용}") + **resolve** |
| 제안 거절/미반영 | **반드시** 답글로 사유 설명 + resolve 하지 않음 |
| 나중에 처리 예정 | 답글 달기 ("별도 작업으로 진행 예정입니다. {사유}") |

> 🚫 **금지**: 리뷰 코멘트를 답글 없이 무시하거나, 사유 설명 없이 resolve 하는 것

## Silent Mode (파일 기반)

`pr-review --silent`로 생성된 리뷰 파일을 읽어, **GitHub에 코멘트/resolve 없이** 코드만 수정합니다.

### 실행 흐름

1. **파일 읽기**: Read tool로 지정된 md 파일 읽기
2. **구조화 데이터 추출**: 파일 하단의 ` ```json ` 블록에서 리뷰 데이터 파싱
3. **각 코멘트 처리**: 코멘트의 path, line, body를 분석하여 코드 수정
4. **GitHub API 호출 없음**: 댓글 작성, thread resolve 모두 스킵
5. **커밋 & push**: 수정사항만 커밋

### 상세 절차

#### 1. Silent Review 파일 읽기

```bash
# Read tool로 파일 내용 읽기
# 파일 경로 예: /tmp/pr-review-6381.md
```

#### 2. 구조화 데이터 파싱

파일 하단의 `## 구조화 데이터` 섹션에서 JSON 블록을 추출합니다:

```json
{
  "pr": { "number": 6381, "title": "...", "headRefName": "...", "baseRefName": "..." },
  "repository": "TPC-Internet/likey-backend",
  "comments": [
    { "path": "src/path.ts", "line": 123, "side": "RIGHT", "severity": "...", "title": "...", "body": "..." }
  ]
}
```

#### 3. 코멘트 분석 및 코드 수정

각 코멘트에 대해:
1. 해당 파일 읽기 (Read tool)
2. 코멘트 본문에서 문제점과 수정 제안 파악
3. 코드 수정 제안이 있으면 수정 (Edit tool)
4. 수정이 불필요하거나 의도적 설계인 경우 스킵 (터미널에만 사유 출력)

#### 4. GitHub API 호출 없음

> **핵심**: Silent Mode에서는 GitHub API를 일절 호출하지 않습니다.
> - ❌ `addPullRequestReviewThreadReply` 없음
> - ❌ `resolveReviewThread` 없음
> - ❌ `gh pr comment` 없음

#### 5. 커밋 & push

```bash
git add {modified_files}
git commit -m "fix: 코드 리뷰 피드백 반영 (silent)

- {수정 내용 요약}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push
```

### 출력 형식

```markdown
## PR #{번호} Silent Review 처리 완료

**제목**: {PR 제목}
**소스 파일**: {silent review 파일 경로}

### 처리 결과

| # | 파일 | 라인 | 심각도 | 처리 | 내용 |
|---|------|------|--------|------|------|
| 1 | `src/path.ts` | 123 | 🔴 Critical | ✅ 수정 | 에러 name 추가 |
| 2 | `src/other.ts` | 456 | 🟡 Minor | ⏭️ 스킵 | 의도적 설계 |

### 요약
- 수정: {N}건
- 스킵: {M}건
- 커밋: {있음/없음}
```

---

## Usage

```bash
# Batch Mode (기본)
/resolve-review
/resolve-review 123

# Interactive Mode
/resolve-review -i
/resolve-review --interactive 123
/resolve-review -i https://github.com/org/repo/pull/123

# Silent Mode (pr-review --silent 출력 파일)
/resolve-review /tmp/pr-review-6381.md
```
