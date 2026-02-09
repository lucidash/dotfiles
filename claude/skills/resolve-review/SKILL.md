---
name: resolve-review
description: PR 리뷰 피드백을 처리합니다. "리뷰 반영해줘", "피드백 처리해줘", "change request 해결해줘" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "[-i | --interactive] [PR번호 또는 URL]"
allowed-tools: Bash, Glob, Grep, Read, Edit, Write, AskUserQuestion
---

# PR Review Resolver

PR의 리뷰 코멘트를 분석하고 처리합니다.

**Arguments:** `$ARGUMENTS`

## 모드 선택

Arguments에서 옵션을 파싱합니다:

- `--interactive` 또는 `-i`: **Interactive Mode** - 각 코멘트를 하나씩 확인
- 옵션 없음: **Batch Mode** - 모든 코멘트를 한번에 처리

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

## 코멘트 답글 달기

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
  addPullRequestReviewThreadReply(input: {body: $body, pullRequestReviewThreadId: $threadId}) {
    comment { id body }
  }
}' -f body="분석 결과 현재 구현이 프로젝트 패턴과 일치합니다.
- 동일 패턴 사용 파일: 45개
- 참고 PR: #1091, #1088
기존 방식을 유지합니다." -f threadId={THREAD_ID}
```

---

## 주의사항

- CLAUDE.md의 컨벤션을 우선 따름
- 프로젝트 전반의 기존 패턴 확인 후 일관성 유지
- 수정 전 반드시 타입 체크/린트 통과 확인
- 반박 시에도 정중하게 사유 설명
- **패턴 확인이 필요하면 analyze-repo-patterns 스킬을 호출할 것 (사용자 confirm 필수)**

## Usage

```bash
# Batch Mode (기본)
/resolve-review
/resolve-review 123

# Interactive Mode
/resolve-review -i
/resolve-review --interactive 123
/resolve-review -i https://github.com/org/repo/pull/123
```
