# Backend PR 코드 리뷰

PR을 분석하고 코드 리뷰를 수행합니다.
- 전체 요약 코멘트 + 각 파일/라인별 인라인 코멘트를 함께 작성합니다.

## 인자
- `$ARGUMENTS`: 다음 중 하나
  - PR 번호 (예: `6381`)
  - GitHub PR URL (예: `https://github.com/TPC-Internet/likey-backend/pull/6381`)
  - 생략 시 현재 브랜치의 PR

---

## 실행 순서

### 0. 인자 파싱

`$ARGUMENTS`에서 PR 번호 추출:

```
- URL인 경우: https://github.com/.../pull/6381 → 6381
- 숫자인 경우: 그대로 사용
- 비어있는 경우: 현재 브랜치의 PR 사용
```

### 1. PR 정보 조회

```bash
# PR 번호/URL이 주어진 경우 (gh는 URL도 직접 처리 가능)
command gh pr view {PR번호 또는 URL} --json number,title,body,files,additions,deletions,author,headRefName,baseRefName,headRefOid

# 인자가 없으면 현재 브랜치의 PR 조회
command gh pr view --json number,title,body,files,additions,deletions,author,headRefName,baseRefName,headRefOid
```

확인할 정보:
| 항목 | 내용 |
|------|------|
| author | PR 작성자 (리뷰 코멘트에 멘션할 대상) |
| title | PR 제목 |
| body | PR 설명 |
| files | 변경된 파일 목록 |
| additions/deletions | 변경 규모 |
| headRefOid | HEAD commit SHA (인라인 코멘트에 필요) |

### 2. 변경 내용 확인

```bash
command gh pr diff {PR번호}
```

diff를 분석하여 다음을 파악:
- 어떤 기능이 추가/수정되었는지
- 변경된 파일들의 역할
- 코드 변경의 의도

### 3. 관련 코드 탐색

변경된 코드를 이해하기 위해 필요시 추가 탐색:

- **기존 코드 확인**: 변경된 파일의 전체 컨텍스트 파악
- **관련 함수 검색**: 사용된 함수나 클래스의 정의 확인
- **유사 패턴 검색**: 코드베이스 내 유사한 구현 참고

```bash
# 관련 함수 검색 예시
grep -r "함수명" src/
```

### 4. 코드 리뷰 수행

다음 관점에서 코드 검토:

#### 필수 체크리스트
- [ ] **성능**: N+1 쿼리, 불필요한 루프, 메모리 누수
- [ ] **보안**: 인젝션, 권한 체크, 민감 정보 노출
- [ ] **에러 처리**: 예외 처리, 에러 메시지 (name 메타데이터 포함 여부)
- [ ] **코드 컨벤션**: CLAUDE.md 규칙 준수 여부
- [ ] **테스트**: 테스트 코드 유무, 커버리지

#### 프로젝트 특화 체크리스트
- [ ] **Datastore**: 인덱싱, 트랜잭션, excludeFromIndexes
- [ ] **Redis 캐싱**: Cache-Aside 패턴, 캐시 무효화
- [ ] **i18n**: 사용자 노출 문자열 번역 처리
- [ ] **tsoa**: 데코레이터 (@Tags, @Security) 확인

### 5. 인라인 코멘트용 라인 번호 계산

피드백이 필요한 각 코드에 대해 **정확한 라인 번호**를 계산해야 합니다.

#### 라인 번호 계산 방법

1. **diff에서 해당 파일의 hunk 헤더 확인**:
   ```bash
   command gh pr diff {PR번호} | sed -n '/^+++ b\/{파일경로}/,/^diff --git/p' | grep "^@@"
   ```
   예: `@@ -150,18 +153,24 @@` → 새 파일에서 153번 라인부터 시작

2. **hunk 내에서 해당 코드의 위치 계산**:
   ```bash
   command gh pr diff {PR번호} | sed -n '/^+++ b\/{파일경로}/,/^diff --git/p' | sed -n '/@@ {hunk헤더}/,/^@@/p' | grep "^[+ -]" | nl
   ```
   - 공백으로 시작하는 줄: 기존 코드 (라인 번호 증가)
   - `+`로 시작하는 줄: 새로 추가된 코드 (라인 번호 증가)
   - `-`로 시작하는 줄: 삭제된 코드 (라인 번호 증가 안 함)

3. **실제 라인 번호 계산**:
   - hunk 시작 라인 + (해당 줄까지의 공백/+ 줄 수 - 1)

#### 새로 생성된 파일의 경우
```bash
# 전체 파일에서 + 라인만 세기
command gh pr diff {PR번호} | sed -n '/^+++ b\/{파일경로}/,/^diff --git/p' | grep "^+" | grep -v "^+++" | nl | grep "{검색어}"
```
결과의 번호가 곧 실제 라인 번호입니다.

### 6. 리뷰 코멘트 작성 (인라인 + 요약)

**GitHub API를 사용하여 전체 요약과 인라인 코멘트를 한 번에 작성합니다.**

```bash
command gh api repos/{owner}/{repo}/pulls/{PR번호}/reviews \
  -X POST \
  --input - << 'EOF'
{
  "commit_id": "{headRefOid}",
  "event": "COMMENT",
  "body": "## 코드 리뷰 요약\n\n@{author} 리뷰 확인 부탁드립니다!\n\n### 전체 요약\n{전체 요약 내용}\n\n### 리뷰 요약\n| 심각도 | 개수 | 내용 |\n|--------|------|------|\n| 🔴 Critical | 0 | - |\n| 🟠 Major | 1 | ... |\n| 🟡 Minor | 0 | - |\n| 💬 Comment | 2 | ... |",
  "comments": [
    {
      "path": "src/path/to/file.ts",
      "line": 123,
      "side": "RIGHT",
      "body": "🟠 **Major**: 이슈 제목\n\n설명...\n\n```typescript\n// 현재 코드\n...\n\n// 개선 제안\n...\n```"
    },
    {
      "path": "src/another/file.ts",
      "line": 456,
      "side": "RIGHT",
      "body": "🟡 **Minor**: 이슈 제목\n\n설명..."
    }
  ]
}
EOF
```

#### 인라인 코멘트 필드 설명
| 필드 | 설명 |
|------|------|
| `path` | 파일 경로 (repo root 기준) |
| `line` | 새 파일 기준 라인 번호 |
| `side` | `"RIGHT"` (새 코드) 또는 `"LEFT"` (삭제된 코드) |
| `body` | 코멘트 내용 (마크다운 지원) |

#### 심각도 레벨
| 레벨 | 설명 |
|------|------|
| 🔴 Critical | 반드시 수정 필요 (버그, 보안 이슈) |
| 🟠 Major | 수정 권장 (성능, 유지보수성) |
| 🟡 Minor | 개선 제안 (코드 스타일, 가독성) |
| 💬 Comment | 질문 또는 의견 |

---

## 출력 형식

```markdown
## PR #{번호} 코드 리뷰 완료

**제목**: {PR 제목}
**작성자**: @{author}
**변경**: +{additions} -{deletions} ({files}개 파일)

### 작성된 인라인 코멘트
| 파일 | 라인 | 심각도 | 내용 |
|------|------|--------|------|
| `src/path/to/file.ts` | 123 | 🟠 Major | 이슈 요약 |
| `src/another/file.ts` | 456 | 🟡 Minor | 이슈 요약 |

### 리뷰 요약
| 심각도 | 개수 | 내용 |
|--------|------|------|
| 🔴 Critical | 0 | - |
| 🟠 Major | 1 | ... |
| 🟡 Minor | 1 | ... |
| 💬 Comment | 0 | - |

### 리뷰 링크
{리뷰 HTML URL}
```

---

## 트러블슈팅

### "Line could not be resolved" 에러
- 라인 번호가 diff 범위 내에 있어야 합니다
- hunk 헤더의 시작 라인 번호를 기준으로 계산했는지 확인하세요
- 새로 추가된 파일은 `side: "RIGHT"`를 사용하세요

### 인라인 코멘트가 안 보이는 경우
- `commit_id`가 정확한지 확인 (PR의 HEAD commit SHA)
- `path`가 정확한 파일 경로인지 확인 (앞에 `/` 없이)
