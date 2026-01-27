# 배치 스크립트 실행

배치 스크립트를 실행합니다.

## 입력
- `$ARGUMENTS`: 스크립트 경로 또는 키워드 (예: "migrate-orphan-pinned-posts", "src/batch/post/...")

---

## 1. 스크립트 파일 확인

### 경로가 명확한 경우
```bash
# 파일 존재 확인 후 읽기
cat src/batch/{path}.ts
```

### 키워드만 있는 경우
```bash
# src/batch/ 에서 검색
find src/batch -name "*{keyword}*" -type f
```

파일을 찾으면 상단 주석에서 **사용법과 옵션**을 파악합니다.

---

## 2. 사용법 안내

파일 상단 주석을 기반으로 사용자에게 안내:

| 항목 | 내용 |
|------|------|
| 스크립트 설명 | {주석에서 추출} |
| 지원 옵션 | --dry-run, --limit=N, --no-slack 등 |
| 출력 | CSV/JSON 경로 (있는 경우) |

---

## 3. 환경 선택

사용자에게 실행 환경을 확인합니다:

| 환경 | 명령어 | 특징 |
|------|--------|------|
| **beta** (권장) | `npm run batch` | 프록시 자동 연결, 스테이징 데이터 |
| **real** | `npm run batch-real` | 프로덕션 데이터, **별도 프록시 필요** |

### real 환경 전제조건
- Cloud SQL Proxy 실행 중
- Redis 연결 가능 (VPN 또는 SSH 터널)

---

## 4. 실행 전략

### 기본 전략: dry-run 먼저
```bash
# 1단계: dry-run으로 대상 확인
npm run batch {script-path} -- --dry-run --limit=100

# 2단계: 결과 확인 후 실제 실행
npm run batch {script-path}
```

### 옵션 조합 예시
```bash
# beta + dry-run + 제한
npm run batch src/batch/{path}.ts -- --dry-run --limit=100

# real + dry-run (프록시 필요)
npm run batch-real src/batch/{path}.ts -- --dry-run --limit=100

# 실제 실행 (Slack 알림 포함)
npm run batch-real src/batch/{path}.ts
```

---

## 5. 실행 및 모니터링

### 실행
```bash
npm run batch {script-path} -- {options}
```

### 프록시 대기 문제 발생 시
`[PROXY] waiting for redis & mysql` 메시지에서 멈추면:

1. **real 환경인 경우**: 프록시가 실행되지 않은 상태
   - 별도 터미널에서 프록시 실행 필요
   - 또는 beta 환경으로 전환 제안

2. **beta 환경인 경우**: 네트워크 문제 가능성
   - 잠시 대기 후 재시도

### 타임아웃
- 기본 타임아웃: 10분 (600000ms)
- 대용량 배치는 더 긴 타임아웃 필요할 수 있음

---

## 6. 결과 확인

### 콘솔 출력 확인 항목
- 처리 건수
- 에러 발생 여부
- 실행 시간

### 파일 출력 (있는 경우)
```bash
ls -la output/
```

---

## 체크리스트

- [ ] 스크립트 파일 확인 및 사용법 파악
- [ ] 환경 선택 (beta/real)
- [ ] dry-run 먼저 실행 권장
- [ ] 프록시 문제 시 대응 안내
- [ ] 결과 요약 제공
