---
name: link-pr-task
description: PR과 Notion 작업을 연결할 때, PR title에 LK-ID를 추가할 때, PR 생성 후 Notion 연결이 필요할 때 사용. PR이 생성된 후 Notion 개발 작업과 연결하고 싶을 때 자동으로 활성화됩니다.
allowed-tools: Bash, Read
---

# PR과 Notion 개발 작업 연결

PR title에 Notion 개발 작업 ID(LK-XXXX)를 추가합니다.
GitHub webhook이 PR title의 LK-ID를 감지하여 Notion 작업 카드에 PR 링크를 자동으로 연결합니다.

## 트리거 키워드

- "Notion 연결해줘", "작업 연결", "LK-ID 추가"
- "PR이랑 Notion 연결", "PR 작업 연결"
- PR 생성 직후 Notion URL 또는 LK-ID 언급

## 인자

- `$ARGUMENTS`: Notion 개발 작업 URL 또는 ID (필수)

## 사용 예시

```
/link-pr-task https://www.notion.so/tpcinternet/LK-10099-...
/link-pr-task 2ef61056-ee12-8133-8b7a-e5f010203771
```

---

## 워크플로우

### 1단계: 현재 브랜치의 PR 확인

```bash
command gh pr list --head $(git branch --show-current) --json url,number,title
```

- PR이 없으면 에러 메시지 출력 후 종료
- 여러 PR이 있으면 사용자에게 선택 요청

### 2단계: Notion 개발 작업 정보 가져오기

```
mcp__tpc-notion__API-retrieve-a-page 사용
- page_id: $ARGUMENTS (URL 또는 ID)
```

- `userDefined:ID` 속성에서 LK-XXXX 형식의 ID 추출
- 페이지 제목 확인

### 3단계: PR title에 LK-ID 추가

기존 title에 이미 LK-ID가 있는지 확인:
- 있으면: 사용자에게 덮어쓸지 확인
- 없으면: title 끝에 `(LK-XXXX)` 추가

```bash
command gh api repos/{owner}/{repo}/pulls/{PR번호} -X PATCH -f title="{새로운 title}"
```

> GitHub webhook이 자동으로 Notion 작업 카드의 PR Link 속성을 업데이트합니다.

### 4단계: 결과 보고

```markdown
## 연결 완료

| 항목 | 내용 |
|------|------|
| PR | #{번호} {제목} |
| Notion | [LK-XXXX](URL) |
| PR title | {업데이트된 title} |

> Notion PR Link 속성은 webhook에 의해 자동 연결됩니다.
```

---

## 에러 처리

| 상황 | 처리 |
|------|------|
| PR이 없음 | "현재 브랜치에 PR이 없습니다. 먼저 PR을 생성해주세요." |
| Notion 페이지 없음 | "Notion 페이지를 찾을 수 없습니다: {URL}" |
| LK-ID 없음 | "해당 페이지에서 LK-ID를 찾을 수 없습니다." |
| 이미 연결됨 | 기존 ID 표시 후 덮어쓸지 확인 |

---

## 참고

- 개발 작업 DB Data Source: `collection://af0b1e4c-6a3f-4d94-81c6-396f86e61574`
- LK-ID는 `userDefined:ID` 속성에 저장됨
- PR title에 LK-ID 추가 시 GitHub webhook이 Notion PR Link 속성 자동 연결
