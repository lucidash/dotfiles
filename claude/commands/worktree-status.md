# 현재 Worktree 상태 확인

현재 작업 중인 worktree의 상태와 컨텍스트를 빠르게 파악합니다.

## 실행 순서

### 1. Worktree 컨텍스트 확인

```bash
# 현재 worktree 경로
git rev-parse --show-toplevel

# 메인 worktree인지 확인 (git-dir이 .git 디렉토리인지)
git rev-parse --git-dir

# 모든 worktree에서 현재 위치
git worktree list | grep "$(pwd)"
```

### 2. 브랜치 및 커밋 상태

```bash
# 현재 브랜치
git branch --show-current

# master 대비 상태
git rev-list --left-right --count master...HEAD

# 최근 커밋
git log --oneline -5
```

### 3. 작업 상태

```bash
# 수정/스테이징 파일
git status --short

# stash 목록
git stash list
```

### 4. 관련 PR 확인

```bash
command gh pr list --head $(git branch --show-current) --json number,title,state,url
```

### 5. 결과 출력

```markdown
## Worktree 상태

### 기본 정보
| 항목 | 값 |
|------|-----|
| 경로 | `{현재 경로}` |
| 유형 | {메인 worktree / 연결된 worktree} |
| 브랜치 | `{브랜치명}` |
| 커밋 상태 | master 기준 +{ahead} / -{behind} |

### 작업 상태
- 수정된 파일: {N}개
- 스테이징된 파일: {N}개
- Untracked 파일: {N}개
- Stash: {N}개

### 관련 PR
- **#{번호}**: {제목}
- 상태: {open/merged/closed}
- URL: {PR URL}

### 다른 Worktree
| 경로 | 브랜치 |
|------|--------|
| {path1} | {branch1} |
| {path2} | {branch2} |

---

### 빠른 액션
- PR 생성: `/open-pr`
- 변경사항 분석: `/checkout`
- Worktree 정리: `/worktree-clean`
```
