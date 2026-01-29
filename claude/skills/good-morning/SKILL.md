---
name: good-morning
description: 출근 시 오늘 할 일을 분석할 때, 아침에 업무 현황을 파악할 때, 하루 시작할 때 사용. "굿모닝", "오늘 뭐해야 돼", "출근했어" 같은 요청에 자동으로 활성화됩니다.
allowed-tools: Bash, Read, Glob, Grep
---

# Good Morning - 오늘 할 일 분석

출근 후 실행하면 최근 24시간 동안의 GitHub, Notion, Slack 활동을 분석하여 오늘 해야 할 일을 리스트업하고 #team-backend 채널에 메시지로 남깁니다.

## 트리거 키워드

- "굿모닝", "좋은 아침", "출근했어"
- "오늘 뭐해야 돼", "오늘 할 일"
- "업무 현황", "하루 시작"

## 인자 (Arguments)

```
/good-morning          # 본인(MUZI) 업무 분석
/good-morning wish     # wish 업무 분석
/good-morning walter   # walter 업무 분석
/good-morning kyle     # kyle 업무 분석
```

**인자가 주어지면 해당 사용자의 정보로 분석을 수행합니다.**

---

## 사용자 정보

| 이름 | Notion User ID | GitHub Username | Git Author | Email |
|------|----------------|-----------------|------------|-------|
| **muzi** (기본) | `0b245cd5-2c61-423b-a74f-3a45435a8fea` | `lucidash` | `muzi`, `lucidash` | lucidash@gmail.com |
| **wish** | `1d5d872b-594c-8141-8cac-0002b604a496` | `wish36` | `wish`, `wish36` | wish@tpcinternet.com |
| **walter** | `2423daec-d330-4f96-bae3-e62238d98437` | `walter-park` | `walter`, `walter-park` | walter@tpcinternet.com |
| **kyle** | `17ad872b-594c-8121-a786-0002554a5616` | `kyle-tpc` | `kyle`, `kyle-tpc` | kyle@tpcinternet.com |

---

## Slack 채널 정보

| 채널 | ID | 용도 |
|------|-----|------|
| #team-backend | `C051U4DUH4H` | 백엔드 팀 채널 (결과 메시지 전송) |

## Notion DB 정보

| DB 이름 | ID | Data Source | 용도 |
|---------|-----|-------------|------|
| 개발 과제 DB | `7e65336e-8ea1-4a85-a034-5afe0a6ccb81` | `collection://e2591524-aa7d-454e-86eb-b925b110aeca` | 과제 단위 |
| 개발 작업 DB | `cdebd8ad-0608-4688-ba55-fee0f33c50e3` | `collection://af0b1e4c-6a3f-4d94-81c6-396f86e61574` | PR 단위 작업 |

## GitHub Repository

| Repository | GitHub | 로컬 경로 |
|------------|--------|----------|
| likey-backend | TPC-Internet/likey-backend | `/Users/muzi/projects/likey-backend` |
| likey-web | TPC-Internet/likey-web | `/Users/muzi/projects/likey-web` |
| likey-admin | TPC-Internet/likey-admin | `/Users/muzi/projects/likey-admin` |
| likey-admin-v2 | TPC-Internet/likey-admin-v2 | `/Users/muzi/projects/likey-admin-v2` |

---

## 워크플로우

### 0단계: 대상 사용자 결정

```
1. 인자가 있으면 해당 사용자 정보 사용
2. 인자가 없으면 기본값 muzi 사용
```

### 1단계: 시간 범위 설정

```
기준: 최근 24시간
시작 시간: 어제 현재 시각
종료 시간: 지금
```

### 2단계: GitHub 활동 수집

#### 2-1. 최근 커밋 확인 (각 레포지토리별)

```bash
cd {repo_path} && git fetch origin && git log --author="{git_author}" --since="24 hours ago" --oneline --all --no-merges | head -30
```

#### 2-2. 머지된 PR 확인

```bash
command gh pr list --repo TPC-Internet/{repo} --state=merged --json number,title,author,mergedAt --limit 20
```

#### 2-3. Open PR 확인

```bash
# 대상 사용자가 작성한 Open PR
command gh pr list --repo TPC-Internet/{repo} --state=open --author="{github_username}" --json number,title,url,updatedAt,reviewDecision

# 대상 사용자가 리뷰어로 지정된 PR
command gh pr list --repo TPC-Internet/{repo} --state=open --json number,title,url,author,reviewRequests
```

### 3단계: Notion 최근 변경 확인

**중요**: Notion API 쿼리 시 반드시 최근 수정순 정렬을 사용합니다.

### 4단계: Slack 활동 수집

주요 확인 채널에서 멘션 및 참여 스레드 확인

### 5단계: 할 일 분류 및 분석

```markdown
## 분석 결과

### [긴급] 즉시 대응 필요
- 멘션된 질문 중 미답변 건
- 리뷰 요청된 PR
- 블로킹 이슈

### [진행중] 계속 작업 필요
- Open PR (리뷰 대기 또는 수정 필요)
- 진행중인 Notion 작업
- 미완료 커밋이 있는 브랜치

### [검토] 확인 필요
- 머지된 PR 후속 조치
- 답변 받은 질문 확인
- 완료 처리 필요한 작업

### [새로운] 신규 작업
- 새로 할당된 Notion 작업
- 새로 리뷰 요청된 PR
```

### 6단계: #team-backend 채널에 메시지 작성

```
mcp__slack__slack_post_message 사용
- channel_id: C051U4DUH4H
- text: {최종 메시지}
```

---

## 체이닝: 다음 단계 제안

분석이 완료된 후, 상황에 따라 다음 단계를 제안합니다:

### 케이스 A: 진행중인 작업이 있는 경우

```markdown
---

### 다음 단계

진행중인 작업이 있습니다. 이어서 작업할까요?

`/worktree {브랜치명 또는 LK-ID}`
```

### 케이스 B: 할 일이 비어있는 경우

```markdown
---

### 다음 단계

진행중인 작업이 없습니다. 다음 작업을 찾아볼까요?

`/schedule-task <슬랙_스레드_URL>`
```

### 케이스 C: 리뷰 요청된 PR이 있는 경우

```markdown
---

### 다음 단계

리뷰 요청된 PR이 있습니다. 리뷰할까요?

`/backend-review {PR번호}`
```

**우선순위**: 리뷰 요청 > 진행중 작업 > 새 작업 찾기

---

## 주의사항

- 수집된 정보가 많을 경우 중요도 순으로 정렬
- PR 리뷰 요청은 우선순위 높게 처리
- 멘션된 질문 중 미답변 건은 긴급으로 분류
- 메시지가 너무 길면 핵심 항목만 포함하고 상세 내용은 스레드로
- 특별한 활동이 없으면 "특이사항 없음" 으로 간단히 작성
- 인자로 받은 사용자가 테이블에 없으면 오류 메시지 출력
