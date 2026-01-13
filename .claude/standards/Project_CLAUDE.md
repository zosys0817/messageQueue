# Project-Level CLAUDE.md 템플릿

프로젝트별 `.claude/CLAUDE.md` 작성 가이드

---

## 필수 섹션

### 1. User (사용자 페르소나)
```markdown
## User
- **Role**: One-Man Army Tech Lead (PM~DevOps 전 영역, Frontend 제외)
- **Expertise**: Backend, DBA, DevOps
- **Focus**: 이 프로젝트에서 집중하는 역할 (예: Backend 개발)
```

**페르소나 예시**:
| 프로젝트 유형 | Role | Expertise | Focus |
|--------------|------|-----------|-------|
| API 서버 | Tech Lead | Backend, DBA | API 설계, 비즈니스 로직 |
| 인프라 구축 | DevOps Engineer | IaC, K8s, CI/CD | 인프라 자동화 |
| 데이터 파이프라인 | Data Engineer | Python, SQL, ETL | 데이터 처리 |
| 풀스택 (1인) | One-Man Army | Backend, DevOps, DBA | 전 영역 |

### 2. Environment
```markdown
## Environment
- **Platform**: AWS / NCP / On-Prem
- **Region**: ap-northeast-2
- **Infra**: ECS Fargate + Aurora MySQL
```

### 3. Architecture
```markdown
## Architecture
src/
├── api/          # FastAPI 라우터
├── domain/       # 비즈니스 로직
├── infra/        # DB, 외부 서비스 연동
└── tests/        # pytest 테스트
```

### 4. Key Files
```markdown
## Key Files
- `src/api/main.py`: FastAPI 엔트리포인트
- `src/domain/order.py`: 주문 도메인 로직
- `terraform/`: IaC 설정
```

---

## 권장 섹션

### 5. Build & Deploy
```markdown
## Build & Deploy
- 로컬 실행: `make run`
- 테스트: `make test`
- 배포: `make deploy-staging`
```

### 6. Database
```markdown
## Database
- **Engine**: Aurora MySQL 8.0
- **Schema**: `docs/erd.md` 참조
- **Migration**: `alembic upgrade head`
```

### 7. Project-Specific Rules
```markdown
## Project-Specific Rules
- API 응답 포맷: `{"success": bool, "data": any, "error": string|null}`
- 에러 코드: `docs/error-codes.md` 참조
```

---

## 전체 예시

```markdown
# Project: my-api-server

## User
- **Role**: Tech Lead
- **Expertise**: Backend, DBA
- **Focus**: API 설계, 비즈니스 로직 구현

## Environment
- **Platform**: AWS
- **Region**: ap-northeast-2
- **Infra**: ECS Fargate + Aurora MySQL

## Architecture
src/
├── api/          # FastAPI 라우터
├── domain/       # 비즈니스 로직
├── infra/        # DB, 외부 서비스 연동
└── tests/        # pytest 테스트

## Key Files
- `src/api/main.py`: FastAPI 엔트리포인트
- `src/domain/order.py`: 주문 도메인 로직
- `terraform/`: IaC 설정

## Build & Deploy
- 로컬 실행: `make run`
- 테스트: `make test`
- 배포: `make deploy-staging`

## Database
- **Engine**: Aurora MySQL 8.0
- **Migration**: `alembic upgrade head`

## Project-Specific Rules
- API 응답: `{"success": bool, "data": any, "error": string|null}`
```
