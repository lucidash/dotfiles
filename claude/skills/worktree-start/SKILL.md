---
name: worktree-start
description: 브랜치 작업 시작 - Worktree 생성/전환 + 변경사항 분석을 한 번에 수행
tools: Read, Bash, Glob, Grep
---

# Worktree 작업 시작

브랜치명 또는 이슈 번호를 받아 해당 작업을 시작할 수 있도록 worktree 설정과 컨텍스트 분석을 한 번에 수행합니다.

## 사용법

```
/worktree-start <브랜치명|이슈번호>
```

예시:
- `/worktree-start feature/user-auth` - 브랜치명으로 시작
- `/worktree-start LK-1234` - 이슈 번호로 시작 (feature/LK-1234 브랜치 사용)

## 워크플로우

### 1단계: 입력 파싱

`$ARGUMENTS`에서 브랜치 식별자를 파싱합니다:
- `feature/xxx`, `fix/xxx`, `hotfix/xxx` 형태면 브랜치명으로 사용
- `LK-xxxx` 형태면 `feature/LK-xxxx` 브랜치로 변환
- 그 외는 `feature/$ARGUMENTS` 형태로 브랜치명 생성

### 2단계: 기존 Worktree 확인

```bash
git worktree list
```

해당 브랜치의 worktree가 이미 존재하는지 확인합니다.

### 3단계: Worktree 준비

#### 3-A. 기존 Worktree 존재 시 (별도 디렉토리)

해당 worktree 경로를 사용합니다.

#### 3-B. 메인 Worktree가 해당 브랜치 사용 중일 때 (중요!)

메인 worktree(프로젝트 기본 디렉토리)가 해당 브랜치를 checkout한 상태라면:

1. 메인 worktree를 `master` 브랜치로 전환
2. 해당 브랜치로 새 worktree 생성

```bash
# 메인 worktree를 master로 전환
git checkout master

# 새 worktree 생성
git worktree add "$PARENT_DIR/${PROJECT_NAME}-${BRANCH_NAME}" "$BRANCH_NAME"
```

**이유**: 메인 worktree는 항상 `master` 브랜치로 유지하고, 피처/픽스 브랜치는 별도 worktree에서 작업하는 것이 권장 패턴입니다.

#### 3-C. 새 Worktree 필요 시

```bash
# 프로젝트 루트 경로 파악
PROJECT_ROOT=$(git rev-parse --show-toplevel)
PROJECT_NAME=$(basename $PROJECT_ROOT)
PARENT_DIR=$(dirname $PROJECT_ROOT)

# 브랜치 존재 여부 확인
git branch -a | grep -q "$BRANCH_NAME"

# 브랜치가 있으면 checkout, 없으면 새로 생성
if [ 브랜치_존재 ]; then
  git worktree add "$PARENT_DIR/${PROJECT_NAME}-${BRANCH_NAME}" "$BRANCH_NAME"
else
  git worktree add -b "$BRANCH_NAME" "$PARENT_DIR/${PROJECT_NAME}-${BRANCH_NAME}"
fi
```

### 4단계: 이전 세션 확인

해당 worktree 경로에서 이전 Claude Code 세션이 있는지 확인합니다:

```bash
# 프로젝트 경로 해시 기반 세션 디렉토리 확인
# Claude Code는 프로젝트 경로를 기반으로 세션을 저장함
ls -la ~/.claude/projects/ | grep -i "{프로젝트명}" || echo "세션 없음"
```

### 5단계: 세션 전환 안내

Worktree 경로와 세션 옵션을 사용자에게 안내합니다:

```markdown
## Worktree 준비 완료

| 항목 | 값 |
|------|-----|
| 브랜치 | `{브랜치명}` |
| 경로 | `{worktree_경로}` |
| 상태 | {새로 생성됨 / 기존 사용} |

### 세션 전환

**이전 세션 이어서 작업** (권장):
\`\`\`bash
cd {worktree_경로} && claude -c
\`\`\`

**새 세션 시작**:
\`\`\`bash
cd {worktree_경로} && claude
\`\`\`

**세션 선택해서 재개**:
\`\`\`bash
cd {worktree_경로} && claude --resume
\`\`\`
```

### 6단계: 변경사항 분석 (Checkout 역할)

해당 브랜치의 컨텍스트를 분석합니다:

```bash
# 브랜치 상태
git -C {worktree_경로} rev-list --left-right --count main...HEAD

# 커밋 히스토리 (main 대비)
git -C {worktree_경로} log --oneline main..HEAD

# 변경된 파일 목록
git -C {worktree_경로} diff --name-status main...HEAD

# 작업 상태
git -C {worktree_경로} status --short
```

### 7단계: 컨텍스트 요약

```markdown
## 브랜치 컨텍스트

### 커밋 현황
main 대비 **+{N}** 커밋

| 커밋 | 메시지 |
|------|--------|
| abc1234 | feat: ... |
| def5678 | fix: ... |

### 변경된 파일
| 상태 | 파일 |
|------|------|
| M | src/components/Foo.vue |
| A | src/utils/bar.ts |

### 작업 상태
- 수정된 파일: {N}개
- 스테이징된 파일: {N}개
- Untracked: {N}개

### 관련 PR
{PR 정보 또는 "PR 없음 - `/open-pr`로 생성 가능"}

---

### 작업 재개 포인트
{마지막 커밋 메시지와 변경 파일을 기반으로 현재 작업 상태 요약}
```

### 8단계: 관련 PR 확인

```bash
command gh pr list --head {브랜치명} --json number,title,state,url
```

PR이 있으면 정보 표시, 없으면 `/open-pr` 안내

## 출력 형식

```markdown
## Worktree 작업 시작: `{브랜치명}`

### Worktree 정보
| 항목 | 값 |
|------|-----|
| 경로 | `{경로}` |
| 브랜치 | `{브랜치명}` |
| 상태 | {새로 생성 / 기존 사용} |

### 세션 전환

**이전 세션 이어서 작업** (권장):
\`\`\`bash
cd {경로} && claude -c
\`\`\`

**새 세션 시작**:
\`\`\`bash
cd {경로} && claude
\`\`\`

### 브랜치 컨텍스트
- main 대비: **+{N}** 커밋
- 변경 파일: **{N}**개
- 작업 상태: {clean / {N}개 수정됨}

### 최근 커밋
{커밋 목록}

### 변경 파일 요약
{파일별 변경 상태}

### 관련 PR
{PR 정보 또는 생성 안내}

---

### 작업 재개 추천
{현재 상태 기반 다음 작업 제안}
```

## 주의사항

- 현재 worktree에 uncommitted 변경사항이 있으면 경고
- 브랜치명에 특수문자가 있으면 디렉토리명 정규화
- remote 브랜치만 있는 경우 자동으로 tracking 설정
- **메인 worktree는 항상 `master` 브랜치로 유지** - 피처/픽스 브랜치 작업은 반드시 별도 worktree에서 수행
