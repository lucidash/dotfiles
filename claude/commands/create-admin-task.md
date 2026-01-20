# Admin (v1) 개발 작업 문서 생성

두 가지 모드로 동작합니다:
- **인자 없음**: 현재 PR 기반으로 작업 문서 생성
- **인자 있음**: 개발과제 문서를 분석하여 Admin v1 작업 필요여부 판단 및 작업 생성

> **참고**: Admin v1은 신규 기능 개발이 중단되었습니다.
> v1에만 있는 기능 수정 시 v2 이관을 권장합니다.
> 신규 기능은 `/create-adminv2-task`를 사용하세요.

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
command gh api repos/tpcint/likey-admin/pulls/{PR번호} -X PATCH -f title="{기존제목} (LK-{ID})"
```

### A-5. 결과 보고
- 생성된 Notion 티켓 URL
- 수정된 PR 타이틀

---

## 모드 B: 개발과제 기반 (인자 있음)

개발과제 문서를 분석하여 Admin v1 코드베이스 분석 후 작업 필요여부 판단 및 작업 생성.

### B-1. 개발과제 문서 가져오기
```
mcp__notion__notion-fetch 사용하여 $ARGUMENTS URL의 내용 가져오기
```
- 요구사항 파악
- 핵심 키워드, 기능명 등 추출

### B-2. Admin v1 코드베이스 분석
- **프로젝트 경로**: `/Users/muzi/projects/likey-admin`
```bash
# 관련 페이지, 컴포넌트 검색
rg "{키워드}" /Users/muzi/projects/likey-admin/pages -g "*.vue" | head -30
rg "{키워드}" /Users/muzi/projects/likey-admin/components -g "*.vue" | head -20
```
- 관련 페이지 확인 (`pages/`)
- 관련 컴포넌트 확인 (`components/`)
- API 호출 부분 확인
- 변경이 필요한 파일 목록 정리

### B-3. Admin v2 존재 여부 확인
```bash
# v2에 동일 기능이 있는지 확인
rg "{키워드}" /Users/muzi/projects/likey-admin-v2/app -g "*.vue" | head -20
```
- **v2에 기능 있음**: 사용자에게 `/create-adminv2-task` 사용 권장
- **v1에만 있음**: v2 이관 선행 필요 안내

### B-4. 작업 필요여부 판단 및 확인
분석 결과를 사용자에게 보여주고 확인:

| 항목 | 내용 |
|------|------|
| 작업 필요 | ✅ 필요 / ❌ 불필요 |
| v2 이관 필요 | ⚠️ 필요 / ✅ 불필요 |
| 판단 근거 | {근거 설명} |
| 관련 파일 | {파일 목록} |
| 예상 변경사항 | {변경 내용 요약} |

- 불필요하다고 판단되면 사용자에게 알리고 종료
- v2 이관이 필요하면 해당 내용 포함하여 진행

### B-5. Notion 개발 작업 DB에 티켓 생성
- **Data Source**: `collection://af0b1e4c-6a3f-4d94-81c6-396f86e61574`
- **속성**:
  - 작업 이름: `[Admin] {작업 설명}`
  - 파트: `Admin`
  - 작업 유형: `새피처`
  - Product: `LIKEY`
- **내용 구조** (v2 이관 필요 시):
  ```
  ## 개요
  {작업 요약}

  ## 개발과제
  - [{개발과제 제목}]({개발과제 URL})

  ## 선행 작업: v1 → v2 이관
  - [ ] v1 관련 파일 분석
  - [ ] v2로 로직 이관

  ### v1 관련 파일
  - {파일 경로 1}
  - {파일 경로 2}

  ## 본 작업 (v2)
  ### 예상 변경사항
  1. {변경사항 1}
  2. {변경사항 2}

  ## Test Plan
  - [ ] {QA 테스트 항목 1}
  - [ ] {QA 테스트 항목 2}
  ```

### B-6. 개발과제 문서 업데이트
생성된 작업을 개발과제 문서의 "개발 작업" 섹션에 추가:
```
- [x] Admin: [{LK-ID} {제목}]({URL})
```

### B-7. 결과 보고
- 생성된 Notion 티켓 URL
- v2 이관 필요 여부
- 개발과제 문서 업데이트 완료 여부
