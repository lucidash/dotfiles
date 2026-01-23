# Preview Beta 배포

현재 브랜치의 PR에 `preview-beta` 라벨을 추가하고 배포 완료를 대기합니다.

## 실행 순서

### 1. PR 확인
```bash
command gh pr view --json labels,number,url
```
- PR이 없으면 `/open-pr` 스킬을 실행하여 PR 먼저 생성

### 2. 라벨 추가
- `preview-beta` 라벨이 이미 있으면 "이미 preview-beta 라벨이 있습니다" 출력 후 배포 대기로 진행
- 라벨이 없으면:
```bash
command gh pr edit --add-label preview-beta
```

### 3. 배포 완료 대기

PR의 check 상태를 폴링하며 배포 완료 대기:

```bash
# 30초 간격으로 최대 15분 대기
command gh pr checks --json name,state,conclusion
```

확인할 check:
- `preview-beta` 또는 `Deploy to beta` 관련 check
- state가 `completed`이고 conclusion이 `success`면 배포 완료

폴링 중 출력:
```
⏳ preview-beta 배포 대기 중... (1/30)
⏳ preview-beta 배포 대기 중... (2/30)
...
```

### 4. 배포 완료 시

```
✅ preview-beta 배포가 완료되었습니다.
PR: {PR_URL}
```

### 5. 슬랙 알림 (선택적)

세션에서 연관된 슬랙 스레드가 있으면 `/notify` 스킬 호출:
```
/notify preview-beta 배포가 완료되었습니다: {PR_URL}
```

슬랙 스레드가 없으면 알림 생략.

## 타임아웃

- 최대 대기 시간: 15분
- 폴링 간격: 30초
- 타임아웃 시: "배포 대기 시간이 초과되었습니다. GitHub Actions에서 직접 확인해주세요."
