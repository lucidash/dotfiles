# PRODUCT SCRUM 자동 작성

PRODUCT SCRUM 스레드에 내 스크럼 상황을 자동으로 분석하고 작성합니다.
GitHub 작업사항, Notion 개발과제/작업 DB 변경, 직전 스크럼 대비 변경점을 파악하여 작성합니다.

## Slack 채널 정보

| 채널 | ID | 용도 |
|------|-----|------|
| #scrum | `C01GNUU7Z8A` | 스크럼 스레드 채널 |

## Notion DB 정보

| DB 이름 | ID | Data Source | 용도 |
|---------|-----|-------------|------|
| 개발 과제 DB | `7e65336e-8ea1-4a85-a034-5afe0a6ccb81` | `collection://e2591524-aa7d-454e-86eb-b925b110aeca` | 과제 단위 |
| 개발 작업 DB | `cdebd8ad-0608-4688-ba55-fee0f33c50e3` | `collection://af0b1e4c-6a3f-4d94-81c6-396f86e61574` | PR 단위 작업 |

## GitHub Repository

| Repository | GitHub |
|------------|--------|
| likey-backend | TPC-Internet/likey-backend |
| likey-web | TPC-Internet/likey-web |
| likey-admin | TPC-Internet/likey-admin |
| likey-admin-v2 | TPC-Internet/likey-admin-v2 |

## 스크럼 형식

```
• {작업 내용} ({진행률}%, ~{예상완료일})
    ◦ {세부 작업 1}
    ◦ {세부 작업 2}
```

**예시:**
```
• 룰렛 결과 채널 변경 (95%)
    ◦ target deeplink path 논의
    ◦ 부족한 tc 채워넣기
    ◦ 클라 대응
• 어드민 즐겨찾기 메뉴 추가 (90%)
```

---

## 실행 순서

### 1. 오늘의 PRODUCT SCRUM 스레드 찾기

```
1. mcp__slack__slack_get_channel_history 호출
   - channel_id: C01GNUU7Z8A
   - limit: 20

2. "PRODUCT SCRUM" 문자열이 포함된 오늘 날짜의 스레드 찾기
   - 형식: "YYYY년 M월 D일 PRODUCT SCRUM"
   - thread_ts 추출
```

### 2. 직전 PRODUCT SCRUM 스레드 찾기

```
1. 채널 히스토리에서 오늘 이전의 가장 최근 PRODUCT SCRUM 스레드 찾기
2. mcp__slack__slack_get_thread_replies로 내용 가져오기
3. 내 이전 스크럼 내용 파악 (user_id로 필터링)
```

### 3. GitHub 작업사항 확인

각 Repository에서 최근 활동 확인:

#### 3-1. PR 기반 확인

```bash
# 최근 머지된 PR (lucidash 작성분)
command gh pr list --repo TPC-Internet/{repo} --state=merged --json number,title,author,mergedAt --limit 20 | jq '[.[] | select(.author.login == "lucidash")]'

# Open PR 확인
command gh pr list --repo TPC-Internet/{repo} --state=open --author="lucidash" --json number,title,updatedAt
```

#### 3-2. 커밋 기반 확인

PR로 확인되지 않는 로컬 브랜치 작업도 확인:

```bash
# 각 레포지토리 로컬 경로
# - /Users/muzi/projects/likey-backend
# - /Users/muzi/projects/likey-admin-v2
# - /Users/muzi/projects/likey-web
# - /Users/muzi/projects/likey-admin

# 1. fetch 후 모든 브랜치의 최근 커밋 확인 (muzi, lucidash 모두 검색 - 모든 레포에서)
cd {repo_path} && git fetch origin && git log --author="muzi" --author="lucidash" --since="{직전 스크럼 날짜}" --oneline --all --no-merges | head -30

# 3. 현재 작업 중인 로컬 브랜치 확인
git branch --sort=-committerdate | head -5

# 4. 진행 중인 브랜치의 최근 커밋 확인
git log {branch_name} --oneline -10 --since="{직전 스크럼 날짜}"
```

#### 3-3. 진행 중인 작업 파악

- 머지되지 않은 로컬 브랜치에서 WIP 커밋 확인
- 브랜치명으로 작업 내용 유추 (예: `feature/roulette-reward-mediapool`)
- 최근 커밋 메시지로 현재 진행 상황 파악

### 4. Notion 개발과제/작업 DB 최근 변경 확인

```
1. mcp__notion__notion-search로 최근 내 작업 검색
   - query: 작업 키워드
   - data_source_url: collection://af0b1e4c-6a3f-4d94-81c6-396f86e61574
   - filters.created_by_user_ids: [내 Notion User ID]

2. 주요 과제/작업 상태 확인
   - Status 변경 여부
   - 진행률 파악
```

### 5. 변경점 분석

이전 스크럼 vs 현재 상황 비교:

```
[이전 스크럼]
• 룰렛 결과 전달 채널 변경 (~1/21, 80%)

[현재 상황]
- PR 머지됨
- 새로운 작업 시작됨
- 진행률 변경

[변경점]
• 룰렛 결과 채널 변경: 80% → 95%
• 새 작업 추가: 어드민 즐겨찾기 메뉴
```

### 6. 스크럼 메시지 작성

변경점을 기반으로 스크럼 메시지 초안 작성:

#### 6-1. Notion 개발과제/작업 링크 연결

각 작업 항목에 대해 Notion 개발작업 DB에서 관련 문서 검색:

```
1. mcp__notion__notion-search로 작업 키워드 검색
   - data_source_url: collection://af0b1e4c-6a3f-4d94-81c6-396f86e61574

2. 검색 결과에서 관련 작업 문서 URL 추출
   - LK-XXXXX 티켓 번호 확인
   - 작업 문서 URL: https://www.notion.so/{page-id}
```

#### 6-2. Slack 링크 포맷 (프리뷰 비활성화)

Notion 링크를 프리뷰 없이 텍스트 링크로 표시:

```
# Slack mrkdwn 링크 형식 (프리뷰 비활성화)
<URL|표시텍스트>

# 예시
(<https://www.notion.so/2ee61056ee1281baacdfdb219182a052|LK-10090>)
```

#### 6-3. 초안 형식

```markdown
## 스크럼 초안

{날짜} 기준

### 진행 중
• {작업명} ({진행률}%, ~{예상완료일})
    ◦ {세부사항} (<https://www.notion.so/{id}|LK-XXXXX>)

### 완료
• {완료된 작업} (<https://www.notion.so/{id}|LK-XXXXX>)

### 변경점 (이전 스크럼 대비)
- {작업} 진행률: {이전}% → {현재}%
- 새 작업 추가: {작업명}
- 완료: {작업명}
```

### 7. 사용자 확인 및 수정

```
초안을 사용자에게 보여주고 확인/수정 요청:
- 진행률 조정 필요?
- 세부 작업 추가/삭제?
- 예상 완료일 수정?
```

### 8. 스레드에 댓글 작성

확정된 내용을 스레드에 작성:

```
mcp__slack__slack_reply_to_thread 사용
- channel_id: C01GNUU7Z8A
- thread_ts: {오늘 PRODUCT SCRUM 스레드 ts}
- text: {최종 스크럼 메시지}
```

### 9. 결과 보고

```
## 스크럼 작성 완료

### 작성된 내용
{스크럼 메시지}

### 스레드 링크
https://tpc-internet.slack.com/archives/C01GNUU7Z8A/p{thread_ts (점 제거)}
```

---

## 참고 정보

### 사용자 정보
- MUZI Notion User ID: `0b245cd5-2c61-423b-a74f-3a45435a8fea`
- MUZI Slack User ID: `U01GYELMU2D`
- Git Author: `muzi` 또는 `lucidash` (email: lucidash@gmail.com)
- GitHub Username: `lucidash`

### 로컬 레포지토리 경로

| Repository | 로컬 경로 |
|------------|----------|
| likey-backend | `/Users/muzi/projects/likey-backend` |
| likey-admin-v2 | `/Users/muzi/projects/likey-admin-v2` |
| likey-web | `/Users/muzi/projects/likey-web` |
| likey-admin | `/Users/muzi/projects/likey-admin` |

## 주의사항

- 오늘 PRODUCT SCRUM 스레드가 없으면 생성하지 않고 알림
- 이미 스크럼을 작성한 경우 덮어쓰기 여부 확인
- 진행률은 사용자 입력 기반으로 최종 결정
- 예상 완료일은 `~M/D` 형식으로 작성
