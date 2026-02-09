---
name: share-file
description: 파일을 GCS에 업로드하고 Slack에 공유합니다. "파일 공유해줘", "GCS 업로드", "링크 공유" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "<파일경로> [#채널 | 스레드URL]"
allowed-tools: Bash, Read, Glob, mcp__slack__slack_post_message, mcp__slack__slack_reply_to_thread, mcp__slack__slack_list_channels
---

# 파일 공유 (GCS 업로드 + Slack 링크)

파일을 Google Cloud Storage에 업로드하고 Slack에 링크를 공유합니다.

**Arguments:** `$ARGUMENTS`

---

## GCS 업로드 (gcloud CLI / gsutil)

### 기본 명령어

```bash
gsutil cp <로컬파일> gs://<버킷>/<경로>
```

### 한글 파일 업로드 (UTF-8 인코딩 필수)

```bash
gsutil -h "Content-Type:text/plain; charset=utf-8" cp <파일> gs://<버킷>/<경로>
```

### Content-Type 참조표

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

### 공유용 버킷

| 환경 | 버킷 | 도메인 |
|------|------|--------|
| Beta | `static-beta.likeycontents.xyz` | `https://static-beta.likeycontents.xyz/` |
| Real | `static.likeycontents.xyz` | `https://static.likeycontents.xyz/` |

**주의:** `stati-beta` 아님, `static-beta`임 (c 포함)

---

## 실행 순서

### 1. 파일 확인

```bash
ls -la <파일경로>
file <파일경로>  # 파일 타입 확인
```

### 2. 파일명 생성 (난수 포함)

```bash
RAND=$(openssl rand -hex 4)
FILENAME="<원본이름>-${RAND}.<확장자>"
```

### 3. Content-Type 결정

파일 확장자에 따라 적절한 Content-Type 선택:
- 텍스트 파일 (txt, md, json, html): `charset=utf-8` 필수
- 바이너리 파일 (이미지, pdf 등): charset 불필요

### 4. GCS 업로드

```bash
# 텍스트 파일 (한글 포함 가능성)
gsutil -h "Content-Type:text/plain; charset=utf-8" \
  cp <파일> gs://static-beta.likeycontents.xyz/share/${FILENAME}

# 바이너리 파일
gsutil cp <파일> gs://static-beta.likeycontents.xyz/share/${FILENAME}

# 업로드 확인
echo "https://static-beta.likeycontents.xyz/share/${FILENAME}"
```

### 5. Slack 공유 (선택사항)

#### 채널명이 주어진 경우 (#채널)

```typescript
// 1. 채널 ID 조회
const channels = await mcp__slack__slack_list_channels();
const channel = channels.find(c => c.name === '채널명');

// 2. 메시지 전송
await mcp__slack__slack_post_message({
  channel_id: channel.id,
  text: ":page_facing_up: *파일 공유*\n{URL}"
});
```

#### 스레드 URL이 주어진 경우

```
URL 형식: https://likey-team.slack.com/archives/{channel_id}/p{timestamp}

파싱:
- channel_id: C05S9LHFUAD
- thread_ts: 1770280943.118619 (p 제거 후 마지막 6자리 앞에 . 추가)
```

```typescript
await mcp__slack__slack_reply_to_thread({
  channel_id: "{channel_id}",
  thread_ts: "{thread_ts}",
  text: ":page_facing_up: *파일 공유*\n{URL}"
});
```

### 6. 결과 출력

```
✅ 파일 업로드 완료
- URL: https://static-beta.likeycontents.xyz/share/...
- Slack: #채널명 또는 스레드 (공유한 경우)
```

---

## 사용 예시

```bash
# 파일만 업로드
/share-file ./report.txt

# 업로드 후 채널에 공유
/share-file ./report.txt #ggultip

# 업로드 후 스레드에 공유
/share-file ./log.txt https://likey-team.slack.com/archives/C05S9LHFUAD/p1770280943118619

# 이미지 업로드
/share-file ./screenshot.png #dev-backend
```

---

## 주의사항

- **한글 인코딩**: 텍스트 파일은 반드시 `charset=utf-8` 지정
- **버킷명**: `static-beta` (stati 아님, c 포함)
- **민감 정보**: 민감한 정보가 포함된 파일은 업로드 전 사용자에게 확인
- **파일 크기**: 대용량 파일(100MB+)은 업로드 시간이 길어질 수 있음
- **공개 URL**: GCS 버킷이 public이므로 업로드된 파일은 누구나 접근 가능

---

## 에러 처리

| 에러 | 원인 | 해결 |
|------|------|------|
| `BucketNotFoundException` | 버킷명 오타 | `static-beta` 확인 (stati 아님) |
| 한글 깨짐 | charset 미지정 | `Content-Type: text/plain; charset=utf-8` 추가 |
| `AccessDeniedException` | gcloud 인증 문제 | `gcloud auth login` 실행 |

---

## gcloud CLI 유용한 명령어

```bash
# 버킷 목록 조회
gsutil ls | grep static

# 파일 목록 조회
gsutil ls gs://static-beta.likeycontents.xyz/share/

# 파일 삭제
gsutil rm gs://static-beta.likeycontents.xyz/share/<파일명>

# 파일 메타데이터 확인
gsutil stat gs://static-beta.likeycontents.xyz/share/<파일명>
```
