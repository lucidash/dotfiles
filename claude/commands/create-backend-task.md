# Backend 개발 작업 문서 생성

두 가지 모드로 동작합니다:
- **인자 없음**: 현재 PR 기반으로 작업 문서 생성
- **인자 있음**: 개발과제 문서를 분석하여 Backend 작업 필요여부 판단 및 작업 생성

## 입력
- `$ARGUMENTS`: (선택) 개발과제 노션 페이지 URL

---

## 모드 A: PR 기반 (인자 없음)

현재 브랜치의 PR을 기반으로 Notion 개발 작업 문서를 생성하고 PR과 연결합니다.

### A-1. PR 확인
```bash
command gh pr list --head $(git branch --show-current) --json url,number,title
```
- PR이 없으면 사용자에게 알림

### A-2. 변경사항 분석
```bash
git diff master..HEAD --stat
git log master..HEAD --oneline
```
- 주요 변경 파일과 커밋 내용 파악
- 필요시 변경된 코드 직접 확인

### A-3. Notion 개발 작업 DB에 티켓 생성
- **Data Source**: `collection://af0b1e4c-6a3f-4d94-81c6-396f86e61574`
- **속성**:
  - 작업 이름: `[Server] {작업 설명}`
  - 파트: `Server`
  - 작업 유형: `새피처` (버그면 `버그`)
  - Product: `LIKEY`
- **내용 구조**:
  ```
  ## 개요
  {변경사항 요약 1-2문장}

  ## PR
  - [#{PR번호} {PR제목}]({PR URL})

  ## 변경사항
  1. {주요 변경사항 1}
  2. {주요 변경사항 2}

  ## Test Plan
  - [ ] {QA 테스트 항목 1}
  - [ ] {QA 테스트 항목 2}
  ```

### A-4. PR 타이틀에 LK-ID 추가
```bash
command gh api repos/tpcint/likey-backend/pulls/{PR번호} -X PATCH -f title="{기존제목} (LK-{ID})"
```

### A-5. 결과 보고
- 생성된 Notion 티켓 URL
- 수정된 PR 타이틀

---

## 모드 B: 개발과제 기반 (인자 있음)

개발과제 문서를 분석하여 Backend 코드베이스 분석 후 작업 필요여부 판단 및 작업 생성.

### B-1. 개발과제 문서 가져오기
```
mcp__notion__notion-fetch 사용하여 $ARGUMENTS URL의 내용 가져오기
```
- 요구사항 파악
- 핵심 키워드, 기능명, API 엔드포인트 등 추출

### B-2. Backend 코드베이스 분석
- **프로젝트 경로**: `/Users/muzi/projects/likey-backend`
```bash
# API 엔드포인트, 서비스, 모델 검색
rg "{키워드}" /Users/muzi/projects/likey-backend/src -t ts | head -30
```
- 관련 API 컨트롤러 확인 (`src/api/`, `src/admin-api/`)
- 관련 서비스/모델 확인 (`src/likey/`)
- 변경이 필요한 파일 목록 정리

### B-3. 작업 필요여부 판단 및 확인
분석 결과를 사용자에게 보여주고 확인:

| 항목 | 내용 |
|------|------|
| 작업 필요 | ✅ 필요 / ❌ 불필요 |
| 판단 근거 | {근거 설명} |
| 관련 파일 | {파일 목록} |
| 예상 변경사항 | {변경 내용 요약} |

- 불필요하다고 판단되면 사용자에게 알리고 종료
- 필요하다면 다음 단계 진행

### B-4. Notion 개발 작업 DB에 티켓 생성
- **Data Source**: `collection://af0b1e4c-6a3f-4d94-81c6-396f86e61574`
- **속성**:
  - 작업 이름: `[Server] {작업 설명}`
  - 파트: `Server`
  - 작업 유형: `새피처`
  - Product: `LIKEY`
- **내용 구조**:
  ```
  ## 개요
  {작업 요약}

  ## 개발과제
  - [{개발과제 제목}]({개발과제 URL})

  ## 코드 분석 결과
  ### 관련 파일
  - {파일 경로 1}
  - {파일 경로 2}

  ### 예상 변경사항
  1. {변경사항 1}
  2. {변경사항 2}

  ## Test Plan
  - [ ] {QA 테스트 항목 1}
  - [ ] {QA 테스트 항목 2}
  ```

### B-5. 개발과제 문서 업데이트
생성된 작업을 개발과제 문서의 "개발 작업" 섹션에 추가:
```
- [x] Backend: [{LK-ID} {제목}]({URL})
```

### B-6. 결과 보고
- 생성된 Notion 티켓 URL
- 개발과제 문서 업데이트 완료 여부
