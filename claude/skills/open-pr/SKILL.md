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

### 5.5단계: Admin v2 확인 경로 감지 (likey-admin-v2 레포인 경우)

레포가 `likey-admin-v2`인 경우, 변경된 파일 중 `app/pages/` 하위 파일을 분석하여 QA가 확인해야 할 어드민 페이지 경로를 추출합니다.

```bash
# 변경된 페이지 파일 목록 추출
git diff master..HEAD --name-only | grep '^app/pages/'
```

**경로 변환 규칙**:
1. `app/pages/` 접두사 제거
2. `/index.vue`, `.vue` 확장자 제거
3. `[[param]]` → `:param` (선택 파라미터)
4. `[param]` → `:param` (필수 파라미터)

예시: `app/pages/app/app-version.vue` → `/app/app-version`

**페이지 파일이 없고 컴포넌트만 변경된 경우**: `app/components/` 하위 파일의 도메인 디렉토리명으로 관련 페이지 경로를 추정합니다.

### 6단계: PR 생성

```bash
command gh pr create --title "PR 제목" --body "$(cat <<'EOF'
## Summary
- 변경사항 요약

## 확인 경로 (Admin v2인 경우에만 포함)
| 경로 | 설명 |
|------|------|
| `/app/app-version` | 앱 버전 관리 페이지 |

> Preview URL에 `?_preview={route}` 파라미터를 추가하면 해당 페이지로 바로 이동합니다.

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

---

## 체이닝: 다음 단계 제안

PR 생성이 완료되면 사용자에게 다음 단계를 제안합니다:

```markdown
---

### 다음 단계

PR이 생성되었습니다! Notion 개발 작업과 연결할까요?

`/link-pr-task <Notion 작업 URL 또는 LK-ID>`
```

**자동 연결 조건**:
- 브랜치명에 `LK-XXXX` 패턴이 포함된 경우
- 커밋 메시지에 `LK-XXXX` 패턴이 포함된 경우

이 경우 사용자 확인 후 자동으로 `/link-pr-task` 실행을 제안합니다.
