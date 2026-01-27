---
name: worktree-handoff
description: Worktree 세션 전환 - 현재 세션을 대상 worktree로 복사하고 CLI 안내
tools: Bash
---

# Worktree 세션 전환

현재 세션을 대상 worktree로 복사하고 CLI 전환 명령어를 안내합니다.

## 사용법

```
/worktree-handoff <worktree_경로>
```

이 스킬은 주로 `/worktree-start` 완료 후 자동으로 호출됩니다.

## 워크플로우

### 1단계: 인자 파싱

`$ARGUMENTS`에서 대상 worktree 경로를 파싱합니다.

### 2단계: 현재 세션 ID 파악

```bash
CURRENT_DIR=$(pwd)
SESSION_DIR_NAME=$(echo "$CURRENT_DIR" | sed 's|/|-|g')
SESSION_DIR="$HOME/.claude/projects/$SESSION_DIR_NAME"

# 가장 최근 수정된 .jsonl 파일에서 세션 ID 추출
CURRENT_SESSION_ID=$(ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | head -1 | xargs basename 2>/dev/null | sed 's/.jsonl$//')
```

### 3단계: 세션 파일 복사

```bash
TARGET_WORKTREE_PATH="$ARGUMENTS"
TARGET_SESSION_DIR_NAME=$(echo "$TARGET_WORKTREE_PATH" | sed 's|/|-|g')
TARGET_SESSION_DIR="$HOME/.claude/projects/$TARGET_SESSION_DIR_NAME"

mkdir -p "$TARGET_SESSION_DIR"
cp "$SESSION_DIR/$CURRENT_SESSION_ID.jsonl" "$TARGET_SESSION_DIR/"
```

### 4단계: CLI 안내 출력

```markdown
---

### 세션 전환

| 현재 세션 ID | `{현재_세션_ID}` |
|--------------|------------------|
| 세션 복사 | ✅ 완료 |

**현재 세션 유지하며 전환** (권장 - 위 대화 내용 포함):
\`\`\`bash
cd {경로} && claude --resume {현재_세션_ID}
\`\`\`

**해당 worktree의 이전 세션 이어서 작업**:
\`\`\`bash
cd {경로} && claude -c
\`\`\`

**새 세션 시작**:
\`\`\`bash
cd {경로} && claude
\`\`\`

**세션 선택해서 재개**:
\`\`\`bash
cd {경로} && claude --resume
\`\`\`
```

## 주의사항

- 이 스킬은 모든 출력이 완료된 후 호출되어야 세션 내용이 완전히 복사됨
- Claude Code는 프로젝트 경로를 `-`로 시작하는 형태로 저장 (예: `-Users-muzi-projects-...`)
