# RabbitMQ 인프라 구축 가이드

> 아웃바운드 메시지큐 구성 | DMZ + 내부구간 분리 환경

## 1. 개요

### 1.1 문서 목적

- 인프라 관리자를 위한 RabbitMQ 구축 가이드
- 개발자가 메시지 브로커를 구현할 수 있도록 인프라 환경 제공
- DMZ/내부구간 분리 환경에서의 아웃바운드 MQ 구성

### 1.2 용어 정리

> 편의점 택배함에 비유해서 설명

| 용어 | 쉬운 설명 | 비유 |
|------|----------|------|
| **Producer** | 메시지를 보내는 쪽 | 택배 보내는 사람 |
| **Consumer** | 메시지를 받는 쪽 | 택배 찾아가는 사람 |
| **Queue** | 메시지가 쌓이는 곳 | 택배함 (보관함) |
| **Exchange** | 어느 큐로 보낼지 정하는 곳 | 택배 분류센터 |
| **Broker** | RabbitMQ 서버 자체 | 편의점 (택배함 있는 곳) |
| **VHOST** | 큐를 그룹으로 나눈 것 | 아파트 동 (1동, 2동...) |
| **Binding** | Exchange와 Queue 연결 | "이 택배는 3번 보관함으로" 규칙 |
| **아웃바운드** | 내부 → 외부로 나가는 방향 | 회사에서 외부로 택배 보내기 |

**전체 흐름:**

```
Producer가 메시지를 보냄
       ↓
   Exchange가 받음 (분류센터)
       ↓
   Binding 규칙에 따라 Queue 선택
       ↓
   Queue에 메시지 저장 (택배함)
       ↓
Consumer가 메시지를 가져감
```

### 1.3 아웃바운드 메시지큐란?

```
[내부 시스템] → [RabbitMQ] → [외부 시스템]
  Producer        Broker       Consumer
  (내부구간)                    (DMZ/외부)
```

내부 시스템에서 발생한 데이터를 외부 시스템으로 전달하는 구조

---

## 2. 네트워크 구성

### 2.1 구간 정의

```
┌─────────────────────────────────────────────────────────────────┐
│                         인터넷                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ (외부 통신)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         DMZ 구간                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   WAF/LB    │    │  Consumer   │    │  API G/W    │         │
│  │             │    │  (외부향)    │    │             │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                              ▲                                   │
└──────────────────────────────│───────────────────────────────────┘
                               │ (5672 포트)
                    ┌──────────┴──────────┐
                    │      방화벽          │
                    └──────────┬──────────┘
                               │
┌──────────────────────────────│───────────────────────────────────┐
│                         내부 구간                                 │
│                              │                                   │
│  ┌─────────────┐    ┌───────▼───────┐    ┌─────────────┐        │
│  │  Producer   │───▶│   RabbitMQ    │    │   DB/App    │        │
│  │  (내부 App) │    │   (Broker)    │    │   Server    │        │
│  └─────────────┘    └───────────────┘    └─────────────┘        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 RabbitMQ 배치 위치

**권장: 내부 구간에 배치**

| 배치 위치 | 장점 | 단점 |
|----------|------|------|
| **내부 구간 (권장)** | 보안 강화, 내부 시스템 접근 용이 | DMZ→내부 방화벽 오픈 필요 |
| DMZ 구간 | 외부 접근 용이 | 보안 취약, 내부 DB 접근 복잡 |

**이유:**
1. Producer(내부 App)가 RabbitMQ에 직접 접근 가능
2. 민감한 메시지 데이터가 내부에서 관리됨
3. 외부에서는 Consumer만 연결 (단방향 수신)

### 2.3 방화벽 정책

| 출발지 | 목적지 | 포트 | 용도 | 비고 |
|--------|--------|------|------|------|
| 내부 App 서버 | RabbitMQ | 5672 | AMQP 통신 | Producer 연결 |
| 내부 관리자 | RabbitMQ | 15672 | 관리 UI | 관리 목적 |
| DMZ Consumer | RabbitMQ | 5672 | AMQP 통신 | Consumer 연결 |
| DMZ Consumer | RabbitMQ | 5671 | AMQPS (TLS) | 보안 통신 (권장) |

---

## 3. 서버 구성

### 3.1 하드웨어 권장 사양

| 환경 | CPU | Memory | Disk | 비고 |
|------|-----|--------|------|------|
| 개발/테스트 | 2 Core | 4 GB | 50 GB SSD | 단일 노드 |
| 스테이징 | 4 Core | 8 GB | 100 GB SSD | 단일 노드 |
| 운영 (소규모) | 4 Core | 16 GB | 200 GB SSD | 클러스터 3노드 |
| 운영 (대규모) | 8 Core | 32 GB | 500 GB SSD | 클러스터 3노드 |

### 3.2 리소스별 중요도 및 RabbitMQ 동작 원리

> RabbitMQ는 **메모리 기반**으로 동작함. 디스크는 백업용.

#### 리소스 우선순위

```
1순위: Memory (메모리)  ★★★★★
2순위: Disk I/O (디스크) ★★★☆☆
3순위: CPU              ★★☆☆☆
4순위: Network          ★★☆☆☆
```

#### Memory (메모리) - 가장 중요

**왜 중요한가?**
- RabbitMQ는 메시지를 **메모리에 먼저 저장**함
- Consumer가 빨리 가져가면 → 메모리에서 바로 삭제 (디스크 안 씀)
- Consumer가 느리면 → 메시지가 메모리에 쌓임 → 터짐

**동작 원리:**

```
[정상 상황]
Producer → 메시지 → Memory → Consumer (빠르게 처리)
                     ↓
              (메모리에서 삭제)

[문제 상황 - Consumer가 느릴 때]
Producer → 메시지 → Memory에 쌓임 → 메모리 부족!
                         ↓
              Memory Alarm 발생 (Producer 차단)
                         ↓
              디스크로 밀어냄 (Page Out) → 느려짐
```

**Memory Alarm:**
- 기본값: 전체 메모리의 40% 사용 시 경고
- Alarm 발생 시: Producer 연결 차단 (메시지 발행 불가)
- 해결: Consumer 처리 속도 개선 또는 메모리 증설

| 상황 | 필요 메모리 |
|------|------------|
| 메시지 빠르게 처리됨 | 4~8 GB |
| 메시지가 쌓이는 경우 | 16~32 GB |
| 대용량 메시지 (1MB 이상) | 32 GB+ |

#### Disk (디스크) - 보조 저장소

**언제 디스크를 쓰는가?**
1. **Durable Queue** (영속성 큐) 설정 시 → 메시지를 디스크에도 저장
2. **Memory Alarm** 발생 시 → 메모리 메시지를 디스크로 이동
3. **서버 재시작** 시 → 디스크에서 메시지 복구

**동작 원리:**

```
[Durable Queue = false (기본)]
메시지 → Memory만 저장 → 서버 재시작 시 메시지 유실

[Durable Queue = true]
메시지 → Memory + Disk 동시 저장 → 서버 재시작해도 복구됨
         (성능 약간 저하)
```

**디스크 용량 계산:**
- 메시지 크기 × 예상 쌓일 개수 × 2배 (여유분)
- 예: 1KB 메시지 × 100만 개 = 약 2GB 필요

| 상황 | 필요 디스크 |
|------|------------|
| 메시지 빠르게 처리 | 50 GB |
| 메시지 쌓임 (Durable) | 100~200 GB |
| 장기 보관 필요 | 500 GB+ SSD |

**중요:** 반드시 **SSD** 사용. HDD는 Page Out 시 병목 발생.

#### CPU - 상대적으로 덜 중요

**CPU를 쓰는 작업:**
- 메시지 라우팅 (Exchange → Queue)
- TLS 암호화/복호화
- Management UI 통계 계산
- 클러스터 노드 간 동기화

**권장:**
- 일반: 4 Core
- TLS 사용 시: 8 Core (암호화 연산 때문)

#### 요약: 상황별 리소스 증설 가이드

| 증상 | 원인 | 해결책 |
|------|------|--------|
| Memory Alarm 발생 | 메시지 쌓임 | Consumer 개선 또는 **메모리 증설** |
| 디스크 Full | Durable 메시지 과적재 | 큐 정리 또는 **디스크 증설** |
| 메시지 처리 느림 | Page Out 발생 | **메모리 증설** (디스크 아님!) |
| TLS 연결 느림 | 암호화 부하 | **CPU 증설** |
| 클러스터 동기화 느림 | 노드 간 지연 | **네트워크 대역폭** 확인 |

### 3.3 OS 요구사항

- RHEL/Rocky Linux 8.x 이상
- Ubuntu 22.04 LTS 이상
- 시간 동기화 (NTP) 필수

### 3.3 클러스터 구성 (운영 환경)

```
┌─────────────────────────────────────────────────────┐
│                   내부 구간                          │
│                                                     │
│   ┌───────────┐  ┌───────────┐  ┌───────────┐     │
│   │ RabbitMQ  │  │ RabbitMQ  │  │ RabbitMQ  │     │
│   │  Node 1   │──│  Node 2   │──│  Node 3   │     │
│   │ (Master)  │  │ (Mirror)  │  │ (Mirror)  │     │
│   └───────────┘  └───────────┘  └───────────┘     │
│        │              │              │             │
│        └──────────────┴──────────────┘             │
│                       │                            │
│              ┌────────▼────────┐                   │
│              │    L4 / VIP     │                   │
│              │  (로드밸런서)    │                   │
│              └─────────────────┘                   │
│                       │                            │
└───────────────────────│────────────────────────────┘
                        │
              Producer / Consumer 연결
```

**클러스터 포트:**

| 포트 | 용도 |
|------|------|
| 4369 | EPMD (Erlang Port Mapper) |
| 5672 | AMQP 클라이언트 |
| 5671 | AMQPS (TLS) |
| 15672 | Management UI |
| 25672 | 클러스터 노드 간 통신 |

---

## 4. 설치 가이드

### 4.1 Docker 기반 설치 (권장)

#### docker-compose.yml (단일 노드)

```yaml
services:
  rabbitmq:
    image: rabbitmq:3-management
    container_name: rabbitmq
    hostname: rabbitmq-node1
    ports:
      - "5672:5672"      # AMQP
      - "5671:5671"      # AMQPS
      - "15672:15672"    # Management UI
    environment:
      RABBITMQ_DEFAULT_USER: admin
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD}  # 환경변수로 관리
      RABBITMQ_DEFAULT_VHOST: /production
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
      - ./rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf:ro
      - ./certs:/etc/rabbitmq/certs:ro  # TLS 인증서
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "check_running"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  rabbitmq_data:
```

#### 실행

```bash
# 비밀번호 환경변수 설정
export RABBITMQ_PASSWORD="your-secure-password"

# 컨테이너 실행
docker-compose up -d

# 상태 확인
docker ps
docker logs rabbitmq
```

### 4.2 패키지 설치 (VM/Bare Metal)

#### RHEL/Rocky Linux

```bash
# Erlang 저장소 추가
curl -s https://packagecloud.io/install/repositories/rabbitmq/erlang/script.rpm.sh | sudo bash

# RabbitMQ 저장소 추가
curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh | sudo bash

# 설치
sudo yum install -y erlang rabbitmq-server

# 서비스 시작
sudo systemctl enable rabbitmq-server
sudo systemctl start rabbitmq-server

# Management 플러그인 활성화
sudo rabbitmq-plugins enable rabbitmq_management
```

#### Ubuntu

```bash
# 저장소 추가
curl -1sLf 'https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/setup.deb.sh' | sudo bash
curl -1sLf 'https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/setup.deb.sh' | sudo bash

# 설치
sudo apt-get update
sudo apt-get install -y erlang-base rabbitmq-server

# 서비스 시작
sudo systemctl enable rabbitmq-server
sudo systemctl start rabbitmq-server
```

---

## 5. 보안 설정

### 5.1 계정 관리

```bash
# 기본 guest 계정 삭제 (운영 필수)
rabbitmqctl delete_user guest

# 관리자 계정 생성
rabbitmqctl add_user admin "secure-password"
rabbitmqctl set_user_tags admin administrator

# 애플리케이션 계정 생성 (Producer용)
rabbitmqctl add_user producer_app "producer-password"
rabbitmqctl set_permissions -p /production producer_app ".*" ".*" ""

# Consumer 계정 생성
rabbitmqctl add_user consumer_app "consumer-password"
rabbitmqctl set_permissions -p /production consumer_app "" "" ".*"
```

**권한 설명:**

| 계정 | configure | write | read | 용도 |
|------|-----------|-------|------|------|
| admin | .* | .* | .* | 전체 관리 |
| producer_app | .* | .* | (없음) | 메시지 발행만 |
| consumer_app | (없음) | (없음) | .* | 메시지 수신만 |

### 5.2 Virtual Host 분리

```bash
# 환경별 VHOST 생성
rabbitmqctl add_vhost /production
rabbitmqctl add_vhost /staging
rabbitmqctl add_vhost /development

# 용도별 VHOST 생성 (선택)
rabbitmqctl add_vhost /outbound-order      # 주문 아웃바운드
rabbitmqctl add_vhost /outbound-payment    # 결제 아웃바운드
```

### 5.3 TLS 설정 (DMZ 통신 필수)

#### rabbitmq.conf

```ini
# TLS 활성화
listeners.ssl.default = 5671

# 인증서 경로
ssl_options.cacertfile = /etc/rabbitmq/certs/ca_certificate.pem
ssl_options.certfile   = /etc/rabbitmq/certs/server_certificate.pem
ssl_options.keyfile    = /etc/rabbitmq/certs/server_key.pem

# TLS 버전 (1.2 이상만 허용)
ssl_options.versions.1 = tlsv1.2
ssl_options.versions.2 = tlsv1.3

# 클라이언트 인증서 검증 (선택)
ssl_options.verify = verify_peer
ssl_options.fail_if_no_peer_cert = true
```

---

## 6. 운영 가이드

### 6.1 모니터링 항목

| 항목 | 임계치 | 확인 방법 |
|------|--------|----------|
| 큐 메시지 수 | > 10,000 | Management UI / API |
| 메모리 사용률 | > 80% | `rabbitmqctl status` |
| 디스크 여유 | < 20% | 시스템 모니터링 |
| 연결 수 | > 1,000 | Management UI |
| Unacked 메시지 | > 100 | Consumer 처리 지연 의심 |

### 6.2 관리 명령어

```bash
# 상태 확인
rabbitmqctl status
rabbitmqctl list_queues name messages consumers

# 큐 메시지 수 확인
rabbitmqctl list_queues -p /production name messages

# 연결 확인
rabbitmqctl list_connections user peer_host peer_port state

# 클러스터 상태
rabbitmqctl cluster_status
```

### 6.3 백업/복구

```bash
# 정의 내보내기 (큐, Exchange, 바인딩)
rabbitmqctl export_definitions /backup/rabbitmq-definitions.json

# 정의 가져오기
rabbitmqctl import_definitions /backup/rabbitmq-definitions.json

# 데이터 디렉토리 백업 (메시지 포함)
tar -czvf rabbitmq-data-backup.tar.gz /var/lib/rabbitmq/
```

### 6.4 로그 위치

| 로그 | 경로 | 용도 |
|------|------|------|
| 서버 로그 | /var/log/rabbitmq/rabbit@hostname.log | 일반 로그 |
| 업그레이드 로그 | /var/log/rabbitmq/rabbit@hostname_upgrade.log | 업그레이드 |
| 감사 로그 | Management API로 조회 | 접근 기록 |

---

## 7. 장애 대응

### 7.1 일반적인 문제

| 증상 | 원인 | 해결 방법 |
|------|------|----------|
| 연결 거부 | 서비스 다운 | `systemctl restart rabbitmq-server` |
| 메시지 쌓임 | Consumer 다운 | Consumer 상태 확인, 재시작 |
| 디스크 Full | 메시지 과적재 | 큐 purge 또는 TTL 설정 |
| 메모리 부족 | 메시지 과적재 | Memory Alarm 확인, 큐 정리 |

### 7.2 클러스터 노드 장애

```bash
# 노드 상태 확인
rabbitmqctl cluster_status

# 장애 노드 제거 (필요시)
rabbitmqctl forget_cluster_node rabbit@failed-node

# 노드 재참여
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqctl join_cluster rabbit@master-node
rabbitmqctl start_app
```

---

## 8. 체크리스트

### 8.1 구축 전 확인

- [ ] 네트워크 구간 정의 완료 (DMZ/내부)
- [ ] 방화벽 정책 신청 (5672, 15672, 5671)
- [ ] 서버 사양 확정
- [ ] TLS 인증서 발급 (DMZ 통신용)
- [ ] 계정/권한 정책 수립

### 8.2 구축 후 확인

- [ ] RabbitMQ 서비스 정상 실행
- [ ] Management UI 접속 확인
- [ ] Producer 연결 테스트
- [ ] Consumer 연결 테스트 (DMZ → 내부)
- [ ] TLS 통신 확인
- [ ] 모니터링 연동 (Prometheus/Grafana)
- [ ] 백업 정책 수립

---

## 9. 참고 자료

- [RabbitMQ 공식 문서](https://www.rabbitmq.com/documentation.html)
- [RabbitMQ Clustering Guide](https://www.rabbitmq.com/clustering.html)
- [RabbitMQ TLS Support](https://www.rabbitmq.com/ssl.html)
- [RabbitMQ Production Checklist](https://www.rabbitmq.com/production-checklist.html)
