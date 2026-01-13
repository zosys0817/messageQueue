---
name: project-init
description: 새 프로젝트 설정 시 대화형으로 요구사항을 파악하여 CLAUDE.md와 docs 구조를 생성합니다. 새 프로젝트 시작, CLAUDE.md 생성 요청 시 자동 활성화됩니다.
---

# Project Init

새 프로젝트의 기초 설정을 대화형으로 진행합니다.

**이 스킬은 프로젝트 시작 시 가장 먼저 실행합니다.**

---

## 스킬 워크플로우

```
┌─────────────────────────────────────────────────────────────────┐
│                    프로젝트 초기화 워크플로우                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  project-init → api-planning → plan-review → api-scaffold      │
│       │              │              │              │            │
│       ▼              ▼              ▼              ▼            │
│  [기초 설정]    [계획서 작성]   [전문가 리뷰]   [코드 생성]       │
│                                                                 │
│  생성물:                                                         │
│  • .claude/CLAUDE.md                                            │
│  • docs/ 폴더 구조                                               │
│  • PRD_overview.md                                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Step 0: 기존 설정 확인

**자동 실행** - 사용자 질문 없이 먼저 확인

1. `.claude/CLAUDE.md` 존재 여부 확인
2. `docs/` 폴더 존재 여부 확인

**기존 설정이 있을 경우:**
```markdown
⚠️ 기존 프로젝트 설정이 감지되었습니다.

발견된 파일:
- .claude/CLAUDE.md ✅
- docs/ 폴더 ✅

어떻게 진행할까요?
1. 덮어쓰기 (기존 설정 대체)
2. 취소 (기존 설정 유지)
```

---

## Step 1: 초기화 모드 선택

**AskUserQuestion 사용:**

```markdown
## 🚀 프로젝트 초기화

어떤 모드로 초기화할까요?

### 빠른 초기화
- `.claude/CLAUDE.md`만 생성
- 기존 프로젝트에 Claude 설정만 추가할 때

### 전체 초기화
- `.claude/CLAUDE.md` 생성
- `docs/` 폴더 구조 생성 (01~07)
- `PRD_overview.md` 생성
- 새 프로젝트를 처음부터 시작할 때
```

---

## Step 2: 프로젝트 기본 정보 수집

**AskUserQuestion 사용:**

```markdown
## 📋 프로젝트 기본 정보

### 프로젝트명
예: my-api-server, data-pipeline, infra-setup

### 한 줄 설명
예: 사용자 인증 및 주문 관리 API

### 프로젝트 유형
- API 서버
- 데이터 파이프라인
- 인프라 구축
- 풀스택
- 기타
```

---

## Step 3: 환경 정보 수집

**AskUserQuestion 사용:**

```markdown
## 🖥️ 환경 정보

### Platform
- AWS
- NCP (Naver Cloud Platform)
- On-Premise
- 기타

### Region
예: ap-northeast-2, kr-standard

### 주요 기술 스택
예: FastAPI, MySQL, Docker, Terraform

### 데이터베이스
예: MySQL 8.0, PostgreSQL 15, MongoDB 6.0
```

---

## Step 4: 핵심 기능 파악 (전체 모드만)

**AskUserQuestion 사용:**

```markdown
## ✨ 핵심 기능

### 주요 기능 (3-5개)
각 기능을 한 줄로 설명해주세요.

예:
1. 사용자 인증 - JWT 기반 로그인/회원가입
2. 상품 관리 - CRUD 및 카테고리 분류
3. 주문 처리 - 장바구니, 결제 연동
4. 관리자 대시보드 - 통계 및 관리 기능

### 비기능 요구사항 (선택)
- 성능: 예) 동시 접속 1000명
- 보안: 예) OAuth 2.0, HTTPS 필수
- 확장성: 예) Auto Scaling 필요
```

---

## Step 5: 미리보기 & 확인

**생성될 파일 미리보기:**

```markdown
## 📄 생성될 파일 미리보기

### 1. .claude/CLAUDE.md

# Project: {프로젝트명}

## User
- **Role**: {자동 매핑된 Role}
- **Expertise**: {자동 매핑된 Expertise}
- **Focus**: {자동 매핑된 Focus}

## Environment
- **Platform**: {Platform}
- **Region**: {Region}
- **Infra**: {기술 스택 요약}

## Architecture
{기술 스택 기반 폴더 구조}

## Key Files
{주요 파일 목록}

## Database
- **Engine**: {DB 종류}

---

### 2. docs/00_index.md (전체 모드)

# {프로젝트명} 문서 인덱스

**프로젝트 설명**: {한 줄 설명}

## 폴더 구조
- 01_requirements/ - 요구사항
- 02_architecture/ - 아키텍처
...

---

### 3. docs/01_requirements/PRD_overview.md (전체 모드)

# PRD: {프로젝트명}

## 핵심 기능
1. {기능 1}
2. {기능 2}
...

---

## ✅ 이대로 생성할까요?

- 이대로 생성
- {항목} 수정
- 취소
```

**확인 후 파일 생성 진행**

---

## 정보 → 문서 매핑

| 수집 정보 | 사용처 |
|----------|--------|
| 프로젝트명 | CLAUDE.md 제목, 00_index.md 제목 |
| 프로젝트 유형 | User 페르소나 자동 선택 |
| Platform/Region | Environment 섹션 |
| 기술 스택 | Architecture 섹션, Key Files |
| DB 종류 | Database 섹션 |
| 핵심 기능 | PRD_overview.md 기능 목록 |

### 프로젝트 유형 → User 페르소나 자동 매핑

| 프로젝트 유형 | Role | Expertise | Focus |
|--------------|------|-----------|-------|
| API 서버 | Tech Lead | Backend, DBA | API 설계, 비즈니스 로직 |
| 인프라 구축 | DevOps Engineer | IaC, K8s, CI/CD | 인프라 자동화 |
| 데이터 파이프라인 | Data Engineer | Python, SQL, ETL | 데이터 처리 |
| 풀스택 | One-Man Army | Backend, DevOps, DBA | 전 영역 |
| 기타 | Tech Lead | Backend | 커스텀 |

---

## 생성 파일 목록

### 빠른 모드
```
.claude/CLAUDE.md          # 프로젝트 설정
```

### 전체 모드
```
.claude/CLAUDE.md          # 프로젝트 설정
docs/
├── 00_index.md            # 마스터 인덱스
├── 01_requirements/
│   └── PRD_overview.md    # PRD 개요
├── 02_architecture/
│   └── .gitkeep
├── 03_system/
│   └── .gitkeep
├── 04_database/
│   └── .gitkeep
├── 05_api/
│   └── .gitkeep
├── 06_code/
│   └── .gitkeep
└── 07_backlog/
    └── .gitkeep
```

---

## 참조 템플릿

| 용도 | 참조 파일 |
|------|----------|
| 프로젝트 CLAUDE.md 구조 | `~/.claude/standards/Project_CLAUDE.md` |
| 문서 폴더 구조 | `~/.claude/standards/spec-docs-guide.md` |
| PRD 형식 | `~/.claude/standards/spec-docs-guide.md` PRD 섹션 |

---

## 트러블슈팅

### 이미 초기화된 프로젝트
1. Step 0에서 기존 설정 감지
2. 덮어쓰기 또는 취소 선택
3. 중요 파일은 백업 권장

### docs 폴더만 있고 CLAUDE.md 없음
1. 빠른 모드 선택하여 CLAUDE.md만 생성
2. 기존 docs 구조 유지

### 권한 오류
1. 디렉토리 쓰기 권한 확인
2. `ls -la .claude/` 또는 `ls -la docs/` 로 권한 확인
3. 필요시 `chmod` 또는 `sudo` 사용

### 프로젝트 유형이 목록에 없음
1. "기타" 선택
2. 이후 CLAUDE.md에서 User 섹션 직접 수정

---

## 다음 단계

프로젝트 초기화 완료 후:

1. **API 개발 시작** → `api-planning` 스킬로 API 계획서 작성
2. **인프라 구축 시작** → Terraform/Ansible 코드 작성
3. **문서 보강** → 각 폴더에 상세 문서 추가

```
project-init (완료)
    │
    ├── API 프로젝트 → api-planning → plan-review → api-scaffold
    │
    └── 인프라 프로젝트 → IaC 코드 작성 → terraform plan
```
