# Worktree 목록 및 상태 확인

현재 모든 worktree의 상태를 확인하고 분석합니다.

## 실행 순서

### 1. Worktree 목록 조회

```bash
git worktree list --porcelain
```

### 2. 각 Worktree 상태 분석

각 worktree에 대해:

```bash
# 해당 worktree 경로로 이동해서 상태 확인
cd {worktree_path}

# 브랜치 상태
git status --short

# base 브랜치(master) 대비 커밋 수
git rev-list --count master..HEAD 2>/dev/null || echo "0"

# 관련 PR 확인
command gh pr list --head $(git branch --show-current) --json number,title,state --jq '.[0]' 2>/dev/null
```

### 3. 결과 출력

```markdown
## Git Worktree 현황

| # | 경로 | 브랜치 | 상태 | 커밋 | PR |
|---|------|--------|------|------|-----|
| 1 | /path/to/main | master | clean | - | - |
| 2 | /path/to/feature-a | feature/LK-1234 | 3 modified | +5 | #123 (open) |
| 3 | /path/to/hotfix | hotfix/urgent | clean | +2 | #456 (merged) |

### 상세 정보

#### 1. {worktree_path}
- **브랜치**: `{브랜치명}`
- **상태**: {clean / N개 수정됨 / N개 스테이징됨}
- **커밋**: master 대비 +{N}
- **PR**: #{번호} - {제목} ({상태})

#### 2. ...

### 권장 액션

- **정리 필요**: {merged PR의 worktree 목록}
  - `git worktree remove {path}` 또는 `/worktree-clean` 실행

- **작업 중**: {open PR의 worktree 목록}
```

---

## 참고

- `--porcelain` 옵션은 스크립트 파싱에 적합한 형식으로 출력
- PR 상태: `open`, `closed`, `merged`
- merged된 PR의 worktree는 정리 대상
