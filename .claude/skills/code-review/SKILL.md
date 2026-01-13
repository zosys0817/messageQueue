---
name: code-review
description: 커밋된 코드를 TDD 준수, 코딩 표준, 보안 관점에서 리뷰합니다. 커밋 후, 코드 리뷰 요청 시, 또는 변경사항 검토 요청 시 자동 활성화됩니다.
---

# Code Review

커밋된 코드를 리뷰합니다.

---

## 리뷰 절차

### Step 1: 변경 사항 분석
1. `git show` 또는 `git diff`로 변경 내용 확인
2. 변경된 파일 목록 추출
3. 각 파일별 변경 라인 분석

### Step 2: TDD 준수 확인
`docs/06_code/code_tdd.md` 기준으로 검증:
- 구현 코드 변경 시 테스트 파일도 함께 변경되었는지 확인
- 테스트가 먼저 커밋되었는지 히스토리 확인
- 테스트 실행: `pytest backend/tests/ -v`
- **커버리지 확인 (임계값 80%)**:
  ```bash
  pytest --cov=app --cov-fail-under=80 backend/tests/
  ```

### Step 3: 코딩 표준 검증
`docs/06_code/code_backend.md` 기준으로 검증:
- **레이어 패턴**: Router → Service → Repository 준수
- **네이밍**: snake_case 사용
- **타입 힌트**: 모든 함수/메서드에 타입 힌트 있는지
- **에러 처리**: 적절한 예외 처리 및 로깅
- **파일 크기**: 200줄 초과 시 분리 제안

### Step 4: 보안 체크

#### 4.1 인증 (Authentication)
- JWT 토큰 검증 적용 여부
- `Depends(get_current_user)` 사용 확인

#### 4.2 인가 (Authorization)
- 리소스 소유자 확인 로직 (`user_id == resource.owner_id`)
- 권한 레벨 체크 (`is_admin`, `role` 등)
- 본인 확인 필요 API에 적용 여부

#### 4.3 입력 검증
- Pydantic 스키마로 입력 검증
- 경로 파라미터 타입 검증 (`Path(gt=0)`)
- 쿼리 파라미터 범위 검증

#### 4.4 시크릿 노출
- 하드코딩된 API 키, 비밀번호 없는지
- 환경 변수 사용 확인

#### 4.5 SQL Injection
- ORM 사용 여부 (raw query 지양)
- raw query 사용 시 파라미터 바인딩 확인

#### 4.6 CORS 설정
- `backend/app/main.py`의 CORS 설정 확인
- 허용 origin이 적절한지 (`*` 지양)

#### 4.7 CSRF 보호
- 상태 변경 API (POST, PUT, DELETE)에 적용 여부
- SameSite 쿠키 설정 확인

#### 4.8 민감 정보 로깅
- 비밀번호, 토큰이 로그에 노출되지 않는지
- 개인정보 마스킹 적용 여부

### Step 5: 문서 동기화
- API 엔드포인트 변경 시 `docs/05_api/` 업데이트 여부
- 스키마 변경 시 `docs/04_database/` 업데이트 여부

---

## 출력 형식

```markdown
# Code Review Report

## 변경 요약
- **커밋**: {hash} - {message}
- **변경 파일**: N개
- **추가/삭제**: +X / -Y lines

---

## 리뷰 결과

### TDD 준수
| 항목 | 결과 | 비고 |
|------|------|------|
| 테스트 동반 여부 | [PASS/WARN/FAIL] | |
| 테스트 커버리지 | [PASS/WARN/FAIL] | 현재: XX%, 목표: 80% |

### 코딩 표준
| 항목 | 결과 | 비고 |
|------|------|------|
| 레이어 패턴 | [PASS/WARN/FAIL] | |
| 네이밍 컨벤션 | [PASS/WARN/FAIL] | |
| 타입 힌트 | [PASS/WARN/FAIL] | |
| 에러 처리 | [PASS/WARN/FAIL] | |
| 파일 크기 | [PASS/WARN/FAIL] | |

### 보안
| 항목 | 결과 | 심각도 | 비고 |
|------|------|--------|------|
| 인증 적용 | [PASS/WARN/FAIL] | - | |
| 인가 검증 | [PASS/WARN/FAIL] | HIGH | |
| 입력 검증 | [PASS/WARN/FAIL] | HIGH | |
| 시크릿 노출 | [PASS/WARN/FAIL] | CRITICAL | |
| SQL Injection | [PASS/WARN/FAIL] | CRITICAL | |
| CORS 설정 | [PASS/WARN/FAIL] | MEDIUM | |
| CSRF 보호 | [PASS/WARN/FAIL] | MEDIUM | |
| 민감정보 로깅 | [PASS/WARN/FAIL] | HIGH | |

### 문서 동기화
| 항목 | 결과 | 비고 |
|------|------|------|
| API 문서 | [PASS/WARN/FAIL] | |
| DB 문서 | [PASS/WARN/FAIL] | |

---

## 종합 평가

**보안 점수**: X/10
**품질 점수**: X/10

---

## 필수 수정 (Must Fix)
1. [CRITICAL] ...
2. [HIGH] ...

## 권장 수정 (Should Fix)
1. [MEDIUM] ...
2. [LOW] ...

## 개선 제안
1. ...
2. ...
```

---

## 트러블슈팅

### 커밋을 찾을 수 없음
1. `git log --oneline -10`으로 커밋 해시 확인
2. 올바른 브랜치인지 확인: `git branch`

### 테스트 실행 실패
1. 가상환경 활성화: `source backend/venv/bin/activate`
2. 의존성 설치: `pip install -r backend/requirements.txt`
3. DB 연결 확인

### 커버리지 측정 실패
1. pytest-cov 설치: `pip install pytest-cov`
2. 설정 확인: `pytest.ini` 또는 `pyproject.toml`

---

## 다음 단계

리뷰 완료 후:

### 1. 필수 수정 사항 반영
- Must Fix 항목 우선 처리
- 테스트 코드 누락 시 추가

### 2. 테스트 재실행
```bash
pytest backend/tests/ -v
pytest --cov=app --cov-fail-under=80 backend/tests/
```

### 3. 문서 동기화 확인 (권장)
```
/docs-sync 또는 "문서 동기화 확인해줘"
```

> **💡 권장**: API 엔드포인트 추가/변경 시 반드시 docs-sync를 실행하여 명세와 코드의 일치 여부를 확인하세요.

### 4. 커밋
```
"커밋해줘" 또는 직접 git commit
```

---

## 자동 권고 메시지

리뷰 완료 시 다음 메시지를 출력에 포함합니다:

```
---
📋 **다음 단계 권장**: API 변경이 포함된 경우 `docs-sync` 실행을 권장합니다.
   → "문서 동기화 확인해줘" 또는 `/docs-sync`
```
