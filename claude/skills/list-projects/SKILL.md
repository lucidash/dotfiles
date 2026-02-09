---
name: list-projects
description: Notion 개발과제/작업 DB를 조회하고 관리합니다. "개발과제 조회", "인입 후보 리스트", "작업 배정", "노션 과제" 같은 요청에 자동으로 활성화됩니다.
argument-hint: "[조회조건] [--assign=사용자] [--status=상태]"
allowed-tools: mcp__tpc-notion__API-post-search, mcp__tpc-notion__API-query-data-source, mcp__tpc-notion__API-retrieve-a-data-source, mcp__tpc-notion__API-get-users, mcp__tpc-notion__API-patch-page
---

# Notion 개발과제/작업 관리

Notion 개발과제 DB와 개발 작업 DB를 조회하고 관리합니다.

**Arguments:** `$ARGUMENTS`

---

## 핵심 DB 정보 (외우기)

| DB | ID | 용도 |
|----|-----|------|
| 개발 과제 DB | `e2591524-aa7d-454e-86eb-b925b110aeca` | 프로젝트/과제 관리 |
| 개발 작업 DB | `af0b1e4c-6a3f-4d94-81c6-396f86e61574` | 파트별 작업 관리 |

---

## 개발 과제 DB 주요 프로퍼티

| 프로퍼티 | 타입 | 값 예시 |
|----------|------|---------|
| `프로젝트 이름` | title | 과제 제목 |
| `작업 상태` | status | 과제 인입 후보, 기획 대기 중, 개발 중, 배포 완료 등 |
| `우선순위` | select | 최상, 상, 중, 하 |
| `카테고리` | select | 일반과제, QA과제, 개발과제 등 |
| `컴포넌트` | multi_select | 포스트, 결제, 라이브, DM 등 |
| `PM` | people | 담당 PM |
| `작업` | relation | 개발 작업 DB와 연결 |
| `ID` | unique_id | TPC-1234 형식 |

### 작업 상태 옵션 (status)

```
아이디어 → 연기 → 과제 인입 후보 → 기획 대기 중 → 기획 중 → 
개발 대기 중 → 개발 중 → 배포 대기 중 → 배포 완료 / 취소
```

---

## 개발 작업 DB 주요 프로퍼티

| 프로퍼티 | 타입 | 값 예시 |
|----------|------|---------|
| `작업 이름` | title | 작업 제목 |
| `상태` | status | 인입됨, 작업 중, 작업 완료, QA 필요 등 |
| `파트` | select | Server, iOS, Android, Web, Admin, 디자인 |
| `작업자` | people | 담당 개발자 |
| `과제` | relation | 개발 과제 DB와 연결 |
| `ID` | unique_id | LK-10234 형식 |
| `QA` | people | QA 담당자 |

### 작업 상태 옵션 (status)

```
인입됨 → 재인입 → 파악중 → 작업 대기중 → 작업 할당됨 → 작업 중 → 
작업 리뷰중 → 작업 완료 → QA 필요 → QA 진행중 → QA 완료 → 
베타 배포 → 배포 완료 / 작업 불필요 / 연기됨
```

### 파트 옵션 (select)

```
Server, iOS, Android, Web, Admin, 디자인
```

---

## 자주 사용하는 쿼리

### 1. 인입 후보 과제 조회

```typescript
mcp__tpc-notion__API-query-data-source({
  data_source_id: "e2591524-aa7d-454e-86eb-b925b110aeca",
  filter: {
    property: "작업 상태",  // "상태" 아님!
    status: { equals: "과제 인입 후보" }
  },
  page_size: 50
})
```

### 2. 특정 과제의 Server 작업 조회

```typescript
mcp__tpc-notion__API-query-data-source({
  data_source_id: "af0b1e4c-6a3f-4d94-81c6-396f86e61574",
  filter: {
    and: [
      { property: "과제", relation: { contains: "<과제_page_id>" } },
      { property: "파트", select: { equals: "Server" } }
    ]
  },
  page_size: 10
})
```

### 3. 특정 사용자의 진행 중 작업 조회

```typescript
mcp__tpc-notion__API-query-data-source({
  data_source_id: "af0b1e4c-6a3f-4d94-81c6-396f86e61574",
  filter: {
    and: [
      { property: "작업자", people: { contains: "<user_id>" } },
      { property: "상태", status: { equals: "작업 중" } }
    ]
  }
})
```

### 4. 개발 중인 과제 조회

```typescript
mcp__tpc-notion__API-query-data-source({
  data_source_id: "e2591524-aa7d-454e-86eb-b925b110aeca",
  filter: {
    property: "작업 상태",
    status: { equals: "개발 중" }
  },
  sorts: [{ property: "우선순위", direction: "ascending" }]
})
```

---

## 사용자 ID 조회

```typescript
// 전체 사용자 목록
mcp__tpc-notion__API-get-users({ page_size: 100 })
```

### 주요 사용자 ID (Backend 팀)

| 이름 | Notion ID |
|------|-----------|
| Kyle | `17ad872b-594c-8121-a786-0002554a5616` |
| MUZI | `0b245cd5-2c61-423b-a74f-3a45435a8fea` |
| Carrot | `18fd872b-594c-81ab-8426-000241feca9b` |

---

## 작업 업데이트

### 작업자 배정

```typescript
mcp__tpc-notion__API-patch-page({
  page_id: "<작업_page_id>",
  properties: {
    "작업자": {
      people: [{ id: "<user_id>" }]
    }
  }
})
```

### 상태 변경

```typescript
mcp__tpc-notion__API-patch-page({
  page_id: "<작업_page_id>",
  properties: {
    "상태": {
      status: { name: "작업 중" }
    }
  }
})
```

---

## 실행 순서 예시: 과제 조회 → 작업 배정

### Step 1: 인입 후보 과제 조회
```typescript
const projects = await mcp__tpc-notion__API-query-data-source({
  data_source_id: "e2591524-aa7d-454e-86eb-b925b110aeca",
  filter: { property: "작업 상태", status: { equals: "과제 인입 후보" } }
});
```

### Step 2: 특정 과제의 Server 작업 찾기
```typescript
const tasks = await mcp__tpc-notion__API-query-data-source({
  data_source_id: "af0b1e4c-6a3f-4d94-81c6-396f86e61574",
  filter: {
    and: [
      { property: "과제", relation: { contains: projects[0].id } },
      { property: "파트", select: { equals: "Server" } }
    ]
  }
});
```

### Step 3: 사용자 ID 조회 (필요시)
```typescript
const users = await mcp__tpc-notion__API-get-users({ page_size: 100 });
const kyle = users.find(u => u.name === "Kyle");
```

### Step 4: 작업자 배정
```typescript
await mcp__tpc-notion__API-patch-page({
  page_id: tasks[0].id,
  properties: {
    "작업자": { people: [{ id: kyle.id }] }
  }
});
```

---

## 주의사항

### 프로퍼티명 정확히!

| 잘못된 예 | 올바른 예 |
|-----------|-----------|
| `상태` | `작업 상태` (과제 DB) |
| `상태` | `상태` (작업 DB는 맞음) |
| `담당자` | `작업자` |
| `제목` | `프로젝트 이름` 또는 `작업 이름` |

### 필터 문법

```typescript
// status 타입
{ property: "작업 상태", status: { equals: "개발 중" } }

// select 타입  
{ property: "파트", select: { equals: "Server" } }

// people 타입
{ property: "작업자", people: { contains: "<user_id>" } }

// relation 타입
{ property: "과제", relation: { contains: "<page_id>" } }

// AND 조건
{ and: [ {조건1}, {조건2} ] }

// OR 조건
{ or: [ {조건1}, {조건2} ] }
```

---

## 에러 처리

| 에러 | 원인 | 해결 |
|------|------|------|
| `Could not find property with name` | 프로퍼티명 오타 | 위 프로퍼티 목록 참조 |
| `validation_error` | 필터 문법 오류 | status/select/people 타입 확인 |
| 빈 결과 | 조건에 맞는 데이터 없음 | 필터 조건 완화 |

---

## Quick 모드

`--quick` 또는 `-q` 옵션으로 간단한 리스트 출력. 번호로 빠르게 참조 가능.

### 출력 형식

```
## 개발 중인 과제 (23건)

#1  [최상] [admin] 유저 배송 정보 수집 기능
#2  [최상] 판매된 디지털 컨텐츠 상품 콘텐츠 수정/삭제 제한
#3  [상]   룰렛 결과 전달 채널 변경 (DM → 구매 항목)
#4  [상]   쿠폰함 기능 추가
...
```

### Quick Reference 사용

리스트 출력 후 번호로 참조:
- `#3 상세` → 3번 과제 상세 정보
- `#3 서버작업` → 3번 과제의 Server 작업 조회
- `#3 배정 kyle` → 3번 과제 Server 작업을 Kyle에게 배정

### 구현

```typescript
// 결과에 번호 매기기
const numbered = results.map((r, i) => ({
  num: i + 1,
  id: r.id,
  title: r.properties["프로젝트 이름"].title[0]?.plain_text,
  priority: r.properties["우선순위"]?.select?.name || "-",
  status: r.properties["작업 상태"]?.status?.name,
  components: r.properties["컴포넌트"]?.multi_select?.map(c => c.name).join(", ")
}));

// 세션 컨텍스트에 저장 (번호 → ID 매핑)
const projectMap = Object.fromEntries(numbered.map(p => [`#${p.num}`, p.id]));
```

### Quick 모드 출력 예시

```bash
/list-projects 진행중 -q
```

```
## 개발 중 (23건)

#1  [최상] [admin] 유저 배송 정보 수집 기능 | 어드민
#2  [최상] 판매된 디지털 컨텐츠 수정/삭제 제한 | 스토어
#3  [최상] 결제 체크아웃 환불 불가 문구 변경
#4  [상]   어드민에서 팬의 구독 시작일 만료일 조정 | 어드민
#5  [상]   룰렛 결과 전달 채널 변경 | 룰렛
#6  [상]   AI 채팅 모니터링 v1 | 모니터링
#7  [상]   쿠폰함 기능 추가 | 쿠폰
#8  [상]   Ably 채팅 메시지 전송 방식 변경 | 개발과제
#9  [상]   보안 취약 API 변경 | 보안
#10 [중]   탈퇴한 크리에이터 포스트 알림 정책 변경 | 포스트
...

> #번호로 참조 가능 (예: "#3 상세", "#5 서버작업 배정 kyle")
```
