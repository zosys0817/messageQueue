---
name: api-planning
description: 신규 API 구현을 위한 계획서를 작성합니다. 새로운 API 개발, 도메인 구현, 엔드포인트 추가 요청 시 Plan Mode로 진입하여 상세 계획을 수립합니다.
---

# API Plan

신규 API 구현을 위한 계획서를 작성합니다.

## 필수: Plan Mode 진입

**이 스킬은 반드시 Plan Mode에서 시작합니다.**

`EnterPlanMode` 도구를 호출하여 계획 모드로 진입하세요.

---

## Step 1: 도메인 분석

현재 프로젝트 상태를 분석합니다:

1. **API 명세 확인**: `docs/05_api/api_*.md` 파일 목록
2. **구현 현황 확인**: `backend/app/api/v1/routes/*.py` 파일 목록
3. **미구현 도메인 식별**: 명세는 있으나 코드가 없는 도메인

사용자에게 질문 (AskUserQuestion):
> 어떤 도메인의 API를 계획할까요?
> - 미구현 도메인 목록 표시
> - 특정 엔드포인트만 선택 가능

---

## Step 2: API 명세 분석

선택된 도메인의 명세 파일 읽기:
- `docs/05_api/api_{domain}.md`

추출할 정보:
- 엔드포인트 목록 (method, path, summary)
- Request/Response 스키마
- 에러 응답 코드
- 의사코드 로직
- 구현 힌트

---

## Step 3: 계획서 작성

계획서 파일에 아래 템플릿으로 작성:

```markdown
# {Domain} API 구현 계획

## 1. 개요

| 항목 | 내용 |
|------|------|
| 도메인 | {domain} |
| API 명세 | docs/05_api/api_{domain}.md |
| 엔드포인트 수 | N개 |
| 예상 복잡도 | 낮음/중간/높음 |
| 외부 의존성 | (있다면) |

## 2. 엔드포인트 상세

### 2.1 {엔드포인트 1}
- **Method**: POST/GET/...
- **Path**: /api/v1/{domain}/...
- **Summary**: ...
- **인증**: 필요/불필요
- **Rate Limit**: 필요시 명시

**Request:**
```json
{
  "field": "type"
}
```

**Response:**
```json
{
  "field": "type"
}
```

**비즈니스 로직:**
1. 입력 검증
2. ...
3. 결과 반환

**에러 케이스:**
- 400: 잘못된 요청
- 401: 인증 필요
- 403: 권한 없음
- 404: 리소스 없음

### 2.2 {엔드포인트 2}
(반복)

## 3. 인가(Authorization) 매트릭스

| 엔드포인트 | 인증 | 권한 | 본인확인 | 비고 |
|-----------|------|------|---------|------|
| GET /api/v1/{domain} | ✅ | - | - | 목록 조회 |
| POST /api/v1/{domain} | ✅ | - | - | 생성 |
| GET /api/v1/{domain}/{id} | ✅ | - | owner | 본인 것만 |
| PATCH /api/v1/{domain}/{id} | ✅ | - | owner | 본인 것만 |
| DELETE /api/v1/{domain}/{id} | ✅ | admin | - | 관리자만 |

**권한 설명:**
- `owner`: 리소스 소유자만 접근 가능
- `admin`: 관리자 권한 필요
- `-`: 인증만 되면 접근 가능

## 4. 데이터 모델

### 4.1 DB 테이블
- 사용할 테이블: `docs/04_database/database_mysql.md` 참조
- 신규 테이블 필요 여부

### 4.2 Pydantic 스키마
| 스키마명 | 용도 | 필드 |
|----------|------|------|
| {Domain}CreateRequest | 생성 요청 | ... |
| {Domain}UpdateRequest | 수정 요청 | ... |
| {Domain}Response | 응답 | ... |
| {Domain}ListResponse | 목록 응답 | items, total, page |

## 5. 생성할 파일

### 5.1 프로덕션 코드
- [ ] `backend/app/api/v1/routes/{domain}.py` - 라우터
- [ ] `backend/app/domains/{domain}/schemas.py` - 스키마
- [ ] `backend/app/domains/{domain}/service.py` - 서비스
- [ ] `backend/app/domains/{domain}/repository.py` - 리포지토리
- [ ] `backend/app/domains/{domain}/models.py` - ORM 모델 (필요시)

### 5.2 테스트 코드
- [ ] `backend/tests/unit/{domain}/test_service.py`
- [ ] `backend/tests/unit/{domain}/test_repository.py`
- [ ] `backend/tests/integration/{domain}/test_{endpoint}.py`

## 6. 구현 순서 (TDD)

### Phase 1: 테스트 작성 (RED)
1. 단위 테스트 스켈레톤 작성
2. 통합 테스트 스켈레톤 작성
3. `pytest` 실행하여 실패 확인

### Phase 2: 구현 (GREEN)
1. 스키마 정의
2. 리포지토리 구현
3. 서비스 구현
4. 라우터 구현
5. 테스트 통과 확인 (커버리지 80% 이상)

### Phase 3: 정리 (REFACTOR)
1. 코드 정리
2. 라우터 등록
3. 문서 업데이트

## 7. DB 마이그레이션

### 7.1 변경 사항
- [ ] 신규 테이블: (있다면)
- [ ] 컬럼 추가: (있다면)
- [ ] 인덱스 추가: (있다면)

### 7.2 마이그레이션 계획
```bash
# 1. 마이그레이션 생성
alembic revision --autogenerate -m "{domain}: description"

# 2. 마이그레이션 검토 (자동 생성 결과 확인)
cat alembic/versions/{revision}_*.py

# 3. 마이그레이션 적용
alembic upgrade head

# 4. 롤백 계획 (문제 발생 시)
alembic downgrade -1
```

### 7.3 롤백 전략
- 롤백 스크립트 검증 필수
- 데이터 손실 가능성 확인
- 프로덕션 적용 전 스테이징 테스트

## 8. 로깅 계획

### 8.1 로깅 포인트
| 레벨 | 위치 | 내용 | 예시 |
|------|------|------|------|
| INFO | Service 시작 | 요청 정보 | `{domain}.create started: user_id={user_id}` |
| INFO | Service 완료 | 결과 요약 | `{domain}.create completed: id={id}` |
| WARNING | 비즈니스 예외 | 예외 상황 | `{domain} not found: id={id}` |
| ERROR | 시스템 예외 | 스택 트레이스 | `{domain}.create failed: {error}` |

### 8.2 로깅 금지 항목
- 비밀번호, 토큰
- 개인정보 (이메일 전체, 전화번호)
- 카드 정보
- API 키

## 9. 의존성 & 연동

### 9.1 내부 의존성
- 참조할 기존 모듈: auth, users
- 공용 유틸리티: core/security.py, utils/...

### 9.2 외부 의존성
- 외부 API: (있다면)
- 환경 변수: (필요시)

## 10. 주의사항 & 리스크

### 10.1 기술적 주의사항
- (명세에서 발견한 특이사항)
- (구현 힌트에서 추출한 내용)

### 10.2 비즈니스 주의사항
- (도메인 특수 규칙)

### 10.3 보안 고려사항
- 인증/인가 요구사항 (위 매트릭스 참조)
- 입력 검증 포인트
- 민감 데이터 처리
- CSRF 보호 필요 여부
- CORS 설정 확인

### 10.4 성능 고려사항
- N+1 쿼리 방지
- 페이지네이션 필수 여부
- 캐싱 필요 여부

## 11. 체크리스트

구현 완료 시 확인:
- [ ] 모든 테스트 통과
- [ ] 커버리지 80% 이상
- [ ] 코딩 표준 준수 (docs/06_code/code_backend.md)
- [ ] API 문서 자동 생성 확인 (/docs)
- [ ] 에러 처리 완료
- [ ] 로깅 추가
- [ ] 인가 검증 완료
- [ ] 마이그레이션 적용 (필요시)
```

---

## Step 4: 사용자 승인

계획서 작성 완료 후:
1. 계획서 요약 출력
2. `ExitPlanMode` 호출하여 승인 요청

---

## 다음 단계

승인 후:
1. `/plan-review` - 계획서 전문가 리뷰 (선택)
2. `/api-scaffold` - 코드 생성

---

## 참조 문서

- API 명세: `docs/05_api/`
- DB 스키마: `docs/04_database/database_mysql.md`
- 코딩 표준: `docs/06_code/code_backend.md`
- TDD 가이드: `docs/06_code/code_tdd.md`
- 레이어 아키텍처: `docs/06_code/code_backend_layers.md`

---

## 트러블슈팅

### Plan Mode 진입 실패
1. `EnterPlanMode` 도구 직접 호출
2. 또는 대화로 "계획 모드로 진입해줘" 요청

### 명세 파일을 찾을 수 없음
1. `docs/05_api/` 디렉토리 확인
2. 파일명 패턴: `api_{domain}.md`
3. 없으면 명세 먼저 작성 필요

### 계획서 저장 위치
- 자동: `.claude/plans/{domain}-api-plan-{date}.md`
- 수동 지정 가능
