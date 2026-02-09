---
name: slack:download-files
description: Slack 스레드에서 파일을 일괄 다운로드합니다. "슬랙 파일 다운로드", "스레드 파일 받기", "slack download" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "<스레드URL> [저장경로]"
allowed-tools: Bash, Read, mcp__slack__slack_get_thread_replies
---

# Slack 스레드 파일 일괄 다운로드

Slack 스레드 URL을 입력받아 해당 스레드에 첨부된 모든 파일을 다운로드합니다.

**Arguments:** `$ARGUMENTS`

---

## 워크플로우

```
1. 스레드 URL 파싱 → channel_id, thread_ts 추출
2. MCP로 스레드 메시지 조회 → 파일 메타데이터 획득
3. Slack Bot Token으로 파일 다운로드
```

---

## 1. 스레드 URL 파싱

### URL 형식

```
https://{workspace}.slack.com/archives/{channel_id}/p{timestamp}
```

### 파싱 규칙

```
예시: https://tpc-internet.slack.com/archives/C07L41777U4/p1770285029364989

- channel_id: C07L41777U4
- thread_ts: 1770285029.364989
  └─ p 제거 후 마지막 6자리 앞에 . 추가
  └─ p1770285029364989 → 1770285029.364989
```

---

## 2. 스레드 조회 (MCP)

```typescript
const result = await mcp__slack__slack_get_thread_replies({
  channel_id: "{channel_id}",
  thread_ts: "{thread_ts}"
});
```

### 응답에서 파일 정보 추출

```json
{
  "messages": [
    {
      "files": [
        {
          "id": "F12345",
          "name": "document.pdf",
          "url_private": "https://files.slack.com/files-pri/...",
          "url_private_download": "https://files.slack.com/files-pri/.../download/..."
        }
      ]
    }
  ]
}
```

---

## 3. 파일 다운로드

### 토큰 추출

```bash
SLACK_TOKEN=$(cat ~/.claude.json | python3 -c "import sys,json; print(json.load(sys.stdin)['mcpServers']['slack']['env']['SLACK_BOT_TOKEN'])")
```

### 파일 다운로드 (curl)

```bash
curl -sL -H "Authorization: Bearer $SLACK_TOKEN" \
  "{url_private_download}" \
  -o "{저장경로}/{filename}"
```

**중요:** `url_private` 대신 `url_private_download` 사용 권장

---

## 실행 순서

### 1. URL 파싱

사용자가 제공한 스레드 URL에서 channel_id와 thread_ts 추출

### 2. 저장 경로 결정

- 인자로 경로가 주어진 경우: 해당 경로 사용
- 없는 경우: 현재 디렉토리 또는 `/tmp/slack-downloads/` 사용

```bash
DOWNLOAD_DIR="${저장경로:-/tmp/slack-downloads}"
mkdir -p "$DOWNLOAD_DIR"
```

### 3. 스레드 조회

MCP 도구로 스레드 메시지 조회

### 4. 파일 목록 추출

응답에서 `files` 배열이 있는 메시지 찾기:
- `id`: 파일 ID
- `name`: 파일명
- `url_private_download`: 다운로드 URL
- `size`: 파일 크기

### 5. 일괄 다운로드

```bash
SLACK_TOKEN=$(cat ~/.claude.json | python3 -c "import sys,json; print(json.load(sys.stdin)['mcpServers']['slack']['env']['SLACK_BOT_TOKEN'])")

# 각 파일에 대해
curl -sL -H "Authorization: Bearer $SLACK_TOKEN" \
  "{url_private_download}" \
  -o "$DOWNLOAD_DIR/{filename}"
```

### 6. 결과 출력

**반드시 아래 형식으로 출력:**

```
✅ 다운로드 완료

| #  | 파일명   | 크기 | 절대 경로                          | 상태 |
|----|----------|------|------------------------------------|------|
| #1 | 30.png   | 15MB | /tmp/slack-downloads/30.png        | ✅   |
| #2 | 50.png   | 14MB | /tmp/slack-downloads/50.png        | ✅   |
| #3 | 70.png   | 13MB | /tmp/slack-downloads/70.png        | ✅   |
| ...| ...      | ...  | ...                                | ...  |

저장 위치: /tmp/slack-downloads/
총 N개 파일, XX MB
```

**중요:** 각 파일에 `#1`, `#2`, `#3` ... 순서대로 넘버링하고, 절대 경로를 반드시 포함할 것

---

## 사용 예시

```bash
# 기본 사용 (현재 디렉토리에 다운로드)
/slack-download https://tpc-internet.slack.com/archives/C07L41777U4/p1770285029364989

# 특정 경로에 다운로드
/slack-download https://tpc-internet.slack.com/archives/C07L41777U4/p1770285029364989 ./downloads

# 절대 경로
/slack-download https://tpc-internet.slack.com/archives/C07L41777U4/p1770285029364989 /Users/muzi/Desktop
```

---

## 주의사항

- **Bot 권한**: Slack Bot에 `files:read` 스코프 필요
- **채널 접근**: Bot이 해당 채널에 참여해 있어야 함 (초대 필요: `/invite @봇이름`)
- **대용량 파일**: 큰 파일은 다운로드 시간이 오래 걸릴 수 있음
- **중복 파일명**: 동일한 이름의 파일이 있으면 덮어씀

---

## 에러 처리

| 에러 | 원인 | 해결 |
|------|------|------|
| `not_in_channel` | Bot이 채널에 없음 | 채널에서 `/invite @봇이름` 실행 |
| `channel_not_found` | 잘못된 channel_id | URL 확인 |
| `thread_not_found` | 잘못된 thread_ts | URL 파싱 확인 (마지막 6자리 앞에 . 추가) |
| `not_authed` | 토큰 문제 | `~/.claude.json`의 SLACK_BOT_TOKEN 확인 |
| 파일 없음 | 스레드에 파일 없음 | 스레드 내용 확인 |

---

## 토큰 설정 위치

```
~/.claude.json → mcpServers.slack.env.SLACK_BOT_TOKEN
```

토큰 유효성 테스트:
```bash
SLACK_TOKEN=$(cat ~/.claude.json | python3 -c "import sys,json; print(json.load(sys.stdin)['mcpServers']['slack']['env']['SLACK_BOT_TOKEN'])")
curl -s -H "Authorization: Bearer $SLACK_TOKEN" "https://slack.com/api/auth.test" | python3 -m json.tool
```
