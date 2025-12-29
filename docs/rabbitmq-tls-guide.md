# RabbitMQ TLS 인증서 가이드

> AMQPS(5671) 보안 통신 설정 | 인프라 관리자용

## 1. 개요

### 1.1 TLS가 필요한 이유

```
[TLS 없이 통신]
App ──── 평문 메시지 ────> RabbitMQ
         (도청 가능)

[TLS 적용 시]
App ──── 암호화된 메시지 ────> RabbitMQ
         (도청 불가)
```

**필수 적용 구간:**
- DMZ ↔ 내부 구간 통신
- 민감한 데이터가 포함된 메시지

### 1.2 포트 구분

| 포트 | 프로토콜 | 암호화 | 용도 |
|------|---------|--------|------|
| 5672 | AMQP | X | 내부 통신 (평문) |
| 5671 | AMQPS | O | 외부/DMZ 통신 (암호화) |

---

## 2. 인증서 구성

### 2.1 인증서 종류

> RabbitMQ용 인증서는 웹 서비스 인증서와 **별도로 발급**

| 구분 | 웹 서비스 인증서 | RabbitMQ 인증서 |
|------|-----------------|-----------------|
| 용도 | HTTPS (브라우저 ↔ 웹서버) | AMQPS (App ↔ RabbitMQ) |
| 도메인 | `www.example.com` | `rabbitmq.internal.example.com` |
| 포트 | 443 | 5671 |
| 클라이언트 | 불특정 다수 (브라우저) | 특정 App (Producer/Consumer) |
| 인증서 타입 | 공인 CA (외부 노출) | **사설 CA 가능** (내부 통신) |

### 2.2 필요한 파일

| 파일 | 용도 | 배포 위치 |
|------|------|----------|
| `ca_certificate.pem` | 신뢰할 CA 인증서 | RabbitMQ + 모든 Client |
| `server_certificate.pem` | RabbitMQ 서버 인증서 | RabbitMQ만 |
| `server_key.pem` | RabbitMQ 서버 개인키 | RabbitMQ만 (비공개) |
| `client_certificate.pem` | 클라이언트 인증서 | Client App (mTLS 시) |
| `client_key.pem` | 클라이언트 개인키 | Client App (mTLS 시) |

### 2.3 인증 방식 선택

#### 방식 1: 서버 인증만 (일반적)

```
┌─────────────────────────────────────────┐
│                  CA                      │
│         (인증서 발급 기관)                │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│            RabbitMQ 서버                 │
│   server_certificate.pem (인증서)        │
│   server_key.pem (개인키)                │
└─────────────────────────────────────────┘
                    ▲
                    │ TLS 연결
                    │
┌─────────────────────────────────────────┐
│            Client App                    │
│   ca_certificate.pem (CA만 신뢰)         │
│   + ID/PW 인증                          │
└─────────────────────────────────────────┘
```

- Client는 RabbitMQ 서버가 진짜인지 확인
- RabbitMQ는 Client를 **ID/PW**로 인증
- 설정이 간단함

#### 방식 2: 양방향 인증 (mTLS) - 보안 강화

```
┌─────────────────────────────────────────┐
│                  CA                      │
│         (인증서 발급 기관)                │
└─────────────────────────────────────────┘
          │                    │
          ▼                    ▼
┌─────────────────┐    ┌─────────────────┐
│   RabbitMQ      │    │   Client App    │
│ server_cert.pem │◄──►│ client_cert.pem │
│ server_key.pem  │    │ client_key.pem  │
└─────────────────┘    └─────────────────┘
        서로 인증서로 검증
```

- 서로가 서로를 **인증서로 검증**
- ID/PW 없이도 인증 가능
- **DMZ ↔ 내부 구간 통신 시 권장**

---

## 3. 인증서 발급

### 3.1 사설 CA 생성 (내부용)

```bash
# 1. CA 개인키 생성
openssl genrsa -out ca_key.pem 4096

# 2. CA 인증서 생성 (10년 유효)
openssl req -x509 -new -nodes \
  -key ca_key.pem \
  -sha256 -days 3650 \
  -out ca_certificate.pem \
  -subj "/C=KR/ST=Seoul/O=MyCompany/CN=MyCompany-RabbitMQ-CA"
```

### 3.2 서버 인증서 발급

```bash
# 1. 서버 개인키 생성
openssl genrsa -out server_key.pem 2048

# 2. CSR (인증서 서명 요청) 생성
openssl req -new \
  -key server_key.pem \
  -out server_csr.pem \
  -subj "/C=KR/ST=Seoul/O=MyCompany/CN=rabbitmq.internal.example.com"

# 3. SAN (Subject Alternative Name) 설정 파일 생성
cat > server_san.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = rabbitmq.internal.example.com
DNS.2 = rabbitmq-node1
DNS.3 = rabbitmq-node2
DNS.4 = rabbitmq-node3
IP.1 = 10.0.1.10
IP.2 = 10.0.1.11
IP.3 = 10.0.1.12
EOF

# 4. 서버 인증서 발급 (CA로 서명)
openssl x509 -req \
  -in server_csr.pem \
  -CA ca_certificate.pem \
  -CAkey ca_key.pem \
  -CAcreateserial \
  -out server_certificate.pem \
  -days 365 \
  -sha256 \
  -extfile server_san.cnf \
  -extensions v3_req
```

### 3.3 클라이언트 인증서 발급 (mTLS용)

```bash
# 1. 클라이언트 개인키 생성
openssl genrsa -out client_key.pem 2048

# 2. CSR 생성
openssl req -new \
  -key client_key.pem \
  -out client_csr.pem \
  -subj "/C=KR/ST=Seoul/O=MyCompany/CN=producer-app"

# 3. 클라이언트 인증서 발급
openssl x509 -req \
  -in client_csr.pem \
  -CA ca_certificate.pem \
  -CAkey ca_key.pem \
  -CAcreateserial \
  -out client_certificate.pem \
  -days 365 \
  -sha256
```

### 3.4 인증서 검증

```bash
# CA 인증서 정보 확인
openssl x509 -in ca_certificate.pem -text -noout

# 서버 인증서가 CA로 서명되었는지 확인
openssl verify -CAfile ca_certificate.pem server_certificate.pem

# 인증서 만료일 확인
openssl x509 -in server_certificate.pem -noout -enddate
```

---

## 4. RabbitMQ 설정

### 4.1 인증서 파일 배치

```bash
# 디렉토리 생성
sudo mkdir -p /etc/rabbitmq/certs
sudo chmod 750 /etc/rabbitmq/certs

# 파일 복사
sudo cp ca_certificate.pem /etc/rabbitmq/certs/
sudo cp server_certificate.pem /etc/rabbitmq/certs/
sudo cp server_key.pem /etc/rabbitmq/certs/

# 권한 설정
sudo chown -R rabbitmq:rabbitmq /etc/rabbitmq/certs
sudo chmod 640 /etc/rabbitmq/certs/*.pem
```

### 4.2 rabbitmq.conf 설정

#### 서버 인증만 (방식 1)

```ini
# TLS 리스너 활성화
listeners.ssl.default = 5671

# 인증서 경로
ssl_options.cacertfile = /etc/rabbitmq/certs/ca_certificate.pem
ssl_options.certfile   = /etc/rabbitmq/certs/server_certificate.pem
ssl_options.keyfile    = /etc/rabbitmq/certs/server_key.pem

# TLS 버전 (1.2 이상만 허용)
ssl_options.versions.1 = tlsv1.2
ssl_options.versions.2 = tlsv1.3

# 클라이언트 인증서 검증 안 함
ssl_options.verify = verify_none
ssl_options.fail_if_no_peer_cert = false
```

#### 양방향 인증 mTLS (방식 2)

```ini
# TLS 리스너 활성화
listeners.ssl.default = 5671

# 인증서 경로
ssl_options.cacertfile = /etc/rabbitmq/certs/ca_certificate.pem
ssl_options.certfile   = /etc/rabbitmq/certs/server_certificate.pem
ssl_options.keyfile    = /etc/rabbitmq/certs/server_key.pem

# TLS 버전
ssl_options.versions.1 = tlsv1.2
ssl_options.versions.2 = tlsv1.3

# 클라이언트 인증서 검증 (mTLS)
ssl_options.verify = verify_peer
ssl_options.fail_if_no_peer_cert = true
```

### 4.3 서비스 재시작

```bash
sudo systemctl restart rabbitmq-server

# 상태 확인
sudo rabbitmqctl status | grep -A5 "Listeners"
```

---

## 5. 클라이언트 연결

### 5.1 Python (pika) 예시

#### 서버 인증만

```python
import pika
import ssl

context = ssl.create_default_context(cafile="/path/to/ca_certificate.pem")

credentials = pika.PlainCredentials("user", "password")
parameters = pika.ConnectionParameters(
    host="rabbitmq.internal.example.com",
    port=5671,
    credentials=credentials,
    ssl_options=pika.SSLOptions(context),
)

connection = pika.BlockingConnection(parameters)
```

#### mTLS (양방향 인증)

```python
import pika
import ssl

context = ssl.create_default_context(cafile="/path/to/ca_certificate.pem")
context.load_cert_chain(
    certfile="/path/to/client_certificate.pem",
    keyfile="/path/to/client_key.pem",
)

parameters = pika.ConnectionParameters(
    host="rabbitmq.internal.example.com",
    port=5671,
    ssl_options=pika.SSLOptions(context),
)

connection = pika.BlockingConnection(parameters)
```

### 5.2 개발자에게 전달할 것

| 항목 | 서버 인증만 | mTLS |
|------|-----------|------|
| CA 인증서 | O | O |
| 클라이언트 인증서 | X | O |
| 클라이언트 키 | X | O |
| 접속 호스트 | O | O |
| 포트 | 5671 | 5671 |
| 계정 정보 | O (ID/PW) | X (인증서로 대체) |

---

## 6. 문제 해결

### 6.1 일반적인 오류

| 오류 | 원인 | 해결 |
|------|------|------|
| `certificate verify failed` | CA 인증서 없거나 잘못됨 | CA 인증서 경로 확인 |
| `certificate has expired` | 인증서 만료 | 인증서 갱신 |
| `hostname mismatch` | CN/SAN이 호스트명과 다름 | 인증서 재발급 (SAN 추가) |
| `no peer certificate` | 클라이언트 인증서 없음 | mTLS 시 인증서 설정 |

### 6.2 연결 테스트

```bash
# TLS 연결 테스트
openssl s_client -connect rabbitmq.internal.example.com:5671 \
  -CAfile /path/to/ca_certificate.pem

# 인증서 체인 확인
openssl s_client -connect rabbitmq.internal.example.com:5671 \
  -CAfile /path/to/ca_certificate.pem \
  -showcerts
```

---

## 7. 인증서 관리

### 7.1 갱신 주기

| 인증서 | 권장 유효기간 | 갱신 시점 |
|--------|-------------|----------|
| CA 인증서 | 10년 | 만료 1년 전 |
| 서버 인증서 | 1년 | 만료 1개월 전 |
| 클라이언트 인증서 | 1년 | 만료 1개월 전 |

### 7.2 갱신 체크리스트

- [ ] 새 인증서 발급
- [ ] RabbitMQ 서버에 배포
- [ ] 클라이언트에 CA 인증서 배포 (CA 변경 시)
- [ ] 서비스 재시작
- [ ] 연결 테스트

### 7.3 모니터링

```bash
# 인증서 만료일 확인 스크립트
CERT_FILE="/etc/rabbitmq/certs/server_certificate.pem"
EXPIRY=$(openssl x509 -in $CERT_FILE -noout -enddate | cut -d= -f2)
echo "인증서 만료일: $EXPIRY"
```

---

## 8. 요약

| 구간 | 권장 방식 | 포트 |
|------|----------|------|
| 내부 ↔ 내부 | 평문 (AMQP) 또는 사설 CA TLS | 5672 또는 5671 |
| DMZ ↔ 내부 | **mTLS (양방향 인증)** | 5671 |
| 외부 ↔ DMZ | 공인 CA TLS | 5671 |

**인프라 관리자 역할:**
1. 인증서 발급 및 관리
2. RabbitMQ TLS 설정
3. 개발자에게 CA 인증서 + 연결 정보 전달
4. 인증서 갱신 모니터링
