# 개발 과제 문서 생성

노션/슬랙 링크에서 요구사항을 분석하여 개발과제 DB에 문서를 생성합니다.
**파트별 작업 분석 및 생성은 각 파트별 커맨드를 사용하세요.**

## 입력
- `$ARGUMENTS`: 노션 페이지 URL 또는 슬랙 스레드 링크

## 관련 커맨드
| 커맨드 | 용도 |
|--------|------|
| `/create-backend-task {개발과제URL}` | Backend 코드 분석 + 작업 생성 |
| `/create-admin-task {개발과제URL}` | Admin v1 코드 분석 + 작업 생성 |
| `/create-adminv2-task {개발과제URL}` | Admin v2 코드 분석 + 작업 생성 |
| `/create-web-task {개발과제URL}` | Web 코드 분석 + 작업 생성 |

## 실행 순서

### 1. 소스 정보 가져오기
- **노션 링크인 경우**: `mcp__notion__notion-fetch` 사용
- **슬랙 링크인 경우**: `mcp__slack__slack_get_thread_replies` 사용
- 가져온 내용을 분석하여 요구사항 파악
- 핵심 키워드, 기능명, API 엔드포인트 등 추출

### 2. 요구사항 분석 결과 확인
사용자에게 분석된 요구사항을 보여주고 확인 요청:
- 과제 제목 (제안)
- 요구사항 요약
- 예상 필요 파트 (Backend, Admin, Web, iOS, Android)

### 3. 개발과제 DB에 문서 생성
- **Data Source**: `collection://e2591524-aa7d-454e-86eb-b925b110aeca`
- **속성**:
  - 이름: `{과제 제목}`
  - Product: `LIKEY`
  - Status: `기획 완료`
- **내용 구조**:
  ```markdown
  ## 개요
  {요구사항 요약}

  ## 소스
  - [{소스 제목}]({소스 URL})

  ## 예상 필요 파트
  - [ ] Backend
  - [ ] Admin
  - [ ] Web
  - [ ] iOS
  - [ ] Android

  ## 상세 요구사항
  {분석된 요구사항 상세}

  ## 개발 작업
  > 파트별 작업은 각 커맨드로 분석 후 생성됩니다.
  > - `/create-backend-task {이 문서 URL}`
  > - `/create-admin-task {이 문서 URL}` 또는 `/create-adminv2-task {이 문서 URL}`
  > - `/create-web-task {이 문서 URL}`
  ```

### 4. 결과 보고
```
## 생성 완료

### 개발과제
- [{과제 제목}]({URL})

### 다음 단계
필요한 파트별로 아래 커맨드를 실행하세요:
- `/create-backend-task {URL}`
- `/create-adminv2-task {URL}`
- `/create-web-task {URL}`
```
