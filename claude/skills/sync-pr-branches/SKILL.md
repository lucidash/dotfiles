---
name: sync-pr-branches
description: 열린 PR 브랜치들에 origin/master를 머지하여 최신화합니다. "PR 최신화", "브랜치 싱크", "master 머지", "PR 업데이트" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "[author | --all] [--dry-run] [--repo=backend|admin|admin-v2|all]"
allowed-tools: Bash, Read, Glob, Grep, Agent, AskUserQuestion
---

# PR 브랜치 일괄 최신화 (멀티 레포 지원)

열린 PR 브랜치들 중 기본 브랜치(master/main)와 갭이 있는 것들을 찾아, 서브에이전트를 활용하여 병렬로 머지하고, conflict 발생 시 자동으로 resolve합니다.

**지원 레포:** likey-backend, likey-admin, likey-admin-v2

## 트리거 키워드

- "PR 최신화", "브랜치 싱크", "PR 업데이트"
- "master 머지", "브랜치 업데이트"
- "sync branches", "update PRs"
- "PR에 마스터 머지해줘"

## 인자

- `$ARGUMENTS`: 다음 조합 가능
  - `author`: GitHub username (예: `lucidash`). 생략 시 `command gh api user --jq '.login'`으로 현재 사용자 자동 감지
  - `--all`: author 필터 없이 repo의 **모든** 열린 PR 대상으로 처리
  - `--dry-run`: 실제 push 없이 갭 분석만 수행
  - `--skip-conflicts` (alias: `--sc`): conflict 발생 시 resolve 시도 없이 해당 브랜치 스킵 (clean merge만 처리)
  - `--min-behind=N`: N 커밋 이상 뒤처진 브랜치만 처리 (기본: 1)
  - `--max-behind=N`: N 커밋 이하로 뒤처진 브랜치만 처리 (기본: 무제한)
  - `--repo=REPO`: 대상 레포 지정. 생략 시 **all** (3개 레포 모두 처리)
    - `backend` — likey-backend만
    - `admin` — likey-admin만
    - `admin-v2` — likey-admin-v2만
    - `all` (기본값) — likey-backend + likey-admin + likey-admin-v2 모두

---

## 레포 설정

| 레포 | 로컬 경로 | GitHub | 기본 브랜치 |
|------|-----------|--------|-------------|
| likey-backend | `/Users/muzi/projects/likey-backend` | `tpcint/likey-backend` | `master` |
| likey-admin | `/Users/muzi/projects/likey-admin` | `tpcint/likey-admin` | `master` |
| likey-admin-v2 | `/Users/muzi/projects/likey-admin-v2` | `tpcint/likey-admin-v2` | `main` |

## 실행 순서

### 0단계: 대상 레포 결정

`--repo` 인자로 대상 레포를 결정합니다.

- `--repo` 미지정 시: **기본값 `all`** — 3개 레포 모두를 **순차적으로** 처리 (각 레포 내에서는 병렬)
- `--repo=backend|admin|admin-v2` 시: 해당 레포만 처리

### 1단계: Author 결정

```bash
# author 결정 (인자에서 파싱하거나, 현재 GitHub 사용자)
# 인자가 있으면 해당 author 사용
# 없으면:
author=$(command gh api user --jq '.login')
```

### 2단계: 각 레포별 처리 (레포가 여러 개면 순차 반복)

각 대상 레포에 대해 아래 2-A ~ 2-E를 실행합니다.
여러 레포 처리 시 레포별 구분 헤더를 출력합니다: `## 📦 {repo_name}`

#### 2-A: origin fetch

해당 레포 디렉토리에서:
```bash
cd {repo_path}
default_branch={해당 레포의 기본 브랜치}  # master 또는 main
git fetch origin ${default_branch}
git fetch origin  # 모든 remote branch fetch
```

#### 2-B: 열린 PR 목록 조회

```bash
cd {repo_path}

# --all 옵션인 경우: author 필터 없이 전체 조회
command gh pr list --state open \
  --json number,title,headRefName,baseRefName,author --limit 200

# 특정 author인 경우:
command gh pr list --author {author} --state open \
  --json number,title,headRefName,baseRefName --limit 200
```

PR이 없으면 "{repo_name}: 열린 PR이 없습니다"로 해당 레포 스킵.

#### 2-C: 각 PR 브랜치의 기본 브랜치 대비 갭 분석

각 PR 브랜치에 대해:
```bash
cd {repo_path}
behind=$(git rev-list --count "origin/{branch}..origin/${default_branch}")
ahead=$(git rev-list --count "origin/${default_branch}..origin/{branch}")
```

- `behind == 0`인 브랜치는 이미 최신 → 스킵
- `behind > 0`인 브랜치만 처리 대상

**결과를 테이블로 출력:**
```markdown
### {repo_name} 갭 분석

| Branch | PR# | Behind | Ahead | 상태 |
|--------|-----|--------|-------|------|
| fix/something | #1234 | 3 | 2 | 처리 대상 |
| feat/other | #1235 | 0 | 5 | 이미 최신 |
```

`--dry-run` 인자가 있으면 해당 레포의 갭 분석만 출력하고 다음 레포로 진행.

#### 2-D: 서브에이전트 배분 및 병렬 머지

처리 대상 브랜치를 **6~8개 그룹으로 분배**합니다.

**배분 기준:**
- behind 수가 적은 것부터 많은 것 순으로 정렬
- 그룹당 6~8개 브랜치
- 각 그룹은 하나의 Agent (worktree 격리)로 처리

**각 서브에이전트 프롬프트:**

```
You are working in the {repo_name} repository (path: {repo_path}). Your task is to merge origin/{default_branch} into each of the following PR branches, resolve any conflicts, and push the result.

For each branch below, do the following steps:
1. `git checkout -b {branch} origin/{branch}` (create local tracking branch)
2. `git merge origin/{default_branch}` (merge default branch into it)
3. If there are conflicts:
   - **`--skip-conflicts` 모드**: `git merge --abort`로 머지 취소하고 SKIPPED (conflict) 보고 후 다음 브랜치로 진행
   - **기본 모드 (resolve)**:
     - Analyze the conflicting files
     - Resolve conflicts intelligently based on context (keep both sides' changes where appropriate, prefer {default_branch}'s structural changes while keeping the branch's feature changes)
     {conflict_strategy}
     - `git add` the resolved files
     - `git commit` (use the default merge commit message)
4. `git push origin {branch}` (push the updated branch)
5. Clean up: `git checkout {default_branch} && git branch -D {branch}`

Branches to process:
{브랜치 목록}

IMPORTANT:
- Use `command gh` instead of `gh` for GitHub CLI
- If a merge has no conflicts, just push immediately
- If conflicts are in source code (.ts/.tsx/.vue files), read the conflicting sections carefully and resolve based on context
- Report the result for each branch: SUCCESS (clean merge), SUCCESS (conflicts resolved), or FAILED (with reason)
- Do NOT force push. Use regular `git push origin {branch}`
- Fetch first: `git fetch origin`
```

**서브에이전트 실행:**
```
Agent tool:
- isolation: "worktree"
- run_in_background: true
- 각 그룹별 하나의 Agent 소환
- 모든 Agent를 동시에 (한 메시지에 여러 Agent tool call) 소환하여 병렬 실행
```

#### 2-E: 해당 레포 결과 수집

서브에이전트 완료 후 해당 레포의 결과를 정리합니다.

### 3단계: 종합 리포트

모든 레포 처리 완료 후 종합 결과를 출력합니다.

**단일 레포 모드:**
```markdown
## PR 브랜치 최신화 결과

### 요약
- 전체: {N}개 브랜치
- 성공 (clean merge): {X}개
- 성공 (conflict resolved): {Y}개
- 실패: {Z}개
- 이미 최신: {W}개

### 상세 결과

| # | Branch | PR# | Behind | 결과 | 비고 |
|---|--------|-----|--------|------|------|
| 1 | fix/something | #1234 | 3 | SUCCESS (clean) | - |
| 2 | feat/other | #1235 | 50 | SUCCESS (resolved) | conflict in X |
| 3 | feat/big | #1236 | 500 | FAILED | 수동 resolve 필요 |
```

**멀티 레포 모드 (`--repo=all`):**
```markdown
## PR 브랜치 최신화 종합 결과

### 레포별 요약

| 레포 | 전체 | Clean | Resolved | Failed | 최신 |
|------|------|-------|----------|--------|------|
| likey-backend | 12 | 8 | 2 | 1 | 1 |
| likey-admin | 3 | 3 | 0 | 0 | 0 |
| likey-admin-v2 | 5 | 4 | 0 | 0 | 1 |
| **합계** | **20** | **15** | **2** | **1** | **2** |

### likey-backend 상세
| # | Branch | PR# | Behind | 결과 | 비고 |
|---|--------|-----|--------|------|------|
...

### likey-admin 상세
...

### likey-admin-v2 상세
...
```

**실패한 브랜치가 있으면:**
- 실패 사유와 충돌 파일 목록 표시
- 수동 resolve 방법 안내

---

## Conflict Resolution 전략

### 레포별 전략

서브에이전트 프롬프트의 `{conflict_strategy}` 자리에 레포에 맞는 전략을 삽입합니다.

#### likey-backend

```
- For generated files like `spec/*.yaml` or `src/gen/*`, accept {default_branch}'s version
- For `locales/*.yaml`, accept {default_branch}'s version
- For `package-lock.json`, accept {default_branch}'s version then run `npm install` if needed
- For `index.yaml` (Datastore), keep both sides' index entries
```

#### likey-admin

```
- For `package-lock.json`, accept {default_branch}'s version then run `npm install` if needed
- For config files (firebase.json, etc.), prefer {default_branch}'s version unless the branch intentionally modifies them
```

#### likey-admin-v2

```
- For `package-lock.json`, accept {default_branch}'s version then run `npm install` if needed
- For config files (firebase.json, etc.), prefer {default_branch}'s version unless the branch intentionally modifies them
- For `.vue` files, carefully merge template/script/style sections
```

### 공통 소스 코드 conflict resolve 원칙

1. **Import 충돌**: 양쪽 import를 모두 유지 (additive)
2. **함수/메서드 추가 충돌**: 양쪽 추가분 모두 유지
3. **동일 줄 수정 충돌**: branch의 feature 변경 유지 + 기본 브랜치의 구조적 변경 반영
4. **Enum/Switch 추가 충돌**: 양쪽 case 모두 유지
5. **Test 파일 충돌**: 양쪽 테스트 블록 모두 유지

---

## 주의사항

- `command gh` 사용 (gh alias 충돌 방지)
- force push 절대 금지 — regular `git push` 만 사용
- 머지 실패 시 해당 브랜치 건너뛰고 다음 진행
- 서브에이전트는 반드시 `isolation: "worktree"` 사용 (메인 워킹 디렉토리 보호)
- 각 서브에이전트는 `run_in_background: true`로 병렬 실행
- **기본 브랜치 주의**: likey-admin-v2는 `main`, 나머지는 `master` — 반드시 레포별 설정 참조
- 멀티 레포 모드에서 서브에이전트 프롬프트에 `repo_path`를 명시하여 올바른 디렉토리에서 작업하도록 함
