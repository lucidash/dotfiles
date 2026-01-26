# 새 Worktree 생성

새로운 git worktree를 생성하고 작업 환경을 설정합니다.

## 인자

- `$ARGUMENTS`: (선택) 생성 대상
  - **생략 시**: 새 브랜치명 입력 요청
  - **브랜치명**: 해당 이름으로 새 worktree 생성
  - **PR 번호**: `6475` 또는 `#6475` → PR 브랜치 기반 worktree
  - **GitHub PR URL**: PR 브랜치로 worktree 생성
  - **Slack URL**: 스레드에서 관련 PR 찾아서 worktree 생성
  - **Notion URL**: 문서에서 관련 PR 찾아서 worktree 생성
  - **LK-XXXXX**: 이슈 번호로 브랜치명 생성

---

## 실행 순서

### 1. 현재 상태 확인

```bash
# 현재 worktree 목록
git worktree list

# 현재 위치가 메인 worktree인지 확인
git rev-parse --git-dir
```

### 2. 입력 유형 감지

```
입력값 패턴에 따라 처리:

1. 생략: AskUserQuestion으로 브랜치명 요청
2. 숫자만 또는 #숫자: `command gh pr view {번호} --json headRefName`로 브랜치명 가져오기
3. github.com/.../pull/ 포함: URL에서 PR 번호 추출 후 브랜치명 가져오기
4. slack.com 포함: Slack 스레드 분석 → 관련 PR/키워드 추출 → 브랜치명 결정
5. notion.so 포함: Notion 문서 분석 → 관련 PR/LK-ID 추출 → 브랜치명 결정
6. LK-XXXXX 패턴: `feature/LK-XXXXX` 형식 브랜치명 생성
7. 그 외: 입력값을 브랜치명으로 사용
```

### 3. Worktree 디렉토리 결정

```bash
# 현재 repo 이름 추출
REPO_NAME=$(basename $(git rev-parse --show-toplevel))

# worktree 경로 결정 (형식: ../{repo}-{branch})
# 예: ../likey-backend-feature-LK-1234
WORKTREE_PATH="../${REPO_NAME}-${BRANCH_NAME}"
```

### 4. Worktree 생성

```bash
# 기존 브랜치가 있는 경우
git worktree add "${WORKTREE_PATH}" "${BRANCH_NAME}"

# 새 브랜치 생성이 필요한 경우
git worktree add "${WORKTREE_PATH}" -b "${BRANCH_NAME}"
```

### 5. 의존성 설치

```bash
cd "${WORKTREE_PATH}"

# package.json 존재 확인
if [ -f "package.json" ]; then
    npm install
fi
```

### 6. 환경 파일 복사

```bash
# .env 파일이 있고 새 worktree에 없는 경우 복사
MAIN_WORKTREE=$(git worktree list | head -1 | awk '{print $1}')
for env_file in .env .env.local; do
    if [ -f "${MAIN_WORKTREE}/${env_file}" ] && [ ! -f "${WORKTREE_PATH}/${env_file}" ]; then
        cp "${MAIN_WORKTREE}/${env_file}" "${WORKTREE_PATH}/${env_file}"
    fi
done
```

### 7. 결과 보고

```markdown
## Worktree 생성 완료

| 항목 | 값 |
|------|-----|
| 브랜치 | `{브랜치명}` |
| 경로 | `{절대 경로}` |
| 소스 | {PR #123 / Slack 스레드 / Notion 문서 / 직접 지정} |

### 다음 단계

새 터미널에서 다음 명령을 실행하세요:

\`\`\`bash
cd {worktree 경로}
claude
\`\`\`

또는 현재 세션에서 작업하려면:

\`\`\`bash
cd {worktree 경로}
\`\`\`
```

---

## 주의사항

- 같은 브랜치로 여러 worktree를 만들 수 없습니다
- worktree 내에서 다시 worktree를 생성하지 마세요 (메인에서 생성)
- `node_modules`는 각 worktree마다 별도로 설치됩니다
