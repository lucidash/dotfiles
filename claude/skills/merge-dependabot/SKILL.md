---
name: merge-dependabot
description: Dependabot PR들을 일괄 분석하고 머지합니다. "디펜다봇 머지", "dependabot 정리", "의존성 PR 처리" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "[owner/repo 또는 repo명]"
allowed-tools: Bash, Glob, Grep, Read, Task, AskUserQuestion, WebFetch, WebSearch, TodoWrite
---

# Dependabot PR 일괄 분석 및 머지

Dependabot이 생성한 의존성 업데이트 PR들을 **병렬 subagent**로 분석하고, 영향도 리포트를 제공한 뒤, 사용자 승인 후 일괄 머지합니다.

## 트리거 키워드

- "디펜다봇", "dependabot", "의존성 PR"
- "디펜던시 업데이트", "dependency update"
- "패키지 업데이트 PR 정리"

## 인자

- `$ARGUMENTS`: 다음 중 하나
  - `owner/repo` (예: `tpcint/likey-backend`)
  - `repo명` (예: `likey-backend`) — owner는 `tpcint`로 기본 설정
  - 생략 시 현재 디렉토리의 repo 사용

---

## 실행 순서

### 1. Repository 결정

```bash
# 인자가 있으면 파싱
# owner/repo 형식이면 그대로 사용
# repo명만 있으면 tpcint/{repo}로 조합
# 인자 없으면 현재 디렉토리에서 감지
repo=$(command gh repo view --json nameWithOwner --jq '.nameWithOwner')
```

### 2. 프로젝트 CLAUDE.md 로딩

해당 repo의 CLAUDE.md를 로딩하여 프로젝트 기술 스택과 컨벤션을 파악합니다.

**로컬 디렉토리가 있는 경우** (repo명으로 추정):
```bash
# ~/projects/{repo}/CLAUDE.md 읽기
cat ~/projects/{repo}/CLAUDE.md
```

**로컬에 없는 경우**:
```bash
command gh api repos/{owner}/{repo}/contents/CLAUDE.md?ref=main --jq '.content' | base64 -d
```

### 3. Open Dependabot PR 목록 조회

```bash
command gh pr list --repo {owner}/{repo} --author "app/dependabot" --state open --json number,title,url,headRefName --limit 50
```

PR이 없으면 "열린 Dependabot PR이 없습니다"로 종료.

### 4. 병렬 Subagent로 각 PR 분석

**각 PR마다 하나의 Task subagent를 background로 소환합니다.**

각 subagent에게 전달할 정보:
- PR 번호, 제목
- owner/repo
- 프로젝트 기술 스택 요약 (CLAUDE.md에서 추출)

각 subagent가 수행할 작업:

```
1. PR diff 확인
   command gh pr diff {PR번호} --repo {owner}/{repo}

2. PR CI 상태 확인
   command gh pr checks {PR번호} --repo {owner}/{repo}

3. 라이브러리 변경사항 조사
   - 웹에서 해당 버전의 릴리즈 노트/changelog 확인
   - Breaking change 여부 확인
   - 보안 패치 포함 여부 확인

4. 프로젝트 내 사용처 검색
   - 해당 패키지의 import/require 검색
   - 사용 패턴과 변경사항의 연관성 분석

5. 결과 리포트 작성 (아래 포맷)
```

**Subagent 리포트 포맷:**
```
- 변경 내용 요약: 어떤 변경이 있는지
- 프로젝트 사용처: 어디서 어떻게 사용하는지
- 영향도: 높음/중간/낮음
- 머지 권장 여부: 머지 가능 / 주의 필요 / 머지 불가
- 근거: 왜 그렇게 판단했는지
```

**Subagent 소환 예시:**
```
Task 도구 사용:
- subagent_type: "general-purpose"
- run_in_background: true
- prompt: |
    {owner}/{repo} 프로젝트에서 Dependabot PR #{번호}를 분석해줘.
    PR: {제목} (예: axios 1.13.4 → 1.13.5)
    프로젝트 경로: {로컬 경로 또는 "로컬 없음"}
    프로젝트 기술 스택: {CLAUDE.md에서 추출한 요약}

    다음을 수행해줘:
    1. `command gh pr diff {번호} --repo {owner}/{repo}` 로 diff 확인
    2. `command gh pr checks {번호} --repo {owner}/{repo}` 로 CI 상태 확인
    3. 웹에서 해당 라이브러리의 릴리즈 노트/changelog 확인
    4. 프로젝트에서 해당 패키지 사용처 검색 (Grep)
    5. Breaking change, 보안 패치 여부 분석

    최종적으로 다음 포맷으로 결과를 알려줘:
    - **변경 내용 요약**: ...
    - **프로젝트 사용처**: ...
    - **CI 상태**: pass / fail / pending
    - **영향도**: 높음/중간/낮음
    - **머지 권장 여부**: 머지 가능 / 주의 필요 / 머지 불가
    - **근거**: ...
```

### 5. 종합 리포트 작성

모든 subagent 결과를 수집하여 종합 테이블을 작성합니다.

```markdown
## Dependabot PR 종합 분석 리포트

### 요약 테이블

| # | PR | 변경 | CI | 영향도 | 판정 | 비고 |
|---|-----|------|-----|--------|------|------|
| 1 | #6690 | axios 1.13.4→1.13.5 | pass | 낮음 | **머지 권장** | 보안 패치 포함 |
| 2 | #6689 | semver 7.7.3→7.7.4 | pass | 낮음 | **머지 가능** | CLI 버그 수정만 |

### 특이사항
- 보안 패치가 포함된 PR은 우선 머지 권장으로 별도 표기
- CI 실패 PR은 머지 불가로 표기
- 영향도가 높은 PR은 상세 설명 추가
```

### 6. 사용자 확인 후 머지

리포트 출력 후 사용자에게 머지 진행 여부를 확인합니다.

```
머지 진행할까요?
```

### 7. 머지 실행

사용자 승인 후 순차적으로 머지합니다.

```bash
# 1. 각 PR approve
command gh pr review {PR번호} --repo {owner}/{repo} --approve --body "Dependabot patch update. Safe to merge."

# 2. squash 머지
command gh pr merge {PR번호} --repo {owner}/{repo} --squash
```

**머지 순서:**
1. 보안 패치 포함 PR 우선
2. 나머지 patch 업데이트
3. minor 업데이트

**충돌 처리:**
- 여러 PR이 `package-lock.json`을 수정하므로, 머지 후 다음 PR이 충돌 상태가 될 수 있음
- 충돌 발생 시 `@dependabot rebase` 코멘트로 rebase 요청
- rebase 후 다시 머지 시도하거나, 사용자에게 알림

```bash
# 충돌 확인
command gh pr view {PR번호} --repo {owner}/{repo} --json mergeable --jq '.mergeable'

# 충돌 시 rebase 요청
command gh pr comment {PR번호} --repo {owner}/{repo} --body "@dependabot rebase"
```

### 8. 최종 결과 보고

```markdown
## 머지 완료 결과

| # | PR | 상태 |
|---|-----|------|
| #6690 | axios 1.13.4→1.13.5 | **머지 완료** |
| #6686 | @google-cloud/run 3.1.0→3.2.0 | **rebase 대기** |

{N}/{M}개 머지 완료. {rebase 대기 PR이 있으면 안내}
```

---

## 주의사항

- `gh` 명령어는 반드시 `command gh`로 실행 (alias 충돌 방지)
- CI가 실패한 PR은 머지하지 않음
- 영향도가 "높음"인 PR은 사용자에게 별도 확인 필요
- `package-lock.json` 충돌은 dependabot rebase로 해결
- 보안 패치(security advisory)가 포함된 PR은 우선 처리
