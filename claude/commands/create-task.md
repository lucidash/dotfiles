# 개발 작업 문서 자동 생성

현재 브랜치의 PR 또는 개발과제를 기반으로 Notion 개발 작업 문서를 생성합니다.
**Workspace를 자동 감지하거나 명시적으로 지정할 수 있습니다.**

## 사용법

```
/create-task                      # 현재 workspace + PR 기반
/create-task {개발과제URL}        # 현재 workspace + 개발과제 분석
/create-task backend              # Backend 명시 + PR 기반
/create-task backend {URL}        # Backend 명시 + 개발과제 분석
/create-task web {URL}            # Web 명시
/create-task admin {URL}          # Admin v2 명시 (기본)
/create-task admin-v1 {URL}       # Admin v1 명시
```

## 입력

- `$ARGUMENTS`: (선택) 다음 조합 가능
  - **파트 지정**: `backend`, `server`, `web`, `admin`, `admin-v1`, `admin-v2`
  - **개발과제 URL**: Notion 페이지 URL

---

## Workspace 설정

| Workspace / 파트 | 접두사 | 파트 | 레포 | 프로젝트 경로 |
|------------------|--------|------|------|---------------|
| likey-backend / backend / server | `[Server]` | Server | likey-backend | `/Users/muzi/projects/likey-backend` |
| likey-web / web | `[Web]` | Web | likey-web | `/Users/muzi/projects/likey-web` |
| likey-admin-v2 / admin / admin-v2 | `[Admin]` | Admin | likey-admin-v2 | `/Users/muzi/projects/likey-admin-v2` |
| likey-admin / admin-v1 | `[Admin]` | Admin | likey-admin | `/Users/muzi/projects/likey-admin` |

---

## 실행 순서

### 0. 인자 파싱

`$ARGUMENTS`에서 파트와 URL 분리:

```
1. 첫 단어가 파트명(backend/server/web/admin/admin-v1/admin-v2)이면 파트 지정
2. notion.so URL이 있으면 개발과제 URL로 사용
3. 파트 미지정 시 workspace 자동 감지
```

### 1. Workspace 감지 (파트 미지정 시)

```bash
git remote get-url origin
```

- remote URL에서 프로젝트 판별 (위 테이블 참조)
- 감지된 프로젝트를 사용자에게 알림

---

## 모드 A: PR 기반 (개발과제 URL 없을 때)

현재 브랜치의 PR을 기반으로 작업 문서를 생성합니다.

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

- **Database ID**: `cdebd8ad-0608-4688-ba55-fee0f33c50e3`
  - (Data Source ID `af0b1e4c-6a3f-4d94-81c6-396f86e61574`와 다름, post-page에는 Database ID 사용)

#### 3단계 API 호출 절차

**Step 1. `post-page`** — 페이지 생성 (select/title 속성만)
```json
{
  "parent": {"database_id": "cdebd8ad-0608-4688-ba55-fee0f33c50e3"},
  "properties": {
    "title": [{"text": {"content": "{접두사} {작업 설명}"}}],
    "파트": {"name": "{파트}"},
    "작업 유형": {"name": "{작업 유형}"},
    "Product": {"name": "LIKEY"}
  }
}
```
> ⚠️ select는 `{"name": "..."}` 형식. `{"select": {"name": "..."}}` 사용 금지
> ⚠️ properties에 `"type": "title"` 포함 금지
> ⚠️ property `id` 포함 금지 (data source ID와 DB ID가 다름)

**Step 2. `patch-block-children`** — 본문 내용 추가
- `block_id`에 생성된 page ID 사용
- children은 object 배열로 전달

**Step 3. `patch-page`** — people 속성 설정
```json
{
  "page_id": "{생성된 page ID}",
  "properties": {
    "PM": {"people": [{"object": "user", "id": "18fd872b-594c-81ab-8426-000241feca9b"}]}
  }
}
```
> ⚠️ people 속성은 post-page에서 거부됨 → patch-page 필수

#### 속성 값 가이드
- **작업 유형** (select):
  - 새피처: 신규 기능
  - 서비스 개선: 기존 기능 개선
  - 인입 이슈: 외부 제보/CS 인입 버그
  - QA 버그: QA 과정에서 발견된 버그
  - 코드 리팩토링, 성능/비용 개선, 보안강화, 운영 개선, 개발 환경 개선, 데이터 마이그레이션
  - ⚠️ "버그"라는 옵션은 없음
- **파트** (select): Server, Admin, Web, iOS, Android, PM, 디자인, QA, AI
- **Product** (select): LIKEY, Tixee
- **PM** (people): Carrot `18fd872b-594c-81ab-8426-000241feca9b`

- **내용 구조**:
  ```markdown
  ## 개요
  {변경사항 요약 1-2문장}

  ## PR
  - [#{PR번호} {PR제목}]({PR URL})

  ## 확인 경로 (Admin v2인 경우에만 포함)
  | 경로 | 설명 |
  |------|------|
  | `/{route}` | {페이지 설명} |

  > Preview URL에 `?_preview={route}` 파라미터를 추가하면 해당 페이지로 바로 이동합니다.

  ## 변경사항
  1. {주요 변경사항 1}
  2. {주요 변경사항 2}

  ## Test Plan
  - [ ] {QA 테스트 항목 1}
  - [ ] {QA 테스트 항목 2}
  ```

  **Admin v2 확인 경로 감지 방법**:
  변경된 파일 중 `app/pages/` 하위 파일을 찾아 URL 경로로 변환합니다.
  - `app/pages/` 접두사 제거, `/index.vue` 또는 `.vue` 확장자 제거
  - `[[param]]` → `:param`, `[param]` → `:param`
  - 페이지 파일이 없으면 `app/components/` 도메인 디렉토리로 관련 페이지 추정

### A-4. PR 타이틀에 LK-ID 추가

```bash
command gh api repos/tpcint/{레포명}/pulls/{PR번호} -X PATCH -f title="{기존제목} (LK-{ID})"
```

### A-5. 결과 보고

- 감지/지정된 workspace 정보
- 생성된 Notion 티켓 URL
- 수정된 PR 타이틀

---

## 모드 B: 개발과제 기반 (URL 있을 때)

개발과제 문서를 분석하여 코드베이스 확인 후 작업 문서를 생성합니다.

### B-1. 개발과제 문서 가져오기

```
mcp__tpc-notion__API-retrieve-a-page 또는 WebFetch 사용하여 개발과제 URL 내용 가져오기
```

- 요구사항 파악
- 핵심 키워드, 기능명, API 엔드포인트 등 추출

### B-2. 코드베이스 분석 (파트별)

#### Backend (likey-backend)

```bash
# API 엔드포인트, 서비스, 모델 검색
rg "{키워드}" /Users/muzi/projects/likey-backend/src -t ts | head -30
```

- 관련 API 컨트롤러 확인 (`src/api/`, `src/admin-api/`)
- 관련 서비스/모델 확인 (`src/likey/`)

#### Web (likey-web)

```bash
# 관련 페이지, 컴포넌트, 라이브러리 검색
rg "{키워드}" /Users/muzi/projects/likey-web/pages -g "*.vue" | head -20
rg "{키워드}" /Users/muzi/projects/likey-web/components -g "*.vue" | head -20
rg "{키워드}" /Users/muzi/projects/likey-web/lib -g "*.{ts,js}" | head -20
rg "{키워드}" /Users/muzi/projects/likey-web/store /Users/muzi/projects/likey-web/composables -g "*.{ts,js}" | head -20
```

- 관련 페이지/컴포넌트/store/composables 확인

#### Admin v2 (likey-admin-v2)

```bash
# 관련 페이지, 컴포넌트 검색
rg "{키워드}" /Users/muzi/projects/likey-admin-v2/app -g "*.vue" | head -30
rg "{키워드}" /Users/muzi/projects/likey-admin-v2/components -g "*.vue" | head -20
```

- 관련 페이지 확인 (`app/`)
- 관련 컴포넌트 확인 (`components/`)

#### Admin v1 (likey-admin) - 특별 처리

> **참고**: Admin v1은 신규 기능 개발이 중단되었습니다.
> v1에만 있는 기능 수정 시 v2 이관을 권장합니다.

```bash
# v1 검색
rg "{키워드}" /Users/muzi/projects/likey-admin/pages -g "*.vue" | head -30
rg "{키워드}" /Users/muzi/projects/likey-admin/components -g "*.vue" | head -20

# v2에 동일 기능이 있는지 확인
rg "{키워드}" /Users/muzi/projects/likey-admin-v2/app -g "*.vue" | head -20
```

- v2에 기능 있음 → 사용자에게 admin-v2로 변경 권장
- v1에만 있음 → v2 이관 선행 필요 안내

### B-3. 작업 필요여부 판단 및 확인

분석 결과를 사용자에게 보여주고 확인:

| 항목 | 내용 |
|------|------|
| 작업 필요 | ✅ 필요 / ❌ 불필요 |
| v2 이관 필요 | ⚠️ 필요 / ✅ 불필요 (Admin v1인 경우만) |
| 판단 근거 | {근거 설명} |
| 관련 파일 | {파일 목록} |
| 예상 변경사항 | {변경 내용 요약} |

- 불필요하다고 판단되면 사용자에게 알리고 종료
- 필요하다면 다음 단계 진행

### B-4. Notion 개발 작업 DB에 티켓 생성

- **A-3과 동일한 3단계 API 호출 절차 사용** (post-page → patch-block-children → patch-page)
- **추가 속성**:
  - **과제**: `{개발과제 URL}` ← Relation 자동 연결

- **내용 구조** (일반):
  ```markdown
  ## 개요
  {작업 요약}

  ## 확인 경로 (Admin v2인 경우에만 포함)
  | 경로 | 설명 |
  |------|------|
  | `/{route}` | {페이지 설명} |

  > Preview URL에 `?_preview={route}` 파라미터를 추가하면 해당 페이지로 바로 이동합니다.

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

- **내용 구조** (Admin v1 → v2 이관 필요 시):
  ```markdown
  ## 개요
  {작업 요약}

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

> **Note**: `과제` relation 속성에 개발과제 URL을 설정하면 자동으로 연결됩니다.

### B-5. 결과 보고

- 생성된 Notion 티켓 URL
- 개발과제와의 Relation 연결 완료 여부
- (Admin v1인 경우) v2 이관 필요 여부

---

## 관련 커맨드

| 커맨드 | 용도 |
|--------|------|
| `/create-dev-project {URL}` | 개발과제 문서 생성 (상위 레벨) |
| `/link-pr-task` | 기존 PR과 작업 연결 |
