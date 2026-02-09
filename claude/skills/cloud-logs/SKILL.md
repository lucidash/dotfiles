---
name: cloud-logs
description: GCP Cloud Run 서비스의 API 로그를 조회합니다. Preview/본 환경의 에러 로그, 특정 요청 추적, 상태 코드별 필터링 등을 지원합니다. "로그 확인해줘", "에러 로그 봐줘", "400 에러 조회", "preview 로그" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "[beta|real] [상태코드] [시간범위]"
allowed-tools: Bash, Read, Grep, AskUserQuestion
---

# GCP Cloud Logging 조회

Cloud Run 서비스의 API 호출 로그를 gcloud CLI로 조회하는 진단 도구입니다.

**Arguments:** `$ARGUMENTS`

## 환경 정보

| 환경 | GCP 프로젝트 | API 서비스명 | Admin 서비스명 |
|------|-------------|-------------|---------------|
| beta | `likey-beta` | `api-beta` | `admin-api-beta` |
| real | `likey-real` | `api` | `admin-api` |

## 인자 파싱

`$ARGUMENTS`에서 자유 형식으로 다음을 추출 (순서 무관, 모두 선택적):

| 인자 | 패턴 | 기본값 | 예시 |
|------|------|--------|------|
| 환경 | `beta` 또는 `real` | `beta` | `beta` |
| 서비스 | `api` 또는 `admin` | `api` | `admin` |
| 상태 코드 | 3자리 숫자 또는 `4xx`, `5xx` | `>=400` (4xx+5xx 전체) | `400`, `5xx` |
| 시간 범위 | `{숫자}h` 또는 `{숫자}d` | `3h` | `6h`, `1d` |
| trace ID | 32자리 hex | - | `0da937272fc91eca4291c3582b1d2a5f` |
| 경로 필터 | `/`로 시작하는 문자열 | - | `/api/studio/roulette` |
| UID | 숫자 16자리 이상 | - | `6031190279716864` |

인자가 없거나 모호하면 **현재 브랜치의 preview 환경(beta), 최근 3시간, 4xx+5xx 에러**를 기본으로 조회한다.

---

## 실행 순서

### 1. Preview 환경 파악

현재 브랜치에서 preview 이름을 추출한다.

```bash
# 현재 브랜치명
git branch --show-current
# 예: feature/roulette-reward-mediapool → roulette-reward-mediapool
```

Cloud Run에 해당 preview가 배포되어 있는지 확인:

```bash
gcloud run services describe {서비스명} --project={프로젝트} --region=us-central1 \
  --format="yaml(status.traffic)" 2>&1 | grep "tag: {preview-name}"
```

- 배포되어 있으면 → preview 환경 로그 조회
- 배포되어 있지 않으면 → 사용자에게 알림. 본 환경 로그 조회할지 확인

### 2. Revision 확인

앱 로그(Bunyan)에서 해당 preview의 revision 이름을 확인한다:

```bash
gcloud logging read \
  'resource.type="cloud_run_revision"
   AND resource.labels.service_name="{서비스명}"
   AND jsonPayload.previewEnv="{preview-name}"' \
  --project={프로젝트} \
  --freshness={시간범위} \
  --format="json" \
  --limit=1
```

`resource.labels.revision_name`에서 revision prefix를 추출한다.
(예: `api-beta-23909-sif` → `api-beta-23909`)

### 3. 에러 로그 조회

#### 3-1. Cloud Run request log (HTTP 레벨)

```bash
gcloud logging read \
  'resource.type="cloud_run_revision"
   AND resource.labels.service_name="{서비스명}"
   AND resource.labels.revision_name:"{revision-prefix}"
   AND httpRequest.status{상태필터}' \
  --project={프로젝트} \
  --freshness={시간범위} \
  --format="table(timestamp.date(tz=Asia/Seoul), httpRequest.status, httpRequest.requestMethod, httpRequest.requestUrl, httpRequest.latency)" \
  --limit=50
```

상태 필터 변환:
- `400` → `=400`
- `4xx` → `>=400 AND httpRequest.status<500`
- `5xx` → `>=500 AND httpRequest.status<600`
- 기본값 → `>=400`

#### 3-2. 앱 로그 (Bunyan, 경로/UID 필터 시)

경로 필터나 UID가 지정된 경우:

```bash
gcloud logging read \
  'resource.type="cloud_run_revision"
   AND resource.labels.service_name="{서비스명}"
   AND jsonPayload.previewEnv="{preview-name}"
   AND jsonPayload.requestPath:"{경로}"
   AND severity>=WARNING' \
  --project={프로젝트} \
  --freshness={시간범위} \
  --format="json" \
  --limit=20
```

### 4. 결과 분석 및 보고

#### 에러가 있는 경우

1. **요약 테이블**: 상태코드별, 엔드포인트별 에러 횟수 그룹핑
2. **패턴 분석**: 같은 엔드포인트 반복 에러, 시간대 집중 등
3. **대표 에러 상세**: 가장 빈번하거나 중요한 에러의 상세 정보

#### 에러가 없는 경우

"해당 조건에 에러 로그가 없습니다." 출력.

### 5. 상세 추적 (필요 시)

특정 요청의 전체 로그를 trace ID로 추적:

```bash
# Cloud Run request log에서 trace ID 추출 (insertId 기반)
gcloud logging read \
  'resource.type="cloud_run_revision"
   AND resource.labels.revision_name:"{revision-prefix}"
   AND httpRequest.requestUrl:"{해당URL}"' \
  --project={프로젝트} \
  --freshness={시간범위} \
  --format="json" \
  --limit=1

# trace ID로 해당 요청의 모든 앱 로그 추적
gcloud logging read \
  'trace="projects/{프로젝트}/traces/{traceId}"' \
  --project={프로젝트} \
  --format="json"
```

이를 통해 에러의 정확한 원인 (비즈니스 로직 에러, ValidateError 등)을 파악한다.

---

## 주요 필터 필드 레퍼런스

### Cloud Run request log

| 필드 | 설명 |
|------|------|
| `httpRequest.status` | HTTP 상태 코드 |
| `httpRequest.requestUrl` | 전체 요청 URL |
| `httpRequest.requestMethod` | HTTP 메서드 |
| `httpRequest.latency` | 응답 시간 |

### 앱 로그 (Bunyan jsonPayload)

| 필드 | 설명 |
|------|------|
| `jsonPayload.previewEnv` | Preview 환경 이름 |
| `jsonPayload.requestPath` | API 경로 |
| `jsonPayload.requestMethod` | HTTP 메서드 |
| `jsonPayload.requestLikeyUid` | 요청 사용자 UID |
| `jsonPayload.requestDevice` | 요청 기기 정보 |
| `jsonPayload.apiVersion` | API 버전 |
| `severity` | 로그 레벨 (INFO, WARNING, ERROR) |
| `trace` | 요청 트레이스 ID |

---

## 주의사항

- **real 환경 조회 시** UID 등 PII 출력 주의
- gcloud 인증이 안 되어 있으면 `gcloud auth login` 안내
- 로그 조회가 오래 걸리면 `--freshness`를 줄이거나 `--limit`을 낮춰서 범위를 제한
- `--limit`은 필요에 따라 조절 (기본 50, 상세 추적 시 줄이기)

## 사용 예시

```bash
/cloud-logs                              # 현재 preview(beta) 에러 조회 (3시간)
/cloud-logs 400                          # 400 에러만
/cloud-logs 5xx 6h                       # 5xx 에러, 6시간
/cloud-logs real                         # real 환경 조회
/cloud-logs /api/studio/roulette         # 특정 경로 필터
/cloud-logs 0da937272fc91eca...          # trace ID로 요청 추적
```
