# Worktree로 세션 전환

현재 Claude Code 세션을 지정된 worktree로 전환합니다.

**중요**: Claude Code 세션은 디렉토리별로 분리되어 있어 `cd`로는 세션을 유지할 수 없습니다. 이 skill은 현재 세션을 대상 worktree로 복사하여 `--resume`으로 이어갈 수 있게 합니다.

## 인자

- `$ARGUMENTS`: (선택) 전환 대상
  - **생략 시**: worktree 목록에서 선택
  - **브랜치명**: 해당 브랜치의 worktree로 전환 (예: `feature/LK-1234`)
  - **경로**: 해당 경로의 worktree로 전환 (예: `../likey-backend-feature-LK-1234`)
  - **번호**: worktree 목록의 인덱스 (예: `2`)

---

## 실행 순서

### 1. 현재 Worktree 목록 조회

```bash
git worktree list
```

### 2. 대상 Worktree 결정

```
인자 유형에 따라:

1. 생략: AskUserQuestion으로 worktree 목록 보여주고 선택 요청
2. 숫자: worktree 목록에서 해당 인덱스의 worktree 선택
3. 경로 (/, ../ 로 시작): 해당 경로가 worktree인지 확인
4. 브랜치명: 해당 브랜치를 사용하는 worktree 찾기
```

### 3. Worktree 유효성 확인

```bash
# 대상 경로가 유효한 worktree인지 확인
git worktree list | grep -q "{TARGET_PATH}"
```

### 4. 세션 복사 실행

Claude Code 세션 데이터를 대상 worktree로 복사합니다.

#### 4.1. 경로 변환 함수

디렉토리 경로를 Claude 세션 폴더명으로 변환 (슬래시 → 대시):
```bash
# 예: /Users/muzi/projects/likey-backend → -Users-muzi-projects-likey-backend
```

#### 4.2. 현재 세션 ID 확인

```bash
# 현재 프로젝트의 세션 인덱스에서 가장 최근 세션 ID 확인
CURRENT_PROJECT_PATH=$(pwd)
CURRENT_SESSION_FOLDER=$(echo "$CURRENT_PROJECT_PATH" | sed 's|/|-|g')
SESSION_INDEX="$HOME/.claude/projects/$CURRENT_SESSION_FOLDER/sessions-index.json"

# 가장 최근 세션 ID (현재 세션)
CURRENT_SESSION_ID=$(cat "$SESSION_INDEX" | jq -r '.entries | last | .sessionId')
```

#### 4.3. 세션 파일 복사

```bash
TARGET_SESSION_FOLDER=$(echo "$TARGET_PATH" | sed 's|/|-|g')
TARGET_SESSION_DIR="$HOME/.claude/projects/$TARGET_SESSION_FOLDER"

# 세션 디렉토리가 없으면 생성
mkdir -p "$TARGET_SESSION_DIR"

# 세션 .jsonl 파일 복사
cp "$HOME/.claude/projects/$CURRENT_SESSION_FOLDER/$CURRENT_SESSION_ID.jsonl" \
   "$TARGET_SESSION_DIR/"

# 세션 폴더 복사 (있는 경우 - scratchpad 등)
if [ -d "$HOME/.claude/projects/$CURRENT_SESSION_FOLDER/$CURRENT_SESSION_ID" ]; then
  cp -r "$HOME/.claude/projects/$CURRENT_SESSION_FOLDER/$CURRENT_SESSION_ID" \
        "$TARGET_SESSION_DIR/"
fi
```

#### 4.4. 대상 sessions-index.json 업데이트

대상 worktree의 `sessions-index.json`에 복사된 세션 정보를 추가합니다.
기존 entries 배열에 새 세션 항목을 추가하거나, 같은 sessionId가 있으면 덮어씁니다.

```bash
# sessions-index.json이 없으면 생성
if [ ! -f "$TARGET_SESSION_DIR/sessions-index.json" ]; then
  echo '{"version":1,"entries":[],"originalPath":"'"$TARGET_PATH"'"}' > "$TARGET_SESSION_DIR/sessions-index.json"
fi

# 새 세션 항목 추가 (jq 사용)
# - sessionId, fullPath 등 업데이트
# - projectPath를 TARGET_PATH로 변경
```

### 5. 결과 보고

```markdown
## Worktree 세션 복사 완료

| 항목 | 값 |
|------|-----|
| 세션 ID | `{CURRENT_SESSION_ID}` |
| 원본 경로 | `{CURRENT_PROJECT_PATH}` |
| 대상 경로 | `{TARGET_PATH}` |
| 브랜치 | `{TARGET_BRANCH}` |

### 세션 이어가기

터미널에서 다음 명령어를 실행하세요:

\`\`\`bash
cd {TARGET_PATH} && claude --resume {CURRENT_SESSION_ID}
\`\`\`

또는:
\`\`\`bash
cd {TARGET_PATH} && claude --continue
\`\`\`
```

---

## 참고

- **세션 복사 방식**: Claude Code는 디렉토리별로 세션이 분리되어 있어, `cd`로는 세션을 유지할 수 없습니다. 대신 세션 파일을 복사하여 대상 worktree에서 `--resume`으로 이어갈 수 있습니다.
- **세션 저장 위치**: `~/.claude/projects/{디렉토리경로를-대시로변환}/`
- **동기화 주의**: 세션이 복사된 후에는 원본과 복사본이 독립적입니다. 양쪽에서 동시에 작업하면 히스토리가 분기됩니다.
- 메인 worktree로 돌아가려면: `/worktree-use master` 또는 `/worktree-use 1`
