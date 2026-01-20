# 데이터 추출 배치 스크립트 생성

데이터 추출/분석을 위한 배치 스크립트를 작성합니다.

## 입력
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

## 2. 관련 코드 분석

### 데이터 소스 확인
```bash
# Entity 모델 확인
rg "gstore.model" /Users/muzi/projects/likey-backend/src/likey -l

# BigQuery 테이블 확인
rg "getBqTableName" /Users/muzi/projects/likey-backend/src --type ts
```

### 기존 배치 스크립트 참조
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
 *   npm run batch src/batch/{category}/{script-name}.ts -- [--dry-run] [--limit=N]
 *
 * 옵션:
 *   --dry-run: 파일 저장 없이 콘솔에만 출력
 *   --limit=N: 처리할 최대 건수
 *
 * 출력:
 *   - CSV: output/{prefix}_{timestamp}.csv
 *   - JSON: output/{prefix}_{timestamp}.json
 */

import {runBatch} from '@/lib/batch.js';
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
};

function parseArgs(args: string[]): ParsedArgs {
  const dryRun = args.includes('--dry-run');
  const limitArg = args.find(arg => arg.startsWith('--limit='));
  const limit = limitArg ? parseInt(limitArg.split('=')[1], 10) : undefined;
  return {dryRun, limit: limit && limit > 0 ? limit : undefined};
}

async function main(options: ParsedArgs) {
  const {dryRun, limit} = options;

  console.log('=== 스크립트 시작 ===');
  if (dryRun) console.log('[DRY-RUN 모드]');
  if (limit) console.log(`[LIMIT] 최대 ${limit}건 처리`);

  // 1단계: 데이터 조회
  // 2단계: 데이터 처리/변환
  // 3단계: 추가 정보 조회 (필요시)
  // 4단계: 통계 출력
  // 5단계: 파일 저장 (dry-run이 아닌 경우)

  return {/* 결과 요약 */};
}

runBatch(async () => {
  const options = parseArgs(process.argv.slice(2));
  const result = await main(options);
  console.log('\n=== 최종 결과 ===');
  console.log(JSON.stringify(result, null, 2));
  console.log('\ndone');
});
```

## 4. 데이터 소스별 패턴

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

### 사용자 정보 배치 조회
```typescript
import {getUsers} from '@likey/user/index.js';

const userMap = await getUsers(userUids); // 내부적으로 캐시 + 1000개씩 청크 처리
```

## 5. 출력 패턴

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

## 6. 실행 및 테스트

### 개발 환경 (beta)
```bash
npm run batch src/batch/{category}/{script}.ts -- --dry-run --limit=10
```

### 운영 환경 (real)
```bash
npm run batch-real src/batch/{category}/{script}.ts -- --dry-run --limit=10
npm run batch-real src/batch/{category}/{script}.ts  # 실제 실행
```

## 7. 체크리스트

- [ ] 타입 정의 완료
- [ ] dry-run 모드 지원
- [ ] limit 옵션 지원
- [ ] 진행 상황 로깅 (대량 데이터 처리 시)
- [ ] 에러 핸들링
- [ ] 통계 요약 출력
- [ ] CSV/JSON 파일 저장
- [ ] 코드 주석 (사용법 포함)
