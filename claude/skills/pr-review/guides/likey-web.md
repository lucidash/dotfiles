# Frontend (likey-web) 코드 리뷰 체크리스트

Nuxt.js 2 + Vue 2 기반 프론트엔드 서비스 전용 체크리스트입니다.

---

## 리뷰 제외 대상

다음 파일들은 **자동 생성**되므로 리뷰에서 제외합니다:

| 파일/패턴 | 설명 |
|-----------|------|
| `models/spec/likey-api.ts` | 백엔드 OpenAPI 스펙에서 자동 생성 |
| `locales/*.json` | Lokalise에서 자동 동기화 |

> **Important**: `likey-api.ts` 변경사항은 백엔드 API 스펙 업데이트에 의해 발생합니다.
> "PR 목적과 무관한 변경"이라는 피드백은 해당되지 않습니다.

---

## 1. 컴포넌트 구조

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| Composition API | 새 컴포넌트는 `defineNuxtComponent` + setup 사용 | 🟡 Minor |
| Script Setup | `<script setup>` 대신 `setup()` 함수 사용 (Nuxt 2) | 🟡 Minor |

## 2. 파일 업로드

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| FileUploader V2 | 새 업로드 기능은 `FileUploaderV2` 사용 | 🟠 Major |
| ProductFileManager V2 | 다중 파일 관리는 `ProductFileManagerV2` 사용 | 🟠 Major |
| upload-type | 각 기능별 올바른 `upload-type` 값 사용 | 🟠 Major |

```typescript
// ✅ 올바른 예시
<FileUploaderV2 upload-type="rouletteRewardMedia" />
<ProductFileManagerV2 upload-type="storeProductCoverMedia" />
```

## 3. API 호출

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| FetchClient | API 호출은 `FetchClient` 사용 | 🟠 Major |
| 타입 안전성 | API 응답에 적절한 타입 지정 | 🟡 Minor |
| Promise 반환 | async 메서드는 `Promise<T>` 반환 타입 명시 | 🟡 Minor |

## 4. 상태 관리

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| Vuex Store | 전역 상태는 Vuex store 사용 | 🟠 Major |
| ref/reactive | 로컬 상태는 Composition API ref/reactive 사용 | 🟡 Minor |

## 5. 라우팅

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 페이지 구조 | `pages/` 디렉토리 구조가 URL 패턴과 일치 | 🟠 Major |
| 동적 라우트 | 동적 파라미터는 `_param.vue` 형식 | 🟡 Minor |

---

## 자동 검사 패턴

```bash
# FileUploader V1 사용 확인 (deprecated)
command gh pr diff {PR번호} | grep -n "FileUploader[^V]"

# ProductFileManager V1 사용 확인 (deprecated)
command gh pr diff {PR번호} | grep -n "ProductFileManager[^V]"
command gh pr diff {PR번호} | grep -n "product-file-manager[^-]"
```

---

## 긍정적 피드백 체크

리뷰 시 다음과 같은 좋은 점도 함께 언급:
- Composition API 적절한 활용
- 타입 안전한 코드
- V2 컴포넌트로 마이그레이션
- null 안전한 처리 (optional chaining, nullish coalescing)
