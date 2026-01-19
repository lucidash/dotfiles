# Backend 개발 작업 문서 자동 생성

현재 브랜치의 PR을 기반으로 Notion 개발 작업 문서를 생성하고 PR과 연결합니다.

## 실행 순서

### 1. PR 확인
```bash
command gh pr list --head $(git branch --show-current) --json url,number,title
```
- PR이 없으면 사용자에게 알림

### 2. 변경사항 분석
```bash
git diff master..HEAD --stat
git log master..HEAD --oneline
```
- 주요 변경 파일과 커밋 내용 파악
- 필요시 변경된 코드 직접 확인

### 3. Notion 개발 작업 DB에 티켓 생성
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

### 4. PR 타이틀에 LK-ID 추가
```bash
command gh api repos/tpcint/likey-backend/pulls/{PR번호} -X PATCH -f title="{기존제목} (LK-{ID})"
```

### 5. 결과 보고
- 생성된 Notion 티켓 URL
- 수정된 PR 타이틀
