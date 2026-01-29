---
name: analyze-repo-patterns
description: |
  PR 리뷰 시 특정 패턴/키워드의 최근 사용례를 분석합니다.
  "이 패턴 최근에 어떻게 쓰여?", "프로젝트 컨벤션 확인해줘" 같은 요청에 사용.
  pr-review 스킬에서 sub agent로 호출하여 프로젝트 방향성을 파악할 때 유용합니다.
allowed-tools: Bash, Glob, Grep, Read
---

# 프로젝트 패턴 분석 스킬

PR 리뷰나 코드 작성 시, 특정 패턴/키워드가 프로젝트에서 어떻게 사용되는지 분석합니다.

## 사용 목적

- PR 리뷰 중 "이 방식이 맞나?" 확인
- 프로젝트 내 표준 패턴 파악
- 최근 PR에서의 사용례 및 방향성 확인
- 코드 제안 시 근거 자료 수집

## 트리거 키워드

- "이 패턴 최근에 어떻게 쓰여?"
- "프로젝트 컨벤션 확인해줘"
- "최근 PR에서 어떻게 사용해?"
- "{패턴명} 사용례 찾아줘"
- pr-review에서 sub agent로 호출

## 인자

- `$ARGUMENTS`: 분석할 패턴 또는 키워드
  - 예: `useConfirmDialog`, `notifyError`, `ConfirmDialog ref`
  - 여러 키워드: `useConfirmDialog OR useDialog`

## 실행 순서

### 1. 현재 Repository 확인

```bash
# 현재 repo 이름 확인
basename $(git remote get-url origin) .git
```

### 2. 최근 머지된 PR 목록 조회

```bash
# 최근 20개 머지된 PR 조회
command gh pr list --state merged --limit 20 --json number,title,mergedAt
```

### 3. 코드베이스 내 패턴 사용 현황

```bash
# 현재 코드에서 패턴 사용 파일 검색
grep -r "{패턴}" --include="*.vue" --include="*.ts" -l | head -20

# 사용 횟수 카운트
grep -r "{패턴}" --include="*.vue" --include="*.ts" | wc -l
```

### 4. 최근 PR에서 패턴 사용 확인

가장 관련성 높은 PR 2-3개를 선별하여 diff 확인:

```bash
# PR diff에서 패턴 검색
command gh pr diff {PR번호} | grep -B5 -A10 "{패턴}"
```

### 5. 실제 사용 예시 추출

패턴이 사용된 파일에서 컨텍스트 포함 코드 스니펫 추출:

```bash
# 패턴 사용 예시 (전후 10줄)
grep -r "{패턴}" --include="*.vue" --include="*.ts" -B5 -A10 | head -60
```

### 6. 패턴 비교 (구 방식 vs 신 방식)

만약 대체 패턴이 있다면 비교:

```bash
# 구 방식 사용 횟수
grep -r "{구패턴}" --include="*.vue" --include="*.ts" | wc -l

# 신 방식 사용 횟수
grep -r "{신패턴}" --include="*.vue" --include="*.ts" | wc -l
```

---

## 출력 형식

```markdown
## 패턴 분석: {패턴명}

### 사용 현황
- **총 사용 파일**: {N}개
- **총 사용 횟수**: {M}회

### 최근 PR 예시

#### PR #{번호} - {제목}
```{언어}
// 코드 스니펫
```

#### PR #{번호} - {제목}
```{언어}
// 코드 스니펫
```

### 권장 패턴

```{언어}
// 권장되는 사용 방식
```

### 비교 (해당 시)
| 방식 | 사용 횟수 | 비고 |
|------|----------|------|
| 구 방식 (`{구패턴}`) | {N}회 | 레거시 |
| 신 방식 (`{신패턴}`) | {M}회 | 권장 |

### 참고 PR
- [#{번호}]({URL}) - {제목}
- [#{번호}]({URL}) - {제목}

### 결론
{패턴 사용에 대한 권장 사항 요약}
```

---

## 예시 시나리오

### 시나리오 1: ConfirmDialog 사용 방식 확인

**입력**: `useConfirmDialog`

**분석 과정**:
1. `useConfirmDialog` 사용 파일 검색 → 45개 파일
2. `ConfirmDialog ref` 방식 검색 → 3개 파일 (레거시)
3. 최근 PR #1091, #1088에서 사용례 확인
4. 권장: `useConfirmDialog()` composable 사용

### 시나리오 2: 에러 처리 패턴 확인

**입력**: `notifyError`

**분석 과정**:
1. `notifyError` 사용 횟수 확인
2. `console.error` 사용 횟수 확인 (대체 대상)
3. 최근 PR #1102에서 `alert -> notify~` 리팩토링 확인
4. 권장: `notifyError()` 사용 (auto-import)

---

## Sub Agent 호출 예시

pr-review 스킬에서 이 스킬을 호출할 때:

```
Task 도구 사용:
- subagent_type: "Explore" 또는 "general-purpose"
- prompt: "analyze-repo-patterns 스킬을 실행하여 'useConfirmDialog' 패턴의 최근 사용례를 분석해줘"
```

또는 직접 호출:
```
/analyze-repo-patterns useConfirmDialog
```

---

## 주의사항

- 자동 생성 파일 (예: `admin-api.ts`, `auto-imports.d.ts`)은 분석에서 제외
- 최근 PR 기준은 머지된 PR만 대상
- 패턴 비교 시 단순 횟수뿐 아니라 최근 추세도 고려
- 결과는 리뷰 코멘트 작성 시 참고 자료로 활용
