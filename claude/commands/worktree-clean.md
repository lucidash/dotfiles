# Worktree 정리

완료된 작업의 worktree를 정리합니다. Merged PR 또는 지정한 worktree를 안전하게 삭제합니다.

## 인자

- `$ARGUMENTS`: (선택) 정리 대상
  - **생략 시**: merged PR의 worktree 자동 탐지 후 확인 요청
  - **경로**: 해당 경로의 worktree 삭제
  - **브랜치명**: 해당 브랜치의 worktree 삭제
  - **all-merged**: 모든 merged PR worktree 일괄 삭제

---

## 실행 순서

### 1. 현재 Worktree 목록 조회

```bash
git worktree list
```

### 2. 정리 대상 식별

#### 자동 탐지 (인자 생략 시)

각 worktree에 대해 PR 상태 확인:

```bash
# 브랜치명으로 PR 상태 조회
command gh pr list --head {브랜치명} --state all --json number,state,mergedAt --jq '.[0]'
```

PR이 merged 상태인 worktree를 정리 대상으로 선정

#### 수동 지정 시

- 경로로 지정: 해당 경로가 worktree인지 확인
- 브랜치명으로 지정: 해당 브랜치의 worktree 경로 찾기

### 3. 사용자 확인

```markdown
## 정리 대상 Worktree

| 경로 | 브랜치 | PR | 상태 |
|------|--------|-----|------|
| ../likey-backend-feature-a | feature/LK-1234 | #123 | merged |
| ../likey-backend-feature-b | feature/LK-5678 | #456 | merged |

위 worktree를 삭제하시겠습니까?
```

AskUserQuestion으로 확인:
- 옵션 1: 모두 삭제
- 옵션 2: 선택적 삭제 (개별 선택)
- 옵션 3: 취소

### 4. Worktree 삭제

```bash
# 변경사항이 없는 경우
git worktree remove {worktree_path}

# 변경사항이 있는 경우 (사용자 확인 후)
git worktree remove --force {worktree_path}
```

### 5. 로컬 브랜치 정리 (선택)

```bash
# merged 브랜치 삭제 여부 확인 후
git branch -d {브랜치명}
```

### 6. 정리 완료 보고

```markdown
## Worktree 정리 완료

### 삭제됨
| 경로 | 브랜치 |
|------|--------|
| ../likey-backend-feature-a | feature/LK-1234 |

### 현재 Worktree
| 경로 | 브랜치 | 상태 |
|------|--------|------|
| /main/path | master | 메인 |
| ../likey-backend-hotfix | hotfix/urgent | 작업 중 |
```

---

## 주의사항

- 메인 worktree(bare repo 또는 최초 clone)는 삭제할 수 없습니다
- 변경사항이 있는 worktree는 `--force` 필요 (데이터 손실 가능)
- 삭제 전 항상 `git stash` 또는 커밋 권장
