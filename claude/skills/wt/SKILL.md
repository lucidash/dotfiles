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
| Handoff 파일 생성 + CLI 안내 | ✅ | ✅ |

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

# datastore emulator 데이터 복사 (backend 프로젝트)
[ -d "${MAIN}/.datastore-emulator" ] && [ ! -d ".datastore-emulator" ] && \
    cp -r "${MAIN}/.datastore-emulator" .
```

#### Step 4: 변경사항 분석 (전체 모드만)

```bash
git rev-list --left-right --count master...HEAD
git log --oneline master..HEAD
git diff --name-status master...HEAD
git status --short
command gh pr list --head {브랜치} --json number,title,state,url
```

#### Step 5: Handoff 파일 생성 및 CLI 안내

> **방식**: 세션 파일 복사 대신 `./.claude/handoff.md` 파일을 worktree에 생성합니다.
> 새 세션 시작 시 Claude가 이 파일을 자동으로 읽어 컨텍스트를 파악합니다.

**5-1. 브랜치 정보 수집**

```bash
cd "${WORKTREE_PATH}"

BRANCH=$(git branch --show-current)
COMMITS=$(git rev-list --count master..HEAD 2>/dev/null || echo "0")
BEHIND=$(git rev-list --count HEAD..master 2>/dev/null || echo "0")
PR_INFO=$(command gh pr list --head "$BRANCH" --json number,title,state,url,body --jq '.[0]' 2>/dev/null)
RECENT_COMMITS=$(git log --oneline -5 master..HEAD 2>/dev/null)
CHANGED_FILES=$(git diff --name-status master...HEAD 2>/dev/null | head -20)
UNCOMMITTED=$(git status --short 2>/dev/null)
```

**5-2. `.claude/handoff.md` 파일 생성**

worktree의 .claude 디렉토리에 handoff 파일을 생성합니다:

```bash
mkdir -p "${WORKTREE_PATH}/.claude"
cat > "${WORKTREE_PATH}/.claude/handoff.md" << 'EOF'
# Handoff Context

> 이 파일은 `/wt` 명령으로 자동 생성되었습니다.
> 작업 완료 후 삭제해도 됩니다.

## 브랜치: {브랜치명}

| 항목 | 값 |
|------|-----|
| master 대비 | +{N} commits (behind {M}) |
| PR | #{number} - {title} ({state}) |
| URL | {pr_url} |

## 최근 커밋
{최근 커밋 목록}

## 변경된 파일 ({N}개)
{파일 목록 - A/M/D 표시}

## 미커밋 변경사항
{있으면 표시, 없으면 "없음"}

## PR 설명
{PR body - Summary 섹션}
EOF
```

> **참고**: `.claude/handoff.md`는 `.gitignore`에 추가하는 것을 권장합니다.

**5-3. CLI 안내 출력**

```markdown
---

### 세션 전환

Handoff 파일이 생성되었습니다: `{WORKTREE_PATH}/.claude/handoff.md`

**새 터미널에서 실행**:
```bash
cd {WORKTREE_PATH} && claude
```

---
```

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

Worktree에 `.claude/handoff.md` 파일을 생성하여 컨텍스트를 전달합니다.

> **장점:**
> - 세션 파일 조작 불필요
> - 깨끗한 새 세션으로 시작
> - handoff 파일이 worktree에 남아 언제든 참조 가능
> - `.gitignore`에 추가하면 커밋되지 않음

### 워크플로우

1. 브랜치 정보 수집 (git, gh CLI)
2. `.claude/handoff.md` 파일 생성
3. CLI 전환 명령어 안내

### 출력

```markdown
---

### 세션 전환

Handoff 파일이 생성되었습니다: `{WORKTREE_PATH}/.claude/handoff.md`

**새 터미널에서 실행**:
```bash
cd {경로} && claude
```

---
```

---

## 주의사항

- 메인 worktree는 항상 `master` 브랜치 유지 권장
- uncommitted 변경사항 있으면 경고
- 숫자 1~9는 worktree 인덱스로 해석
