---
name: wt
description: Git Worktree 관리. "worktree 만들어줘", "브랜치 전환", "wt 목록" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "[list|ls|status|st|clean|handoff] [대상] [-q]"
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, Skill
---

# Git Worktree 관리

Git worktree의 생성, 전환, 목록, 상태, 정리를 통합 관리합니다.

**Arguments:** `$ARGUMENTS`

## 서브커맨드

| 커맨드 | 별칭 | 설명 |
|--------|------|------|
| (기본) | - | Worktree 생성/전환 |
| `list` | `ls` | 모든 worktree 목록 |
| `status` | `st` | 현재 worktree 상태 |
| `clean` | - | merged PR worktree 정리 |
| `handoff` | - | 세션 전환 (내부용) |

## 사용법

```bash
/wt                        # 목록에서 선택
/wt feature/LK-1234        # 해당 브랜치로 생성/전환
/wt LK-1234                # feature/LK-1234로 생성/전환
/wt 6475                   # PR 번호로 브랜치 조회 후 전환
/wt 2                      # worktree 목록 인덱스로 전환 (-q 자동)
/wt -q feature/LK-1234     # Quick 모드 (분석 스킵)

/wt list                   # 모든 worktree 목록
/wt ls                     # 위와 동일

/wt status                 # 현재 worktree 상태
/wt st                     # 위와 동일

/wt clean                  # merged PR worktree 자동 탐지 후 정리
/wt clean all-merged       # 모든 merged worktree 일괄 정리
```

---

## 1. 생성/전환 (기본)

### 인자 파싱

```
1. -q 또는 --quick 플래그 → Quick 모드
2. 숫자 1~9 → worktree 인덱스 (자동 Quick)
3. 숫자 10+ → PR 번호
4. #숫자 → PR 번호
5. github PR URL → PR 번호 추출
6. LK-xxxx → feature/LK-xxxx
7. feature/xxx, fix/xxx → 브랜치명
8. 생략 → 목록에서 선택 (자동 Quick)
```

### 모드 비교

| 항목 | 전체 모드 | Quick 모드 (`-q`) |
|------|-----------|-------------------|
| Worktree 생성/전환 | ✅ | ✅ |
| 의존성 설치 | ✅ | ✅ |
| 환경 파일 복사 | ✅ | ✅ |
| 커밋/변경 분석 | ✅ | ❌ |
| PR 정보 조회 | ✅ | ❌ |
| 세션 복사 + CLI 안내 | ✅ | ✅ |

### 워크플로우

#### Step 1: 기존 Worktree 확인

```bash
git worktree list
```

#### Step 2: Worktree 준비

**기존 존재 시**: 해당 경로 사용

**메인 Worktree가 해당 브랜치일 때**:
```bash
git checkout master
git worktree add "$PARENT_DIR/${PROJECT_NAME}-${BRANCH}" "$BRANCH"
```

**새로 생성 시**:
```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
PROJECT_NAME=$(basename $PROJECT_ROOT)
PARENT_DIR=$(dirname $PROJECT_ROOT)
WORKTREE_PATH="$PARENT_DIR/${PROJECT_NAME}-${BRANCH}"

# 브랜치 존재 여부에 따라
git worktree add "$WORKTREE_PATH" "$BRANCH"          # 있으면
git worktree add -b "$BRANCH" "$WORKTREE_PATH"       # 없으면
```

#### Step 3: 의존성 설치 및 환경 복사

```bash
cd "${WORKTREE_PATH}"

# npm install
[ -f "package.json" ] && npm install

# .env 복사
MAIN=$(git worktree list | head -1 | awk '{print $1}')
for f in .env .env.local; do
    [ -f "${MAIN}/${f}" ] && [ ! -f "${f}" ] && cp "${MAIN}/${f}" .
done
```

#### Step 4: 변경사항 분석 (전체 모드만)

```bash
git rev-list --left-right --count master...HEAD
git log --oneline master..HEAD
git diff --name-status master...HEAD
git status --short
command gh pr list --head {브랜치} --json number,title,state,url
```

#### Step 5: 세션 전환 (handoff)

> **중요**: 세션 복사는 반드시 handoff summary 출력 **후**에 수행해야 합니다.
> 세션 파일은 현재 대화의 스냅샷이므로, summary가 포함된 상태에서 복사해야
> 새 세션에서 브랜치 컨텍스트를 볼 수 있습니다.

**5-1. Session Clear**

먼저 현재 세션을 정리합니다:
```
/clear
```

**5-2. 브랜치 컨텍스트 요약 (먼저 출력)**

대상 브랜치의 상태를 요약하여 **텍스트로 출력**합니다:

```bash
cd "${WORKTREE_PATH}"

# 브랜치 정보
BRANCH=$(git branch --show-current)
COMMITS=$(git rev-list --count master..HEAD 2>/dev/null || echo "0")

# PR 정보
PR_INFO=$(command gh pr list --head "$BRANCH" --json number,title,state,url,body --jq '.[0]' 2>/dev/null)

# 최근 커밋 (최대 5개)
RECENT_COMMITS=$(git log --oneline -5 master..HEAD 2>/dev/null)

# 변경된 파일
CHANGED_FILES=$(git diff --name-status master...HEAD 2>/dev/null | head -20)

# uncommitted 변경사항
UNCOMMITTED=$(git status --short 2>/dev/null)
```

**출력 형식 (Handoff Summary)**:

```markdown
---

## Worktree 전환: `{브랜치명}`

### 브랜치 상태
- **커밋 수**: master 대비 +{N}개
- **PR**: #{number} - {title} ({state})
  - URL: {url}

### 최근 작업 내역
{최근 커밋 목록}

### 변경된 파일 ({N}개)
{파일 목록 - 추가/수정/삭제 표시}

### 미커밋 변경사항
{있으면 표시, 없으면 "없음"}

### PR 설명 (작업 컨텍스트)
{PR body 내용 - 있으면 표시}

---
```

**5-3. 세션 복사 (summary 출력 후)**

> ⚠️ **반드시 위 summary를 출력한 후에 세션 복사 수행**

```bash
# summary 출력 완료 후 세션 복사
SESSION_DIR="$HOME/.claude/projects/-Users-muzi-projects-$(basename $CURRENT_DIR)"
# ... 복사 로직
```

**5-4. CLI 안내 출력**

세션 복사 완료 후 CLI 명령어 안내

---

## 2. list (ls)

모든 worktree 상태를 분석합니다.

```bash
git worktree list --porcelain
```

각 worktree에 대해:
```bash
cd {path}
git status --short
git rev-list --count master..HEAD 2>/dev/null
command gh pr list --head $(git branch --show-current) --json number,title,state --jq '.[0]'
```

### 출력 형식

```markdown
## Git Worktree 현황

| # | 경로 | 브랜치 | 상태 | 커밋 | PR |
|---|------|--------|------|------|-----|
| 1 | /path/main | master | clean | - | - |
| 2 | /path/feature-a | feature/LK-1234 | 3 modified | +5 | #123 (open) |

### 권장 액션
- **정리 필요**: {merged PR worktree}
  - `/wt clean` 실행
```

---

## 3. status (st)

현재 worktree의 상태를 빠르게 파악합니다.

```bash
# 컨텍스트
git rev-parse --show-toplevel
git worktree list | grep "$(pwd)"

# 브랜치 상태
git branch --show-current
git rev-list --left-right --count master...HEAD

# 작업 상태
git status --short
git stash list

# PR
command gh pr list --head $(git branch --show-current) --json number,title,state,url
```

### 출력 형식

```markdown
## 현재 Worktree 상태

| 항목 | 값 |
|------|-----|
| 경로 | `{path}` |
| 브랜치 | `{branch}` |
| master 대비 | +{N} / -{M} |
| 변경사항 | {N}개 수정됨 |
| PR | #{number} ({state}) |
```

---

## 4. clean

merged PR의 worktree를 정리합니다.

### 인자

- 생략: merged worktree 자동 탐지 후 확인
- `all-merged`: 모든 merged worktree 일괄 삭제
- 경로/브랜치명: 해당 worktree 삭제

### 워크플로우

```bash
# 각 worktree의 PR 상태 확인
command gh pr list --head {브랜치} --state all --json number,state,mergedAt --jq '.[0]'
```

merged 상태인 worktree 목록 → AskUserQuestion으로 확인 → 삭제

```bash
git worktree remove {path}
git branch -d {branch}  # 로컬 브랜치도 삭제
```

### 출력 형식

```markdown
## Worktree 정리 완료

| 경로 | 브랜치 | PR |
|------|--------|-----|
| {path} | {branch} | #{number} (merged) |

삭제됨: {N}개
```

---

## 5. handoff (내부용)

세션을 대상 worktree로 복사하고 CLI 전환 명령어를 안내합니다.

> **실행 순서 (중요):**
> 1. Handoff summary 텍스트 출력 (브랜치 상태, PR 정보 등)
> 2. 세션 파일 복사 (summary가 포함된 상태)
> 3. CLI 명령어 안내

```bash
# 1. 먼저 summary 출력 완료 후...

# 2. 세션 복사
CURRENT_DIR=$(pwd)
SESSION_DIR="$HOME/.claude/projects/$(echo $CURRENT_DIR | sed 's|/|-|g')"
SESSION_ID=$(ls -t "$SESSION_DIR"/*.jsonl | head -1 | xargs basename | sed 's/.jsonl$//')

TARGET_SESSION_DIR="$HOME/.claude/projects/$(echo $TARGET | sed 's|/|-|g')"
mkdir -p "$TARGET_SESSION_DIR"
cp "$SESSION_DIR/$SESSION_ID.jsonl" "$TARGET_SESSION_DIR/"

# 3. CLI 안내 출력
```

### 출력

```markdown
### 세션 전환

**현재 세션 유지하며 전환** (권장):
```bash
cd {경로} && claude --resume {세션ID}
```

**새 세션 시작**:
```bash
cd {경로} && claude
```
```

---

## 주의사항

- 메인 worktree는 항상 `master` 브랜치 유지 권장
- uncommitted 변경사항 있으면 경고
- 숫자 1~9는 worktree 인덱스로 해석
