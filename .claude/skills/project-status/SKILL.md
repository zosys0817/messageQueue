---
name: project-status
description: 프로젝트 진행 현황을 파악하고 다음 작업을 안내합니다. 업무 시작 시, 현재 상태 확인 요청 시, 또는 다음에 무엇을 해야 할지 물어볼 때 자동 활성화됩니다.
---

# Project Status

프로젝트 진행 현황을 파악하고 다음 작업을 안내합니다.

**이 스킬은 업무 시작 시 가장 먼저 실행합니다.**

---

## 스킬 워크플로우

```
┌─────────────────────────────────────────────────────────────────┐
│                      Claude Skills 워크플로우                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  /status ──→ /api-plan ──→ /plan-review ──→ /api-scaffold      │
│     │            │              │                │              │
│     │            │              │                │              │
│     │            ▼              ▼                ▼              │
│     │       [계획서 작성]   [전문가 리뷰]    [코드 생성]         │
│     │                                            │              │
│     │                                            ▼              │
│     │                                        /review            │
│     │                                            │              │
│     │                                            ▼              │
│     │                                       /docs-sync          │
│     │                                            │              │
│     └────────────────────────────────────────────┘              │
│                         (반복)                                   │
└─────────────────────────────────────────────────────────────────┘

스킬별 역할:
• /status      : 현황 파악, 다음 작업 추천
• /api-plan    : Plan Mode에서 API 구현 계획서 작성
• /plan-review : 계획서 다중 전문가 리뷰
• /api-scaffold: 계획서 기반 코드 자동 생성 (TDD)
• /review      : 커밋 코드 리뷰 (보안, 품질)
• /docs-sync   : 문서-코드 동기화 검사
```

---

## 현황 파악 절차

### Step 1: Git 상태 확인

**1.1 최근 커밋 히스토리**
```bash
git log --oneline -10
```
- 최근 10개 커밋 확인
- 마지막 작업 내용 파악
- 커밋 메시지에서 작업 컨텍스트 추출

**1.2 현재 브랜치 상태**
```bash
git status
git branch -a
```
- 현재 브랜치 확인
- 커밋되지 않은 변경사항 확인
- 스테이징된 파일 확인

**1.3 최근 변경 파일**
```bash
git diff --name-only HEAD~5
```
- 최근 5개 커밋에서 변경된 파일 목록
- 어떤 도메인/기능을 작업했는지 파악

---

### Step 2: 백로그 문서 확인

**2.1 전체 개요**
- `docs/07_backlog/backlog_overview.md` - 전체 Phase 진행률

**2.2 현재 Phase 상세**
- `docs/07_backlog/backlog_phase1_overview.md` - Phase 1 개요
- `docs/07_backlog/backlog_phase1_01_infrastructure.md` - 인프라
- `docs/07_backlog/backlog_phase1_02_auth.md` - 인증
- `docs/07_backlog/backlog_phase1_03_products.md` - 상품
- `docs/07_backlog/backlog_phase1_04_orders.md` - 주문

**확인 사항:**
- [ ] 완료 표시된 항목 (✅, [x])
- [ ] 진행 중 표시된 항목 (🚧, [ ])
- [ ] 다음 우선순위 항목

---

### Step 3: 코드베이스 현황 분석

**3.1 구현된 API 라우터**
```bash
ls backend/app/api/v1/routes/
```
- 어떤 도메인이 구현되었는지 확인

**3.2 도메인별 구현 상태**
각 도메인 폴더 확인:
```
backend/app/domains/
├── auth/      # 구현 상태?
├── users/     # 구현 상태?
├── products/  # 구현 상태?
├── orders/    # 구현 상태?
...
```

**3.3 테스트 현황**
```bash
ls backend/tests/unit/
ls backend/tests/integration/
```
- 테스트가 작성된 도메인 확인

**3.4 테스트 실행 결과**
```bash
pytest backend/tests/ -v --tb=no -q
```
- 현재 테스트 통과 여부 확인
- 실패하는 테스트가 있다면 우선 수정 필요

**3.5 테스트 커버리지**
```bash
pytest --cov=app --cov-report=term-missing backend/tests/
```
- 현재 커버리지 확인 (목표: 80%)

---

### Step 4: API 명세 vs 구현 비교

**4.1 명세 문서**
```bash
ls docs/05_api/api_*.md
```

**4.2 구현 갭 분석**
| 도메인 | 명세 | 구현 | 테스트 | 상태 |
|--------|------|------|--------|------|
| auth | ✅ | ✅ | ✅ | 완료 |
| users | ✅ | 부분 | 부분 | 진행중 |
| products | ✅ | ❌ | ❌ | 미착수 |
| orders | ✅ | ❌ | ❌ | 미착수 |
| ... | | | | |

---

### Step 5: 계획서 & TODO 확인

**5.1 진행 중인 계획서**
```bash
ls .claude/plans/
```
- 작성 중이던 계획서가 있는지 확인
- 승인 대기 중인 계획서가 있는지 확인

**5.2 이전 세션 TODO**
- 이전 대화에서 남긴 TODO 항목 확인

---

### Step 6: 환경 상태 확인

**6.1 서버 실행 상태**
```bash
curl -s http://localhost:8000/health || echo "서버 미실행"
```

**6.2 DB 연결 상태**
- DB 컨테이너 또는 로컬 MySQL 실행 여부

**6.3 Docker 상태** (사용하는 경우)
```bash
docker ps --filter "name=engini" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker-compose ps  # docker-compose 사용 시
```

**6.4 컨테이너 로그 확인** (문제 발생 시)
```bash
docker logs engini-db --tail 20
docker logs engini-app --tail 20
```

---

## 출력 형식

```markdown
# 📊 Project Status Report

## 🕐 마지막 작업
- **커밋**: {hash} - {message}
- **시간**: {date}
- **변경 파일**: {files}

## 📈 전체 진행률

### Phase 1: MVP (현재)
| 영역 | 진행률 | 상태 |
|------|--------|------|
| 인프라 | 100% | ✅ 완료 |
| 인증 | 80% | 🚧 진행중 |
| 상품 | 0% | ⏳ 대기 |
| 주문 | 0% | ⏳ 대기 |

### 전체: Phase 1 진행률 45%

## 🔧 현재 작업 상태

### 커밋되지 않은 변경
- (있다면 표시)

### 진행 중인 계획서
- (있다면 표시)

### 실패 중인 테스트
- (있다면 표시)

### 테스트 커버리지
- 현재: XX% (목표: 80%)

## 🐳 환경 상태

| 서비스 | 상태 | 비고 |
|--------|------|------|
| API 서버 | ✅ 실행중 | localhost:8000 |
| MySQL | ✅ 실행중 | localhost:3306 |
| Docker | ✅ 정상 | 2 containers |

## ✅ 완료된 항목 (최근)
1. ✅ 회원가입 API
2. ✅ 로그인 API
3. ✅ 토큰 갱신 API
4. ✅ 로그아웃 API
5. ✅ 프로필 조회 API

## 🎯 다음 작업 추천

### 우선순위 1 (즉시)
> **{다음 작업 제목}**
> - 근거: 백로그 Phase 1 다음 항목
> - 시작 명령어: `/api-plan`

### 우선순위 2
> **{그 다음 작업}**

### 우선순위 3
> **{그 다음 작업}**

## 💡 권장 스킬

현재 상태에 따른 추천:
- `/api-plan` - 다음 API 계획 수립
- `/plan-review` - 계획서 리뷰
- `/api-scaffold` - 코드 생성
- `/review HEAD~3` - 최근 커밋 리뷰
- `/docs-sync` - 문서-코드 동기화 확인
```

---

## 트러블슈팅

### Git 상태 확인 실패
1. `.git` 디렉토리 존재 확인
2. `git init` 실행 여부 확인

### 테스트 실행 실패
1. 가상환경 활성화: `source backend/venv/bin/activate`
2. 의존성 설치: `pip install -r backend/requirements.txt`
3. DB 연결 확인

### Docker 컨테이너 미실행
1. Docker Desktop 실행 확인
2. `docker-compose up -d` 실행
3. 로그 확인: `docker-compose logs`

### 서버 연결 실패
1. 포트 사용 확인: `lsof -i :8000`
2. 서버 재시작: `uvicorn app.main:app --reload`

---

## 추가 현황 파악 소스

### Serena MCP 활용
- `mcp__serena__list_memories` - 저장된 프로젝트 메모리 확인
- `mcp__serena__read_memory` - 이전 세션 컨텍스트 복원

### 문서 확인
- `docs/00_index.md` - 전체 문서 인덱스
- `CLAUDE.md` - 프로젝트 컨텍스트

### 코드 분석
- `mcp__serena__get_symbols_overview` - 주요 파일 심볼 확인
- 각 도메인의 service.py 메서드 목록으로 구현 범위 파악

---

## 다음 단계

현황 파악 후:
1. 실패 테스트가 있다면 → 먼저 수정
2. 진행 중인 계획서가 있다면 → `/api-scaffold`
3. 새 기능 개발 → `/api-plan`
