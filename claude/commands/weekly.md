# Backend Weekly 문서 자동 업데이트

Backend Weekly 노션 문서에 지난주/이번주 작업 내역을 자동으로 업데이트합니다.
Git log와 GitHub PR 정보를 기반으로 작업 내역을 수집하고, 노션 DB와 연결합니다.

## 대상 Repository

| Repository | 경로 | GitHub |
|------------|------|--------|
| likey-backend | `/Users/muzi/projects/likey-backend` | TPC-Internet/likey-backend |
| likey-web | `/Users/muzi/projects/likey-web` | TPC-Internet/likey-web |
| likey-admin | `/Users/muzi/projects/likey-admin` | TPC-Internet/likey-admin |
| likey-admin-v2 | `/Users/muzi/projects/likey-admin-v2` | TPC-Internet/likey-admin-v2 |

## 노션 DB 정보

| DB 이름 | ID | 용도 |
|---------|-----|------|
| 개발 과제 DB | `7e65336e-8ea1-4a85-a034-5afe0a6ccb81` | 기능/프로젝트 단위 과제 |
| 개발 작업 DB | `cdebd8ad-0608-4688-ba55-fee0f33c50e3` | PR 단위 작업 |

## 실행 순서

### 1. Weekly 문서 확인

노션에서 Backend Weekly 문서를 검색하거나, 가장 최근 Weekly 문서를 찾습니다:
- 노션 검색: "Backend Weekly"
- PRODUCT팀 Weekly 문서 DB에서 파트가 "Backend"인 가장 최근 문서

### 2. 날짜 범위 계산

오늘 날짜 기준으로:
- **지난주**: 지난 월요일 ~ 지난 일요일
- **이번주**: 이번 월요일 ~ 오늘

### 3. Git Log 수집

각 repository에서 내 커밋을 수집합니다:

```bash
# 지난주 커밋
git log --author="muzi" --since="{지난주 월요일}" --until="{지난주 일요일}" --oneline --no-merges

# 이번주 커밋
git log --author="muzi" --since="{이번주 월요일}" --oneline --no-merges
```

### 4. GitHub PR 정보 수집

```bash
# Merged PR (지난주/이번주)
command gh pr list --author="@me" --state=merged --json number,title,body,mergedAt --limit 50

# Open PR (이번주 업데이트된 것)
command gh pr list --author="@me" --state=open --json number,title,updatedAt
```

### 5. 노션 문서 검색 (우선순위)

각 PR/커밋에 대해 다음 우선순위로 노션 문서를 검색합니다:

#### 우선순위 1: 개발 과제 DB 검색
- 커밋 메시지나 PR 제목에서 LK-XXXXX 티켓 번호 추출
- 노션에서 해당 과제 검색: "LK-{티켓번호}" 또는 기능명 키워드
- **개발 과제 문서가 있으면**: `<mention-page>` 로 멘션

#### 우선순위 2: 개발 작업 DB 검색
- 개발 과제가 없는 경우, 개발 작업 DB에서 검색
- PR 제목이나 커밋 메시지로 검색
- **개발 작업 문서가 있으면**: `<mention-page>` 로 멘션

#### 우선순위 3: PR 링크 직접 사용
- 개발 과제/작업 문서가 모두 없는 경우에만
- **GitHub PR 링크를 plain text로 직접 작성**: `[#번호](URL)`

### 6. 작업 목록 구성

**API 구분 태그** (likey-backend만 해당):
- `[admin-api]`: src/admin-api/ 경로의 변경사항 (어드민 API)
- `[api]`: src/api/ 경로의 변경사항 (서비스 API)

**레포지토리 구분 태그**:
- `[likey-web]`: likey-web 레포지토리 작업
- `[likey-admin]`: likey-admin 레포지토리 작업
- `[likey-admin-v2]`: likey-admin-v2 레포지토리 작업

PR의 변경 파일을 확인하여 API 태그 결정:
```bash
command gh pr view {PR번호} --json files --jq '.files[].path' | grep -E '^src/(admin-api|api)/'
```

**작업 멘션 형식 예시**:
```
- <mention-user url="user://0b245cd5-2c61-423b-a74f-3a45435a8fea"/>
    # 개발 과제 문서가 있는 경우
    - <mention-page url="https://www.notion.so/{개발과제ID}"/> - 배포

    # 개발 작업 문서가 있는 경우 (과제 없음)
    - <mention-page url="https://www.notion.so/{개발작업ID}"/> - 배포

    # 둘 다 없는 경우에만 PR 링크 직접 사용
    - [admin-api] {작업설명} ([#{PR번호}](https://github.com/TPC-Internet/likey-backend/pull/{번호}))
    - [likey-web] {작업설명} ([#{PR번호}](https://github.com/TPC-Internet/likey-web/pull/{번호}))
```

### 7. 노션 문서 업데이트

`notion-update-page` 도구를 사용하여 Weekly 문서의 MUZI 섹션을 업데이트합니다:
- `replace_content_range` 명령으로 MUZI 섹션만 교체
- 다른 팀원의 섹션은 유지

### 8. 결과 보고

- 업데이트된 노션 문서 URL
- 지난주 작업 요약 (노션 문서 연결 + GitHub PR)
- 이번주 작업 요약 (배포 완료 + 작업중)

## 참고 정보

- MUZI 노션 User ID: `0b245cd5-2c61-423b-a74f-3a45435a8fea`
- Git Author: `muzi` (email: lucidash@gmail.com)
- GitHub Username: `lucidash`

## 주의사항

- 노션 mention 작성 시 URL에 `{{...}}` 사용하지 않음 (자동 추가됨)
- 다른 팀원의 작업 내역은 수정하지 않음
- 노션 문서 멘션 우선순위: 개발과제 > 개발작업 > PR 링크
- GitHub PR 링크는 마크다운 형식으로 작성: `[#번호](URL)`
