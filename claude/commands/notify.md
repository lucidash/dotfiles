# 슬랙 스레드 알림

현재 세션과 연관된 슬랙 스레드에 진행 과정이나 결과를 노티합니다.

## 인자

- `$ARGUMENTS`: 알림 메시지 (선택사항). 없으면 세션 컨텍스트에서 적절한 메시지 생성

## 실행 순서

### 1. 연관 슬랙 스레드 찾기

다음 순서로 슬랙 스레드를 탐색:

1. **세션 컨텍스트 확인**: 이전 대화에서 언급된 슬랙 스레드 URL이 있는지 확인
   - 형식: `https://likey-team.slack.com/archives/{channel_id}/p{timestamp}`
   - 예: `https://likey-team.slack.com/archives/C05FBNB4G3F/p1737430376869289`

2. **Notion 작업 페이지 확인**: 세션에서 참조한 Notion 작업 페이지가 있다면
   - 해당 페이지에서 슬랙 스레드 링크 검색
   - "슬랙", "Slack", "스레드" 키워드로 링크 찾기

3. **스레드를 찾지 못한 경우**: 사용자에게 슬랙 스레드 URL 요청

### 2. 슬랙 URL 파싱

슬랙 URL에서 channel_id와 thread_ts 추출:
```
URL: https://likey-team.slack.com/archives/C05FBNB4G3F/p1737430376869289
-> channel_id: C05FBNB4G3F
-> thread_ts: 1737430376.869289 (p 제거 후 마지막 6자리 앞에 . 추가)
```

### 3. 알림 메시지 작성

`$ARGUMENTS`가 있으면 해당 메시지 사용.
없으면 세션 컨텍스트에서 적절한 메시지 생성:

- PR 생성 완료 시: "PR이 생성되었습니다: {PR_URL}"
- 배포 완료 시: "{환경} 배포가 완료되었습니다: {PR_URL}"
- 작업 완료 시: "작업이 완료되었습니다. {간단한 요약}"

### 4. 슬랙 스레드에 답글 전송

```typescript
mcp__slack__slack_reply_to_thread({
  channel_id: "{channel_id}",
  thread_ts: "{thread_ts}",
  text: "{메시지}"
})
```

### 5. 결과 출력

```
✅ 슬랙 알림 전송 완료
- 채널: #{channel_name}
- 메시지: {전송된 메시지}
```

## 예시

```bash
# 자동 메시지 (세션 컨텍스트 기반)
/notify

# 직접 메시지 지정
/notify preview-beta 배포가 완료되었습니다. 확인 부탁드립니다.

# PR 링크와 함께
/notify PR 생성 완료: https://github.com/likey-team/likey-backend/pull/6483
```

## 주의사항

- 슬랙 스레드를 찾지 못하면 사용자에게 URL을 요청
- 메시지는 간결하게 작성 (핵심 정보만)
- 이모지는 사용하지 않음
