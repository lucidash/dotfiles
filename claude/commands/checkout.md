# 브랜치 변경사항 분석

현재 브랜치 또는 지정한 대상의 변경사항을 분석합니다.

## 인자

- `$ARGUMENTS`: (선택) 체크아웃 대상
  - **생략 시**: 현재 브랜치의 변경사항만 분석
  - **브랜치명**: 해당 브랜치로 checkout
  - **PR 번호**: `6475` 또는 `#6475` → GitHub PR로 checkout
  - **GitHub PR URL**: `https://github.com/.../pull/123` → 해당 PR checkout
  - **Slack 스레드 URL**: `https://...slack.com/.../p...` → 스레드에서 관련 PR 탐색 후 checkout
  - **Notion 문서 URL**: `https://notion.so/...` → 문서에서 관련 PR 탐색 후 checkout

---

## 실행 순서

### 1. 입력 유형 감지 및 브랜치 처리

```
입력값 패턴에 따라 처리:

1. 생략: 현재 브랜치 유지
2. 숫자만 또는 #숫자: `command gh pr checkout {번호}`
3. github.com/.../pull/ 포함: URL에서 PR 번호 추출 후 `command gh pr checkout`
4. slack.com 포함: Slack 스레드 읽기 → 관련 PR 탐색
5. notion.so 포함: Notion 문서 읽기 → 관련 PR 탐색
6. 그 외: 브랜치명으로 간주하여 `git checkout {브랜치명}`
```

### 1-1. Slack 스레드에서 PR 탐색

Slack URL 형식: `https://{workspace}.slack.com/archives/{channel_id}/p{timestamp}`

```
1. URL에서 channel_id와 timestamp 추출
   - timestamp: p 제거 후 뒤에서 6자리 앞에 . 추가 (예: p1769077934818869 → 1769077934.818869)
2. slack_get_thread_replies(channel_id, thread_ts) 호출
3. 스레드 내용에서 키워드 추출:
   - Notion 링크가 있으면 해당 문서 제목 참고
   - 기능명, 이슈 번호 (LK-XXXXX), PR 번호 등
4. `command gh pr list --state all --limit 20`으로 PR 목록 조회
5. 키워드 매칭으로 관련 PR 선택
6. 여러 PR이 관련될 경우 AskUserQuestion으로 선택 요청
7. 선택된 PR로 checkout
```

### 1-2. Notion 문서에서 PR 탐색

```
1. notion-fetch(url) 호출
2. 문서 내용에서 키워드 추출:
   - 문서 제목, 이슈 번호 (LK-XXXXX)
   - 관련 PR 링크가 있으면 직접 사용
3. `command gh pr list --state all --limit 20`으로 PR 목록 조회
4. 키워드 매칭으로 관련 PR 선택
5. 여러 PR이 관련될 경우 AskUserQuestion으로 선택 요청
6. 선택된 PR로 checkout
```

### 2. 현재 상태 확인

```bash
# 현재 브랜치명 확인
git branch --show-current

# 작업 상태 확인
git status
```

### 3. base 브랜치 대비 변경사항 분석

base 브랜치(master 또는 main)와의 차이를 분석:

```bash
# 변경된 파일 목록 (base 브랜치 대비)
git diff master --name-status

# 커밋 히스토리
git log master..HEAD --oneline

# 전체 diff
git diff master
```

### 4. 변경사항 분석 및 요약

다음 관점에서 변경사항 분석:

- **변경 범위**: 어떤 파일/모듈이 수정되었는지
- **변경 유형**: 새 기능, 버그 수정, 리팩토링 등
- **주요 변경점**: 핵심적인 코드 변경 내용
- **영향 범위**: 변경으로 인해 영향받는 부분

---

## 출력 형식

```markdown
## 브랜치 분석: {브랜치명}

### 기본 정보
- **현재 브랜치**: {브랜치명}
- **base 브랜치**: master
- **커밋 수**: {N}개
- **PR**: #{PR번호} (해당 시)
- **소스**: {Slack 스레드 / Notion 문서 / 직접 지정} (해당 시)

### 변경 파일 요약
| 상태 | 파일 수 | 주요 파일 |
|------|---------|-----------|
| 추가(A) | N | ... |
| 수정(M) | N | ... |
| 삭제(D) | N | ... |

### 커밋 히스토리
1. {커밋 해시} {커밋 메시지}
2. ...

### 주요 변경 분석

#### 1. {변경 영역/기능명}
- **파일**: {파일 경로}
- **내용**: {변경 내용 설명}
- **목적**: {변경 이유/목적}

#### 2. ...

### 요약
{전체 변경사항에 대한 간단한 요약 - 1~2문장}
```
