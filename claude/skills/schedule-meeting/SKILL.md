---
name: schedule-meeting
description: 회의 일정을 자동으로 잡아줍니다. "미팅 잡아줘", "회의 스케줄링", "미팅 예약", "회의실 예약" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "[-i | --interactive] [Slack스레드URL | 참석자목록] [--priority=high|medium|low] [--duration=분]"
allowed-tools: AskUserQuestion, mcp__google-workspace__calendar_findFreeTime, mcp__google-workspace__calendar_createEvent, mcp__google-workspace__calendar_listEvents, mcp__google-workspace__calendar_list, mcp__google-workspace__calendar_updateEvent, mcp__google-workspace__people_getUserProfile, mcp__slack__slack_get_thread_replies, mcp__slack__slack_reply_to_thread, mcp__slack__slack_get_users, mcp__slack__slack_get_user_profile
---

# 회의 스케줄링

회의 일정을 자동으로 잡아줍니다. Slack 스레드 파싱, 참석자 일정 확인, 회의실 예약, 캘린더 생성, Slack 회신까지 한번에 처리합니다.

**Arguments:** `$ARGUMENTS`

## 모드 선택

`$ARGUMENTS`에서 옵션을 파싱합니다:

- `--interactive` 또는 `-i`: **Interactive Mode** - 단계별 질문으로 정보 수집
- 옵션 없음: **Autopilot Mode** - Slack 스레드 또는 인자에서 정보를 자동 추출

---

## 팀 멤버 정보

| 이름 | Email | Slack Display Name |
|------|-------|--------------------|
| **muzi** | lucidash@gmail.com | muzi |
| **wish** | wish@tpcinternet.com | wish |
| **walter** | walter@tpcinternet.com | walter |
| **kyle** | kyle@tpcinternet.com | kyle |

## 회의실 정보

회의실 Calendar ID는 **런타임에 `calendar_list`로 조회**하여 매핑합니다.

| 회의실 | 수용 인원 | 키워드 (calendar_list 필터) | 비고 |
|--------|-----------|---------------------------|------|
| 전화 부스 | 1인 | `전화 부스` 또는 `전화부스` | 2인 이상 회의에서 제외 |
| 소회의실 | 4인 | `소회의실` | - |
| 중회의실 | 6인 | `중회의실` | - |
| 라운지 | 10인 | `라운지` | - |
| 대회의실 | 15인 | `대회의실` | - |

**필터 조건**: `calendar_list` 결과에서 `V&S빌딩` 또는 회의실 키워드를 포함하는 캘린더만 사용합니다.

---

## 인자 파싱

`$ARGUMENTS`에서 자유 형식으로 다음을 추출 (순서 무관, 모두 선택적):

| 인자 | 패턴 | 기본값 | 예시 |
|------|------|--------|------|
| 모드 | `-i`, `--interactive` | Autopilot | `-i` |
| Slack URL | `https://...slack.com/archives/...` | - | Slack 스레드 URL |
| 참석자 | 팀 멤버 이름 (쉼표/공백 구분) | - | `muzi wish walter` |
| duration | `--duration={분}` 또는 `{숫자}분` | 60분 | `--duration=30`, `30분` |
| priority | `--priority={값}` 또는 `high/medium/low` | low | `--priority=high` |

---

## 공통 초기화: Step 0

**회의실 Calendar ID 매핑 생성**

```
1. calendar_list 호출
2. "V&S빌딩" 또는 회의실 키워드를 포함하는 캘린더 필터
3. 각 회의실 이름 → Calendar ID 매핑 저장
4. "전화 부스" / "전화부스" 키워드로 전화부스 태깅 (2인 이상에서 제외)
```

---

## Interactive Mode (`-i`)

AskUserQuestion을 사용하여 5단계로 정보를 수집합니다.

### 단계 1: 참석자 선택

```json
{
  "questions": [{
    "question": "회의 참석자를 선택해주세요.",
    "header": "참석자",
    "options": [
      {"label": "muzi", "description": "lucidash@gmail.com"},
      {"label": "wish", "description": "wish@tpcinternet.com"},
      {"label": "walter", "description": "walter@tpcinternet.com"},
      {"label": "kyle", "description": "kyle@tpcinternet.com"}
    ],
    "multiSelect": true
  }]
}
```

> Other 선택 시 → 이름 또는 이메일을 직접 입력받아 `people_getUserProfile`로 확인

### 단계 2: 회의 시간

```json
{
  "questions": [{
    "question": "회의 시간은 얼마나 필요한가요?",
    "header": "회의 시간",
    "options": [
      {"label": "30분", "description": "짧은 미팅, 데일리 스크럼"},
      {"label": "1시간 (Recommended)", "description": "일반적인 회의"},
      {"label": "1시간 30분", "description": "긴 논의가 필요한 회의"},
      {"label": "2시간", "description": "워크샵, 스프린트 플래닝"}
    ],
    "multiSelect": false
  }]
}
```

### 단계 3: 우선순위

```json
{
  "questions": [{
    "question": "회의 우선순위를 선택해주세요. 우선순위에 따라 일정 충돌 시 처리 방식이 달라집니다.",
    "header": "우선순위",
    "options": [
      {"label": "Low (Recommended)", "description": "전원 참석 가능한 시간만 탐색"},
      {"label": "Medium", "description": "최대 겹침 우선, 부분 참석 허용"},
      {"label": "High", "description": "충돌 일정 조정까지 검토"}
    ],
    "multiSelect": false
  }]
}
```

### 단계 4: 회의 제목

```json
{
  "questions": [{
    "question": "회의 제목을 입력해주세요.",
    "header": "회의 제목",
    "options": [
      {"label": "팀 미팅", "description": "정기 팀 회의"},
      {"label": "1:1 미팅", "description": "1:1 면담"},
      {"label": "기획 리뷰", "description": "기획 검토 회의"},
      {"label": "스프린트 플래닝", "description": "스프린트 계획 회의"}
    ],
    "multiSelect": false
  }]
}
```

> Other 선택 시 → 자유 텍스트로 제목 입력

### 단계 5: 날짜 범위

```json
{
  "questions": [{
    "question": "언제쯤 회의를 잡을까요?",
    "header": "날짜 범위",
    "options": [
      {"label": "오늘", "description": "오늘 남은 시간 중"},
      {"label": "내일", "description": "내일 업무 시간 중"},
      {"label": "이번 주", "description": "이번 주 중 가능한 시간"},
      {"label": "다음 주", "description": "다음 주 중 가능한 시간"}
    ],
    "multiSelect": false
  }]
}
```

> Other 선택 시 → 날짜를 직접 입력 (예: "2/14", "2/14~2/18")

---

## Autopilot Mode (기본)

### Step 1: Slack 스레드 파싱

`$ARGUMENTS`에서 Slack URL이 있으면 파싱:

- 채널 ID: URL의 `/archives/` 뒤의 값 (예: `C051U4DUH4H`)
- 메시지 타임스탬프: `p` 뒤의 숫자를 `XXXXXXXXXX.XXXXXX` 형식으로 변환

`slack_get_thread_replies`로 스레드 내용 조회

### Step 2: 메시지 NLP 분석

스레드 메시지에서 다음을 추출:
- **참석자**: 멘션된 사용자, 대화 참여자
- **선호 일시**: "내일 오후", "이번주 중", "2/14" 등
- **회의 목적/제목**: 논의 주제에서 추론
- **duration 힌트**: "30분이면 될 것 같아", "1시간 정도" 등

### Step 3: 이메일 매핑

- 팀 멤버 테이블에서 이름 → 이메일 매핑
- 테이블에 없는 사용자 → `people_getUserProfile`로 조회 시도
- 그래도 실패 시 → AskUserQuestion으로 이메일 직접 입력 요청

### Step 4: 필수 정보 부족 시 Fallback

다음 정보가 부족하면 AskUserQuestion으로 보충:

| 부족한 정보 | Fallback 질문 |
|-------------|---------------|
| 참석자 | "회의 참석자를 알려주세요" |
| 날짜 범위 | "언제쯤 회의를 잡을까요?" |
| 회의 제목 | "회의 제목을 입력해주세요" |

> duration과 priority는 부족해도 기본값(60분, low) 사용

---

## 공통: 시간 찾기 & 예약

### Step A: 가능 시간 탐색

`findFreeTime`으로 전원 가능한 시간을 탐색합니다.

```
findFreeTime 호출:
- attendees: [참석자 이메일 목록]
- timeMin: 날짜 범위 시작 (업무시간 09:00 KST)
- timeMax: 날짜 범위 끝 (업무시간 18:00 KST)
- duration: 회의 시간 (분)
```

### Step B: 우선순위별 처리

#### Low (전원 필수 - 기본)

1. `findFreeTime` 결과에서 전원 가능 시간 확인
2. 결과 있음 → Step C로 진행
3. 결과 없음 → 사용자에게 보고:

```json
{
  "questions": [{
    "question": "선택한 기간에 전원 가능한 시간이 없습니다. 어떻게 할까요?",
    "header": "시간 없음",
    "options": [
      {"label": "범위 확장", "description": "다음 주까지 검색 범위를 넓힙니다"},
      {"label": "부분 참석", "description": "Medium 우선순위로 전환하여 최대 겹침을 찾습니다"},
      {"label": "취소", "description": "스케줄링을 취소합니다"}
    ],
    "multiSelect": false
  }]
}
```

- **범위 확장** → 다음 주 / 2주까지 재검색. 끝까지 없으면 불가 보고
- **부분 참석** → Medium 로직으로 전환

#### Medium (최대 겹침 우선)

1. 전원 가능 시간 없으면 → 참석자별 개별 `findFreeTime`
2. 슬롯별 가능 인원 카운트 → 최대 겹침 순 정렬
3. 부분 참석 옵션 테이블을 사용자에게 표시:

```markdown
| 순위 | 시간 | 가능 인원 | 불참 |
|------|------|-----------|------|
| 1 | 2/14 14:00~15:00 | muzi, wish, walter (3/4) | kyle |
| 2 | 2/14 16:00~17:00 | muzi, wish, kyle (3/4) | walter |
| 3 | 2/15 10:00~11:00 | muzi, walter (2/4) | wish, kyle |
```

4. AskUserQuestion으로 사용자에게 선택 요청

#### High (일정 조정 검토)

1. Medium과 동일하게 최대 겹침 분석
2. 충돌 참석자의 기존 일정을 `listEvents`로 조회
3. 조정 가능 판단:
   - **조정 가능**: 1:1 미팅, 내부 소규모 회의
   - **조정 불가**: 외부 미팅, 전사 회의, 다수 참석자 회의
4. 조정 가능한 일정이 있으면:

```json
{
  "questions": [{
    "question": "kyle의 14:00~15:00 '1:1 면담' 일정을 다른 시간으로 조정하면 전원 참석이 가능합니다. 조정을 시도할까요?",
    "header": "일정 조정",
    "options": [
      {"label": "조정 시도", "description": "기존 일정을 다른 시간으로 이동합니다"},
      {"label": "부분 참석으로 진행", "description": "현재 가능한 시간으로 예약합니다"},
      {"label": "취소", "description": "스케줄링을 취소합니다"}
    ],
    "multiSelect": false
  }]
}
```

5. **조정 시도** 승인 시에만 → `updateEvent`로 기존 일정 이동 후 전원 참석 슬롯으로 예약

### Step C: 회의실 선택

인원 기반 최소 적합 방 자동 선택:

```
1. 인원 기반 필터: capacity >= attendee_count
2. 전화부스 제외 (2인 이상일 경우)
3. 최소 적합 방 우선:
   - 2~4인 → 소회의실(4)
   - 5~6인 → 중회의실(6)
   - 7~10인 → 라운지(10)
   - 11~15인 → 대회의실(15)
4. listEvents로 해당 시간대 가용성 확인
5. 불가하면 다음 크기 방으로 시도
6. 전부 불가 시:
```

```json
{
  "questions": [{
    "question": "해당 시간에 사용 가능한 회의실이 없습니다. 어떻게 할까요?",
    "header": "회의실 없음",
    "options": [
      {"label": "회의실 없이 예약", "description": "회의실 없이 캘린더 일정만 생성합니다"},
      {"label": "다른 시간", "description": "다른 시간대를 찾아봅니다"},
      {"label": "취소", "description": "스케줄링을 취소합니다"}
    ],
    "multiSelect": false
  }]
}
```

### Step D: 최종 확인

예약 전 최종 확인을 표시합니다:

```markdown
## 회의 예약 확인

| 항목 | 내용 |
|------|------|
| 제목 | {title} |
| 일시 | {date} {start}~{end} |
| 회의실 | {room} |
| 참석자 | {names} |
```

```json
{
  "questions": [{
    "question": "위 내용으로 회의를 예약할까요?",
    "header": "최종 확인",
    "options": [
      {"label": "예약", "description": "캘린더 이벤트를 생성합니다"},
      {"label": "다른 시간", "description": "다른 시간대를 찾아봅니다"},
      {"label": "취소", "description": "스케줄링을 취소합니다"}
    ],
    "multiSelect": false
  }]
}
```

### Step E: 캘린더 이벤트 생성

`createEvent`로 회의를 생성합니다:

```
- summary: {회의 제목}
- start/end: {선택된 시간}
- attendees: [참석자 이메일 + 회의실 Calendar ID]
- description: (Slack URL이 있는 경우) "관련 스레드: {slack_url}"
```

> 회의실은 attendees에 Calendar ID를 추가하여 자동 예약합니다.

### Step F: Slack 스레드 회신

Slack URL이 있는 경우 `slack_reply_to_thread`로 결과를 회신합니다:

```
:calendar: 회의 예약 완료
• {title}
• {date} {start}~{end} | {room}
• 참석: {names}
캘린더 초대 발송 완료
```

---

## 에러 처리

| 상황 | 처리 |
|------|------|
| Slack URL 형식 오류 | "올바른 Slack 스레드 URL을 입력해주세요. (예: https://xxx.slack.com/archives/CXXX/pXXX)" |
| 참석자 이름 매핑 실패 | `people_getUserProfile` 시도 → 실패 시 AskUserQuestion으로 이메일 직접 입력 |
| 과거 날짜 지정 | "지정한 날짜가 과거입니다. 올바른 날짜를 입력해주세요." 경고 후 재입력 |
| 회의실 전부 불가 | 3가지 옵션 제시 (회의실 없이 / 다른 시간 / 취소) |
| calendar_list 회의실 조회 실패 | 회의실 없이 참석자만으로 예약 진행 |

---

## 출력 형식

### 콘솔 (완료 시)

```markdown
## 회의 예약 완료

| 항목 | 내용 |
|------|------|
| 제목 | {title} |
| 일시 | {date} {start}~{end} |
| 회의실 | {room} |
| 참석자 | {names} |

캘린더 초대가 발송되었습니다.
```

### Slack 회신 (URL이 있는 경우)

```
:calendar: 회의 예약 완료
• {title}
• {date} {start}~{end} | {room}
• 참석: {names}
캘린더 초대 발송 완료
```

---

## 사용 예시

```bash
# Interactive Mode
/schedule-meeting -i

# Slack 스레드에서 자동 추출
/schedule-meeting https://tpc-internet.slack.com/archives/C051U4DUH4H/p1234567890123456

# 참석자 직접 지정
/schedule-meeting muzi wish walter --duration=30 --priority=medium

# 혼합 사용
/schedule-meeting https://tpc-internet.slack.com/archives/C051U4DUH4H/p1234567890123456 --priority=high

# 간단한 형태
/schedule-meeting muzi wish 30분 내일
```
