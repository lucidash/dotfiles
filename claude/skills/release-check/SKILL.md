---
name: release-check
description: iOS/Android 릴리즈 문서 URL을 입력하면, 관련 서버/백엔드 작업의 배포 상태를 체크하고 Backend 엔지니어가 준비해야 할 사항을 정리합니다. "릴리즈 체크", "배포 준비 확인", "release check", "릴리즈 문서 확인" 같은 요청에 자동으로 활성화됩니다.
allowed-tools: Bash, Glob, Grep, Read, Agent, mcp__tpc-notion__API-retrieve-a-page, mcp__tpc-notion__API-get-block-children
---

# Release Check - 클라이언트 릴리즈 대비 서버 배포 준비 상태 확인

클라이언트(iOS/Android) 릴리즈 Notion 문서를 분석하여, 관련 서버/백엔드 작업의 배포 상태를 체크하고 Backend 엔지니어가 준비해야 할 사항을 정리합니다.

## 트리거 키워드

- "릴리즈 체크", "릴리즈 확인", "release check"
- "배포 준비 확인", "서버 배포 준비"
- "릴리즈 문서 확인해줘"
- iOS/Android 릴리즈 Notion URL이 포함된 요청

## 인자

- `$ARGUMENTS`: Notion 릴리즈 문서 URL
  - 예: `https://www.notion.so/tpcinternet/iOS-7-4-5-31461056ee12805d9d1ae063be385b2d`

---

## 실행 순서

### 1단계: Notion 페이지 ID 추출 및 릴리즈 문서 조회

URL에서 마지막 하이픈(`-`) 뒤의 32자리 hex 문자열이 page ID입니다.

```
예: ...iOS-7-4-5-31461056ee12805d9d1ae063be385b2d
→ page_id: 31461056ee12805d9d1ae063be385b2d
```

`mcp__tpc-notion__API-retrieve-a-page`로 페이지를 조회합니다.

**추출할 정보**:
- `Name` (title): 릴리즈 이름 (예: "iOS 7.4.5")
- `플랫폼` (select): iOS / Android
- `배포예정일` (date): 배포 예정 날짜
- `상태` (status): 릴리즈 상태
- `포함 작업` (relation): 릴리즈에 포함된 작업 ID 목록
- `작업 진척도` (rollup): 전체 진척도

### 2단계: 포함 작업 조회 + 서버 작업 탐색 (subagent 병렬 처리)

`포함 작업` relation의 작업 수에 따라 처리 방식을 결정합니다.

#### 분기 기준: 포함 작업 5개 이하 → 직접 처리 / 6개 이상 → subagent 병렬 처리

---

#### A. 직접 처리 (포함 작업 ≤ 5개)

모든 작업 ID를 **병렬** `mcp__tpc-notion__API-retrieve-a-page` 호출로 조회합니다.
조회 후 `과제작업` rollup에서 형제 작업 ID를 수집하고, 미조회 형제 작업을 다시 병렬 조회합니다.
`파트`가 **Server**이거나 `작업 유형`이 **서버 기능 개발**인 작업만 필터링합니다.

---

#### B. subagent 병렬 처리 (포함 작업 ≥ 6개)

포함 작업 ID 목록을 **2~3개 그룹**으로 균등 분할하고, 각 그룹을 Agent 도구의 subagent에 위임합니다.

**그룹 분할 기준**:
- 6~12개 → 2개 subagent
- 13개 이상 → 3개 subagent

**각 subagent 프롬프트 템플릿**:

```
다음 Notion 작업 페이지 ID들을 조회하고, 관련 서버 작업을 찾아서 정리해줘.
이것은 iOS/Android 릴리즈에 포함된 작업들이야.

## 할당된 작업 ID 목록
{할당된 ID 목록, 각 줄에 하나씩}

## 수행할 작업

1. 위 ID들을 `mcp__tpc-notion__API-retrieve-a-page`로 병렬 조회 (ToolSearch로 먼저 로드 필요)
2. 각 작업에서 추출:
   - `작업 이름` (title), `ID` (unique_id): LK-XXXX
   - `파트` (select), `작업 유형` (select)
   - `상태` (status), `배포가능` (formula)
   - `PR Link` (rollup), `과제` (relation)
   - `과제작업` (rollup): 같은 과제 내 다른 작업 ID 목록
   - `작업자` (people), `관련자` (people)
3. `과제작업` rollup에서 이미 조회한 ID를 제외한 형제 작업 ID를 수집
4. 형제 작업들을 병렬 조회
5. 전체 조회 결과에서 `파트`가 "Server"이거나 `작업 유형`이 "서버 기능 개발"인 작업만 필터링

## 반환 형식 (JSON)

서버 작업을 찾지 못했으면 빈 배열 반환.
찾았으면 각 서버 작업에 대해:

{
  "serverTasks": [
    {
      "name": "작업 이름",
      "id": "LK-XXXX",
      "part": "Server",
      "taskType": "서버 기능 개발",
      "status": "상태값",
      "deployable": "배포가능" 또는 "",
      "prLink": "#XXXX" 또는 "",
      "assignee": "작업자 이름",
      "qaStartDate": "QA 진입일",
      "qaEndDate": "QA 완료일",
      "parentProject": "과제 ID",
      "previewBeta": "서버 프리뷰 (BETA) 값"
    }
  ],
  "projectNames": {
    "과제ID": "과제에 속한 작업들의 공통 이름 (접두사 제외)"
  }
}
```

**subagent 호출 예시**:
```
Agent(
  description: "릴리즈 작업 조회 1/2",
  prompt: (위 템플릿에 ID 목록 삽입),
  subagent_type: "general-purpose"
)
```

여러 subagent를 **반드시 단일 메시지에서 동시에** 호출하여 병렬 실행합니다.

**결과 취합**: 모든 subagent 결과의 `serverTasks`를 합치고 중복 제거(LK-ID 기준)합니다.

### 3단계: PR/릴리즈 교차검증

Notion 상태가 `배포 완료`가 **아닌** 서버 작업 중 `prLink`가 있는 작업에 대해, 실제 배포 여부를 GitHub에서 교차검증합니다.
Notion 상태 업데이트가 누락되어 실제로는 이미 배포된 작업을 오탐하는 것을 방지합니다.

**검증 대상**: 상태가 `배포 완료`가 아니면서 prLink(`#XXXX`)가 있는 서버 작업

**검증 방법** (각 대상 PR에 대해 Bash로 실행):

```bash
# 1. PR merge 여부 확인
command gh pr view {PR번호} --json state,mergedAt,mergeCommit

# 2. merged 상태이면 → merge commit이 릴리즈 태그에 포함되었는지 확인
git tag --contains {mergeCommitSHA} | head -5
```

**판정 로직**:
- PR이 `MERGED`이고, merge commit이 릴리즈 태그(예: `v8.0.2`)에 포함 → **실제 배포 완료**
  - 상태를 `배포 완료 (Notion 미반영)` 으로 재분류
  - 배포 버전과 배포일을 태그 정보에서 추출
- PR이 `MERGED`이지만 릴리즈 태그 미포함 → **merge만 완료, 배포 아직 안 됨**
  - Notion 상태 그대로 유지 (배포 대기 등)
- PR이 `OPEN` 또는 `CLOSED` → Notion 상태 그대로 유지

**병렬 실행**: 검증 대상이 여러 개이면 Bash 호출을 병렬로 수행합니다.

### 4단계: 서버 작업 배포 상태 분류

발견된 모든 서버 작업을 다음 기준으로 분류합니다 (3단계 교차검증 결과 반영):

#### 배포 완료 (안전)
- Notion 상태가 `배포 완료`
- 또는 3단계에서 실제 배포 확인됨 → `배포 완료 (Notion 미반영)` 표시

#### 배포 가능 (조치 필요)
- `배포가능` 필드가 "배포가능"
- 상태가 `배포 대기` 또는 `QA 완료`
- 3단계에서 실제 배포가 확인되지 않은 경우
- → **iOS/Android 배포 전에 서버 본 환경 배포 필요**

#### 배포 불가 (위험)
- QA가 아직 완료되지 않음 (상태: `QA 진행중`, `QA 필요`, `작업 중` 등)
- `배포가능` 필드가 비어있음
- → **클라이언트 배포 전까지 QA 완료 + 서버 배포 필요**

#### 서버 작업 없음 (해당 없음)
- 해당 과제에 서버 파트 작업이 없는 경우
- → 서버 배포 불필요

### 5단계: 결과 출력

---

## 출력 형식

```markdown
## {릴리즈 이름} 서버 배포 준비 상태

**배포 예정일**: {배포예정일}
**릴리즈 상태**: {상태}
**전체 진척도**: {진척도}%

---

### 관련 과제 및 서버 작업 현황

#### 과제 1: {과제명}

| 작업 | ID | 파트 | 상태 | 배포가능 | PR | 작업자 |
|------|-----|------|------|---------|-----|-------|
| [서버] XXX | LK-XXXX | Server | 배포 대기 | 배포가능 | #XXXX | @name |

(서버 작업이 없으면: "서버 작업 없음 - 서버 배포 불필요")

---

### Backend 엔지니어 Action Items

#### 즉시 배포 가능 (릴리즈 전 배포만 하면 됨)
| 작업 | ID | PR | 담당 |
|------|-----|-----|------|

#### QA 완료 대기 중 (QA 후 배포 필요)
| 작업 | ID | 현재 상태 | 예상 완료 | 담당 |
|------|-----|----------|----------|------|

#### 이미 배포 완료
| 작업 | ID | 배포 버전 | 배포일 | 비고 |
|------|-----|---------|-------|------|

(3단계 교차검증으로 실제 배포가 확인된 경우 비고에 "Notion 미반영" 표시)

### 최종 판정

| 항목 | 결과 |
|------|------|
| **서버 배포 준비 상태** | Ready / Not Ready / 부분 Ready |
| **필요 조치** | (있으면 기술) |
| **배포 순서 권고** | 서버 먼저 배포 → 클라이언트 릴리즈 |
| **주의사항** | (있으면 기술) |
```

---

## 주의사항

- **병렬 조회 필수**: 작업/과제 조회는 항상 가능한 한 병렬로 수행
- **중복 조회 방지**: 이미 조회한 페이지 ID는 다시 조회하지 않음
- **서버 프리뷰 확인**: `서버 프리뷰 (BETA)` 필드가 있으면 BETA 프리뷰 상태도 포함
- Notion MCP 도구 사용: `mcp__tpc-notion__API-retrieve-a-page` (ToolSearch로 먼저 로드 필요)
- 작업의 `관련자` 또는 `작업자` 필드에서 담당자 이름을 추출
- 과제가 없는 독립 작업(QA 버그, Sentry 이슈 등)에는 서버 작업이 없으므로 스킵 가능
