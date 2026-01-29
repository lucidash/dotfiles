# Preview 배포

현재 브랜치의 PR에 preview 라벨을 추가하고 배포 완료를 대기합니다.

## 사용법

```
/preview beta    # preview-beta 배포
/preview real    # preview-real 배포 (프로덕션)
/preview         # 환경 선택 프롬프트
```

## 입력

- `$ARGUMENTS`: (선택) 배포 환경
  - `beta` - preview-beta 배포 (스테이징)
  - `real` - preview-real 배포 (프로덕션)
  - 생략 시 AskUserQuestion으로 선택

---

## 실행 순서

### 1. 환경 결정

`$ARGUMENTS` 파싱:
- `beta` 또는 `b` → `preview-beta`
- `real` 또는 `r` → `preview-real`
- 생략 → AskUserQuestion으로 선택 요청

### 2. PR 확인

```bash
command gh pr view --json labels,number,url
```

- PR이 없으면 `/open-pr` 스킬을 실행하여 PR 먼저 생성

### 3. 라벨 추가

```bash
# 라벨이 이미 있는지 확인
command gh pr view --json labels --jq '.labels[].name' | grep -q "{라벨명}"

# 없으면 추가
command gh pr edit --add-label {라벨명}
```

- 이미 라벨이 있으면 "이미 {라벨명} 라벨이 있습니다" 출력 후 배포 대기로 진행

### 4. 배포 완료 대기

PR의 check 상태를 폴링하며 배포 완료 대기:

```bash
# 30초 간격으로 최대 15분 대기
command gh pr checks --json name,state,conclusion
```

확인할 check:
- `preview-beta` 또는 `Deploy to beta` 관련 check (beta인 경우)
- `preview-real` 또는 `Deploy to real` 관련 check (real인 경우)
- state가 `completed`이고 conclusion이 `success`면 배포 완료

폴링 중 출력:
```
⏳ {라벨명} 배포 대기 중... (1/30)
⏳ {라벨명} 배포 대기 중... (2/30)
...
```

### 5. 배포 완료 시 Preview URL 조회

배포가 완료되면 GitHub Deployments API를 통해 실제 Preview URL을 조회:

```bash
# 레포 정보 조회
repo=$(command gh repo view --json nameWithOwner --jq '.nameWithOwner')
pr_number=$(command gh pr view --json number --jq '.number')

# Environment 이름 패턴 (레포마다 다름)
# - likey-admin-v2, likey-web: {stage}-preview-pr{number}
# - likey-backend: {stage}-preview-{short-name} (preview-action에서 생성한 이름)

# Deployment ID 조회 (가장 최근 해당 stage의 preview deployment)
deployment_id=$(command gh api repos/{repo}/deployments \
  --jq "[.[] | select(.environment | startswith(\"{stage}-preview\"))] | .[0].id")

# Preview URL 조회
preview_url=$(command gh api repos/{repo}/deployments/{deployment_id}/statuses \
  --jq '.[0].environment_url')
```

출력:
```
✅ {라벨명} 배포가 완료되었습니다.
PR: {PR_URL}
Preview URL: {preview_url}
```

**레포별 Preview URL 패턴** (참고용, 실제 URL은 API로 조회):

| 레포 | Stage | URL 패턴 |
|------|-------|----------|
| likey-admin-v2 | beta | `https://likey-admin-beta--{preview}-{random}.web.app` |
| likey-admin-v2 | real | `https://likey-admin-real--{preview}-{random}.web.app` |
| likey-backend | beta | `https://{preview}.api-beta.likeyme.net` |
| likey-backend | real | `https://{preview}.api.likey.me` |
| likey-web | beta | `https://{preview}.web-beta.likeyme.net` |
| likey-web | real | `https://{preview}.web.likey.me` |

**주의**: admin-v2는 random 부분이 매번 다를 수 있으므로 반드시 API로 조회해야 합니다.

### 6. 슬랙 알림 (선택적)

세션에서 연관된 슬랙 스레드가 있으면 `/notify` 스킬 호출:
```
/notify {라벨명} 배포가 완료되었습니다: {PR_URL}
```

슬랙 스레드가 없으면 알림 생략.

---

## 타임아웃

- 최대 대기 시간: 15분
- 폴링 간격: 30초
- 타임아웃 시: "배포 대기 시간이 초과되었습니다. GitHub Actions에서 직접 확인해주세요."

## 주의사항

- **preview-real은 프로덕션 환경 배포**이므로 신중하게 사용
- 배포 전 preview-beta에서 충분히 테스트 권장
- real 선택 시 확인 프롬프트 표시
