# 공통 코드 리뷰 체크리스트

모든 프로젝트에 적용되는 공통 체크리스트입니다.

---

## 1. 코드 품질

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 하드코딩 시크릿 | API 키, 비밀번호 등 하드코딩 금지 | 🔴 Critical |
| console.log | 디버깅용 console.log 제거 | 🟠 Major |
| 주석 처리 코드 | 사용하지 않는 주석 처리된 코드 제거 | 🟡 Minor |
| TODO/FIXME | 해결되지 않은 TODO 확인 | 💬 Comment |

## 2. 보안

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 인증/인가 | 적절한 권한 체크 여부 | 🔴 Critical |
| 입력 검증 | 사용자 입력 검증 여부 | 🔴 Critical |
| SQL/NoSQL 인젝션 | 쿼리 파라미터 이스케이프 | 🔴 Critical |
| XSS | 사용자 입력 출력 시 이스케이프 | 🔴 Critical |

## 3. 에러 처리

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| try-catch | 적절한 에러 처리 여부 | 🟠 Major |
| 에러 전파 | 에러가 적절히 전파되는지 | 🟠 Major |
| 에러 로깅 | 에러 발생 시 로깅 여부 | 🟡 Minor |

## 4. 성능

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| N+1 쿼리 | 반복문 내 개별 쿼리 호출 | 🟠 Major |
| 불필요한 연산 | 반복문 내 불필요한 연산 | 🟡 Minor |
| 메모리 누수 | 이벤트 리스너, 타이머 정리 | 🟠 Major |

## 5. 타입 안전성 (TypeScript)

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| any 타입 | `any` 타입 사용 최소화 | 🟠 Major |
| 타입 단언 | 불필요한 `as` 캐스팅 | 🟠 Major |
| null 체크 | optional chaining 또는 null 체크 | 🟠 Major |

## 6. 라이브러리 사용

| 항목 | 검사 내용 | 심각도 |
|------|----------|--------|
| 날짜 처리 | `dayjs` 사용 (`moment` 금지) | 🟠 Major |
| 유틸리티 | `es-toolkit` 사용 (`lodash` 금지) | 🟠 Major |

---

## 자동 검사 패턴

```bash
# console.log 사용 확인
command gh pr diff {PR번호} | grep -n "console\\.log"

# moment 사용 확인
command gh pr diff {PR번호} | grep -n "from ['\"]moment['\"]"

# lodash 사용 확인
command gh pr diff {PR번호} | grep -n "from ['\"]lodash['\"]"

# 하드코딩된 시크릿 패턴
command gh pr diff {PR번호} | grep -niE "(api_key|apikey|secret|password|token)\s*[:=]\s*['\"][^'\"]+['\"]"
```

---

## 긍정적 피드백 체크

리뷰 시 다음과 같은 좋은 점도 함께 언급:
- 깔끔한 코드 구조
- 적절한 에러 처리
- 좋은 변수/함수 네이밍
- 재사용 가능한 추상화
- 충분한 테스트 커버리지
