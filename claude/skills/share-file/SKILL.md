---
name: share-file
description: 파일을 Slack에 직접 업로드하거나 GCS에 업로드하고 링크를 공유합니다. "파일 공유해줘", "슬랙에 파일 올려줘", "GCS 업로드" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "<파일경로> [#채널 | 스레드URL | --slack-thread 채널ID:thread_ts]"
allowed-tools: Bash, Read, Glob, mcp__slack__slack_post_message, mcp__slack__slack_reply_to_thread, mcp__slack__slack_list_channels
---

# 파일 공유 (Slack API 직접 업로드 + GCS fallback)

파일을 Slack API로 직접 업로드합니다. Slack 업로드 실패 시 GCS에 업로드하고 링크를 공유합니다.

**Arguments:** `$ARGUMENTS`

---

## 실행 순서

### 1. 파일 확인

```bash
ls -la <파일경로>
file <파일경로>  # 파일 타입 확인
```

### 2. Slack 공유 대상 파싱

#### `#채널명`인 경우

MCP `mcp__slack__slack_list_channels`로 채널 ID 조회

#### 스레드 URL인 경우

```
URL 형식: https://tpc-internet.slack.com/archives/{channel_id}/p{timestamp}

파싱:
- channel_id: C05S9LHFUAD
- thread_ts: 1770280943.118619 (p 제거 후 마지막 6자리 앞에 . 추가)
```

#### `--slack-thread 채널ID:thread_ts` 형식인 경우

직접 channel_id와 thread_ts 사용

### 3. Slack API 직접 업로드 (기본 방식)

Bot token으로 Slack API를 직접 호출하여 파일을 업로드합니다.

#### 3-1. Bot Token 가져오기

```bash
SLACK_TOKEN=$(cat ~/.claude.json | python3 -c "import sys,json; print(json.load(sys.stdin)['mcpServers']['slack']['env']['SLACK_BOT_TOKEN'])")
```

#### 3-2. 업로드 URL 받기

```bash
FILE_SIZE=$(wc -c < <파일경로> | tr -d ' ')
UPLOAD_RESP=$(curl -s -X POST "https://slack.com/api/files.getUploadURLExternal" \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -d "filename=<파일명>&length=$FILE_SIZE")

UPLOAD_URL=$(echo "$UPLOAD_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['upload_url'])")
FILE_ID=$(echo "$UPLOAD_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['file_id'])")
```

#### 3-3. 파일 업로드

```bash
curl -s -X POST "$UPLOAD_URL" -F "file=@<파일경로>"
```

#### 3-4. 업로드 완료 + 채널/스레드에 공유

```bash
# 채널에 공유 (스레드 아닌 경우)
curl -s -X POST "https://slack.com/api/files.completeUploadExternal" \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"files\": [{\"id\": \"$FILE_ID\", \"title\": \"<파일명>\"}],
    \"channel_id\": \"<channel_id>\"
  }"

# 스레드에 공유
curl -s -X POST "https://slack.com/api/files.completeUploadExternal" \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"files\": [{\"id\": \"$FILE_ID\", \"title\": \"<파일명>\"}],
    \"channel_id\": \"<channel_id>\",
    \"thread_ts\": \"<thread_ts>\"
  }"
```

#### 3-5. 성공 확인

응답의 `ok` 필드가 `true`이면 성공. 결과 출력 후 종료.

```
✅ 파일 공유 완료 (Slack 직접 업로드)
- 파일: <파일명> (<크기>)
- Slack: #채널명 또는 스레드
```

#### 3-6. 실패 시 → GCS fallback (4단계로 이동)

Slack API 호출이 실패하면 (토큰 없음, 권한 부족, API 에러 등) GCS 업로드 방식으로 fallback.

---

### 4. GCS 업로드 (fallback)

Slack API 직접 업로드가 실패한 경우에만 사용합니다.

#### 4-1. 파일명 생성 (난수 포함)

```bash
RAND=$(openssl rand -hex 4)
FILENAME="<원본이름>-${RAND}.<확장자>"
```

#### 4-2. Content-Type 결정

| 확장자 | Content-Type |
|--------|--------------|
| `.txt` | `text/plain; charset=utf-8` |
| `.html` | `text/html; charset=utf-8` |
| `.json` | `application/json; charset=utf-8` |
| `.md` | `text/markdown; charset=utf-8` |
| `.png` | `image/png` |
| `.jpg`, `.jpeg` | `image/jpeg` |
| `.gif` | `image/gif` |
| `.pdf` | `application/pdf` |
| `.zip` | `application/zip` |

#### 4-3. GCS 업로드

공유용 버킷: `static-beta.likeycontents.xyz` (도메인: `https://static-beta.likeycontents.xyz/`)

**주의:** `stati-beta` 아님, `static-beta`임 (c 포함)

```bash
# 텍스트 파일 (한글 포함 가능성) — charset=utf-8 필수
gsutil -h "Content-Type:text/plain; charset=utf-8" \
  cp <파일> gs://static-beta.likeycontents.xyz/share/${FILENAME}

# 바이너리 파일
gsutil cp <파일> gs://static-beta.likeycontents.xyz/share/${FILENAME}
```

#### 4-4. Slack에 링크 공유

채널명이 주어진 경우:
```typescript
await mcp__slack__slack_post_message({
  channel_id: "<channel_id>",
  text: ":page_facing_up: *파일 공유*\n<URL>"
});
```

스레드에 공유하는 경우:
```typescript
await mcp__slack__slack_reply_to_thread({
  channel_id: "<channel_id>",
  thread_ts: "<thread_ts>",
  text: ":page_facing_up: *파일 공유*\n<URL>"
});
```

#### 4-5. 결과 출력

```
✅ 파일 공유 완료 (GCS fallback)
- URL: https://static-beta.likeycontents.xyz/share/...
- Slack: #채널명 또는 스레드
```

---

## Slack 공유 대상 없이 파일만 업로드하는 경우

Slack 채널/스레드 지정이 없으면 GCS에 업로드하고 URL만 반환합니다.

```
✅ 파일 업로드 완료
- URL: https://static-beta.likeycontents.xyz/share/...
```

---

## 사용 예시

```bash
# 채널에 파일 직접 공유
/share-file ./report.txt #ggultip

# 스레드에 파일 직접 공유
/share-file ./log.txt https://tpc-internet.slack.com/archives/C05S9LHFUAD/p1770280943118619

# 채널ID:thread_ts 형식으로 스레드에 공유
/share-file ./data.zip --slack-thread C051U4DUH4H:1773217461.265859

# 파일만 업로드 (GCS, Slack 공유 없음)
/share-file ./screenshot.png
```

---

## 주의사항

- **민감 정보**: 민감한 정보가 포함된 파일은 업로드 전 사용자에게 확인
- **GCS 공개 URL**: GCS 버킷이 public이므로 업로드된 파일은 누구나 접근 가능
- **Bot 권한**: Slack 직접 업로드 시 Bot에 `files:write` 스코프 필요
- **채널 접근**: Bot이 해당 채널에 참여해 있어야 함

---

## 에러 처리

### Slack API 에러

| 에러 | 원인 | 동작 |
|------|------|------|
| 토큰 없음 | `~/.claude.json`에 SLACK_BOT_TOKEN 없음 | GCS fallback |
| `not_authed` | 토큰 만료/무효 | GCS fallback |
| `not_in_channel` | Bot이 채널에 없음 | GCS fallback + 안내 |
| `channel_not_found` | 잘못된 channel_id | GCS fallback |

### GCS 에러

| 에러 | 원인 | 해결 |
|------|------|------|
| `BucketNotFoundException` | 버킷명 오타 | `static-beta` 확인 |
| 한글 깨짐 | charset 미지정 | `Content-Type` 에 `charset=utf-8` 추가 |
| `AccessDeniedException` | gcloud 인증 문제 | `gcloud auth login` 실행 |

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
