# 사전 정의 문서 작성 가이드

> 업무 누락 방지 | 일정 지연 방지 | 원활한 인수인계

---

## 목적

프로젝트 시작 전 "무엇을, 왜, 어떻게" 만들지 정의하여:
- 개발 중 방향 상실 방지
- 요구사항 누락 최소화
- 인수인계 시 컨텍스트 전달

---

## 문서 폴더 구조 (권장)

번호 접두사로 논리적 순서 표현:

```
docs/
├── 00_index.md                    # 마스터 인덱스
├── cross_reference_strategy.md    # 상호 참조 규칙
├── DOCUMENT_MAINTENANCE_GUIDE.md  # 유지보수 가이드
│
├── 01_requirements/               # 무엇을 만들 것인가?
├── 02_architecture/               # 어떻게 설계할 것인가?
├── 03_system/                     # 어떤 기술을 사용할 것인가?
├── 04_database/                   # 데이터를 어떻게 저장할 것인가?
├── 05_api/                        # API를 어떻게 설계할 것인가?
├── 06_code/                       # 코드를 어떻게 작성할 것인가?
└── 07_backlog/                    # 언제, 무엇을 개발할 것인가?
```

**폴더별 역할**:

| 폴더 | 핵심 질문 | 주요 문서 |
|------|----------|----------|
| 01_requirements | 무엇을? | PRD, 기능 명세, 비기능 요구사항 |
| 02_architecture | 어떻게 설계? | 아키텍처 개요, ADR (결정 기록) |
| 03_system | 어떤 기술? | 기술 스택, 환경 설정 |
| 04_database | 데이터 저장? | ERD, 스키마 정의 |
| 05_api | API 설계? | API 공통 규칙, 도메인별 명세 |
| 06_code | 코드 작성? | 코딩 표준, TDD, 레이어별 가이드 |
| 07_backlog | 언제, 무엇을? | 전체 일정, Phase별 태스크 |

---

## 핵심 문서 3종

### 1. 마스터 인덱스 (00_index.md)

모든 문서의 진입점. 필수 포함 요소:

```markdown
# {프로젝트명} 문서 인덱스

**프로젝트 설명**: 한 줄 요약
**기간**: YYYY-MM-DD ~ YYYY-MM-DD

---

## 신규 팀원 온보딩 순서
1. PRD → 2. 아키텍처 → 3. 기술스택 → 4. 환경설정 → 5. 코딩규칙 → 6. 담당 도메인

## 폴더별 문서 목록
(각 폴더와 주요 문서 링크)

## 도메인별 문서 맵
(기능 개발 시 참조해야 할 문서 연결 관계)
```

### 2. 상호 참조 전략 (cross_reference_strategy.md)

문서 간 링크 규칙:

```markdown
## 링크 규칙

### 상대 경로 필수
[API 문서](../05_api/api_auth.md)        # O
[API 문서](/docs/05_api/api_auth.md)     # X (절대 경로)

### 섹션 앵커
[users 테이블](../04_database/schema.md#users-테이블)

앵커 규칙: 소문자, 공백→하이픈, 특수문자 제거

## 도메인별 참조 관계
(PRD → API → DB → Code 흐름을 Mermaid로 표현)
```

### 3. 문서 유지보수 가이드 (DOCUMENT_MAINTENANCE_GUIDE.md)

일관성 유지 프로세스:

```markdown
## 핵심 규칙
1. 세부 문서 수정 시 → 인덱스 문서도 확인
2. 인덱스 수정 시 → 세부 문서와 일관성 확인
3. 파일 이동/이름 변경 시 → 모든 참조 링크 업데이트

## 케이스별 체크리스트
(세부 수정, 인덱스 수정, 문서 추가, 문서 삭제/병합)
```

---

## 문서 작성 패턴

### 패턴 1: 문서 헤더 템플릿

모든 문서는 동일한 헤더 구조:

```markdown
# 문서 제목

**목적**: 한 줄 설명
**작성일**: YYYY-MM-DD
**상위 문서**: [00_index.md](../00_index.md)

**관련 문서**:
- [문서 A](경로) - 설명
- [문서 B](경로) - 설명

---

본문
```

### 패턴 2: 인덱스-세부 문서 분리

**300줄 초과 시 분리**:

```
code_backend.md (인덱스 - 개요 + 링크)
├── code_backend_structure.md
├── code_backend_layers.md
└── code_backend_api.md
```

인덱스 문서는 네비게이터 역할, 세부 문서는 상세 내용.

### 패턴 3: 변경 이력

문서 하단에 버전 관리:

```markdown
---

**마지막 업데이트**: YYYY-MM-DD
**문서 버전**: X.X
**변경 이력**:
- YYYY-MM-DD vX.X: 변경 내용
```

---

## 문서 유형별 템플릿

### PRD (Product Requirements Document)

```markdown
# PRD: {기능명}

## 유치원생 설명
(현실 비유로 기능 설명)

## 비즈니스 로직

FUNCTION {function_name}(params):
    1. validate()
    2. IF condition:
           action_A()
       ELSE:
           action_B()
    3. RETURN result

**구현 힌트**:
- 라이브러리: {권장}
- 주의사항: {엣지 케이스}

## 시니어 엔지니어 설명
(기술적 상세)

## 관련 문서
- [API 명세](경로)
- [DB 스키마](경로)
```

### ADR (Architecture Decision Record)

```markdown
## ADR-{번호}: {결정 제목}

**Status**: Proposed | Accepted | Deprecated
**Date**: YYYY-MM-DD

### Context
(왜 이 결정이 필요한가?)

### Decision
(무엇을 선택했는가?)

### Alternatives
| 옵션 | 장점 | 단점 |
|------|------|------|

### Consequences
#### 유치원생 설명
(현실 비유로 장단점)

#### 시니어 엔지니어 설명
(기술적 트레이드오프)
```

### Database Schema

```markdown
## {테이블명}

**유치원생 설명**:
(테이블 역할을 현실 비유로)

**테이블 구조**:
| 컬럼 | 타입 | 설명 | 제약조건 |
|------|------|------|----------|

**인덱스**:
- `idx_name` (columns) - 용도

**구현 힌트**:
- 특이사항, 주의점
```

### API Specification

```markdown
## {METHOD} {endpoint}

**설명**: 한 줄 설명

**Request**:
```json
{ ... }
```

**Response** (200):
```json
{ ... }
```

**에러 코드**:
| 코드 | HTTP | 설명 |
|------|------|------|

**구현 힌트**:
- 인증, Rate Limit 등
```

### Backlog (Phase별)

```markdown
# Phase {N}: {목표}

**기간**: Week X-Y
**목표**: 한 줄 설명

## Week X: {주간 목표}

### Day 1-2: {태스크명}
TASK: {task_id}
- [ ] 구현 항목 1
- [ ] 구현 항목 2
- [ ] 테스트 작성

**OUTPUT**: 산출물 설명

**구현 힌트**:
- 기술적 참고사항
```

---

## 상호 참조 규칙

### 도메인별 문서 연결

기능 개발 시 참조 흐름:

```
PRD_function_{기능}.md (요구사항)
    ↓
api_{도메인}.md (API 설계)
    ↓
database_schema.md#{테이블} (데이터 구조)
    ↓
code_{레이어}.md (구현 패턴)
    ↓
architecture_decisions.md#ADR-{N} (기술 결정 이유)
```

### 핵심 허브 문서

가장 많이 참조되는 문서 (변경 시 주의):
1. **api_overview.md** - 모든 API 문서가 참조
2. **code_overview.md** - 모든 코드 작성 시 참조
3. **database_schema.md** - 대부분의 API가 참조
4. **PRD_function.md** - 모든 기능 개발 시 참조

---

## 체크리스트

### 프로젝트 시작 시
- [ ] 00_index.md 작성
- [ ] cross_reference_strategy.md 작성
- [ ] DOCUMENT_MAINTENANCE_GUIDE.md 작성
- [ ] PRD.md 작성
- [ ] architecture_overview.md 작성
- [ ] database_schema.md 작성
- [ ] backlog_overview.md 작성

### 문서 수정 시
- [ ] 세부 문서 수정 → 인덱스 확인
- [ ] 관련 문서 링크 검증
- [ ] 변경 이력 기록

---

## Anti-Patterns

| 하지 말 것 | 문제 | 해결 |
|-----------|------|------|
| 절대 경로 사용 | 이동 시 깨짐 | 상대 경로 사용 |
| 세부만 수정, 인덱스 무시 | 불일치 | 함께 업데이트 |
| 변경 이력 미기록 | 추적 불가 | 수정 시 기록 |
| 300줄 초과 | 가독성 저하 | 인덱스+세부 분리 |
| 관련 문서 링크 없음 | 컨텍스트 단절 | 헤더에 필수 포함 |
| 온보딩 순서 미정의 | 신규 인원 혼란 | 00_index.md에 명시 |
