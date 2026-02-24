---
name: compat-check
description: Backend PR의 API 변경이 기존 클라이언트(Android, iOS, Web)에서 하위 호환성 문제를 일으키는지 검증합니다. "하위 호환 검증", "배포 안전성 체크", "클라이언트 영향 분석", "compat check" 같은 요청에 자동으로 활성화됩니다.
allowed-tools: Bash, Glob, Grep, Read, Task
---

# Backend PR 하위 호환성 검증

Backend PR의 API 변경사항을 분석하고, 현재 릴리즈된 클라이언트(Android, iOS, Web)에서 안전한지 병렬로 검증합니다.

## 트리거 키워드

- "하위 호환 검증", "하위호환 체크", "compat check"
- "배포해도 안전한지", "배포 안전성", "safe to deploy"
- "클라이언트 영향 분석", "breaking change 체크"
- "이 PR 배포해도 돼?"

## 인자

- `$ARGUMENTS`: 다음 중 하나
  - PR URL (예: `https://github.com/tpcint/likey-backend/pull/6438`)
  - PR 번호 (예: `6438`) - 현재 디렉토리의 repo 기준
  - 생략 시 현재 브랜치의 PR

---

## 실행 순서

### 1단계: PR 정보 조회 및 diff 분석

```bash
# PR 정보 조회
command gh pr view {PR} --json number,title,body,files,additions,deletions,author,headRefName,headRefOid,url

# diff 조회 (auto-generated 제외)
command gh pr diff {PR번호} -R tpcint/likey-backend
```

리뷰 제외 대상 (diff 분석 시 스킵):
- `locales/` - 번역 파일
- `spec/*.yaml` - 자동 생성 OpenAPI 스펙
- `src/gen/` - 자동 생성 라우트

### 2단계: API 변경사항 추출

diff에서 다음 카테고리별 변경사항을 분류:

#### 2-1. Breaking Change 후보 식별

| 카테고리 | 검색 패턴 | 위험도 |
|----------|----------|--------|
| **필드 required → optional** | spec YAML에서 `required` 배열 변경, model의 `type: String` → `optional: true` | 높음 |
| **필드 삭제/이름 변경** | 기존 응답 필드가 제거되거나 이름이 바뀐 경우 | 매우 높음 |
| **새 enum 값 추가** | type 필드에 새 값 (예: 새 버킷 타입, 새 아이템 타입) | 중간 |
| **응답 구조 변경** | 중첩 구조 변경, 배열 → 객체 등 | 높음 |
| **필터링/정렬 변경** | 기존에 내려오던 데이터가 필터링되어 안 내려오는 경우 | 중간 |
| **새 필드 추가 (additive)** | 기존 응답에 새 필드 추가 | 낮음 |

#### 2-2. 변경된 API 엔드포인트 목록화

어떤 API 경로가 영향 받는지 파악:
- Controller 파일 변경 → 해당 엔드포인트
- Model/Service 변경 → 해당 모델을 사용하는 엔드포인트

### 3단계: 클라이언트 최신 릴리즈 버전 확인

각 클라이언트의 **현재 프로덕션 배포 버전**을 확인:

```bash
# Android: 최신 release/ 태그 (release/X.Y.Z 형식이 현행 버전)
command gh api 'repos/tpcint/likey-android/tags?per_page=30' --jq '[.[] | select(.name | startswith("release/"))][0].name'

# iOS: master 브랜치 최신 커밋 (master가 릴리즈 브랜치)
command gh api 'repos/tpcint/likey-ios/commits?sha=master&per_page=1' --jq '.[0] | "\(.sha[0:7]) \(.commit.message | split("\n")[0])"'

# Web: 최신 릴리즈 태그
command gh api 'repos/tpcint/likey-web/tags?per_page=1' --jq '.[0].name'
```

**버전 식별 규칙**:

| 플랫폼 | 레포 | 릴리즈 기준 | 참조 |
|--------|------|-----------|------|
| **Android** | `tpcint/likey-android` | 최신 `release/X.Y.Z` 태그 | `command gh api 'repos/tpcint/likey-android/tags?per_page=30'` 에서 `release/` prefix 필터 |
| **iOS** | `tpcint/likey-ios` | **`master` 브랜치** (develop 아님!) | `?ref=master` 사용 |
| **Web** | `tpcint/likey-web` | 최신 릴리즈 태그 (`v6.x.x`) | `command gh release list -R tpcint/likey-web --limit 1` |

### 4단계: 클라이언트별 병렬 검증 (Task 도구 사용)

**3개의 서브에이전트를 동시에** 실행하여 각 클라이언트를 검증합니다.

각 서브에이전트에 전달할 정보:
1. 2단계에서 추출한 **API 변경사항 목록** (구체적으로)
2. 3단계에서 확인한 **해당 플랫폼의 릴리즈 버전/ref**
3. 아래의 **플랫폼별 체크리스트**

#### 서브에이전트 공통 프롬프트 구조

```
## 목표
likey-backend PR #{번호}의 API 변경이 {플랫폼} 클라이언트 ({버전})에서
하위 호환성 문제를 일으키는지 검토합니다.

## API 변경사항
{2단계에서 추출한 구체적 변경 목록}

## 검토 기준
{플랫폼}: `tpcint/{repo}`의 `{ref}` 기준

## 핵심 확인 사항
{플랫폼별 체크리스트 — 아래 참조}

## 출력 형식
| 변경점 | 영향 여부 | 근거 (파일 또는 코드 스니펫) | 위험도 |
```

### 5단계: 결과 종합 및 판정

서브에이전트 결과를 종합하여 최종 판정을 내립니다.

---

## 플랫폼별 체크리스트

### Android 체크리스트

**레포**: `tpcint/likey-android`
**릴리즈 기준**: 최신 `release/X.Y.Z` 태그
**파일 조회**: `command gh api 'repos/tpcint/likey-android/contents/{path}?ref={tag}' --jq '.content' | base64 -d`

| 확인 항목 | 방법 | 위험 판단 기준 |
|----------|------|--------------|
| **JSON 파서** | `build.gradle` 또는 DI 모듈에서 Moshi/Gson/kotlinx.serialization 확인 | Moshi/Gson은 unknown fields 무시 (안전), kotlinx.serialization은 `ignoreUnknownKeys` 설정 필요 |
| **모델 필드 nullability** | data class에서 `val field: String` vs `val field: String?` vs `val field: String = ""` | non-nullable + 기본값 없음 → JSON 누락 시 크래시 |
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
| **Decodable 모델** | struct에서 `let field: String` vs `let field: String?` | non-optional → JSON 누락 시 `DecodingError` |
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
| **컴포넌트 매핑** | `mappingComponentName()` 등에서 type → component 매핑 | unknown type에 대한 fallback 없으면 빈 렌더링 |
| **필드 사용처** | `.targetUrl`, `.callToAction` 등 실제 접근 코드 | null check 없이 `.trim()`, `new URL()` 등 호출 시 TypeError |
| **Vue 컴포넌트 가드** | `v-if` 가드, `<component :is="...">` 동작 | `undefined` 시 Vue 2는 경고만 출력, 크래시 안함 |

**검색 키워드**: `targetUrl`, `BucketType`, `bucketType`, `mappingComponentName`, `category`, `explore`, `bucket`

---

## 출력 형식

### 최종 보고서

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

---

## 주의사항

- **실제 코드를 반드시 읽고** 근거를 제시할 것. 추측 금지
- additive 변경(새 필드 추가)은 대부분 안전하지만, strict JSON 파서 사용 시 확인 필요
- OpenAPI spec 변경과 실제 서버 코드 동작이 다를 수 있으므로 **둘 다** 확인
- 서버에서 "여전히 값을 설정하고 있는지" 실제 코드 경로를 추적하여 확인
- 운영 절차로 보호되는 항목(예: 어드민에서 수동 생성)도 리스크로 기록하되 위험도를 낮게 판정
