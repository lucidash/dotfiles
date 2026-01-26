# Admin V2 개발 작업 문서 생성

두 가지 모드로 동작합니다:
- **인자 없음**: 현재 PR 기반으로 작업 문서 생성
- **인자 있음**: 개발과제 문서를 분석하여 Admin v2 작업 필요여부 판단 및 작업 생성

> **참고**: 모든 Admin 신규 기능은 v2에서 개발합니다.

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
  - 작업 이름: `[Admin] {작업 설명}`
  - 파트: `Admin`
  - 작업 유형: `새피처` (버그면 `버그`)
  - Product: `LIKEY`
  - PM: `["18fd872b-594c-81ab-8426-000241feca9b"]` (Carrot)
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
command gh api repos/tpcint/likey-admin-v2/pulls/{PR번호} -X PATCH -f title="{기존제목} (LK-{ID})"
```

### A-5. 결과 보고
- 생성된 Notion 티켓 URL
- 수정된 PR 타이틀

---

## 모드 B: 개발과제 기반 (인자 있음)

개발과제 문서를 분석하여 Admin v2 코드베이스 분석 후 작업 필요여부 판단 및 작업 생성.

### B-1. 개발과제 문서 가져오기
```
mcp__notion__notion-fetch 사용하여 $ARGUMENTS URL의 내용 가져오기
```
- 요구사항 파악
- 핵심 키워드, 기능명 등 추출

### B-2. Admin v2 코드베이스 분석
- **프로젝트 경로**: `/Users/muzi/projects/likey-admin-v2`
```bash
# 관련 페이지, 컴포넌트 검색
rg "{키워드}" /Users/muzi/projects/likey-admin-v2/app -g "*.vue" | head -30
rg "{키워드}" /Users/muzi/projects/likey-admin-v2/components -g "*.vue" | head -20
```
- 관련 페이지 확인 (`app/`)
- 관련 컴포넌트 확인 (`components/`)
- API 호출 부분 확인
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
  - 작업 이름: `[Admin] {작업 설명}`
  - 파트: `Admin`
  - 작업 유형: `새피처`
  - Product: `LIKEY`
  - PM: `["18fd872b-594c-81ab-8426-000241feca9b"]` (Carrot)
  - **과제**: `{개발과제 URL}` ← Relation 자동 연결
- **내용 구조**:
  ```
  ## 개요
  {작업 요약}

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

> **Note**: `과제` relation 속성에 개발과제 URL을 설정하면 자동으로 연결됩니다.
> 개발과제 문서 본문을 별도로 수정할 필요 없습니다.

### B-5. 결과 보고
- 생성된 Notion 티켓 URL
- 개발과제와의 Relation 연결 완료 여부
