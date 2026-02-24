---
name: can-i-release
description: PR의 변경이 현재 배포된 다른 서비스와 하위 호환되는지 양방향으로 검증합니다. Backend PR은 클라이언트(Android, iOS, Web) 대비, Client PR은 Backend 대비 검증합니다. "배포해도 돼?", "릴리즈 가능?", "can I release" 같은 요청에 자동으로 활성화됩니다.
allowed-tools: Bash, Glob, Grep, Read, Task
---

# PR 배포 호환성 양방향 검증

PR의 API 변경사항을 분석하고, 현재 릴리즈된 상대 서비스와의 하위 호환성을 양방향으로 검증합니다.

- **Backend PR** -> 클라이언트(Android, iOS, Web) 3곳 최신 릴리즈 기준 검증
- **Client PR (Android/iOS/Web)** -> Backend 최신 릴리즈(master) 기준 검증

## 트리거 키워드

- "릴리즈 가능?", "릴리즈해도 돼?", "can I release", "release check"
- "배포 가능?", "배포해도 돼?", "지금 배포해도 돼?"
- "하위 호환 검증", "하위호환 체크", "compat check"
- "배포해도 안전한지", "배포 안전성", "safe to deploy"
- "클라이언트 영향 분석", "breaking change 체크"
- "이 PR 배포해도 돼?"

## 인자

- `$ARGUMENTS`: 다음 중 하나
  - PR URL (예: `https://github.com/tpcint/likey-backend/pull/6438`, `https://github.com/tpcint/likey-android/pull/1234`)
  - PR 번호 (예: `6438`) - 현재 디렉토리의 repo 기준
  - 생략 시 현재 브랜치의 PR

---

## 실행 순서

### 1단계: PR 정보 조회 및 레포 자동 감지

```bash
# PR 정보 조회
command gh pr view {PR} --json number,title,body,files,additions,deletions,author,headRefName,headRefOid,url,baseRefName
```

PR URL 또는 조회 결과에서 레포를 자동 판별:

| PR 레포 | 판별 결과 | 검증 방향 |
|---------|----------|----------|
| `tpcint/likey-backend` | Backend PR | -> 클라이언트 3곳 검증 |
| `tpcint/likey-android` | Android PR | -> Backend 검증 |
| `tpcint/likey-ios` | iOS PR | -> Backend 검증 |
| `tpcint/likey-web` | Web PR | -> Backend 검증 |

판별 후, **2단계-A** (Backend PR) 또는 **2단계-B** (Client PR) 중 해당 플로우로 진행합니다.

---

### 2단계-A: Backend PR인 경우 (기존 compat-check와 동일)

#### 2-A-1. diff 분석

```bash
# diff 조회 (auto-generated 제외)
command gh pr diff {PR번호} -R tpcint/likey-backend
```

리뷰 제외 대상 (diff 분석 시 스킵):
- `locales/` - 번역 파일
- `spec/*.yaml` - 자동 생성 OpenAPI 스펙
- `src/gen/` - 자동 생성 라우트

#### 2-A-2. API 변경사항 추출

diff에서 다음 카테고리별 변경사항을 분류:

##### Breaking Change 후보 식별

| 카테고리 | 검색 패턴 | 위험도 |
|----------|----------|--------|
| **필드 required -> optional** | spec YAML에서 `required` 배열 변경, model의 `type: String` -> `optional: true` | 높음 |
| **필드 삭제/이름 변경** | 기존 응답 필드가 제거되거나 이름이 바뀐 경우 | 매우 높음 |
| **새 enum 값 추가** | type 필드에 새 값 (예: 새 버킷 타입, 새 아이템 타입) | 중간 |
| **응답 구조 변경** | 중첩 구조 변경, 배열 -> 객체 등 | 높음 |
| **필터링/정렬 변경** | 기존에 내려오던 데이터가 필터링되어 안 내려오는 경우 | 중간 |
| **새 필드 추가 (additive)** | 기존 응답에 새 필드 추가 | 낮음 |

##### 변경된 API 엔드포인트 목록화

어떤 API 경로가 영향 받는지 파악:
- Controller 파일 변경 -> 해당 엔드포인트
- Model/Service 변경 -> 해당 모델을 사용하는 엔드포인트

#### 2-A-3. 클라이언트 최신 릴리즈 버전 확인

```bash
# Android: 최신 release/ 태그 (release/X.Y.Z 형식이 현행 버전)
command gh api 'repos/tpcint/likey-android/tags?per_page=30' --jq '[.[] | select(.name | startswith("release/"))][0].name'

# iOS: master 브랜치 최신 커밋 (master가 릴리즈 브랜치)
command gh api 'repos/tpcint/likey-ios/commits?sha=master&per_page=1' --jq '.[0] | "\(.sha[0:7]) \(.commit.message | split("\n")[0])"'

# Web: 최신 릴리즈 태그
command gh api 'repos/tpcint/likey-web/tags?per_page=1' --jq '.[0].name'
```

#### 2-A-4. 클라이언트별 병렬 검증 (Task 도구 사용)

**3개의 서브에이전트를 동시에** 실행하여 각 클라이언트를 검증합니다.

각 서브에이전트에 전달할 정보:
1. 2-A-2에서 추출한 **API 변경사항 목록** (구체적으로)
2. 2-A-3에서 확인한 **해당 플랫폼의 릴리즈 버전/ref**
3. 아래의 **플랫폼별 체크리스트**

##### 서브에이전트 공통 프롬프트 구조

```
## 목표
likey-backend PR #{번호}의 API 변경이 {플랫폼} 클라이언트 ({버전})에서
하위 호환성 문제를 일으키는지 검토합니다.

## API 변경사항
{2-A-2에서 추출한 구체적 변경 목록}

## 검토 기준
{플랫폼}: `tpcint/{repo}`의 `{ref}` 기준

## 핵심 확인 사항
{플랫폼별 체크리스트 -- 아래 참조}

## 출력 형식
| 변경점 | 영향 여부 | 근거 (파일 또는 코드 스니펫) | 위험도 |
```

#### 2-A-5. 결과 종합 및 판정

서브에이전트 결과를 종합하여 최종 판정을 내립니다. -> **5단계: 결과 출력**으로 이동

---

### 2단계-B: Client PR인 경우 (Android/iOS/Web -> Backend 검증)

#### 2-B-1. 클라이언트 diff 분석

```bash
# diff 조회
command gh pr diff {PR번호} -R tpcint/{repo}
```

#### 2-B-2. API 사용 변경사항 추출

클라이언트 diff에서 API 관련 변경사항을 추출:

| 카테고리 | 검색 포인트 | 예시 |
|----------|-----------|------|
| **새 API 엔드포인트 호출** | 새로운 API 경로 추가, Retrofit/URLSession/fetch 호출 | `@GET("v2/explore/new-endpoint")` |
| **새 필드 사용** | 응답 모델에서 새 필드 접근 | `response.newField` |
| **새 enum 값 전송** | 요청에 새 enum 값 포함 | `type = "NEW_TYPE"` |
| **삭제된 필드 미전송** | 더 이상 보내지 않는 요청 필드 | 요청 body에서 필드 제거 |
| **변경된 요청 구조** | 요청 body/query 파라미터 구조 변경 | 파라미터 이름/타입 변경 |

#### 2-B-3. Backend 최신 릴리즈 버전 확인

```bash
# Backend: master 브랜치 최신 커밋 (현재 배포 버전)
command gh api 'repos/tpcint/likey-backend/commits?sha=master&per_page=1' --jq '.[0] | "\(.sha[0:7]) \(.commit.message | split("\n")[0])"'
```

#### 2-B-4. Backend 대비 검증 (Task 도구 사용)

**1개의 서브에이전트**를 실행하여 Backend 대비 호환성을 검증합니다.

##### 서브에이전트 프롬프트 구조

```
## 목표
{플랫폼} PR #{번호}의 API 사용 변경이 Backend 현재 배포 버전(master)에서
호환되는지 검토합니다.

## API 사용 변경사항
{2-B-2에서 추출한 구체적 변경 목록}

## 검토 기준
Backend: `tpcint/likey-backend`의 `master` 기준

## 핵심 확인 사항
{아래 Backend 대비 체크리스트}

## 출력 형식
| 변경점 | 영향 여부 | 근거 (파일 또는 코드 스니펫) | 위험도 |
```

##### Backend 대비 체크리스트

**레포**: `tpcint/likey-backend`
**릴리즈 기준**: `master` 브랜치 (최신 배포 버전)
**파일 조회**: `command gh api 'repos/tpcint/likey-backend/contents/{path}?ref=master' --jq '.content' | base64 -d`

| 확인 항목 | 방법 | 위험 판단 기준 |
|----------|------|--------------|
| **새 API 엔드포인트 호출** | 클라이언트 diff에서 새로운 API 경로 추가 확인 -> Backend master에 해당 라우트 존재 여부 | Backend에 없으면 배포 불가 |
| **새 필드 사용** | 클라이언트가 응답에서 새 필드를 읽는 경우 -> Backend master에서 해당 필드 제공 여부 | Backend에서 안 내려오면 null/undefined로 동작 확인 필요 |
| **새 enum 값 전송** | 클라이언트가 요청에 새 enum 값을 포함하는 경우 -> Backend에서 해당 값 처리 여부 | Backend에서 unknown 값 에러 시 위험 |
| **삭제된 필드 의존** | 클라이언트가 더 이상 보내지 않는 필드 -> Backend에서 해당 필드 필수 여부 | Backend에서 required면 에러 |
| **변경된 요청 구조** | 요청 body/query 구조 변경 -> Backend 검증 통과 여부 | tsoa 검증 실패 시 400 에러 |

**검증 방법**:
- Backend master의 Controller/Service 코드에서 해당 엔드포인트 확인
- tsoa 라우트의 파라미터 검증 로직 확인
- OpenAPI spec(`spec/*.yaml`)에서 해당 엔드포인트 스키마 확인
- 실제 서비스 코드에서 필드 사용 여부 및 필수/선택 여부 확인

#### 2-B-5. 결과 종합 및 판정

서브에이전트 결과를 종합하여 최종 판정을 내립니다. -> **5단계: 결과 출력**으로 이동

---

## 버전 식별 규칙 (4개 레포 전체)

| 플랫폼 | 레포 | 릴리즈 기준 | 조회 방법 |
|--------|------|-----------|----------|
| **Backend** | `tpcint/likey-backend` | `master` 브랜치 (최신 배포 버전) | `command gh api 'repos/tpcint/likey-backend/commits?sha=master&per_page=1'` |
| **Android** | `tpcint/likey-android` | 최신 `release/X.Y.Z` 태그 | `command gh api 'repos/tpcint/likey-android/tags?per_page=30' --jq '[.[] \| select(.name \| startswith("release/"))][0].name'` |
| **iOS** | `tpcint/likey-ios` | **`master` 브랜치** (develop 아님!) | `command gh api 'repos/tpcint/likey-ios/commits?sha=master&per_page=1'` |
| **Web** | `tpcint/likey-web` | 최신 릴리즈 태그 (`v6.x.x`) | `command gh api 'repos/tpcint/likey-web/tags?per_page=1' --jq '.[0].name'` |

---

## 플랫폼별 체크리스트 (Backend PR -> 클라이언트 검증 시 사용)

### Android 체크리스트

**레포**: `tpcint/likey-android`
**릴리즈 기준**: 최신 `release/X.Y.Z` 태그
**파일 조회**: `command gh api 'repos/tpcint/likey-android/contents/{path}?ref={tag}' --jq '.content' | base64 -d`

| 확인 항목 | 방법 | 위험 판단 기준 |
|----------|------|--------------|
| **JSON 파서** | `build.gradle` 또는 DI 모듈에서 Moshi/Gson/kotlinx.serialization 확인 | Moshi/Gson은 unknown fields 무시 (안전), kotlinx.serialization은 `ignoreUnknownKeys` 설정 필요 |
| **모델 필드 nullability** | data class에서 `val field: String` vs `val field: String?` vs `val field: String = ""` | non-nullable + 기본값 없음 -> JSON 누락 시 크래시 |
| **enum 처리** | enum class 또는 String 타입 사용 여부, unknown value 처리 | `@JsonClass`의 enum은 unknown 시 크래시 가능. String이면 안전 |
| **타입 필터링/매핑** | Mapper 클래스에서 `when(type)`, `filter {}` 등 | `else ->` 분기 또는 `runCatching` 있으면 안전 |
| **해당 API 호출 존재 여부** | API interface (Retrofit)에서 엔드포인트 검색 | 호출하지 않는 API면 영향 없음 |

**검색 키워드**: `targetUrl`, `bucketType`, `BucketType`, `bucket`, `category`, `explore`, `Mapper`, `@JsonClass`

### iOS 체크리스트

**레포**: `tpcint/likey-ios`
**릴리즈 기준**: `master` 브랜치 (develop 아님!)
**파일 조회**: `command gh api 'repos/tpcint/likey-ios/contents/{path}?ref=master' --jq '.content' | base64 -d`

| 확인 항목 | 방법 | 위험 판단 기준 |
|----------|------|--------------|
| **Decodable 모델** | struct에서 `let field: String` vs `let field: String?` | non-optional -> JSON 누락 시 `DecodingError` |
| **enum 디코딩** | `Codable` enum, `EnumDecodable` 프로토콜 여부 | `EnumDecodable`에 `.unknown` case 있으면 안전, 없으면 unknown 값에서 크래시 |
| **unknown type 필터링** | `filter { $0.type != .unknown }` 같은 코드 | 필터링 있으면 새 타입이 와도 안전 |
| **해당 API 호출 존재 여부** | `APIService.swift` 또는 Repository에서 엔드포인트 검색 | 호출하지 않는 API면 영향 없음 |

**검색 키워드**: `targetUrl`, `BucketType`, `ItemOnBucket`, `category`, `explore`, `EnumDecodable`, `Decodable`

### Web 체크리스트

**레포**: `tpcint/likey-web`
**릴리즈 기준**: 최신 릴리즈 태그
**파일 조회**: `command gh api 'repos/tpcint/likey-web/contents/{path}?ref={tag}' --jq '.content' | base64 -d`

| 확인 항목 | 방법 | 위험 판단 기준 |
|----------|------|--------------|
| **TypeScript 타입 정의** | `models/interfaces/`, `models/classes/`에서 필드 타입 확인 | non-optional 타입이어도 JS 런타임에서는 undefined가 됨 (크래시는 아니지만 TypeError 가능) |
| **컴포넌트 매핑** | `mappingComponentName()` 등에서 type -> component 매핑 | unknown type에 대한 fallback 없으면 빈 렌더링 |
| **필드 사용처** | `.targetUrl`, `.callToAction` 등 실제 접근 코드 | null check 없이 `.trim()`, `new URL()` 등 호출 시 TypeError |
| **Vue 컴포넌트 가드** | `v-if` 가드, `<component :is="...">` 동작 | `undefined` 시 Vue 2는 경고만 출력, 크래시 안함 |

**검색 키워드**: `targetUrl`, `BucketType`, `bucketType`, `mappingComponentName`, `category`, `explore`, `bucket`

---

## 출력 형식

### Backend PR 보고서

```markdown
## Backend PR #{번호} 하위 호환성 검증 결과

**PR**: {제목}
**작성자**: @{author}

### 검증 기준 버전

| 플랫폼 | 버전/Ref | 날짜 |
|--------|---------|------|
| Android | `release/X.Y.Z` | YYYY-MM-DD |
| iOS | `master` (`commitMsg`) | YYYY-MM-DD |
| Web | `vX.Y.Z` | YYYY-MM-DD |

### API 변경사항 요약

| 카테고리 | 변경 내용 | 영향 범위 |
|----------|----------|----------|

### 플랫폼별 검증 결과

#### Android
| 변경점 | 영향 | 근거 | 위험도 |
|--------|------|------|--------|

#### iOS
| 변경점 | 영향 | 근거 | 위험도 |
|--------|------|------|--------|

#### Web
| 변경점 | 영향 | 근거 | 위험도 |
|--------|------|------|--------|

### 최종 판정

| 항목 | 결과 |
|------|------|
| **즉시 배포 가능 여부** | Safe / Unsafe / 조건부 Safe |
| **배포 전 필요 조치** | (있으면 기술) |
| **배포 후 주의사항** | (있으면 기술) |
| **향후 주의사항** | (deprecation 등 장기 영향) |
```

### Client PR 보고서 (Android/iOS/Web)

```markdown
## {플랫폼} PR #{번호} 배포 호환성 검증 결과

**PR**: {제목}
**작성자**: @{author}
**플랫폼**: {Android/iOS/Web}

### 검증 기준
| 대상 | 버전/Ref |
|------|---------|
| Backend | `master` ({commit message}) |

### API 사용 변경사항
| 카테고리 | 변경 내용 | Backend 지원 여부 |
|----------|----------|-----------------|

### Backend 대비 검증 결과
| 변경점 | 영향 | 근거 | 위험도 |
|--------|------|------|--------|

### 최종 판정
| 항목 | 결과 |
|------|------|
| **즉시 배포 가능 여부** | Safe / Unsafe / 조건부 Safe |
| **배포 전 필요 조치** | (있으면 기술) |
| **배포 순서** | (Backend 먼저 등) |
```

---

## 주의사항

- **실제 코드를 반드시 읽고** 근거를 제시할 것. 추측 금지
- additive 변경(새 필드 추가)은 대부분 안전하지만, strict JSON 파서 사용 시 확인 필요
- OpenAPI spec 변경과 실제 서버 코드 동작이 다를 수 있으므로 **둘 다** 확인
- 서버에서 "여전히 값을 설정하고 있는지" 실제 코드 경로를 추적하여 확인
- 운영 절차로 보호되는 항목(예: 어드민에서 수동 생성)도 리스크로 기록하되 위험도를 낮게 판정
- **Client PR 검증 시**: 클라이언트가 새로 사용하는 API/필드가 Backend master에 이미 존재하는지가 핵심. 존재하지 않으면 Backend를 먼저 배포해야 하므로 **Unsafe** 판정
- **배포 순서 권고**: Client PR이 Backend 미배포 기능에 의존하면, 반드시 "Backend 먼저 배포" 순서를 명시
- `command gh` 사용 필수 (gh는 git history로 aliased 되어 있음)
