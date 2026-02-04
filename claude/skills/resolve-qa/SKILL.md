---
name: resolve-qa
description: QA 이슈 수정 후 Notion 문서 상태를 "QA 필요"로 변경하고 수정 내용 댓글을 남깁니다. "QA 이슈 해결", "QA 상태 업데이트", "노션 QA 업데이트" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "<Notion permalink 또는 LK-ID>"
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion, Skill
---

# QA 이슈 해결 → Notion 업데이트

QA 이슈를 분석하고, 적절한 브랜치/worktree를 설정한 뒤, 수정 완료 후 Notion 상태를 "QA 필요"로 변경하고 댓글을 남깁니다.

**Arguments:** `$ARGUMENTS`

## 인자 파싱

`$ARGUMENTS`는 다음 중 하나:

1. **Notion permalink**: `https://www.notion.so/...` 형태의 URL
2. **LK-ID**: `LK-10258` 형태의 ID

### Notion permalink에서 page_id 추출

URL의 마지막 32자리 hex 문자열이 page_id (하이픈 없는 UUID):

```
https://www.notion.so/QA-2fd61056ee1280a4ab14e37ce2261ead
                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                           → page_id: 2fd61056-ee12-80a4-ab14-e37ce2261ead
```

하이픈을 삽입하여 UUID 형식으로 변환: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### LK-ID에서 page 검색

LK-ID가 주어진 경우 Notion 검색으로 페이지를 찾습니다:

```
mcp__tpc-notion__API-post-search
- query: "LK-{number}"
- page_size: 10
```

검색 결과에서 `ID.unique_id.number` 또는 `ID.unique_id.prefix + number`가 일치하는 페이지를 찾습니다.
찾지 못하면 에러 메시지를 출력하고 종료합니다.

---

## 워크플로우

### 1단계: Notion 페이지 조회 및 컨텍스트 파악

```
mcp__tpc-notion__API-retrieve-a-page
- page_id: {추출된 page_id}
```

다음 정보를 추출합니다:

| 속성 | 용도 |
|------|------|
| `작업 이름` (title) | QA 이슈 내용 파악 |
| `상태` (status) | 현재 상태 확인 |
| `ID` (unique_id) | LK-XXXX |
| `상위 작업` (parent_task_relation) | 상위 개발 작업 ID |

### 1-2단계: 첨부 미디어 분석 (자동)

Notion 페이지에 첨부된 이미지/동영상을 분석하여 QA 이슈의 시각적 컨텍스트를 파악합니다.
미디어가 없으면 이 단계는 자동으로 스킵됩니다.

**1-2-1. 페이지 블록에서 미디어 탐색**

```
mcp__tpc-notion__API-get-block-children
- block_id: {page_id}
```

응답에서 다음 타입의 블록을 탐색합니다:
- `image` — 스크린샷, UI 캡처 등
- `video` — 화면 녹화, 재현 영상 등
- `file` — 이미지/동영상 파일 첨부
- `pdf` — PDF 첨부

> 하위 블록이 있는 경우 (`has_children: true`) 재귀적으로 `API-get-block-children`을 호출하여 중첩된 미디어도 탐색합니다.

**1-2-2. 미디어 다운로드 및 분석**

발견된 미디어를 scratchpad 디렉토리에 다운로드하여 분석합니다:

```bash
# scratchpad에 임시 디렉토리 생성
media_dir="${SCRATCHPAD}/qa_media_$(date +%s)"
mkdir -p "$media_dir"
```

**이미지 처리:**
```bash
# Notion signed URL에서 다운로드
curl -sL "<signed_url>" -o "$media_dir/image_01.png"
```
→ Read 도구로 이미지 직접 분석 (병렬 처리)

**동영상 처리:**
```bash
# 다운로드
curl -sL "<signed_url>" -o "$media_dir/video_01.mp4"
# ffmpeg으로 프레임 추출 (1fps)
ffmpeg -i "$media_dir/video_01.mp4" -vf "fps=1,scale=1920:-1" "$media_dir/video_01_frame_%04d.png" -y
```
→ Read 도구로 추출된 프레임 분석 (병렬 처리)

**PDF 처리:**
→ Read 도구로 PDF 직접 읽기 (pages 파라미터 활용)

**1-2-3. 분석 결과 활용**

분석에서 파악한 내용을 이후 단계에서 활용합니다:
- **코드 수정 방향**: 에러 화면, UI 깨짐 등 시각적 문제의 구체적 증상 파악
- **Notion 댓글 작성**: 원인 설명에 분석 내용 반영
- **추정 원인**: 스크린샷/영상의 에러 메시지, URL 경로 등에서 단서 추출

**1-2-4. 임시 파일 정리**

분석 완료 후 다운로드한 미디어 파일을 정리합니다:
```bash
rm -rf "$media_dir"
```

> **참고**: 미디어 분석 결과는 별도로 사용자에게 보고하지 않고, QA 이슈 해결을 위한 내부 컨텍스트로만 사용합니다.

### 2단계: 상위 작업에서 브랜치 정보 추적

**2-1. 상위 작업 조회**

QA 이슈의 `상위 작업` relation을 따라가 개발 작업 페이지를 조회합니다:

```
mcp__tpc-notion__API-retrieve-a-page
- page_id: {상위 작업 page_id}
```

상위 작업에서 추출할 정보:

| 속성 | 용도 |
|------|------|
| `PR` (relation) | 연결된 PR 페이지 ID |
| `서버 프리뷰 (BETA)` (formula) | 프리뷰 브랜치명 (= 작업 브랜치) |
| `상태` (status) | 작업 상태 (개발 중 / QA 진행중 / 완료 등) |

**2-2. 브랜치 결정 로직**

상위 작업의 `서버 프리뷰 (BETA)` formula에서 브랜치명을 추출합니다.
이 값이 비어있으면 PR 정보에서 head branch를 가져옵니다:

```bash
command gh pr view {PR번호} --json headRefName --jq '.headRefName'
```

### 3단계: Worktree 설정

추출된 브랜치의 상태에 따라 분기합니다:

**3-1. 현재 worktree가 이미 해당 브랜치인 경우**

```bash
current_branch=$(git branch --show-current)
```

현재 브랜치가 대상 브랜치와 같으면 → 그대로 진행 (worktree 전환 불필요)

**3-2. 브랜치가 아직 활성 상태 (PR open, 미머지)**

해당 브랜치의 worktree로 전환합니다:

```
/wt -q {branch_name}
```

> `-q` (Quick 모드)로 분석 스킵하고 빠르게 전환

**3-3. 브랜치가 이미 머지/릴리즈된 경우**

새로운 fix 브랜치를 생성합니다:

```bash
# PR 상태 확인
command gh pr list --head {branch_name} --state all --json state,mergedAt --jq '.[0]'
```

머지된 경우:

```
/wt fix/LK-{QA이슈번호}
```

> 예: QA 이슈가 LK-10258이면 → `fix/LK-10258` 브랜치로 worktree 생성
> wt 스킬이 `master` 기반으로 새 브랜치를 자동 생성합니다.

**3-4. 상위 작업/PR 정보가 없는 경우**

사용자에게 확인합니다 (AskUserQuestion):

```
현재 브랜치({current_branch})에서 작업할까요,
아니면 새 fix 브랜치를 만들까요?
```

### 판단 흐름도

```
상위 작업에서 브랜치 추출
  │
  ├─ 현재 브랜치와 동일 → 그대로 진행
  │
  ├─ PR open (미머지) → /wt -q {branch}
  │
  ├─ PR merged/closed → /wt fix/LK-{QA번호}
  │
  └─ 정보 없음 → 사용자에게 확인
```

### 4단계: (코드 수정은 사용자/에이전트가 수행)

이 단계는 스킬 범위 밖입니다. 스킬 호출 시점에 이미 수정이 완료된 경우도 있고, 이 스킬을 통해 worktree 설정만 먼저 한 뒤 수정을 시작하는 경우도 있습니다.

**수정이 이미 완료된 경우** (커밋이 존재하는 경우) → 5단계로 진행
**worktree 설정만 한 경우** (커밋이 없는 경우) → 사용자에게 안내 후 종료

```markdown
## Worktree 준비 완료

| 항목 | 내용 |
|------|------|
| QA 이슈 | [LK-{number}]({notion_url}) - {제목} |
| 브랜치 | `{branch}` |
| 경로 | `{worktree_path}` |

코드 수정 후 `/resolve-qa {같은 인자}`를 다시 실행하면 Notion 업데이트를 진행합니다.
```

### 5단계: Git 정보 수집 및 변경 요약

병렬로 실행:

```bash
# 현재 브랜치
git branch --show-current

# 최근 커밋 (현재 브랜치에서)
git log -1 --format="%h %s"

# 최근 커밋의 변경 요약
git diff HEAD~1 --stat
```

댓글 내용 구성:

```
수정 완료되었습니다.

원인: {간략한 원인 설명}
수정: {변경 내용 요약}

commit: {short hash} ({branch name})
```

**원인/수정 내용 작성 규칙:**
- 최근 커밋 메시지와 diff에서 핵심 내용을 추출
- 비개발자도 이해할 수 있는 수준으로 작성
- 기술적 세부사항보다 "무엇이 문제였고 어떻게 해결했는지"에 초점

### 6단계: Notion 상태 업데이트

```
mcp__tpc-notion__API-patch-page
- page_id: {page_id}
- properties: {"상태": {"status": {"name": "QA 필요"}}}
```

### 7단계: 댓글 작성

```
mcp__tpc-notion__API-create-a-comment
- parent: {"page_id": "{page_id}"}
- rich_text: [{
    "text": {
      "content": "{5단계에서 생성한 댓글 내용}"
    }
  }]
```

### 8단계: 결과 보고

```markdown
## QA 이슈 업데이트 완료

| 항목 | 내용 |
|------|------|
| 문서 | [LK-{number}]({notion_url}) |
| 상태 | {이전상태} → **QA 필요** |
| 브랜치 | `{branch}` |
| 커밋 | `{short_hash}` |
| 댓글 | 수정 내용 작성됨 |
```

---

## 에러 처리

| 상황 | 처리 |
|------|------|
| 인자 없음 | "Notion permalink 또는 LK-ID를 입력해주세요." |
| 페이지 없음 | "Notion 페이지를 찾을 수 없습니다: {input}" |
| LK-ID 검색 실패 | "LK-{number}에 해당하는 QA 문서를 찾을 수 없습니다." |
| 상위 작업 없음 | 브랜치 자동 추적 스킵, 사용자에게 확인 |
| 이미 QA 필요 상태 | "이미 'QA 필요' 상태입니다. 댓글만 추가할까요?" (AskUserQuestion) |
| 커밋 없음 | Worktree 설정만 완료 후 안내 (4단계 참조) |
| worktree 전환 실패 | 에러 내용 표시 후 현재 브랜치에서 계속할지 확인 |

---

## 사용 예시

```bash
# Notion permalink 사용 (수정 완료 후 Notion 업데이트)
/resolve-qa https://www.notion.so/QA-2fd61056ee1280a4ab14e37ce2261ead

# LK-ID 사용
/resolve-qa LK-10258

# 워크플로우 예시:
# 1. /resolve-qa LK-10258  → worktree 설정 + QA 이슈 내용 확인
# 2. (코드 수정 & 커밋 & 푸시)
# 3. /resolve-qa LK-10258  → Notion 상태 업데이트 + 댓글
```
