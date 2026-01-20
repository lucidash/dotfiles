# 슬랙 스레드 → 개발과제/작업 생성

슬랙 스레드의 요청을 분석하여 규모에 따라 개발과제 또는 개발작업을 생성합니다.

## 입력
- `$ARGUMENTS`: 슬랙 스레드 링크

## 업무 프로세스

```
슬랙 스레드
    │
    ▼
┌─────────────────┐
│  요청 분석      │
│  규모/복잡도    │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
 규모 큼    규모 작음
    │         │
    ▼         ▼
개발과제   개발작업
 생성      직접 생성
    │         │
    └────┬────┘
         │
         ▼
┌─────────────────┐
│ 슬랙 스레드에   │
│ 결과 댓글 작성  │
└─────────────────┘
```

## 규모 판단 기준

| 구분 | 개발과제 (큰 작업) | 개발작업 (작은 작업) |
|------|-------------------|---------------------|
| 파트 | 2개 이상 파트 필요 | 단일 파트로 완료 가능 |
| 범위 | 신규 기능, 큰 개선 | 버그 수정, 작은 개선, 데이터 수정 |
| 기획 | 기획 문서 필요 | 요청 내용만으로 충분 |
| 예시 | 새 결제 수단 추가, 신규 페이지 | API 필드 추가, 버그 수정, 어드민 필터 추가 |

---

## 실행 순서

### 1. 슬랙 스레드 내용 가져오기
```
슬랙 링크에서 channel_id와 thread_ts 파싱
mcp__slack__slack_get_thread_replies 사용
```

### 2. 요청자 정보 수집 및 Notion 사용자 매핑
```
1. 스레드 첫 메시지의 user ID 추출
2. mcp__slack__slack_get_users로 Slack 사용자 정보 조회
   - display_name, real_name, email 추출
3. mcp__notion__notion-search로 Notion 사용자 검색
   - query: {email}
   - query_type: "user"
4. 매핑 결과 저장
   - 성공: Notion user ID 저장 → 관련자 속성에 사용
   - 실패: 본문에 요청자 정보만 기록
```

### 3. 요청 내용 분석
- 요청자 확인 (Slack display_name + Notion 매핑 여부)
- 요청 내용 요약
- 핵심 키워드 추출
- 필요한 파트 판단 (Backend, Admin, Web, iOS, Android)

### 4. 규모/복잡도 판단 및 확인
분석 결과를 사용자에게 보여주고 확인:

```
## 슬랙 스레드 분석 결과

### 요청 요약
{요청 내용 1-2문장 요약}

### 요청자
{슬랙 사용자명}

### 판단
| 항목 | 내용 |
|------|------|
| 예상 필요 파트 | {Backend, Admin, Web 등} |
| 규모 판단 | 🔵 작은 작업 / 🟠 큰 작업 |
| 판단 근거 | {근거 설명} |

### 추천 액션
- [ ] 개발과제 생성 (규모가 크거나 여러 파트 필요)
- [x] 개발작업 직접 생성 (단일 파트로 해결 가능)
```

**사용자에게 확인 요청:**
- 판단이 맞는지 확인
- 담당 파트 확인 (작은 작업인 경우)

---

## 경로 A: 큰 작업 → 개발과제 생성

### A-1. 개발과제 DB에 문서 생성
- **Data Source**: `collection://e2591524-aa7d-454e-86eb-b925b110aeca`
- **속성**:
  - 프로젝트 이름: `{과제 제목}`
  - Product: `LIKEY`
  - Status: `기획 완료`
  - **관련자**: `{Notion User ID}` (매핑 성공 시)
- **내용 구조**:
  ```markdown
  ## 개요
  {요청 요약}

  ## 소스
  - [슬랙 스레드]({슬랙 URL})
  - 요청자: {요청자명}

  ## 예상 필요 파트
  - [ ] Backend
  - [ ] Admin
  - [ ] Web

  ## 상세 요구사항
  {스레드 내용 정리}
  ```

### A-2. 슬랙 스레드에 결과 댓글 작성
```
mcp__slack__slack_reply_to_thread 사용
- channel_id: {파싱한 channel_id}
- thread_ts: {파싱한 thread_ts}
- text: 개발과제가 생성되었습니다: {Notion URL}
```

### A-3. 결과 보고
```
## 개발과제 생성 완료

- [{과제 제목}]({URL})
- ✅ 슬랙 스레드에 댓글 작성 완료
- ✅ 관련자 설정: {요청자명} (또는 ⚠️ 관련자 매핑 실패)

### 다음 단계
필요한 파트별로 아래 커맨드를 실행하세요:
- `/create-backend-task {URL}`
- `/create-adminv2-task {URL}`
- `/create-web-task {URL}`
```

---

## 경로 B: 작은 작업 → 개발작업 직접 생성

### B-1. 담당 파트 확인
사용자에게 담당 파트 확인:
- Backend (Server)
- Admin
- Web

### B-2. 개발작업 DB에 티켓 생성 (과제 없이)
- **Data Source**: `collection://af0b1e4c-6a3f-4d94-81c6-396f86e61574`
- **속성**:
  - 작업 이름: `[{파트}] {작업 설명}`
  - 파트: `{Server/Admin/Web}`
  - 작업 유형: `새피처` (버그면 `버그`)
  - Product: `LIKEY`
  - **과제**: `null` (과제 없는 단독 작업)
- **내용 구조**:
  ```markdown
  ## 개요
  {요청 요약}

  ## 소스
  - [슬랙 스레드]({슬랙 URL})
  - 요청자: {요청자명}

  ## 요청 내용
  {스레드 내용 정리}

  ## 작업 내용
  > PR 생성 후 업데이트

  ## Test Plan
  - [ ] {테스트 항목}
  ```

### B-3. 슬랙 스레드에 결과 댓글 작성
```
mcp__slack__slack_reply_to_thread 사용
- channel_id: {파싱한 channel_id}
- thread_ts: {파싱한 thread_ts}
- text: 개발작업이 생성되었습니다: {Notion URL}
```

### B-4. 결과 보고
```
## 개발작업 생성 완료

- [{LK-ID} {작업 제목}]({URL})
- 파트: {Server/Admin/Web}
- ✅ 슬랙 스레드에 댓글 작성 완료

### 참고
이 작업은 개발과제 없이 생성된 단독 작업입니다.
(과제 relation이 비어있음)
```

---

## 슬랙 링크 파싱

슬랙 스레드 URL 형식:
- `https://{workspace}.slack.com/archives/{channel_id}/p{timestamp}`
- timestamp: `p1234567890123456` → `1234567890.123456` (6자리 뒤에 점)

```
예시:
https://likey-team.slack.com/archives/C01234567/p1705123456789012
→ channel_id: C01234567
→ thread_ts: 1705123456.789012
```

---

## Slack → Notion 사용자 매핑

### 매핑 플로우
```
Slack User ID
    │
    ▼
mcp__slack__slack_get_users
    │
    ▼
email 추출 (예: min@tpcinternet.com)
    │
    ▼
mcp__notion__notion-search
  - query: {email}
  - query_type: "user"
    │
    ▼
Notion User ID (예: 531b81c6-5911-47af-aa46-779e06bafaee)
```

### 속성 설정 방법
```
관련자 속성에 Notion User ID 직접 전달
예: "관련자": "{notion_user_id}"
```

### Fallback
- 이메일이 없거나 Notion 사용자를 찾지 못한 경우
- 본문 `## 소스` 섹션에 요청자 정보만 기록
- `관련자` 속성은 설정하지 않음

---

## Relation 설정 참고

- **개발과제와 연결된 작업**: `과제` 속성에 개발과제 URL 설정
- **단독 작업 (과제 없음)**: `과제` 속성을 `null`로 설정하거나 생략
- Relation은 URL 형식 필수: `https://www.notion.so/{page-id}`
