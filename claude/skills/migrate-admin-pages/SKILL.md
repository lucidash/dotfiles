# Admin V1 → V2 대량 마이그레이션 스킬

likey-admin (v1)의 페이지들을 likey-admin-v2로 병렬 마이그레이션합니다.
마이그레이션 완료 후 양쪽 repo에 PR을 생성하고 서로 링크합니다.

## 트리거 키워드

- "admin 마이그레이션 진행해줘"
- "v1 페이지 마이그레이션"
- "대량 마이그레이션"
- "마이그레이션 배치"
- "migrate-admin-pages"

## 필수 환경

- likey-admin repo: `~/projects/likey-admin`
- likey-admin-v2 repo: `~/projects/likey-admin-v2`
- likey-backend repo: `~/projects/likey-backend` (API 참조용)

## 전체 워크플로우 개요

```
[Phase 1] 대상 탐색 → [Phase 2] 대상 선택 → [Phase 3] 병렬 마이그레이션
                                                    ↓
                                           각 subagent가:
                                           1. V2 페이지 구현
                                           2. V2 PR 생성
                                           3. V1 페이지 삭제
                                           4. V1 PR 생성
                                           5. 양쪽 PR 링크
```

---

## Phase 1: 마이그레이션 대상 탐색

```bash
# 1.1 likey-admin의 모든 페이지 파일 목록
find ~/projects/likey-admin/pages -name "*.vue" -type f | grep -v "_" | grep -vi "dashboard" | grep -v "/general/" | grep -v "/forms/" | grep -v "/widgets/" | grep -v "/pickers/" | sort

# 1.2 likey-admin-v2의 모든 페이지 파일 목록
find ~/projects/likey-admin-v2/app/pages -name "*.vue" -type f | sort

# 1.3 열린 PR 목록 확인 (양쪽 repo)
command gh pr list --repo tpcint/likey-admin-v2 --state open --json title,headRefName --limit 100
command gh pr list --repo tpcint/likey-admin --state open --json title,headRefName --limit 100
```

---

## Phase 2: 대상 선택 (복잡도 순 정렬)

```bash
for page in $MIGRATION_TARGETS; do
  file="~/projects/likey-admin/pages${page}.vue"
  lines=$(wc -l < "$file")
  printf "%4d lines  %s\n" "$lines" "$page"
done | sort -n | head -10
```

### 선택된 마이그레이션 대상 (복잡도 낮은 순)

1. `/settings/payment-link-in-app` (97 lines)
2. `/settings/monitoring-chat-keywords` (104 lines)
3. `/settings/external-link-white-list` (105 lines)
4. `/settings/banned-words` (115 lines)
5. `/app/test-accounts` (158 lines)
6. `/settings/suspicious-deposit-whitelist` (158 lines)
7. `/celeb/sexual-celebs` (177 lines)
8. `/settings/capture-whitelist` (194 lines)
9. `/user/deleted-account` (209 lines)
10. `/celeb/celebs-hidden-on-home` (229 lines)

---

## Phase 3: 병렬 마이그레이션 실행

**각 subagent에게 전달할 프롬프트:**

```markdown
## Admin V1→V2 마이그레이션: {page_path}

### 환경
- likey-admin (V1): ~/projects/likey-admin
- likey-admin-v2 (V2): ~/projects/likey-admin-v2
- likey-backend: ~/projects/likey-backend (API 참조용)

### 원본 파일
~/projects/likey-admin/pages{page_path}.vue

### 참조 파일
- API 타입: ~/projects/likey-admin-v2/app/models/spec/admin-api.ts
- 개발 가이드: ~/projects/likey-admin-v2/CLAUDE.md

---

## 작업 단계

### Step 1: V1 코드 분석
1. 원본 파일 읽기
2. API 엔드포인트 파악
3. 주요 기능 및 상태 관리 파악

### Step 2: API 타입 확인
1. admin-api.ts에서 관련 API operation 검색
2. 필요한 타입 추출
3. 타입이 없으면 likey-backend 코드 참조

### Step 3: V2 페이지 구현
1. ~/projects/likey-admin-v2로 이동
2. CLAUDE.md 개발 가이드 준수
3. Composition API + TypeScript 사용
4. OpenAPI 타입 활용 (하드코딩 금지)
5. 조회/필터는 URL 쿼리스트링 동기화

### Step 4: V2 검증 및 커밋
```bash
cd ~/projects/likey-admin-v2
git checkout main && git pull
git checkout -b feature/migrate-{page_name}
# 페이지 파일 생성...
npm run lint -- --fix app/pages{page_path}.vue
npm run build
git add app/pages{page_path}.vue
git commit -m "feat: {page_name} 페이지 마이그레이션

admin v1의 {page_path} 페이지를 admin v2로 마이그레이션

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
git push -u origin feature/migrate-{page_name}
```

### Step 5: V2 PR 생성
```bash
V2_PR_URL=$(command gh pr create \
  --repo tpcint/likey-admin-v2 \
  --title "feat: {page_name} 페이지 마이그레이션" \
  --body "$(cat <<'EOF'
## Summary
- admin v1의 `{page_path}` 페이지를 admin v2로 마이그레이션
- [기능 요약]

## Related
- V1 삭제 PR: (아래에서 링크 추가 예정)

## Test plan
- [ ] 페이지 로드 확인
- [ ] 주요 기능 동작 확인

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)")
echo "V2 PR: $V2_PR_URL"
```

### Step 6: V1 페이지 삭제 및 커밋
```bash
cd ~/projects/likey-admin
git checkout master && git pull
git checkout -b chore/remove-migrated-{page_name}
rm pages{page_path}.vue
git add -A
git commit -m "chore: {page_name} 페이지 삭제 (v2 마이그레이션 완료)

admin v2로 마이그레이션 완료: {V2_PR_URL}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
git push -u origin chore/remove-migrated-{page_name}
```

### Step 7: V1 PR 생성 (V2 PR 링크 포함)
```bash
V1_PR_URL=$(command gh pr create \
  --repo tpcint/likey-admin \
  --title "chore: {page_name} 페이지 삭제 (v2 마이그레이션)" \
  --body "$(cat <<EOF
## Summary
- admin v2로 마이그레이션 완료된 \`{page_path}\` 페이지 삭제

## Related
- **V2 마이그레이션 PR**: $V2_PR_URL

## Test plan
- [ ] v2에서 해당 페이지 정상 동작 확인 후 머지

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)")
echo "V1 PR: $V1_PR_URL"
```

### Step 8: V2 PR 본문에 V1 PR 링크 추가
```bash
command gh pr edit "$V2_PR_URL" --body "$(command gh pr view "$V2_PR_URL" --json body -q .body | sed "s|(아래에서 링크 추가 예정)|$V1_PR_URL|")"
```

---

## 완료 조건
- [ ] V2 페이지 파일 생성 및 빌드/린트 통과
- [ ] V2 PR 생성 완료
- [ ] V1 페이지 삭제 및 커밋
- [ ] V1 PR 생성 완료
- [ ] 양쪽 PR 본문에 서로 링크

---

## 중요 규칙
- Chrome DevTools MCP 사용 금지 (코드 기반 분석만)
- API 타입이 없으면 백엔드 코드 참조
- 기존 V2 페이지 패턴 따르기
- 브랜치명 규칙:
  - V2: `feature/migrate-{page_name}`
  - V1: `chore/remove-migrated-{page_name}`
```

---

## Phase 4: 결과 수집

각 subagent 완료 후 결과 요약:

```markdown
## 마이그레이션 결과

### 성공
| 페이지 | V2 PR | V1 PR |
|--------|-------|-------|
| /settings/payment-link-in-app | #1234 | #567 |
| ... | ... | ... |

### 실패
| 페이지 | 사유 |
|--------|------|
| /xxx | 빌드 실패 - API 타입 누락 |
```

---

## 실행 예시

```
사용자: admin 마이그레이션 진행해줘

Claude:
## Phase 1: 마이그레이션 대상 탐색
- V1 페이지: 85개
- V2 페이지: 45개
- 마이그레이션 필요: 76개

## Phase 2: 복잡도 순 상위 10개 선택
[목록 표시]

## Phase 3: 병렬 마이그레이션 시작 (5개씩)

[Batch 1: 5개 병렬 실행]
- /settings/payment-link-in-app ✅ V2 PR: #1234, V1 PR: #567
- /settings/monitoring-chat-keywords ✅ V2 PR: #1235, V1 PR: #568
...

[Batch 2: 5개 병렬 실행]
...

## 결과 요약
- 성공: 10/10
- 생성된 PR: 20개 (V2: 10, V1: 10)
```

---

## 주의사항

1. **병렬 실행 제한**: 최대 5개 동시 실행
2. **PR 머지 순서**: V2 PR 먼저 머지 → V1 PR 머지
3. **실패 시 롤백**: V2 PR 실패 시 V1 삭제 PR 생성하지 않음
4. **브랜치 충돌**: 동일 페이지 작업 중인 PR이 있으면 스킵
