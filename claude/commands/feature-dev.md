# Feature Dev - Backend + Admin 병렬 개발

Backend API와 Admin UI를 병렬로 개발하는 워크플로우입니다.
Plan mode에서 API 스펙을 먼저 정의하고, 두 파트가 동시에 구현을 진행합니다.

## 입력
- `$ARGUMENTS`: 기능 설명 (예: "유저 민감정보 조회 기능")

## 워크플로우 개요

```
┌─────────────────────────────────────────────────────────┐
│  Phase 1: Plan - API 스펙 정의                          │
│  - 요구사항 분석                                         │
│  - API endpoint, request/response 타입 설계             │
│  - scratchpad에 스펙 문서 저장                          │
│  - 사용자 승인                                           │
└─────────────────────┬───────────────────────────────────┘
                      │
         ┌────────────┴────────────┐
         ▼                         ▼
┌─────────────────┐       ┌─────────────────┐
│  Phase 2-A      │       │  Phase 2-B      │
│  Backend Agent  │       │  Admin Agent    │
│                 │       │                 │
│  - 스펙대로     │       │  - 스펙 기반    │
│    API 구현     │       │    임시 타입    │
│  - OpenAPI 추가 │       │  - UI 구현      │
│  - PR 생성      │       │  - PR 생성      │
└────────┬────────┘       └────────┬────────┘
         │                         │
         └────────────┬────────────┘
                      ▼
┌─────────────────────────────────────────────────────────┐
│  Phase 3: Sync                                          │
│  - Backend PR 머지 대기 (또는 수동)                      │
│  - Admin에서 npm run update-spec                        │
│  - 임시 타입 → components['schemas'] 교체               │
└─────────────────────────────────────────────────────────┘
```

---

## Phase 1: API 스펙 정의

### 1-1. 요구사항 분석
사용자에게 다음 정보 확인:
- 기능 설명 (ARGUMENTS 또는 추가 질문)
- 관련 슬랙 스레드 URL (있으면)
- 관련 Notion 문서 URL (있으면)

### 1-2. API 스펙 설계
다음 형식으로 API 스펙 초안 작성:

```markdown
## API 스펙: {기능명}

### Endpoint
- **Method**: GET / POST / PUT / DELETE
- **Path**: `/admin/...` 또는 `/user/...`
- **Auth**: admin_api_token

### Request
```typescript
// Query parameters (GET) 또는 Body (POST/PUT)
type Request = {
  // ...
}
```

### Response
```typescript
type Response = {
  // ...
}
```

### 에러 케이스
- 400: ...
- 404: ...
```

### 1-3. 스펙 문서 저장
```
scratchpad 디렉토리에 api-spec-{feature-name}.md 저장
```

### 1-4. 사용자 승인
스펙을 사용자에게 보여주고 확인:
- 수정 필요 시 반영
- 승인 시 Phase 2로 진행

---

## Phase 2: 병렬 구현

### 2-0. 사전 준비

#### Notion 작업 생성
개발과제 및 작업 생성 (slack-to-proj 스킬 참고):
- 개발과제 DB: `collection://e2591524-aa7d-454e-86eb-b925b110aeca`
- 개발작업 DB: `collection://af0b1e4c-6a3f-4d94-81c6-396f86e61574`

#### Worktree 생성
각 repo에 worktree 생성:
```bash
# Backend
cd /Users/muzi/projects/likey-backend
git worktree add "../likey-backend-feature-{name}" -b "feature/{name}"

# Admin
cd /Users/muzi/projects/likey-admin-v2
git worktree add "../likey-admin-v2-feature-{name}" -b "feature/{name}"
```

#### 환경 설정
```bash
# npm install (백그라운드)
# .env 파일 복사
```

### 2-1. Backend Agent 실행

Task 도구로 Backend agent 실행 (run_in_background: true):

```
## 작업 정보
- Notion 작업: {Backend 작업 URL}
- 작업 디렉토리: /Users/muzi/projects/likey-backend-feature-{name}

## API 스펙
{Phase 1에서 정의한 스펙 전체 내용}

## 구현 요청
1. 위 스펙대로 API 구현
2. OpenAPI 스펙 파일 (spec/likey-admin-api.yaml) 업데이트
3. 테스트 작성 (필요시)
4. PR 생성 (/open-pr)

## 주의사항
- 기존 코드 패턴 따르기
- GitHub CLI는 `command gh`로 실행
```

### 2-2. Admin Agent 실행

Task 도구로 Admin agent 실행 (run_in_background: true):

```
## 작업 정보
- Notion 작업: {Admin 작업 URL}
- 작업 디렉토리: /Users/muzi/projects/likey-admin-v2-feature-{name}

## API 스펙 (임시 타입으로 구현)
{Phase 1에서 정의한 스펙 전체 내용}

## 구현 요청
1. 위 스펙 기반으로 임시 타입 정의 (컴포넌트 내부)
2. UI 구현
3. 나중에 update-spec 후 실제 타입으로 교체 예정임을 주석으로 표시
4. PR 생성 (/open-pr)

## 임시 타입 예시
```typescript
// TODO: Backend 머지 후 update-spec 실행하여 실제 타입으로 교체
// import type {components} from '~/models/spec/admin-api'
// type ResponseType = components['schemas']['...']
type ResponseType = {
  // 스펙 기반 임시 타입
}
```

## 주의사항
- CLAUDE.md 컨벤션 준수
- GitHub CLI는 `command gh`로 실행
```

### 2-3. 진행 상황 모니터링
두 agent가 완료될 때까지 대기하고 결과 보고

---

## Phase 3: 동기화

### 3-1. Backend PR 상태 확인
```bash
command gh pr view {backend-pr-number} --json state,mergedAt
```

### 3-2. 동기화 옵션 제시
사용자에게 다음 옵션 제시:

```
## Phase 3: 동기화

Backend PR: {URL} - {상태}
Admin PR: {URL} - {상태}

### 옵션
1. PR에서 바로 스펙 동기화 (권장)
   - Backend PR 머지 없이 바로 스펙 가져오기
   - 임시 타입 교체 커밋

2. Backend PR 머지 후 동기화
   - Backend PR 머지 대기
   - Admin에서 update-spec
   - 임시 타입 교체 커밋

3. 수동 동기화 (나중에)
   - 현재 상태로 종료
   - 나중에 수동으로 update-spec 실행

어떻게 진행할까요?
```

### 3-3. PR에서 바로 스펙 동기화 (옵션 1 선택 시, 권장)

Backend PR이 머지되지 않아도 PR 번호로 스펙을 가져올 수 있습니다.

#### Admin에서 PR 기반 update-spec
```bash
cd /Users/muzi/projects/likey-admin-v2-feature-{name}
./tools/gen-admin-api-types.sh -p {backend-pr-number}
```

### 3-4. Backend 머지 후 동기화 (옵션 2 선택 시)

#### Backend 머지 대기
```bash
# 머지될 때까지 폴링 (또는 사용자가 머지 완료 알림)
command gh pr view {backend-pr-number} --json state
```

#### Admin에서 update-spec
```bash
cd /Users/muzi/projects/likey-admin-v2-feature-{name}
npm run update-spec
```

#### 임시 타입 교체
Admin 코드에서 임시 타입을 실제 스펙 타입으로 교체:
```typescript
// Before
type ResponseType = { ... }

// After
import type {components} from '~/models/spec/admin-api'
type ResponseType = components['schemas']['...']
```

#### 커밋 및 푸시
```bash
git add -A
git commit -m "chore: update-spec 후 실제 타입으로 교체"
git push
```

---

## 결과 보고

```markdown
## Feature Dev 완료

### 기능: {기능명}

### 생성된 리소스
| 항목 | URL |
|------|-----|
| 개발과제 | {Notion URL} |
| Backend 작업 | {Notion URL} |
| Admin 작업 | {Notion URL} |
| Backend PR | {GitHub URL} |
| Admin PR | {GitHub URL} |

### API 스펙
- Endpoint: {method} {path}
- 스펙 문서: {scratchpad 경로}

### 동기화 상태
- [ ] Backend PR 머지됨
- [ ] Admin update-spec 완료
- [ ] 임시 타입 → 실제 타입 교체 완료
```

---

## 참고: 지원 Repository

| Repo | 경로 | 기본 브랜치 |
|------|------|-------------|
| likey-backend | /Users/muzi/projects/likey-backend | master |
| likey-admin-v2 | /Users/muzi/projects/likey-admin-v2 | main |

## 참고: GitHub CLI

GitHub CLI는 `command gh`로 실행 (alias 충돌 방지)
