---
name: scrum-v2
description: PRODUCT SCRUM 자동 작성 v2. 직전 스크럼 이후 멀티 레포 PR/브랜치 조회, Notion 개발과제/작업 매칭, 진행률 추론, Slack DM 발송까지 자동 수행. "스크럼", "scrum", "작업 현황 정리", "진행 상황 공유" 같은 요청에 자동으로 활성화됩니다.
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[사용자명] [--since 시간범위] [--channel 채널명]"
---

# PRODUCT SCRUM v2 - 멀티레포 작업 현황 리포트

직전 PRODUCT SCRUM 이후의 GitHub 활동(PR, 브랜치)을 모든 대상 레포지토리에서 수집하고, Notion 개발과제/작업과 매칭하여 진행률을 추론한 뒤, Slack으로 보고합니다.

## 트리거 키워드

- "스크럼", "scrum", "scrum-v2"
- "작업 현황 정리", "작업 리포트"
- "내 작업 현황", "진행 상황 공유"
- "작업 요약해줘", "오늘 스크럼 작성해줘"

## 인자 (Arguments)

```
/scrum-v2                            # 기본: 직전 스크럼 이후, muzi, DM 발송
/scrum-v2 wish                       # wish 사용자 기준
/scrum-v2 --since 48h                # 직전 스크럼 대신 48시간 고정 (수동 오버라이드)
/scrum-v2 --channel #team-backend    # 특정 채널로 발송
/scrum-v2 --dry-run                  # Slack 발송 없이 미리보기만
```

### 인자 파싱 규칙

| 인자 | 형식 | 기본값 | 설명 |
|------|------|--------|------|
| 사용자명 | `muzi\|wish\|walter\|kyle` | `muzi` | 대상 사용자 |
| `--since` | `{숫자}h` | 없음 (직전 스크럼 자동 감지) | 수동 시간 오버라이드. 직전 스크럼을 찾지 못했을 때 fallback으로도 사용 |
| `--channel` | `#{채널명}` 또는 `{채널ID}` | DM 발송 | Slack 발송 대상 |
| `--dry-run` | 플래그 | off | 대상 사용자 DM으로 발송 + 터미널 출력 (채널 발송만 안 함) |

**시간 범위 결정 우선순위**:
1. `--since` 인자가 있으면 → 해당 시간 범위 사용
2. `--since` 없으면 → #scrum 채널에서 직전 스크럼 시점 자동 감지
3. 직전 스크럼을 찾지 못하면 → 48h fallback + 사용자에게 알림

---

## 사용자 정보

| 이름 | Slack User ID | Notion User ID | GitHub Username | Git Author |
|------|---------------|----------------|-----------------|------------|
| **muzi** (기본) | `U01GYELMU2D` | `0b245cd5-2c61-423b-a74f-3a45435a8fea` | `lucidash` | `muzi`, `lucidash` |
| **wish** | `U01H3T98U3N` | `1d5d872b-594c-8141-8cac-0002b604a496` | `wish36` | `wish`, `wish36` |
| **walter** | `U01H0Q0G18F` | `2423daec-d330-4f96-bae3-e62238d98437` | `walter-park` | `walter`, `walter-park` |
| **kyle** | `U063PLXSN1J` | `17ad872b-594c-8121-a786-0002554a5616` | `kyle-tpc` | `kyle`, `kyle-tpc` |

## Slack 채널 정보

| 채널 | ID | 용도 |
|------|-----|------|
| #scrum | `C01GNUU7Z8A` | PRODUCT SCRUM 스레드 |
| #team-backend | `C051U4DUH4H` | 백엔드 팀 채널 |

## Notion DB 정보

| DB 이름 | ID | Data Source | 용도 |
|---------|-----|-------------|------|
| 개발 과제 DB | `7e65336e-8ea1-4a85-a034-5afe0a6ccb81` | `collection://e2591524-aa7d-454e-86eb-b925b110aeca` | 과제 단위 |
| 개발 작업 DB | `cdebd8ad-0608-4688-ba55-fee0f33c50e3` | `collection://af0b1e4c-6a3f-4d94-81c6-396f86e61574` | PR 단위 작업 |

## GitHub Repository

| Repository | GitHub Org/Repo | 로컬 경로 |
|------------|-----------------|----------|
| likey-backend | `tpcint/likey-backend` | `/Users/muzi/projects/likey-backend` |
| likey-admin-v2 | `tpcint/likey-admin-v2` | `/Users/muzi/projects/likey-admin-v2` |
| likey-web | `tpcint/likey-web` | `/Users/muzi/projects/likey-web` |
| likey-admin | `tpcint/likey-admin` | `/Users/muzi/projects/likey-admin` |
| tpc-agent | `tpcint/tpc-agent` | `/Users/muzi/projects/tpc-agent` |
| tpc-workspace | `tpcint/tpc-workspace` | `/Users/muzi/projects/tpc-workspace` |
| videoseal-service | `tpcint/videoseal-service` | `/Users/muzi/projects/videoseal-service` |

---

## 워크플로우

**핵심 원칙**: 각 단계에서 독립적인 작업은 **병렬 실행**하여 속도를 최적화합니다. 특히 1단계(직전 스크럼 파악)와 2단계(레포 조회)는 병렬 시작 가능하고, 4단계(Notion 매칭)는 반드시 병렬로 처리합니다.

### 0단계: 대상 사용자 결정

```
1. 인자에 사용자명이 있으면 → 해당 사용자 정보 사용
2. 인자가 없으면 → 기본값 muzi 사용
```

### 1단계: 직전 스크럼 시점 파악

`--since` 인자가 없는 경우, #scrum 채널에서 대상 사용자의 직전 스크럼 작성 시점을 찾습니다.

```
1. mcp__slack__conversations_history 호출
   - channel_id: C01GNUU7Z8A (#scrum)
   - limit: 1w (최근 1주)

2. "PRODUCT SCRUM" 문자열이 포함된 스레드 목록 추출
   - 형식: "YYYY년 M월 D일 PRODUCT SCRUM"
   - 최신 순으로 정렬

3. 각 PRODUCT SCRUM 스레드에서 대상 사용자의 메시지 검색
   - mcp__slack__conversations_replies로 스레드 내용 확인
   - 대상 사용자의 Slack User ID로 필터링

4. 대상 사용자의 가장 최근 스크럼 메시지의 timestamp를 cutoff 시점으로 설정
   - 찾았으면 → 해당 timestamp를 DATE_CUTOFF으로 사용
   - 못 찾았으면 → 48h fallback + "직전 스크럼을 찾지 못해 48시간 기준으로 조회합니다" 안내
```

**중요**: 오늘의 PRODUCT SCRUM 스레드는 건너뛰고, 그 이전의 가장 최근 스레드에서 사용자의 메시지를 찾습니다. (오늘 스크럼은 아직 작성할 대상이므로)

`--since` 인자가 있는 경우:
```bash
DATE_CUTOFF=$(date -u -v-{시간범위}H '+%Y-%m-%dT%H:%M:%SZ')
```

### 2단계: 전체 레포지토리 PR/브랜치 수집 (병렬)

모든 레포지토리에서 직전 스크럼 이후 활동을 **동시에** 조회합니다.

```bash
# DATE_CUTOFF은 1단계에서 결정된 값 사용

# 각 레포지토리에 대해 (전체 병렬 실행):
REPOS=("tpcint/likey-backend" "tpcint/likey-admin" "tpcint/likey-admin-v2" "tpcint/likey-web" "tpcint/tpc-agent" "tpcint/tpc-workspace" "tpcint/videoseal-service")

for REPO in "${REPOS[@]}"; do
  # 1-1. PR 조회: opened 또는 merged가 시간 범위 내인 것
  command gh pr list --repo "$REPO" --author {github_username} --state all \
    --json number,title,state,url,createdAt,mergedAt,headRefName --limit 50

  # 결과를 python3으로 필터링 (createdAt 또는 mergedAt >= cutoff)

  # 1-2. 브랜치 조회: 최근 커밋이 시간 범위 내인 것
  command gh api "repos/$REPO/branches" --paginate --jq '.[].name' | while read branch; do
    command gh api "repos/$REPO/commits?sha=$branch&author={github_username}&since=$DATE_CUTOFF&per_page=1" --jq 'length'
  done
done
```

#### 수집 결과 정리

- **PR 목록**: repo, PR번호, title, state (OPEN/MERGED), URL, headRefName
- **브랜치 목록**: PR이 없는 브랜치만 별도 리스트 (master/main, release-please 브랜치 제외)
- PR title에서 `LK-XXXXX` 패턴 추출

### 3단계: PR/브랜치 그룹화

```
1. PR title에서 LK-ID 추출 → LK-ID가 있는 PR 그룹
2. LK-ID가 없는 PR → 키워드 매칭 그룹
3. PR이 없는 브랜치 → 브랜치명 키워드 매칭 그룹
```

### 4단계: Notion 개발작업/개발과제 매칭 (병렬)

PR/브랜치를 **5개씩 그룹**으로 나누어 각 그룹을 **별도 에이전트**로 병렬 처리합니다.

#### 각 에이전트의 작업:

```
에이전트 입력: PR/브랜치 목록 (최대 5개)

각 항목에 대해:
1. LK-ID가 있으면 → mcp__claude_ai_Notion__notion-search로 LK-ID 검색
   LK-ID가 없으면 → PR title 키워드로 검색

2. 검색 결과에서 개발작업 페이지 찾기
   → mcp__claude_ai_Notion__notion-fetch로 페이지 상세 조회

3. 개발작업에 "개발과제" relation이 있으면
   → 개발과제 fetch → 개발과제 채택 (개발작업 URL도 보존)

4. 개발과제 relation이 없으면
   → 개발작업 채택

5. 속성 수집:
   - 노션 문서 제목
   - 노션 문서 URL (개발과제 URL + 개발작업 URL)
   - 진행상태 (개발과제의 "작업 상태" 속성 또는 개발작업의 "상태" 속성)
   - 완료예정일자 (있는 경우)
```

#### Notion 매칭 전략

| 소스 | 검색 방법 | 검색 도구 |
|------|----------|----------|
| LK-ID 있는 PR | `LK-XXXXX` 직접 검색 | `mcp__claude_ai_Notion__notion-search` |
| LK-ID 없는 PR | PR title 키워드 검색 | `mcp__claude_ai_Notion__notion-search` + `mcp__tpc-notion__API-post-search` |
| PR 없는 브랜치 | 브랜치명 키워드 변환 후 검색 | `mcp__claude_ai_Notion__notion-search` |

**브랜치명 → 키워드 변환 규칙**:
- `feature/` 또는 `feat/` 접두사 제거
- `-` 를 공백으로 변환
- 예: `feature/app-version-management` → `"app version management"`

### 5단계: 진행률 추론 (병렬)

매칭된 항목들을 **개발과제 단위로 그룹화**한 뒤, 진행률을 결정합니다.

#### 자동 결정 (에이전트 불필요)

| 개발작업 상태 | 진행률 |
|-------------|--------|
| 배포 완료 | 100% |
| 배포 대기 | 99% |

#### 에이전트 추론 (병렬)

위 자동 결정에 해당하지 않는 개발과제는 **각각 별도 에이전트**로 진행률을 추론합니다.

```
에이전트 입력:
- 개발과제/작업 Notion URL
- 현재 상태
- 하위 개발작업 상태 목록
- PR 상태 (OPEN/MERGED)

추론 기준:
- QA 완료 → 90~95% (배포만 남음)
- QA 진행중 → 80~90% (개발 완료, QA 중)
- 작업 중 + PR OPEN → 65~80% (코드 작성 완료, 리뷰 중)
- 작업 중 + PR 없음 → 40~65% (개발 진행 중)
- 개발 중 (과제 레벨) → 하위 작업 상태 종합하여 판단
- 배포목표/완료예정일 대비 현재 날짜 고려

에이전트 출력: 추정 진행률 (%)
```

### 6단계: 결과 조합 및 메시지 생성

#### 5-1. 개발과제 단위 그룹화

동일 개발과제에 속하는 여러 PR/브랜치를 하나의 항목으로 그룹화합니다.

```
예: TPC-1251 "[admin] 출금 신청 관리 매니징담당자/세금계산서 필터 기능 추가"
  └ likey-backend #6618 (LK-10310) - 배포 대기
  └ likey-admin-v2 #1183 (LK-10309) - 배포 완료
  → 과제 전체 진행률: 99%
```

#### 5-2. 한줄 문장 생성

각 개발과제/작업에 대해 아래 형식의 한줄 문장을 생성합니다:

```
{노션 문서 제목} {진행상태} ({진행률}%, {완료예정일자})
```

- `진행상태`: Notion DB 속성값 그대로 사용
- `완료예정일자`: Notion DB 속성값 그대로 사용 (없으면 생략)
- `진행률`: 4단계에서 결정된 값

#### 5-3. Slack 메시지 구성

```markdown
{이모지} **작업 현황** (직전 스크럼 이후 | {기준 날짜} ~)

• [**{개발과제 제목}**]({개발과제 Notion URL}) {진행상태} ({진행률}%, {완료예정일자})
  └ [{개발작업 제목}]({개발작업 URL}) · [{개발작업 제목}]({개발작업 URL})

• [**{개발과제 제목}**]({개발과제 Notion URL}) {진행상태} ({진행률}%)
  └ [{개발작업 제목}]({개발작업 URL})

---
{경고 이모지} **Notion 미연결 작업** (개발작업 생성 권장)
• {PR title 또는 브랜치명}
• {PR title 또는 브랜치명}
```

**메시지 작성 규칙**:
- **Notion URL은 반드시 제목 텍스트에 링크를 걸어 표시** (raw URL 노출 금지)
  - 개발과제: `[과제 제목](Notion URL)` 형태
  - 개발작업: `[작업 제목](Notion URL)` 형태 (예: `[[서버] VideoSeal 워터마크 통합](https://www.notion.so/...)`)
- 개발과제가 존재하면 → 개발과제 제목을 메인 bullet, 하위 개발작업 제목을 링크
- 개발과제 없이 개발작업만 존재하면 → 개발작업 제목을 메인 bullet
- PR이나 commit 관련 내용은 포함하지 않음
- Notion 미연결 항목은 마지막에 별도 섹션으로 표시

### 7단계: Slack 발송

```
발송 대상 결정:
1. --channel 인자가 있으면 → 해당 채널로 발송
2. --channel 인자가 없으면 → 대상 사용자에게 DM 발송
3. --dry-run이면 → 대상 사용자에게 DM 발송 + 터미널에도 출력 (채널 발송은 하지 않음)

DM 발송:
- mcp__slack__conversations_add_message
- channel_id: {대상 사용자 Slack User ID}
- content_type: text/markdown
- payload: {생성된 메시지}

채널 발송:
- channel_id: #{채널명} 또는 채널ID
```

**DM 발송 실패 시 (missing_scope 등)**:
1. 사용자에게 에러 안내
2. 메시지 내용을 터미널에 출력
3. 대안 채널 발송 여부를 `AskUserQuestion`으로 확인

### 8단계: 결과 보고

```markdown
## 스크럼 v2 리포트 완료

### 조사 범위
- 레포지토리: {조회된 레포 수}개
- 기준: 직전 스크럼 ({날짜}) 이후 (또는 --since {시간범위})
- 대상: {사용자명}

### 발견 항목
- PR: {PR 수}건 (Merged: {수}, Open: {수})
- 브랜치 (PR 없음): {수}건
- Notion 매칭: {매칭 수}건
- Notion 미연결: {미연결 수}건

### 발송
- {Slack 발송 결과}
```

---

## 주의사항

- 브랜치 조회 시 `master`, `main`, `release-please--*` 브랜치는 결과에서 제외
- GitHub API 호출은 `command gh`를 사용 (alias 우회)
- Notion 검색 시 `mcp__claude_ai_Notion__notion-search`를 우선 사용하고, 결과가 없으면 `mcp__tpc-notion__API-post-search`로 재시도
- 동일 개발과제에 여러 개발작업이 속하는 경우 중복 없이 하나의 bullet로 합침
- 진행률 추론 시 "배포완료=100%, 배포대기=99%"는 고정 규칙이며 에이전트 추론 대상이 아님
- 직전 스크럼이 오래전(3일+)이면 GitHub API 호출이 많아져 속도가 느려질 수 있음. 이 경우 `--since 48h` 등으로 수동 제한 권장
- Notion 페이지의 "작업 상태"와 "Status"는 다른 속성임. "작업 상태"가 실제 개발 진행 상태를 나타냄

---

## 체이닝: 다음 단계 제안

### 케이스 A: Notion 미연결 작업이 있는 경우

```markdown
---

### 다음 단계

Notion에 연결되지 않은 작업이 {수}건 있습니다. 개발작업을 생성할까요?

`/create-task {PR title}`
```

### 케이스 B: 모든 작업이 배포대기/완료인 경우

```markdown
---

### 다음 단계

진행 중인 작업이 모두 배포 단계입니다. 다음 작업을 찾아볼까요?

`/schedule-task`
```

### 케이스 C: 정상적으로 완료된 경우

```markdown
---

### 다음 단계

스크럼 스레드에도 작성할까요?

`/scrum`
```
