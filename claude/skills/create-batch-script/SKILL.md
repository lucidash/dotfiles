---
name: create-batch-script
description: 데이터 추출 배치 스크립트 생성. "배치 스크립트 만들어줘", "데이터 추출 스크립트", "배치 작성", "dump 스크립트" 같은 요청에 자동으로 활성화됩니다.
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
argument-hint: "추출하려는 데이터 설명 (예: JP 크리에이터 구독 결제 내역)"
---

# 데이터 추출 배치 스크립트 생성

데이터 추출/분석을 위한 배치 스크립트를 작성합니다.

## 인자
- `$ARGUMENTS`: 추출하려는 데이터 설명 (예: "JP 크리에이터 구독 결제 내역", "특정 기간 채팅 메시지 통계")

---

## 1. 요구사항 파악

사용자의 요청을 분석하여 다음 항목 정리:

| 항목 | 내용 |
|------|------|
| 대상 데이터 | {Entity 또는 BigQuery 테이블} |
| 필터 조건 | {날짜, 사용자 유형, 국가 등} |
| 필요 필드 | {추출할 필드 목록} |
| 집계/통계 | {필요한 경우} |
| 출력 형식 | CSV, JSON |

## 2. 데이터 소스 탐색

요구사항의 키워드를 기반으로 적절한 데이터 소스를 찾습니다.

### 2-1. 주요 데이터 소스 카탈로그

#### 결제/수익 관련
| 키워드 | Entity | BigQuery | 용도 |
|--------|--------|----------|------|
| 결제, 수익, 구독료 | - | `wallet_history` | 지갑 거래 내역 (description으로 구분) |
| 결제 체크아웃 | `PaymentCheckout` | - | 결제 상세 (할인, 프로모션 정보) |
| 프로모션 적용 | `AppliedMembershipPromotionHistory` | - | 프로모션 적용 이력 |
| 구독 | `Subscription` | - | 구독 상태/이력 |
| 멤버십 | `Membership` | - | 멤버십 설정 |

#### 사용자 관련
| 키워드 | Entity | BigQuery | 용도 |
|--------|--------|----------|------|
| 사용자, 크리에이터, 팬 | `User` | `user` | 사용자 기본 정보 |
| 팔로우 | `Follow` | - | 팔로우 관계 |
| 사용자 속성 | `UserProp` | - | 추가 속성 |

#### 콘텐츠 관련
| 키워드 | Entity | BigQuery | 용도 |
|--------|--------|----------|------|
| 포스트, 게시글 | `Post` | `post` | 게시글 |
| 채팅, 메시지 | `ChatMessage` | `chat_message` | 채팅 메시지 |
| 댓글 | `Comment` | - | 댓글 |
| 좋아요 | `Like` | - | 좋아요 |

#### 통계 관련
| 키워드 | Entity | BigQuery | 용도 |
|--------|--------|----------|------|
| 통계, 집계 | - | `celeb_revenue_stats` | 크리에이터 수익 통계 |
| 구독 통계 | - | `subscription_stats` | 구독 관련 통계 |

### 2-2. 키워드 기반 탐색

요구사항에서 키워드를 추출하여 관련 코드를 검색합니다.

```bash
# 1. Entity 모델 검색 (키워드로)
rg -i "{키워드}" src/likey --type ts -g "*.model.ts" -l

# 2. Entity 스키마 확인
rg "gstore.model\('{EntityName}'" src/likey --type ts -A 30

# 3. BigQuery 테이블 검색
rg "getBqTableName\('{테이블명}'" src --type ts -B 2 -A 5

# 4. 기존 배치 스크립트에서 유사 패턴 검색
rg -i "{키워드}" src/batch --type ts -l
```

### 2-3. 데이터 소스 선택 가이드

| 상황 | 권장 소스 | 이유 |
|------|-----------|------|
| 대량 데이터 집계/통계 | BigQuery | 빠른 집계, 날짜 범위 필터 효율적 |
| 실시간 상세 정보 필요 | Entity | 최신 데이터, 관계 조회 가능 |
| 결제 상세 (할인, 프로모션) | Entity (PaymentCheckout) | BigQuery에 없는 상세 정보 |
| 사용자 정보 보강 | `getUsers()` 함수 | 캐시 레이어 활용, 배치 처리 내장 |
| 복합 조건 필터링 | BigQuery → Entity | BQ로 1차 필터, Entity로 상세 조회 |

### 2-4. 탐색 결과 정리

탐색 후 다음 표를 채워서 사용자에게 확인:

| 항목 | 선택 | 근거 |
|------|------|------|
| 1차 데이터 소스 | {Entity/BigQuery 이름} | {선택 이유} |
| 2차 데이터 소스 (보강) | {있다면} | {필요 이유} |
| 주요 필터 조건 | {필드명} | {BigQuery WHERE 또는 Entity filter} |
| 조인/관계 조회 | {있다면} | {방법} |

### 2-5. 기존 배치 스크립트 참조

유사한 패턴의 기존 스크립트를 참고합니다.

- 경로: `src/batch/` 디렉토리
- 참고할 패턴:
  - `src/batch/payment/dump-jp-creator-subscription-payments.ts` - BigQuery + Entity 조합
  - `src/batch/payment/dump-jp-creator-promotion-history.ts` - Entity 전체 스캔 후 필터링
  - `src/batch/subscription/migrate-subs-records.ts` - 대량 데이터 배치 처리

## 3. 스크립트 구조

### 기본 템플릿
```typescript
/**
 * {스크립트 설명}
 *
 * 사용법:
 *   npm run batch src/batch/{category}/{script-name}.ts -- [--dry-run] [--limit=N] [--no-slack]
 *
 * 옵션:
 *   --dry-run: 파일 저장 없이 콘솔에만 출력
 *   --limit=N: 처리할 최대 건수
 *   --no-slack: Slack 알림 비활성화
 *
 * 출력:
 *   - CSV: output/{prefix}_{timestamp}.csv
 *   - JSON: output/{prefix}_{timestamp}.json
 */

import {runBatch} from '@/lib/batch.js';
import {BatchProgress} from '@/lib/batch-progress.js';
import dayjs from 'dayjs';
import timezone from 'dayjs/plugin/timezone.js';
import utc from 'dayjs/plugin/utc.js';
import fs from 'node:fs';
import path from 'node:path';

dayjs.extend(utc);
dayjs.extend(timezone);

// 타입 정의
type ResultItem = {
  // 필드 정의
};

// 인자 파싱
type ParsedArgs = {
  dryRun: boolean,
  limit?: number,
  noSlack: boolean,
};

function parseArgs(args: string[]): ParsedArgs {
  const dryRun = args.includes('--dry-run');
  const noSlack = args.includes('--no-slack');
  const limitArg = args.find(arg => arg.startsWith('--limit='));
  const limit = limitArg ? parseInt(limitArg.split('=')[1], 10) : undefined;
  return {dryRun, limit: limit && limit > 0 ? limit : undefined, noSlack};
}

async function main(options: ParsedArgs) {
  const {dryRun, limit, noSlack} = options;

  // Slack 진행 알림 초기화
  const progress = new BatchProgress('{스크립트 이름}', {enabled: !noSlack});

  console.log('=== 스크립트 시작 ===');
  if (dryRun) console.log('[DRY-RUN 모드]');
  if (limit) console.log(`[LIMIT] 최대 ${limit}건 처리`);

  // Slack 시작 알림
  await progress.start(`조건: ${dryRun ? 'dry-run, ' : ''}${limit ? `limit=${limit}` : '전체'}`);

  try {
    // 1단계: 데이터 조회
    await progress.step('1단계: 데이터 조회 시작...');
    // ...
    await progress.step('1단계 완료: N건 조회됨');

    // 2단계: 데이터 처리/변환
    // 3단계: 추가 정보 조회 (필요시)
    // 4단계: 통계 출력
    // 5단계: 파일 저장 (dry-run이 아닌 경우)

    const result = {/* 결과 요약 */};

    // Slack 완료 알림
    await progress.complete(result);

    return result;
  } catch (error) {
    // Slack 실패 알림
    await progress.fail(error);
    throw error;
  }
}

runBatch(async () => {
  const options = parseArgs(process.argv.slice(2));
  const result = await main(options);
  console.log('\n=== 최종 결과 ===');
  console.log(JSON.stringify(result, null, 2));
  console.log('\ndone');
});
```

## 4. Slack 진행 알림

배치 실행 시 Slack `#dev-null` 채널에 진행 상황을 알립니다.

### BatchProgress 클래스 사용법
```typescript
import {BatchProgress} from '@/lib/batch-progress.js';

// 초기화 (enabled: false로 테스트시 알림 비활성화)
const progress = new BatchProgress('스크립트 이름', {
  enabled: !noSlack,
  maxProgressMessages: 5,  // 유지할 최대 진행 메시지 수 (초과 시 오래된 것 삭제)
});

// 시작 알림 (메인 메시지)
await progress.start('기간: 2024-01-01 ~ 2024-12-31, 대상: JP 크리에이터');

// 진행 상황 (스레드 댓글로 추가)
await progress.step('1단계: BigQuery 쿼리 실행 중...');
await progress.step('1단계 완료: 10,000건 조회됨');
await progress.step('2단계: Entity 조회 중... (500/1000)');

// step이 많을 때 수동 squash (최근 N개만 유지)
await progress.squash(1);  // 최근 1개만 유지, 나머지 삭제

// 완료 알림 (모든 진행 메시지 삭제 후 결과 요약)
await progress.complete({totalCount: 10000, processedCount: 9500});

// 실패 알림 (진행 메시지 유지, 에러 내용 추가)
await progress.fail(error);
```

### 알림 흐름 예시
```
#dev-null 채널:
┌─────────────────────────────────────────────────┐
│ 🚀 *[REAL] JP 크리에이터 구독 결제 추출* ✅ 완료 (2분 30초) │
│   ├─ ✅ 완료 (2분 30초)                          │
│   │  {"totalCount": 10000, "processedCount": 9500} │
└─────────────────────────────────────────────────┘
```

### 페이징 처리 시 진행 알림
```typescript
let pageNum = 0;
let nextPageCursor: string | null = null;

do {
  pageNum++;
  const result = await SomeEntity.query()
    .start(nextPageCursor)
    .limit(1000)
    .run({readAll: true, cache: false, format: 'JSON'});

  // 1000건마다 진행 알림 (너무 자주 알리지 않음)
  if (pageNum % 5 === 0) {
    await progress.step(`Entity 스캔 중... ${pageNum * 1000}건 처리`);
  }

  nextPageCursor = result.nextPageCursor ?? null;
} while (nextPageCursor);

await progress.step(`Entity 스캔 완료: 총 ${pageNum * 1000}건`);
```

## 5. 데이터 소스별 패턴

### BigQuery 조회
```typescript
import {bigquery, getBqTableName} from '@likey/bq/index.js';

const tableName = getBqTableName('wallet_history');
const query = `
  SELECT * FROM \`${tableName}\`
  WHERE ts >= @startDate AND ts < @endDate
`;
const [job] = await bigquery.createQueryJob({
  query,
  location: 'US',
  params: {startDate: startDate.toISOString(), endDate: endDate.toISOString()},
});
const [rows] = await job.getQueryResults();
```

### Entity 조회 (페이지네이션)
```typescript
let entities: any[];
let nextPageCursor: string | null = null;

do {
  const result = await SomeEntity.query()
    .filter('field', '=', value)
    .start(nextPageCursor)
    .limit(1000)
    .run({readAll: true, cache: false, format: 'JSON'});
  entities = result.entities;
  nextPageCursor = result.nextPageCursor ?? null;

  // 처리 로직
} while (nextPageCursor);
```

### Entity 배치 조회 (최대 1000개)
```typescript
import {nullIfNotExists} from '@/lib/gstore-util.js';

const BATCH_SIZE = 1000;
const chunks: string[][] = [];
for (let i = 0; i < ids.length; i += BATCH_SIZE) {
  chunks.push(ids.slice(i, i + BATCH_SIZE));
}

const resultMap = new Map<string, EntityItem>();
for (const idsBatch of chunks) {
  const entities = await SomeEntity.get(idsBatch).catch(nullIfNotExists);
  if (entities) {
    const arr = Array.isArray(entities) ? entities : [entities];
    for (const entity of arr) {
      if (entity?.id) resultMap.set(entity.id, entity.plain());
    }
  }
}
```

### Entity Key 주의사항
Entity key는 `name` (문자열) 또는 `id` (숫자) 중 하나를 사용합니다. 둘 다 처리하려면:
```typescript
// ❌ 잘못된 예시: name만 사용 (id를 사용하는 엔티티 누락)
const key = entity.entityKey.name as string;

// ✅ 올바른 예시: name과 id 모두 처리
const key = (entity.entityKey.name ?? entity.entityKey.id?.toString()) as string;
```

### 병렬 처리 (대량 데이터)
순차 처리가 느릴 때 `executeInSize`로 병렬 처리:
```typescript
import {executeInSize} from '@/lib/fixed-size-executor.js';

const CONCURRENCY = 20;  // 동시 실행 수

// 배열 항목을 병렬로 처리 (최대 20개씩)
await executeInSize(CONCURRENCY, items, async (item) => {
  try {
    // 개별 처리 로직
    await processItem(item);
  } catch (err) {
    console.error(`Failed: ${item.id}`, err);
  }
});
```

**사용 시점:**
- 개별 API 호출이 많은 경우
- 독립적인 Entity 저장이 많은 경우
- I/O 바운드 작업이 많은 경우

### 사용자 정보 배치 조회
```typescript
import {getUsers} from '@likey/user/index.js';

const userMap = await getUsers(userUids); // 내부적으로 캐시 + 1000개씩 청크 처리
```

## 6. 출력 패턴

### CSV 저장
```typescript
const outputDir = path.join(process.cwd(), 'output');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, {recursive: true});
}

const timestamp = dayjs().format('YYYYMMDD_HHmmss');
const csvPath = path.join(outputDir, `{prefix}_${timestamp}.csv`);

const headers = ['field1', 'field2', 'field3'];
const csvContent = [
  headers.join(','),
  ...results.map(r => [
    r.field1,
    `"${(r.field2 ?? '').replace(/"/g, '""')}"`, // 문자열 이스케이프
    r.field3 ?? '',
  ].join(',')),
].join('\n');

fs.writeFileSync(csvPath, csvContent, 'utf-8');
```

### JSON 저장
```typescript
const jsonPath = path.join(outputDir, `{prefix}_${timestamp}.json`);
fs.writeFileSync(jsonPath, JSON.stringify(results, null, 2), 'utf-8');
```

## 7. 실행 및 테스트

### 개발 환경 (beta)
```bash
npm run batch src/batch/{category}/{script}.ts -- --dry-run --limit=10 --no-slack
```

### 운영 환경 (real)

**⚠️ 전제조건**: real 환경 실행 전 별도 터미널에서 프록시 실행 필요
- Cloud SQL Proxy 실행 중
- Redis 연결 가능 (VPN 또는 SSH 터널)

`[PROXY] waiting for redis & mysql` 메시지에서 멈추면 프록시가 실행되지 않은 상태입니다.

```bash
npm run batch-real src/batch/{category}/{script}.ts -- --dry-run --limit=10  # Slack 알림 O
npm run batch-real src/batch/{category}/{script}.ts  # 실제 실행
```

## 8. 체크리스트

- [ ] 타입 정의 완료
- [ ] dry-run 모드 지원
- [ ] limit 옵션 지원
- [ ] --no-slack 옵션 지원
- [ ] Slack 진행 알림 (BatchProgress 사용)
- [ ] 진행 상황 로깅 (대량 데이터 처리 시)
- [ ] 에러 핸들링 (progress.fail() 포함)
- [ ] 통계 요약 출력
- [ ] CSV/JSON 파일 저장
- [ ] 코드 주석 (사용법 포함)
