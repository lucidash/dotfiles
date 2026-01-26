# Good Morning - 오늘 할 일 분석

출근 후 실행하면 최근 24시간 동안의 GitHub, Notion, Slack 활동을 분석하여 오늘 해야 할 일을 리스트업하고 #team-backend 채널에 메시지로 남깁니다.

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

## 실행 순서

### 0. 대상 사용자 결정

```
1. 인자가 있으면 해당 사용자 정보 사용
   - /good-morning wish → wish 사용자 정보
   - /good-morning walter → walter 사용자 정보
   - /good-morning kyle → kyle 사용자 정보

2. 인자가 없으면 기본값 muzi 사용
```

### 1. 시간 범위 설정

```
기준: 최근 24시간
시작 시간: 어제 현재 시각
종료 시간: 지금
```

### 2. GitHub 활동 수집

#### 2-1. 최근 커밋 확인 (각 레포지토리별)

```bash
# 최근 24시간 내 커밋 확인 (대상 사용자의 Git Author 사용)
cd {repo_path} && git fetch origin && git log --author="{git_author}" --since="24 hours ago" --oneline --all --no-merges | head -30
```

#### 2-2. 머지된 PR 확인

```bash
# 최근 머지된 PR (대상 사용자 작성분)
command gh pr list --repo TPC-Internet/{repo} --state=merged --json number,title,author,mergedAt --limit 20 | jq '[.[] | select(.author.login == "{github_username}") | select(.mergedAt > "{24시간 전 ISO 시간}")]'
```

#### 2-3. Open PR 확인

```bash
# 대상 사용자가 작성한 Open PR
command gh pr list --repo TPC-Internet/{repo} --state=open --author="{github_username}" --json number,title,url,updatedAt,reviewDecision

# 대상 사용자가 리뷰어로 지정된 PR
command gh pr list --repo TPC-Internet/{repo} --state=open --json number,title,url,author,reviewRequests | jq '[.[] | select(.reviewRequests[].login == "{github_username}")]'
```

#### 2-4. PR 코멘트 확인

```bash
# 대상 사용자가 작성한 PR 코멘트 (최근 24시간)
command gh api "repos/TPC-Internet/{repo}/pulls/comments?since={24시간 전 ISO 시간}" | jq '[.[] | select(.user.login == "{github_username}")]'

# 대상 사용자가 멘션된 PR 코멘트
command gh search issues --repo=TPC-Internet/{repo} --mentions={github_username} --updated=">={24시간 전 날짜}" --json number,title,url --limit 20
```

### 3. Notion 최근 변경 확인

#### 3-1. 대상 사용자가 변경한 개발 작업 검색

```
1. mcp__notion__notion-search 호출
   - query: 최근 작업 키워드 또는 빈 쿼리
   - data_source_url: collection://af0b1e4c-6a3f-4d94-81c6-396f86e61574
   - filters.created_date_range.start_date: {어제 날짜}
   - filters.created_by_user_ids: ["{notion_user_id}"]

2. 주요 작업 상태 확인
   - Status 확인 (진행중, 대기중, 완료 등)
   - 담당자 확인
```

#### 3-2. 대상 사용자가 변경한 개발 과제 검색

```
1. mcp__notion__notion-search 호출
   - data_source_url: collection://e2591524-aa7d-454e-86eb-b925b110aeca
   - filters.created_date_range.start_date: {어제 날짜}
   - filters.created_by_user_ids: ["{notion_user_id}"]
```

### 4. Slack 활동 수집

#### 4-1. 대상 사용자가 멘션된 메시지 확인

Slack API를 통해 직접 멘션 검색은 제한적이므로, 주요 채널들의 최근 메시지에서 멘션 확인:

```
주요 확인 채널:
- #team-backend (C051U4DUH4H)
- #scrum (C01GNUU7Z8A)
- 기타 관련 채널

1. mcp__slack__slack_get_channel_history 호출
   - channel_id: {채널 ID}
   - limit: 50

2. 메시지에서 대상 사용자의 Slack 멘션 패턴 검색
   - Slack User ID는 이메일로 검색하여 확인

3. 멘션된 메시지의 스레드 내용 확인
   - mcp__slack__slack_get_thread_replies 사용
```

#### 4-2. 대상 사용자가 참여한 스레드 확인

```
1. 채널 히스토리에서 대상 사용자가 작성한 메시지 찾기

2. 해당 스레드의 후속 답글 확인
   - 답변이 필요한 질문이 있는지 파악
```

### 5. 할 일 분류 및 분석

수집된 정보를 기반으로 다음 카테고리로 분류:

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

### 6. 메시지 형식

```
:sunrise: Good Morning! ({대상 사용자 이름})

오늘의 할 일 ({날짜})

:rotating_light: *긴급*
• {긴급 항목}

:arrows_counterclockwise: *진행중*
• {PR 제목} - {상태}
• {Notion 작업} - {진행률}

:eyes: *검토 필요*
• {검토 항목}

:sparkles: *신규*
• {새 작업}
```

### 7. 사용자 확인

```
초안을 사용자에게 보여주고 확인:
- 추가할 항목이 있는지?
- 삭제할 항목이 있는지?
- 우선순위 조정이 필요한지?
```

### 8. #team-backend 채널에 메시지 작성

```
mcp__slack__slack_post_message 사용
- channel_id: C051U4DUH4H
- text: {최종 메시지}
```

### 9. 결과 보고

```markdown
## Good Morning 완료

### 작성된 내용
{메시지 내용}

### 채널 링크
https://tpc-internet.slack.com/archives/C051U4DUH4H
```

---

## ISO 시간 형식 예시

```bash
# 24시간 전 ISO 형식
date -u -v-24H +"%Y-%m-%dT%H:%M:%SZ"

# 어제 날짜 (YYYY-MM-DD)
date -v-1d +"%Y-%m-%d"
```

## 주의사항

- 수집된 정보가 많을 경우 중요도 순으로 정렬
- PR 리뷰 요청은 우선순위 높게 처리
- 멘션된 질문 중 미답변 건은 긴급으로 분류
- 메시지가 너무 길면 핵심 항목만 포함하고 상세 내용은 스레드로
- 특별한 활동이 없으면 "특이사항 없음" 으로 간단히 작성
- 인자로 받은 사용자가 테이블에 없으면 오류 메시지 출력
