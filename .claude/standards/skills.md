# Skills & Hooks

## Skills

Skills는 특정 조건에서 Claude가 자동으로 활성화하는 확장 프롬프트입니다.

| Skill | 용도 | 트리거 조건 |
|-------|------|-------------|
| project-init | 프로젝트 초기화 (CLAUDE.md + docs 폴더 구조 생성) | 새 프로젝트 시작, 프로젝트 초기화 요청 시 |
| api-plan-workflow | API 계획 → 리뷰 통합 | 새 API 개발 요청 시 (계획+리뷰 자동 연결) |
| api-planning | 신규 API 계획서 작성 | 새 API 개발, 도메인 구현 요청 시 |
| api-scaffold | TDD 방식 백엔드 코드 생성 | 계획서 승인 후 구현 시작 시 |
| code-review | 커밋 코드 리뷰 | 커밋 후, 변경사항 검토 요청 시 |
| plan-review | 계획서 전문가 리뷰 | ExitPlanMode 후 자동 실행 |
| project-status | 프로젝트 현황 파악 | 업무 시작, 다음 작업 확인 시 |
| docs-sync | 문서-코드 동기화 검사 | 문서 업데이트 필요 여부 확인 시 |
| explain-tech | 기술 개념 설명 | "설명해줘", "알려줘" 질문 시 |

---

## Hooks

프로젝트별 `.claude/settings.json`에서 hooks 설정 가능:

### 사용 가능한 Hook 이벤트

| Hook | 시점 | 용도 예시 |
|------|------|-----------|
| PreToolUse | 도구 실행 전 | 위험 명령어 차단, 권한 검증 |
| PostToolUse | 도구 실행 후 | 린트 자동 실행, 포맷팅 |
| Stop | 세션 종료 시 | Slack 알림, 로그 저장 |

### 설정 예시

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit",
        "command": "npx biome check --fix $CLAUDE_FILE_PATH"
      }
    ]
  }
}
```
