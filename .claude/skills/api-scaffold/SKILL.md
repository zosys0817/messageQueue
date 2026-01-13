---
name: api-scaffold
description: 승인된 계획서를 기반으로 TDD 방식으로 백엔드 코드를 생성합니다. 테스트 먼저 작성(RED), 구현(GREEN), 리팩토링 순서를 따릅니다. 코드 생성, 구현 시작 요청 시 활성화됩니다.
---

# API Scaffold

**승인된 계획서를 기반으로** 백엔드 코드를 자동 생성합니다.

> **주의**: 이 스킬은 `/api-plan`으로 작성된 계획서가 있어야 합니다.
> 계획서가 없다면 먼저 `/api-plan`을 실행하세요.

---

## 사전 확인

### Step 0: 계획서 존재 확인

1. `.claude/plans/` 디렉토리에서 계획서 찾기
2. 계획서가 없으면 안내:
   ```
   ⚠️ 계획서가 없습니다.
   먼저 `/api-plan`을 실행하여 계획서를 작성하세요.
   ```
3. 계획서가 있으면 내용 읽고 요약 출력

---

## 코드 생성 단계

### Step 1: 테스트 먼저 생성 (TDD - RED)

계획서의 엔드포인트별로 테스트 스켈레톤 생성:

**단위 테스트:**
- `backend/tests/unit/{domain}/test_service.py`
- `backend/tests/unit/{domain}/test_repository.py`

**통합 테스트:**
- `backend/tests/integration/{domain}/test_{endpoint}.py`

**테스트 실행하여 RED 확인:**
```bash
pytest backend/tests/unit/{domain}/ -v
```

### Step 2: 스키마 정의

`backend/app/domains/{domain}/schemas.py` 생성:
- Request/Response Pydantic 모델
- 계획서의 필드 타입 반영
- 검증 로직 (validator) 포함

### Step 3: Repository 구현

`backend/app/domains/{domain}/repository.py` 생성:

**쿼리 패턴 가이드:**
```python
# N+1 방지: selectinload 사용
from sqlalchemy.orm import selectinload

async def get_with_relations(self, id: int):
    query = select(Model).options(
        selectinload(Model.relation)
    ).where(Model.id == id)

# 페이지네이션 패턴
async def get_list(self, skip: int = 0, limit: int = 20):
    query = select(Model).offset(skip).limit(limit)

# 트랜잭션은 Service에서 관리
```

### Step 4: Service 구현

`backend/app/domains/{domain}/service.py` 생성:

**패턴:**
```python
class {Domain}Service:
    def __init__(self, repository: {Domain}Repository):
        self.repository = repository

    async def create(self, data: CreateRequest) -> Response:
        # 1. 비즈니스 검증
        # 2. Repository 호출
        # 3. 로깅 (INFO 레벨)
        # 4. 결과 반환
```

### Step 5: Router 구현

`backend/app/api/v1/routes/{domain}.py` 생성:

**참조 패턴:** `backend/app/api/v1/routes/auth.py`

**생성 규칙:**
1. 의존성 주입: `Depends(get_db)` → Service → Repository
2. 응답 래핑: `SuccessResponse[T]` / `ErrorResponse`
3. Rate Limiting: 계획서에 명시된 대로 적용
4. 타입 힌트: 모든 함수에 필수
5. 인증/인가: 계획서의 인가 매트릭스 반영

### Step 6: 테스트 통과 확인 (GREEN)

```bash
pytest backend/tests/ -v
pytest --cov=app backend/tests/  # 커버리지 80% 이상 확인
```

### Step 7: 라우터 등록

1. `backend/app/api/v1/routes/__init__.py`에 추가:
   ```python
   from .{domain} import router as {domain}_router
   ```

2. `backend/app/main.py`에 추가:
   ```python
   app.include_router({domain}_router, prefix="/api/v1")
   ```

### Step 8: DB 마이그레이션 (필요시)

계획서에 신규 테이블/컬럼이 있다면:
```bash
# 마이그레이션 생성
alembic revision --autogenerate -m "{domain}: add tables"

# 마이그레이션 적용
alembic upgrade head
```

### Step 9: 최종 검증

```bash
# 전체 테스트
pytest backend/tests/ -v

# 커버리지 확인 (80% 이상)
pytest --cov=app --cov-fail-under=80 backend/tests/

# API 문서 확인
# http://localhost:8000/docs
```

---

## 트러블슈팅

### 테스트 실패 시
1. 에러 메시지 확인: `pytest -v --tb=short`
2. 단일 테스트 실행: `pytest backend/tests/unit/{domain}/test_service.py::test_name -v`
3. DB 연결 확인: `curl http://localhost:8000/health`

### Import 에러 시
1. `__init__.py` 파일 존재 확인
2. PYTHONPATH 설정: `export PYTHONPATH=$PYTHONPATH:$(pwd)/backend`

### 마이그레이션 실패 시
1. 현재 상태 확인: `alembic current`
2. 히스토리 확인: `alembic history`
3. 롤백: `alembic downgrade -1`

---

## 다음 단계

코드 생성 완료 후:

### 1. 테스트 통과 확인
```bash
pytest backend/tests/ -v
pytest --cov=app --cov-fail-under=80 backend/tests/
```

### 2. 코드 리뷰 실행
```
/review 또는 "코드 리뷰해줘"
```
- 최근 변경사항 리뷰
- 보안/품질 체크

### 3. 문서 동기화 확인
```
/docs-sync 또는 "문서 동기화 확인해줘"
```
