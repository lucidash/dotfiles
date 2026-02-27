# Admin V2 (likey-admin-v2) 코드 리뷰 체크리스트

Vue 3 + Nuxt 기반 어드민 프론트엔드 전용 체크리스트입니다.

---

## 1. API 호출 패턴

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 타입 파라미터 | `$api()` 사용 시 적절한 타입 파라미터 사용 | 🟠 Major |
| chunk 처리 | 대량 ID 조회 시 800개 기준 chunk 처리 | 🟠 Major |
| API 응답 타입 | `components['schemas']` 활용 (하드코딩 금지) | 🟠 Major |

```typescript
// ✅ 올바른 API 타입 사용
import type {components} from '~/api/schema';
type UserResponse = components['schemas']['UserResponse'];
```

## 2. TypeScript 규칙

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| any 타입 | `any` 타입 사용 최소화 | 🟠 Major |
| 타입 단언 | `as` 대신 타입 가드 또는 제네릭 사용 | 🟠 Major |

```typescript
// ❌ Bad
const el = document.querySelector('.btn') as HTMLElement;

// ✅ Good
const el = document.querySelector<HTMLElement>('.btn');
```

## 3. Composables 사용

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| useConfirmDialog | `useDialog().confirm()` 사용 금지 (존재하지 않음) | 🔴 Critical |
| Auto-import | `composables/`, `utils/` 함수는 별도 import 불필요 | 🟡 Minor |
| useUserProfiles | 여러 유저 정보 조회 시 사용 | 🟡 Minor |

```typescript
// ❌ Bad - confirm 메서드 없음
const dialog = useDialog();
await dialog.confirm({...});

// ✅ Good
const confirmDialog = useConfirmDialog();
await confirmDialog.open({
  title: '삭제 확인',
  message: '정말 삭제하시겠습니까?',
  options: {okText: '삭제', cancelText: '취소'},
});
```

## 4. 에러 처리

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| notifyError | try-catch에서 `notifyError(err)` 사용 | 🟠 Major |
| console.error | `console.error` 대신 `notifyError()` 사용 | 🟠 Major |

```typescript
// ❌ Bad
catch (error) {
  console.error('Failed to load:', error);
}

// ✅ Good
catch (error) {
  notifyError(error);
}
```

## 5. UI 컴포넌트

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 날짜 범위 | `DateRangePickerMenu` 우선 사용 | 🟡 Minor |
| 미디어 업로드 | `uploadAttachmentMedia()` 사용 | 🟡 Minor |
| video 태그 | `<video>` 대신 `CustomVideo.vue` 사용 | 🟡 Minor |
| 유저 검색 | `UserPicker` 컴포넌트 사용 | 🟡 Minor |

## 6. Vue 템플릿

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| v-model | `@input` 핸들러 대신 `v-model` 사용 권장 | 🟡 Minor |
| 인라인 스타일 | `<style scoped>` 섹션으로 이동 | 🟡 Minor |
| 컴포넌트 크기 | 500줄 이하 유지 | 🟡 Minor |
| key 속성 | `v-for`에 적절한 `:key` 바인딩 | 🟠 Major |

## 7. 유틸리티

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 날짜 처리 | `dayjs` 사용 (`moment` 금지) | 🟠 Major |
| 유틸 함수 | `es-toolkit` 함수 우선 활용 | 🟡 Minor |
| 디바운스 | `onUnmounted`에서 `.cancel()` 호출 | 🟠 Major |

```typescript
// ✅ 디바운스 정리
const debouncedFn = debounce(() => {...}, 300);

onUnmounted(() => {
  debouncedFn.cancel();
});
```

## 8. 확인 다이얼로그 옵션

```typescript
// ❌ Bad - confirmText 대신 options 사용
await confirmDialog.open({
  title: '삭제',
  message: '삭제하시겠습니까?',
  confirmText: '삭제',  // 잘못된 속성
});

// ✅ Good
await confirmDialog.open({
  title: '삭제',
  message: '삭제하시겠습니까?',
  options: {okText: '삭제', cancelText: '취소'},
});
```

## 9. 반응성

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| ref vs reactive | 단순 값은 `ref`, 객체는 `reactive` 또는 `ref` | 🟡 Minor |
| computed | 파생 상태는 `computed` 사용 | 🟡 Minor |
| watch | 불필요한 watch 대신 computed 고려 | 🟡 Minor |

---

## 리뷰 제외 대상

다음 파일은 리뷰 스킵:
- `src/api/` - 자동 생성 API 타입
- `auto-imports.d.ts` - 자동 생성
- `components.d.ts` - 자동 생성

---

## 자동 검사 패턴

```bash
# useDialog().confirm() 잘못된 사용
command gh pr diff {PR번호} | grep -n "useDialog().*confirm"

# console.error 사용
command gh pr diff {PR번호} | grep -n "console\\.error"

# console.log 사용
command gh pr diff {PR번호} | grep -n "console\\.log"

# moment 사용
command gh pr diff {PR번호} | grep -n "from ['\"]moment['\"]"

# lodash 사용
command gh pr diff {PR번호} | grep -n "from ['\"]lodash['\"]"

# any 타입 사용
command gh pr diff {PR번호} | grep -n ": any[^a-zA-Z]"

# as 타입 단언 (과도한 사용 확인)
command gh pr diff {PR번호} | grep -n " as [A-Z]"
```

---

## 자주 발생하는 실수

### 1. 존재하지 않는 유틸리티 사용
- 삭제되거나 없는 유틸 함수 사용 여부 확인
- 코드베이스에서 해당 함수 존재 여부 검증

### 2. 단축키 등록 타이밍
- 전역 단축키는 필요한 데이터 로딩 후 의미가 있음
- 메뉴 데이터가 필요한 검색 단축키 등은 로딩 완료 후 등록

### 3. 히스토리/캐시 UI 표현
- 검색 결과와 히스토리의 표현 방식은 다를 수 있음
- 히스토리 아이템에는 타입 배지 등 부가 정보 생략 가능

### 4. 타입 import
```typescript
// ❌ Bad - 런타임에 타입 import
import {UserResponse} from '~/api/schema';

// ✅ Good - 타입 전용 import
import type {UserResponse} from '~/api/schema';
```

### 5. createEditableModel 패턴 - 별도 loading guard 불필요
`createEditableModel`은 내부적으로 `updating` ref를 관리하며, `EditableSelect` 컴포넌트의 UX 흐름(편집 진입 → 값 선택 → confirm → 저장 → 편집 종료)이 자연스럽게 중복 호출을 방지합니다. `update` 콜백에 별도의 `isLoading` 체크를 추가할 필요 없습니다.

```typescript
// ❌ 과잉 - createEditableModel 내부에서 이미 updating 상태 관리
const model = createEditableModel({
  update: async (v) => {
    if (isLoading.value) return; // 불필요
    await updateUserProps({field: v});
  },
});

// ✅ Good - createEditableModel이 updating 상태를 관리
const model = createEditableModel({
  update: v => updateUserProps({field: v}),
});
```

### 6. API enum 값은 매직넘버가 아님
`items` 배열에 나열된 API enum 값(예: `SexualLevel`의 `[0, 17, 19, 29, 39]`)은 도메인 고유 값이므로, 한 함수 내에서 로컬하게 사용되는 경우 상수 추출을 강제하지 않습니다. 여러 파일/함수에서 반복 사용되는 경우에만 상수화를 권장합니다.

```typescript
// ✅ OK - items 배열과 같은 스코프에서 사용되는 enum 값
const sexualLevelModel = createEditableModel<SexualLevel>({
  items: [0, 17, 19, 29, 39],
  update: async (sexualLevel) => {
    const isDownFromAdult = prevLevel >= 19 && sexualLevel < 19;
    // ...
  },
});
```
