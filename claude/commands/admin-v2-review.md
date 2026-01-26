# Admin V2 PR 코드 리뷰

Admin V2 (likey-admin-v2) PR의 코드를 리뷰합니다.

## 입력

$ARGUMENTS

- GitHub PR URL 또는 PR 번호 (예: https://github.com/tpcint/likey-admin-v2/pull/123 또는 123)

## 수행 작업

1. **PR 정보 확인**
   - `command gh pr view <PR번호>` 로 PR 정보 가져오기
   - 변경된 파일 목록 확인
   - 기존 리뷰 코멘트 확인

2. **코드 변경사항 분석**
   - 변경된 파일 읽기
   - 코드 품질 검토 (CLAUDE.md 가이드라인 기반)

3. **리뷰 결과 출력**
   - 요약, 잘된 점, 개선 필요 사항 정리

## Admin V2 코드 리뷰 체크리스트

### 필수 검토 사항

#### 1. API 호출 패턴
- [ ] `$api()` 사용 시 적절한 타입 파라미터 사용
- [ ] HTTP 메서드/엔드포인트 경로 변경 시 승인 필요 여부 확인
- [ ] 대량 ID 조회 시 chunk 처리 (800개 기준)

#### 2. TypeScript 규칙
- [ ] `any` 타입 사용 최소화
- [ ] `as` 타입 단언 대신 타입 가드 사용
  - `as HTMLElement` → `instanceof HTMLElement` 또는 `querySelector<HTMLElement>()`
  - `as HTMLInputElement` → `v-model` 사용 권장
- [ ] API 응답 타입은 `components['schemas']` 활용 (하드코딩 금지)

#### 3. Composables 사용
- [ ] **useConfirmDialog 사용**: `useDialog().confirm()` 메서드는 존재하지 않음
  ```typescript
  // ❌ Bad
  const dialog = useDialog();
  await dialog.confirm({...});  // confirm 메서드 없음

  // ✅ Good
  const confirmDialog = useConfirmDialog();
  await confirmDialog.open({
    title: '삭제 확인',
    message: '정말 삭제하시겠습니까?',
    options: {okText: '삭제', cancelText: '취소'},
  });
  ```
- [ ] Auto-import 함수는 별도 import 불필요 (`composables/`, `utils/`)
- [ ] 여러 유저 정보 조회 시 `useUserProfiles()` 사용

#### 4. 에러 처리
- [ ] try-catch에서 `notifyError(err)` 사용
- [ ] localStorage 에러도 `notifyError()` 로 사용자에게 알림 (console.error 금지)
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

#### 5. UI 컴포넌트
- [ ] 날짜 범위 선택은 `DateRangePickerMenu` 우선 사용
- [ ] 미디어 업로드는 `uploadAttachmentMedia()` 사용
- [ ] `<video>` 태그 대신 `CustomVideo.vue` 사용
- [ ] 유저 검색은 `UserPicker` 컴포넌트 사용

#### 6. Vue 템플릿
- [ ] `v-model` 사용 가능한 경우 `@input` 핸들러 대신 `v-model` 사용
- [ ] 인라인 스타일은 `<style scoped>` 섹션으로 이동
- [ ] 컴포넌트 500줄 이하 유지

#### 7. 유틸리티
- [ ] 날짜 처리는 `dayjs` 사용 (moment 금지)
- [ ] `es-toolkit` 함수 우선 활용
- [ ] 디바운스 사용 시 `onUnmounted`에서 `.cancel()` 호출

#### 8. 확인 다이얼로그 옵션
- [ ] 중요하지 않은 정보에는 `confirmText` (추가 입력 필드) 불필요
  ```typescript
  // ❌ Bad - 단순 삭제에 confirmText 불필요
  await confirmDialog.open({
    title: '삭제',
    message: '삭제하시겠습니까?',
    confirmText: '삭제',  // 불필요
  });

  // ✅ Good
  await confirmDialog.open({
    title: '삭제',
    message: '삭제하시겠습니까?',
    options: {okText: '삭제', cancelText: '취소'},
  });
  ```

### 자주 발생하는 실수

1. **존재하지 않는 유틸리티 사용**
   - 삭제되거나 없는 유틸 함수 사용 여부 확인
   - 코드베이스에서 해당 함수 존재 여부 검증

2. **단축키 등록 타이밍**
   - 전역 단축키는 필요한 데이터 로딩 후 의미가 있음
   - 메뉴 데이터가 필요한 검색 단축키 등은 로딩 완료 후 등록

3. **히스토리/캐시 UI 표현**
   - 검색 결과와 히스토리의 표현 방식은 다를 수 있음
   - 히스토리 아이템에는 타입 배지 등 부가 정보 생략 가능

## 출력 형식

```markdown
## PR 요약
[PR 제목 및 주요 변경사항 요약]

## 변경 파일
| 파일 | 변경 내용 |
|------|----------|
| ... | ... |

## 리뷰 결과

### 잘된 점
- [항목 1]
- [항목 2]

### 개선 필요 사항

| 심각도 | 파일:라인 | 내용 |
|--------|-----------|------|
| 🔴 Critical | path/file.vue:123 | 설명 |
| 🟠 Major | path/file.ts:45 | 설명 |
| 🟡 Minor | path/file.vue:78 | 설명 |
| 💬 Comment | path/file.ts:90 | 질문/제안 |

### 상세 코멘트
[각 이슈에 대한 상세 설명 및 수정 예시]
```

## 심각도 기준

- **🔴 Critical**: 버그 발생 가능, 보안 취약점, 잘못된 API 사용
- **🟠 Major**: deprecated API 사용, 타입 안전성 문제, 가이드라인 위반
- **🟡 Minor**: 코드 개선 제안, 성능 최적화 가능
- **💬 Comment**: 질문, 토론 필요 사항

## 주의사항

- 리뷰 시 CLAUDE.md 가이드라인 준수 여부 확인
- 변경된 파일만 리뷰 (관련 없는 파일 리팩토링 제안 금지)
- 기존 코드 스타일 존중
