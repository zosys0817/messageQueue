# Workflow Protocol: "Explore → Plan → Code → Verify"

## Step 1: Context & Environment Analysis (맥락 분석)

- **Identify Platform**: AWS / NCP / On-Prem 중 현재 환경 식별
  - **AWS**: 성숙한 Managed Services (RDS, S3, ALB) 우선
  - **NCP**: NCP 고유 특성 (ACG, VPC/Classic 구분, Standard 이미지)
  - **On-Prem**: OS 제한, Disk I/O, 네트워크 제약 직접 관리
- **Read Project Context**: `Project Local CLAUDE.md` 있으면 최우선 확인

---

## Step 2: Safety & Architecture Check (안전성 체크)

### Destructive Actions 발생 시
`DROP`, `DELETE`, `rm -rf`, Infra 변경 등:
- **STOP & ASK**: "백업이나 스냅샷은 있나요?"
- **필수 포함**: Rollback Plan + Dry-run 명령어

### 위험 작업 체크리스트
- [ ] 변경 요약
- [ ] 사전 조건 (백업, 권한, 트래픽 창)
- [ ] Staging 검증 절차
- [ ] 롤백 전략

### Over-engineering 점검
"One-Man Army" 관점에서 관리 포인트가 늘어나지 않는지 확인

---

## Step 3: Implementation (구현)

- **Copy-Paste Ready**: `import`, 파일 경로, 패키지 설치 명령어까지 완전한 코드 제공
- **모호한 요구사항**: 임의 가정 NO → 합리적 가설 + 질문/선택지 제시
- **변경은 작은 단위로 쪼개서** 단계별 진행·검증

---

## Step 4: Verification (검증)

최소 1개 이상의 검증 방법 포함:

| 영역 | 검증 방법 |
|------|-----------|
| Network | `curl -v`, `telnet`, `nc` |
| K8s/Docker | `kubectl get`, `docker ps`, `docker logs` |
| DB | Read-only user로 먼저 확인, 단위 테스트 |
| CLI | `aws`, `ncloud`, `terraform plan` 등 |
