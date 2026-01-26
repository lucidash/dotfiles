---
name: monitoring-mentions
description: likey-monitoring 채널에서 @dev-server, @dev-admin 또는 그룹원 멘션 스레드를 찾아 리스트합니다.
tools: Bash, Grep, Read
---

# 모니터링 채널 개발팀 확인 필요 항목 조회

#likey-monitoring 채널에서 엔지니어가 확인해야 할 스레드를 찾아 #team-backend 채널로 정리해서 전송합니다.

## 사용법

```
/monitoring-mentions [시간범위]
```

예시:
- `/monitoring-mentions` - 기본 48시간
- `/monitoring-mentions 24h` - 최근 24시간
- `/monitoring-mentions 72h` - 최근 72시간

## 채널 정보

| 채널 | ID | 용도 |
|------|-----|------|
| #likey-monitoring | `C01HCQERW8Y` | 모니터링 알림 (소스) |
| #team-backend | `C051U4DUH4H` | Backend 팀 채널 (결과 전송) |

## 그룹 정보

| 그룹명 | Subteam ID | 설명 |
|--------|------------|------|
| @dev-admin | S02NCK3L4CX | Admin 개발팀 |
| @dev-server | (확인 필요) | Backend 개발팀 |

## 워크플로우

### 1단계: 시간 범위 파싱

$ARGUMENTS 에서 시간 범위를 파싱합니다:
- 기본값: 48h (48시간)
- 형식: `XXh` (예: 24h, 72h)

### 2단계: 채널 히스토리 조회

`mcp__slack__slack_get_channel_history` 도구로 채널 메시지 조회:

```
channel_id: "C01HCQERW8Y"
limit: 100
```

결과가 파일로 저장되면 jq로 파싱합니다.

### 3단계: 엔지니어 확인 필요 항목 필터링

다음 조건 중 하나라도 해당하면 엔지니어 확인 필요로 분류:

#### A. 직접 멘션 (우선순위 높음)

1. **Subteam 멘션** (그룹 전체 멘션)
   - 패턴: `<!subteam^S02NCK3L4CX>` (dev-admin)
   - jq 필터: `.messages[] | select(.text | test("subteam\\^S02NCK3L4CX"))`

2. **개발팀원 개인 멘션**
   - 패턴: `<@UXXXXXXXX>` 형태
   - dev-admin/dev-server 그룹원 ID 목록과 대조
   - 개발팀원 ID: U02F8VABWKH (walter273), U01GYELMU2D (muzi), U088PUXC3DF

#### B. 이슈/버그 키워드 (엔지니어 확인 필요)

다음 키워드가 포함된 메시지 (봇 자동 메시지 제외):
- 버그/이슈: `버그`, `오류`, `에러`, `안됨`, `안됩니다`, `안돼`, `문제`, `이슈`
- 기능 장애: `작동 안`, `동작 안`, `안 뜸`, `안뜸`, `안 나옴`, `안나옴`, `실패`
- 긴급: `긴급`, `급함`, `ASAP`, `장애`

```bash
jq '.messages[] | select(
  (.text | test("버그|오류|에러|안됨|안됩니다|안돼|문제가|이슈|작동.*안|동작.*안|안.*뜸|안.*나옴|실패|긴급|장애")) and
  (.bot_id == null) and
  (.text | test("제재 상세 페이지") | not)
)'
```

#### C. 논의가 진행 중인 스레드

- `reply_count >= 2` 이고
- 봇 자동 메시지(제재 알림)가 아닌 경우
- 답변자 중 개발팀원이 있는 경우 우선 확인

### 4단계: 시간 범위 필터링

Unix timestamp 기준으로 필터링:

```bash
NOW=$(date +%s)
SINCE=$((NOW - ${시간}*3600))

jq --argjson since "$SINCE" '.messages[] | select((.ts | tonumber) > $since)'
```

### 5단계: 스레드 상세 조회

reply_count가 있는 메시지는 `mcp__slack__slack_get_thread_replies`로 상세 조회:

```
channel_id: "C01HCQERW8Y"
thread_ts: "<메시지_ts>"
```

### 6단계: 유저 정보 조회

멘션된 유저 ID를 `mcp__slack__slack_get_users`로 이름 확인:

```bash
jq '.members[] | select(.id == "UXXXXXXXX") | {id, name, real_name}'
```

### 7단계: 결과 분류 및 정리

발견된 항목을 다음 카테고리로 분류:

1. **직접 멘션** - 개발팀 직접 멘션된 스레드
2. **이슈/버그 리포트** - 키워드로 감지된 문제 보고
3. **논의 진행 중** - 답변이 많은 활발한 스레드

### 8단계: #team-backend 채널로 전송

`mcp__slack__slack_post_message` 도구로 결과 전송:

```
channel_id: "C051U4DUH4H"
```

메시지 형식:
```
:eyes: *#likey-monitoring 엔지니어 확인 필요 항목* (최근 {시간범위})

---

:mega: *직접 멘션*

*1. {이슈 요약}*
• 작성자: {이름}
• 멘션: {멘션된 사람들}
• 내용: {요약}
• 스레드 링크: {URL}

*스레드 요약:*
> {답변 요약}

---

:warning: *이슈/버그 리포트*

*1. {이슈 요약}*
• 작성자: {이름}
• 키워드: {감지된 키워드}
• 내용: {요약}
• 스레드 링크: {URL}

---

:speech_balloon: *논의 진행 중* (답변 {N}개 이상)

*1. {주제 요약}*
• 참여자: {참여자들}
• 스레드 링크: {URL}

---
:robot_face: 자동 생성됨 | 확인 완료 시 :white_check_mark: 리액션 부탁드립니다
```

## 제외 대상

다음은 필터링에서 제외:
- 제재 알림 봇 메시지 (`제재 상세 페이지`, `제재 담당자` 포함)
- 활동 담당자 멘션 (Harrison, Angella, angry, Gina, Lucy, Kila 등) - 크리에이터 담당자
- 채널 참여/나감 알림 (`채널에 참여함`, `나갔습니다`)
- 활동 담당자 그룹 멘션 (S065HEXCG5S)

## 개발팀 그룹원 참고

| User ID | 이름 | 실명 | 역할 |
|---------|------|------|------|
| U02F8VABWKH | walter273 | 박정수 | Admin 개발 |
| U01GYELMU2D | muzi | Sanghoon KIM | Backend 개발 |
| U088PUXC3DF | (확인필요) | | Admin 개발 |

## 링크 생성 규칙

Slack 메시지 링크 형식:
```
https://tpc-internet.slack.com/archives/{channel_id}/p{ts에서_점_제거}
```

예시:
- ts: `1769404897.997339`
- 링크: `https://tpc-internet.slack.com/archives/C01HCQERW8Y/p1769404897997339`

## 결과 없을 경우

확인이 필요한 항목이 없으면:
```
:white_check_mark: *#likey-monitoring 확인 완료* (최근 {시간범위})

엔지니어 확인이 필요한 새로운 항목이 없습니다.
```
