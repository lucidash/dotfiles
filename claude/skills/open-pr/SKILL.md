---
name: open-pr
description: PR을 생성할 때, PR을 만들어달라고 할 때, PR 올려달라고 할 때, 머지 요청할 때, 커밋 후 PR 생성이 필요할 때 사용. 변경사항을 GitHub에 PR로 올리고 싶을 때 자동으로 활성화됩니다.
allowed-tools: Bash, Read, Glob, Grep
---

# PR 생성

현재 변경사항으로 PR을 생성합니다.

## 트리거 키워드

- "PR 만들어줘", "PR 올려줘", "PR 생성해줘"
- "머지 요청", "풀 리퀘스트"
- "이제 PR", "PR 부탁"
- 커밋 완료 후 "올려줘", "push 해줘"

## 워크플로우

### 1단계: 현재 상태 확인

```bash
# 변경사항 확인
git status

# 스테이징되지 않은 변경사항 확인
git diff

# 스테이징된 변경사항 확인
git diff --cached

# 현재 브랜치 확인
git branch --show-current
```

### 2단계: 커밋 필요 여부 판단

- 스테이징된 변경사항이 있으면 → 커밋 진행
- 스테이징되지 않은 변경사항만 있으면 → 사용자에게 확인 후 스테이징
- 모든 변경사항이 이미 커밋됨 → 3단계로 진행

### 3단계: 브랜치 확인 및 생성

```bash
# 현재 브랜치가 master/main이면 새 브랜치 필요
CURRENT=$(git branch --show-current)
if [ "$CURRENT" = "master" ] || [ "$CURRENT" = "main" ]; then
  # 커밋 메시지나 변경 내용 기반으로 브랜치명 제안
  git checkout -b feature/적절한-브랜치명
fi
```

### 4단계: 커밋 (필요시)

```bash
# Conventional Commits 형식
git commit -m "$(cat <<'EOF'
feat: 변경 내용 요약

상세 설명 (필요시)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### 5단계: Push

```bash
git push -u origin $(git branch --show-current)
```

### 6단계: PR 생성

```bash
command gh pr create --title "PR 제목" --body "$(cat <<'EOF'
## Summary
- 변경사항 요약

## Test plan
- [ ] 테스트 항목

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## 주의사항

- master/main 브랜치에서 직접 PR 생성 시 새 브랜치 생성 필요
- 커밋 메시지는 Conventional Commits 형식 사용
- PR 본문에 Summary와 Test plan 포함
- push 전 빌드/린트 확인 (CLAUDE.md 규칙)
