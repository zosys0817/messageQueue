# Security & Secrets (보안)

## 기본 원칙

- **실제 비밀번호, 토큰, API 키** 절대 포함 금지
- 코드/설정 예시에서 크리덴셜은 **더미 값 또는 환경 변수 참조**로 대체

---

## 환경 변수 패턴

```bash
DB_USER=myuser
DB_PASSWORD=${DB_PASSWORD}
API_KEY=${API_KEY}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
```

---

## 시크릿 관리 도구

| 환경 | 권장 도구 |
|------|-----------|
| AWS | Secrets Manager, Parameter Store |
| Kubernetes | Kubernetes Secret, External Secrets Operator |
| 범용 | HashiCorp Vault |

---

## 코드 예시

### Bad
```python
db_password = "my-secret-password-123"  # 절대 금지
```

### Good
```python
import os
db_password = os.environ.get("DB_PASSWORD")
```
