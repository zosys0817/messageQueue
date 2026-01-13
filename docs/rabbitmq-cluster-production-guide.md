# RabbitMQ 운영 클러스터 구성 가이드

> 온프레미스 3대 서버 클러스터 | RHEL/CentOS/Rocky 환경

## 목차

1. [개요](#1-개요)
2. [클러스터 아키텍처](#2-클러스터-아키텍처)
3. [사전 준비사항](#3-사전-준비사항)
4. [설치 및 구성](#4-설치-및-구성)
5. [데이터 지속성 전략](#5-데이터-지속성-전략)
6. [모니터링 설정](#6-모니터링-설정)
7. [장애 복구 시나리오](#7-장애-복구-시나리오)
8. [운영 가이드](#8-운영-가이드)

---

## 1. 개요

### 1.1 클러스터란?

**아파트 택배함 3개를 서로 연결**해서 하나처럼 쓰는 것

```
[택배함 A] ──┐
              ├─── [전체가 하나의 시스템처럼 동작]
[택배함 B] ──┤
              │
[택배함 C] ──┘
```

**장점:**
- 한 곳이 고장나도 다른 곳에서 계속 동작 (고가용성)
- 메시지를 여러 노드에 복제 (데이터 안전성)
- 부하를 나눠서 처리 (성능)

### 1.2 환경 정보

| 항목 | 내용 |
|------|------|
| OS | RHEL/CentOS/Rocky Linux 8.x 이상 |
| 서버 대수 | 3대 (홀수 권장) |
| 네트워크 | 같은 서브넷 (예: 192.168.1.x) |
| RabbitMQ | 3.13.x 이상 |
| Erlang | 26.x 이상 |

---

## 2. 클러스터 아키텍처

### 2.1 전체 구성도

```
┌─────────────────────────────────────────────────────────────────┐
│                         내부 구간                                 │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ RabbitMQ-1   │  │ RabbitMQ-2   │  │ RabbitMQ-3   │          │
│  │              │  │              │  │              │          │
│  │ 192.168.1.11 │──│ 192.168.1.12 │──│ 192.168.1.13 │          │
│  │              │  │              │  │              │          │
│  │ rabbit-node1 │  │ rabbit-node2 │  │ rabbit-node3 │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                 │                   │
│         └─────────────────┴─────────────────┘                   │
│                           │                                     │
│                  ┌────────▼─────────┐                           │
│                  │   HAProxy / LB   │                           │
│                  │  192.168.1.10    │                           │
│                  │   (VIP)          │                           │
│                  └──────────────────┘                           │
│                           │                                     │
└───────────────────────────│─────────────────────────────────────┘
                            │
                   Application 연결
                   (단일 엔드포인트)
```

### 2.2 서버 구성

| 서버명 | IP | Hostname | 역할 | 비고 |
|--------|-------|----------|------|------|
| RabbitMQ-1 | 192.168.1.11 | rabbit-node1 | Master | 첫 번째 노드 |
| RabbitMQ-2 | 192.168.1.12 | rabbit-node2 | Mirror | 복제 노드 |
| RabbitMQ-3 | 192.168.1.13 | rabbit-node3 | Mirror | 복제 노드 |
| Load Balancer | 192.168.1.10 | rabbitmq-lb | VIP | HAProxy (선택) |

### 2.3 클러스터 통신 포트

| 포트 | 프로토콜 | 용도 | 방화벽 허용 |
|------|---------|------|------------|
| **4369** | TCP | EPMD (Erlang Port Mapper Daemon) | 노드 간 필수 |
| **5672** | TCP | AMQP 클라이언트 통신 | 클라이언트 ↔ 서버 |
| **5671** | TCP | AMQPS (TLS) | 클라이언트 ↔ 서버 |
| **15672** | TCP | Management UI/API | 관리자 접근 |
| **25672** | TCP | 클러스터 노드 간 통신 | 노드 간 필수 |

**방화벽 설정 예시:**

```bash
# 노드 간 통신 (3대 서버 모두)
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.11/32" port port="4369" protocol="tcp" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.12/32" port port="4369" protocol="tcp" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.13/32" port port="4369" protocol="tcp" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.11/32" port port="25672" protocol="tcp" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.12/32" port port="25672" protocol="tcp" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.13/32" port port="25672" protocol="tcp" accept'

# 클라이언트 통신 (애플리케이션 서브넷에서)
firewall-cmd --permanent --add-port=5672/tcp
firewall-cmd --permanent --add-port=5671/tcp

# 관리 UI (관리자 IP만)
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="15672" protocol="tcp" accept'

firewall-cmd --reload
```

---

## 3. 사전 준비사항

### 3.1 하드웨어 사양

| 환경 | CPU | Memory | Disk | 비고 |
|------|-----|--------|------|------|
| **운영 (소규모)** | 4 Core | 16 GB | 200 GB SSD | TPS < 1,000 |
| **운영 (중규모)** | 8 Core | 32 GB | 500 GB SSD | TPS < 5,000 |
| **운영 (대규모)** | 16 Core | 64 GB | 1 TB NVMe SSD | TPS > 5,000 |

### 3.2 OS 설정 (3대 서버 공통)

#### 3.2.1 Hostname 설정

```bash
# Node 1
sudo hostnamectl set-hostname rabbit-node1

# Node 2
sudo hostnamectl set-hostname rabbit-node2

# Node 3
sudo hostnamectl set-hostname rabbit-node3
```

#### 3.2.2 /etc/hosts 설정 (3대 모두 동일하게)

```bash
sudo tee -a /etc/hosts <<EOF
192.168.1.11 rabbit-node1
192.168.1.12 rabbit-node2
192.168.1.13 rabbit-node3
EOF
```

#### 3.2.3 시간 동기화 (NTP)

```bash
sudo yum install -y chrony
sudo systemctl enable chronyd
sudo systemctl start chronyd

# 시간 동기화 확인
chronyc sources
```

**중요:** 클러스터 노드 간 시간이 5초 이상 차이나면 클러스터링 실패!

#### 3.2.4 파일 디스크립터 제한 증가

```bash
sudo tee /etc/security/limits.d/90-rabbitmq.conf <<EOF
rabbitmq soft nofile 65536
rabbitmq hard nofile 65536
EOF
```

#### 3.2.5 SELinux 설정 (선택)

```bash
# SELinux 비활성화 (권장하지 않음)
# sudo setenforce 0

# 또는 RabbitMQ 포트 허용
sudo semanage port -a -t amqp_port_t -p tcp 5672
sudo semanage port -a -t amqp_port_t -p tcp 5671
sudo semanage port -a -t amqp_port_t -p tcp 15672
sudo semanage port -a -t amqp_port_t -p tcp 25672
sudo semanage port -a -t amqp_port_t -p tcp 4369
```

---

## 4. 설치 및 구성

### 4.1 RabbitMQ 설치 (3대 서버 모두)

#### 4.1.1 Erlang 설치

```bash
# Erlang 저장소 추가
sudo tee /etc/yum.repos.d/rabbitmq_erlang.repo <<EOF
[rabbitmq_erlang]
name=rabbitmq_erlang
baseurl=https://packagecloud.io/rabbitmq/erlang/el/8/\$basearch
repo_gpgcheck=1
gpgcheck=1
enabled=1
gpgkey=https://packagecloud.io/rabbitmq/erlang/gpgkey
       https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF

# Erlang 설치
sudo yum install -y erlang
```

#### 4.1.2 RabbitMQ 설치

```bash
# RabbitMQ 저장소 추가
sudo tee /etc/yum.repos.d/rabbitmq_server.repo <<EOF
[rabbitmq_server]
name=rabbitmq_server
baseurl=https://packagecloud.io/rabbitmq/rabbitmq-server/el/8/\$basearch
repo_gpgcheck=1
gpgcheck=1
enabled=1
gpgkey=https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey
       https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF

# RabbitMQ 설치
sudo yum install -y rabbitmq-server

# 서비스 활성화 (아직 시작하지 않음)
sudo systemctl enable rabbitmq-server
```

#### 4.1.3 버전 확인

```bash
erl -version
# Expected: Erlang 26.x

rabbitmq-server --version
# Expected: RabbitMQ 3.13.x
```

### 4.2 Erlang Cookie 동기화

클러스터 노드들이 서로 인증하기 위해 **동일한 Erlang Cookie**가 필요

#### 4.2.1 Node 1에서 Cookie 생성

```bash
# Node 1에서 실행
sudo systemctl start rabbitmq-server
sudo cat /var/lib/rabbitmq/.erlang.cookie
# 출력 예: XMPLABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890
```

#### 4.2.2 Node 2, 3에 Cookie 복사

```bash
# Node 2, 3에서 실행
sudo systemctl stop rabbitmq-server

# Node 1의 Cookie 값을 복사
sudo tee /var/lib/rabbitmq/.erlang.cookie <<EOF
XMPLABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890
EOF

sudo chmod 400 /var/lib/rabbitmq/.erlang.cookie
sudo chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
```

### 4.3 클러스터 구성

#### 4.3.1 모든 노드 시작

```bash
# Node 1, 2, 3 각각 실행
sudo systemctl start rabbitmq-server
sudo systemctl status rabbitmq-server
```

#### 4.3.2 Node 2, 3을 Node 1에 Join

```bash
# Node 2에서 실행
sudo rabbitmqctl stop_app
sudo rabbitmqctl reset
sudo rabbitmqctl join_cluster rabbit@rabbit-node1
sudo rabbitmqctl start_app

# Node 3에서 실행
sudo rabbitmqctl stop_app
sudo rabbitmqctl reset
sudo rabbitmqctl join_cluster rabbit@rabbit-node1
sudo rabbitmqctl start_app
```

#### 4.3.3 클러스터 상태 확인

```bash
# 아무 노드에서 실행
sudo rabbitmqctl cluster_status

# 출력 예시:
# Cluster status of node rabbit@rabbit-node1 ...
# Basics
#
# Cluster name: rabbit@rabbit-node1
#
# Disk Nodes
#
# rabbit@rabbit-node1
# rabbit@rabbit-node2
# rabbit@rabbit-node3
#
# Running Nodes
#
# rabbit@rabbit-node1
# rabbit@rabbit-node2
# rabbit@rabbit-node3
```

### 4.4 Management 플러그인 활성화

```bash
# 3대 서버 모두 실행
sudo rabbitmq-plugins enable rabbitmq_management
sudo rabbitmq-plugins enable rabbitmq_prometheus  # 모니터링용
```

### 4.5 기본 설정 파일 생성

#### 4.5.1 rabbitmq.conf (3대 서버 공통)

```bash
sudo tee /etc/rabbitmq/rabbitmq.conf <<EOF
# 클러스터 이름
cluster_name = production-cluster

# 로그 레벨
log.console.level = info

# 디스크 여유 공간 경고 (5GB 미만 시 경고)
disk_free_limit.absolute = 5GB

# 메모리 사용 제한 (전체의 40%)
vm_memory_high_watermark.relative = 0.4

# Heartbeat (클라이언트 연결 유지 확인 간격)
heartbeat = 60

# Management 플러그인
management.tcp.port = 15672
management.tcp.ip = 0.0.0.0

# 클러스터 파티션 처리 전략
# - ignore: 아무 조치 안 함 (기본값)
# - autoheal: 자동으로 복구 시도 (권장)
# - pause_minority: 소수 노드 일시정지
cluster_partition_handling = autoheal

# 네트워크 설정
tcp_listen_options.backlog = 128
tcp_listen_options.nodelay = true
tcp_listen_options.sndbuf = 196608
tcp_listen_options.recbuf = 196608
EOF
```

#### 4.5.2 서비스 재시작

```bash
# 3대 서버 모두 실행
sudo systemctl restart rabbitmq-server
```

### 4.6 클러스터 HA Policy 설정 (미러링)

클러스터가 구성되었으면 **큐를 여러 노드에 복제**하는 HA Policy를 설정해야 합니다.

#### 4.6.1 HA Policy 옵션

| 옵션 | 설명 | 사용 예 |
|------|------|---------|
| **ha-mode: all** | 모든 노드에 미러링 | 노드 추가 시 자동 복제 |
| **ha-mode: exactly** | 정확히 N개 노드에 미러링 | 3노드 클러스터에서 3 지정 |
| **ha-sync-mode: automatic** | 새 노드 join 시 자동 동기화 | 권장 |
| **ha-sync-mode: manual** | 수동 동기화 필요 | 대용량 큐에서만 |

#### 4.6.2 HA Policy 설정 (Node 1에서만 실행)

**옵션 A: 모든 큐를 3개 노드에 미러링 (권장)**

```bash
sudo rabbitmqctl set_policy ha-all ".*" \
  '{"ha-mode":"exactly","ha-params":3,"ha-sync-mode":"automatic"}' \
  --priority 0 --apply-to queues
```

**옵션 B: 모든 노드에 미러링 (유연성)**

```bash
# 노드가 추가되면 자동으로 모든 노드에 복제됨
sudo rabbitmqctl set_policy ha-all ".*" \
  '{"ha-mode":"all","ha-sync-mode":"automatic"}' \
  --priority 0 --apply-to queues
```

**옵션 C: 특정 패턴 큐만 미러링**

```bash
# "orders"로 시작하는 큐만 미러링
sudo rabbitmqctl set_policy ha-orders "^orders\." \
  '{"ha-mode":"exactly","ha-params":3,"ha-sync-mode":"automatic"}' \
  --priority 1 --apply-to queues

# "critical"이 포함된 큐만 미러링
sudo rabbitmqctl set_policy ha-critical "critical" \
  '{"ha-mode":"all","ha-sync-mode":"automatic"}' \
  --priority 2 --apply-to queues
```

#### 4.6.3 Policy 확인

```bash
# Policy 목록 확인
sudo rabbitmqctl list_policies

# 출력 예시:
# vhost  name     pattern  apply-to  definition                                              priority
# /      ha-all   .*       queues    {"ha-mode":"exactly","ha-params":3,"ha-sync-mode":"automatic"}  0
```

#### 4.6.4 큐별 미러링 상태 확인

```bash
# 큐별 미러링 노드 확인
sudo rabbitmqctl list_queues name policy slave_nodes synchronised_slave_nodes

# 출력 예시:
# orders  ha-all  [rabbit@rabbit-node2,rabbit@rabbit-node3]  [rabbit@rabbit-node2,rabbit@rabbit-node3]
```

**주의사항:**
- **기존 큐에 Policy 적용**: 새로 생성되는 큐부터 적용됨
- **기존 큐 동기화**: `rabbitmqctl sync_queue <queue-name>` 수동 실행 필요
- **성능**: 미러링은 약간의 성능 저하 발생 (쓰기 작업이 여러 노드에 복제됨)

---

## 5. 데이터 지속성 전략

### 5.1 옵션 비교

RabbitMQ는 **메모리 우선** 처리를 기본으로 하며, 디스크는 보조 수단

| 전략 | 성능 | 안정성 | 재시작 시 | 용도 |
|------|------|--------|-----------|------|
| **메모리 우선** | ★★★★★ | ★★☆☆☆ | 메시지 손실 | 실시간 이벤트, 로그 |
| **디스크 지속성** | ★★★☆☆ | ★★★★★ | 메시지 복구 | 주문, 결제, 중요 데이터 |
| **하이브리드** | ★★★★☆ | ★★★★☆ | 중요 메시지만 복구 | 일반적 운영 환경 |

### 5.2 메모리 우선 전략

**특징:**
- Queue를 `durable=false`로 생성
- 메시지를 `persistent=false`로 발행
- 서버 재시작 시 메시지 손실됨
- 최고 성능

**설정 예시 (Python pika):**

```python
import pika

connection = pika.BlockingConnection(
    pika.ConnectionParameters('192.168.1.10')
)
channel = connection.channel()

# Non-Durable Queue (메모리만)
channel.queue_declare(
    queue='logs',
    durable=False  # 재시작 시 큐 삭제
)

# Non-Persistent Message
channel.basic_publish(
    exchange='',
    routing_key='logs',
    body='Log message',
    properties=pika.BasicProperties(
        delivery_mode=1  # Non-persistent
    )
)
```

**언제 사용?**
- 실시간 로그 수집
- 이벤트 알림 (이메일, Slack)
- 캐시 무효화 메시지
- 일시적 작업 큐

### 5.3 디스크 지속성 전략

**특징:**
- Queue를 `durable=true`로 생성
- 메시지를 `persistent=true`로 발행
- 서버 재시작 시 메시지 복구됨
- 성능 약간 저하 (디스크 I/O)

**설정 예시 (Python pika):**

```python
# Durable Queue (디스크 저장)
channel.queue_declare(
    queue='orders',
    durable=True  # 재시작 후에도 큐 유지
)

# Persistent Message
channel.basic_publish(
    exchange='',
    routing_key='orders',
    body='Order data',
    properties=pika.BasicProperties(
        delivery_mode=2  # Persistent
    )
)
```

**언제 사용?**
- 주문/결제 처리
- 데이터베이스 변경 이벤트
- 이메일 발송 대기열
- 배치 작업

### 5.4 하이브리드 전략 (권장)

**구성:**
- **중요 큐** (주문, 결제): Durable + Persistent
- **일반 큐** (로그, 알림): Non-Durable + Non-Persistent

**예시:**

```python
# 중요: 주문 큐 (디스크 저장)
channel.queue_declare(queue='orders', durable=True)
channel.basic_publish(
    exchange='',
    routing_key='orders',
    body='Order #12345',
    properties=pika.BasicProperties(delivery_mode=2)
)

# 일반: 로그 큐 (메모리만)
channel.queue_declare(queue='logs', durable=False)
channel.basic_publish(
    exchange='',
    routing_key='logs',
    body='INFO: User logged in',
    properties=pika.BasicProperties(delivery_mode=1)
)
```

### 5.5 Quorum Queue (고급 - 클러스터 환경)

클러스터 환경에서 **더 강력한 데이터 안전성**을 원할 때 사용

**특징:**
- Raft 알고리즘 기반 (분산 합의)
- 메시지를 **다수 노드에 복제** (2/3 이상)
- 네트워크 파티션 시에도 안전

**설정:**

```python
channel.queue_declare(
    queue='critical-orders',
    durable=True,
    arguments={
        'x-queue-type': 'quorum'  # Quorum Queue 활성화
    }
)
```

**언제 사용?**
- 금융 거래
- 절대 손실 불가 데이터
- 규제 준수 필요 환경

**주의사항:**
- Classic Queue보다 약간 느림
- 최소 3노드 클러스터 필요

### 5.6 데이터 지속성 확인

```bash
# 큐 목록 및 durable 속성 확인
sudo rabbitmqctl list_queues name durable arguments

# 출력 예시:
# orders    true    []
# logs      false   []
# critical-orders  true  [{"x-queue-type","quorum"}]
```

### 5.7 클러스터 미러링 설정 (HA)

클러스터 환경에서 큐를 여러 노드에 복제하여 **단일 노드 장애 시에도 메시지를 보호**합니다.

#### 5.7.1 Classic Queue 미러링 vs Quorum Queue

| 비교 항목 | Classic Queue + HA Policy | Quorum Queue |
|---------|---------------------------|--------------|
| **설정 방법** | Policy로 미러링 활성화 | 큐 생성 시 `x-queue-type: quorum` |
| **복제 알고리즘** | Master-Slave (비동기) | Raft (동기 합의) |
| **데이터 안전성** | ★★★☆☆ | ★★★★★ |
| **성능** | ★★★★☆ | ★★★☆☆ |
| **네트워크 파티션** | 문제 가능 | 안전 |
| **권장 사용** | 기존 시스템, 일반 큐 | 신규 시스템, 중요 데이터 |
| **상태** | Deprecated 예정 (3.12+) | 권장 |

#### 5.7.2 Quorum Queue 사용 (권장)

**Python 예시:**

```python
import pika

connection = pika.BlockingConnection(
    pika.ConnectionParameters('192.168.1.10')  # HAProxy VIP
)
channel = connection.channel()

# Quorum Queue 생성 (자동으로 3노드에 복제)
channel.queue_declare(
    queue='orders',
    durable=True,
    arguments={
        'x-queue-type': 'quorum'
    }
)

# 메시지 발행
channel.basic_publish(
    exchange='',
    routing_key='orders',
    body='Order #12345',
    properties=pika.BasicProperties(delivery_mode=2)
)
```

**특징:**
- 자동으로 과반수(2/3) 노드에 복제
- 리더 노드 장애 시 자동 선출
- 네트워크 파티션 안전

#### 5.7.3 Classic Queue 미러링 (기존 시스템)

**HA Policy 설정 (Node 1에서):**

```bash
# 모든 큐를 3개 노드에 미러링
sudo rabbitmqctl set_policy ha-all ".*" \
  '{"ha-mode":"exactly","ha-params":3,"ha-sync-mode":"automatic"}' \
  --priority 0 --apply-to queues
```

**Python 예시:**

```python
# Classic Queue 생성 (일반 durable)
channel.queue_declare(
    queue='legacy-orders',
    durable=True
)

# Policy가 자동 적용되어 3노드에 미러링됨
```

#### 5.7.4 미러링 상태 확인

```bash
# 1. Policy 확인
sudo rabbitmqctl list_policies

# 2. 큐별 복제 상태 확인
sudo rabbitmqctl list_queues name policy slave_nodes synchronised_slave_nodes

# 3. Quorum Queue 리더 확인
sudo rabbitmqctl list_queues name type leader members

# 출력 예시:
# orders  quorum  rabbit@rabbit-node1  [rabbit@rabbit-node1,rabbit@rabbit-node2,rabbit@rabbit-node3]
```

#### 5.7.5 Management UI에서 확인

1. http://192.168.1.11:15672 접속
2. **Queues** 탭 클릭
3. 큐 목록에서 확인:
   - **Classic Queue**: `+2 mirrors` 표시
   - **Quorum Queue**: `Type: quorum`, `Members: 3` 표시

#### 5.7.6 기존 큐 동기화

Policy 적용 후 **기존 큐는 수동 동기화** 필요:

```bash
# 특정 큐 동기화
sudo rabbitmqctl sync_queue orders

# 모든 큐 동기화 (스크립트)
for queue in $(sudo rabbitmqctl list_queues -q name); do
    echo "Syncing queue: $queue"
    sudo rabbitmqctl sync_queue $queue
done
```

#### 5.7.7 미러링 동작 테스트

**테스트 시나리오:**

```bash
# 1. 테스트 큐 생성 (Node 1)
sudo rabbitmqctl eval 'rabbit_amqqueue:declare({resource, <<"/">>, queue, <<"test-ha">>}, true, false, [], none, <<"admin">>).'

# 2. 메시지 발행 (100개)
for i in {1..100}; do
    sudo rabbitmqctl eval "rabbit_basic:publish({resource, <<\"/\">>, exchange, <<>>}, <<\"test-ha\">>, false, false, {basic_message, {content, 60, {basic_properties, none, none, none, 2, none, none, none, none, none, none, none, none, none, none}, <<\"Message $i\">>, none}})."
done

# 3. 미러링 확인
sudo rabbitmqctl list_queues name messages slave_nodes

# 4. Node 2 정지
ssh rabbit-node2 'sudo systemctl stop rabbitmq-server'

# 5. 메시지 확인 (여전히 100개여야 함)
sudo rabbitmqctl list_queues name messages

# 6. Node 2 재시작 및 동기화 확인
ssh rabbit-node2 'sudo systemctl start rabbitmq-server'
sleep 10
sudo rabbitmqctl list_queues name messages synchronised_slave_nodes
```

#### 5.7.8 미러링 권장 사항

| 큐 유형 | 권장 미러링 전략 | 설정 |
|--------|----------------|------|
| **중요 데이터** | Quorum Queue | `x-queue-type: quorum` |
| **일반 작업 큐** | Classic + HA (exactly 3) | `ha-mode: exactly, ha-params: 3` |
| **임시 큐** | 미러링 없음 | Policy 미적용 |
| **대용량 로그** | 미러링 없음 또는 2개 노드 | `ha-mode: exactly, ha-params: 2` |

**성능 고려사항:**
- 미러링은 쓰기 성능을 약 30-50% 저하시킴
- 읽기 성능은 영향 거의 없음 (Master 노드에서만 읽음)
- Quorum Queue는 Classic보다 약간 더 느림 (합의 프로토콜)

---

## 6. 모니터링 설정

### 6.1 Prometheus + Grafana 구성

#### 6.1.1 Prometheus 설치 (별도 서버)

```bash
# Prometheus 다운로드
wget https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
tar -xzf prometheus-2.48.0.linux-amd64.tar.gz
sudo mv prometheus-2.48.0.linux-amd64 /opt/prometheus

# 설정 파일
sudo tee /opt/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'rabbitmq'
    static_configs:
      - targets:
          - '192.168.1.11:15692'  # Node 1
          - '192.168.1.12:15692'  # Node 2
          - '192.168.1.13:15692'  # Node 3
    metrics_path: '/metrics'
EOF

# Systemd 서비스
sudo tee /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
ExecStart=/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo useradd -rs /bin/false prometheus
sudo mkdir -p /opt/prometheus/data
sudo chown -R prometheus:prometheus /opt/prometheus
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
```

#### 6.1.2 Grafana 설치

```bash
# Grafana 저장소 추가
sudo tee /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
EOF

# 설치
sudo yum install -y grafana

# 시작
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

**접속:**
- URL: http://[grafana-server]:3000
- 기본 계정: admin / admin

#### 6.1.3 Grafana 대시보드 추가

1. Grafana 접속 후 **Data Sources** 추가
   - Type: Prometheus
   - URL: http://[prometheus-server]:9090

2. **Dashboard Import**
   - Dashboard ID: `10991` (RabbitMQ-Overview)
   - 또는 `11340` (RabbitMQ Cluster)

### 6.2 주요 모니터링 메트릭

| 메트릭 | 임계치 | 의미 | 조치 |
|--------|--------|------|------|
| **Memory Used** | > 80% | 메모리 부족 임박 | Consumer 처리 속도 확인 |
| **Disk Free** | < 5GB | 디스크 공간 부족 | 큐 정리 또는 디스크 증설 |
| **Queue Messages** | > 10,000 | 메시지 적체 | Consumer 증설 |
| **Unacked Messages** | > 100 | Consumer 처리 지연 | Consumer 상태 확인 |
| **Connection Churn** | 급증 | 연결 재시도 폭증 | 네트워크/인증 문제 |
| **Node Down** | 1개 이상 | 노드 장애 | 즉시 대응 |

### 6.3 알림 설정 (Prometheus Alertmanager)

```yaml
# /opt/prometheus/alert.rules.yml
groups:
  - name: rabbitmq
    interval: 30s
    rules:
      - alert: RabbitMQNodeDown
        expr: up{job="rabbitmq"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "RabbitMQ node down (instance {{ $labels.instance }})"

      - alert: RabbitMQMemoryHigh
        expr: rabbitmq_process_resident_memory_bytes / rabbitmq_resident_memory_limit_bytes > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "RabbitMQ memory usage > 80%"

      - alert: RabbitMQDiskSpaceLow
        expr: rabbitmq_disk_space_available_bytes < 5e9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "RabbitMQ disk space < 5GB"
```

---

## 7. 장애 복구 시나리오

### 7.1 단일 노드 장애

**증상:** 3대 중 1대 다운

**영향:**
- 클러스터 계속 운영 (2/3 정족수 유지)
- Quorum Queue는 정상 동작
- Classic Queue는 해당 노드의 메시지만 일시 접근 불가

**복구 절차:**

```bash
# 1. 장애 노드 확인
sudo rabbitmqctl cluster_status

# 2. 장애 노드 서버 접속 후 재시작
sudo systemctl restart rabbitmq-server

# 3. 클러스터 자동 재참여 확인
sudo rabbitmqctl cluster_status

# 4. 정상 복귀 확인
sudo rabbitmqctl node_health_check
```

**자동 복구되지 않을 경우:**

```bash
# 장애 노드에서
sudo rabbitmqctl stop_app
sudo rabbitmqctl join_cluster rabbit@rabbit-node1
sudo rabbitmqctl start_app
```

### 7.2 다수 노드 장애 (2대 이상 다운)

**증상:** 3대 중 2대 다운 → 클러스터 정지

**영향:**
- 클러스터 전체 서비스 중단
- 정족수(Quorum) 부족으로 쓰기 불가

**복구 절차:**

```bash
# 1. 모든 노드 정지 (안전한 재시작을 위해)
# Node 1, 2, 3 각각에서
sudo rabbitmqctl stop

# 2. 첫 번째 노드부터 시작
# Node 1에서
sudo rabbitmqctl start_app
sudo rabbitmqctl wait /var/lib/rabbitmq/mnesia/rabbit@rabbit-node1.pid

# 3. 나머지 노드 시작
# Node 2, 3에서
sudo rabbitmqctl start_app

# 4. 클러스터 상태 확인
sudo rabbitmqctl cluster_status
```

**강제 부팅 (최후 수단):**

```bash
# 정족수 무시하고 단일 노드로 시작
sudo rabbitmqctl force_boot
sudo rabbitmqctl start_app

# 다른 노드 재참여
# Node 2, 3에서
sudo rabbitmqctl stop_app
sudo rabbitmqctl join_cluster rabbit@rabbit-node1
sudo rabbitmqctl start_app
```

### 7.3 네트워크 파티션 (Split-Brain)

**증상:** 노드 간 통신 단절로 클러스터 분리

**확인:**

```bash
sudo rabbitmqctl cluster_status
# Partitions 항목에 노드 표시됨
```

**복구 (autoheal 전략 사용 시 자동):**

```bash
# 수동 복구
# 파티션된 노드에서
sudo rabbitmqctl stop_app
sudo rabbitmqctl start_app

# 해결 안 될 경우
sudo rabbitmqctl stop_app
sudo rabbitmqctl reset
sudo rabbitmqctl join_cluster rabbit@rabbit-node1
sudo rabbitmqctl start_app
```

### 7.4 데이터 손상 복구

**백업에서 복구:**

```bash
# 1. 서비스 정지
sudo systemctl stop rabbitmq-server

# 2. 데이터 디렉토리 교체
sudo mv /var/lib/rabbitmq /var/lib/rabbitmq.corrupted
sudo tar -xzf /backup/rabbitmq-data-backup.tar.gz -C /var/lib/

# 3. 권한 복구
sudo chown -R rabbitmq:rabbitmq /var/lib/rabbitmq

# 4. 서비스 시작
sudo systemctl start rabbitmq-server
```

### 7.5 장애 복구 체크리스트

- [ ] 장애 노드 식별 (`cluster_status`)
- [ ] 영향 범위 파악 (몇 대 다운?)
- [ ] 백업 확인 (최신 백업 존재?)
- [ ] 로그 확인 (`/var/log/rabbitmq/`)
- [ ] 네트워크 연결 확인 (ping, 방화벽)
- [ ] 디스크 공간 확인 (`df -h`)
- [ ] 메모리 상태 확인 (`free -h`)
- [ ] 복구 후 클러스터 상태 검증
- [ ] 애플리케이션 재연결 확인

---

## 8. 운영 가이드

### 8.1 보안 설정

#### 8.1.1 기본 계정 삭제

```bash
# Node 1에서만 실행 (클러스터 전체 반영됨)
sudo rabbitmqctl delete_user guest
```

#### 8.1.2 운영 계정 생성

```bash
# 관리자 계정
sudo rabbitmqctl add_user admin "$(openssl rand -base64 32)"
sudo rabbitmqctl set_user_tags admin administrator
sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"

# Producer 계정
sudo rabbitmqctl add_user producer_app "$(openssl rand -base64 32)"
sudo rabbitmqctl set_permissions -p / producer_app ".*" ".*" ""

# Consumer 계정
sudo rabbitmqctl add_user consumer_app "$(openssl rand -base64 32)"
sudo rabbitmqctl set_permissions -p / consumer_app "" "" ".*"
```

**비밀번호 안전하게 보관:**

```bash
# Secrets 파일에 저장 (권한 제한)
sudo tee /etc/rabbitmq/credentials.txt <<EOF
admin: [생성된 비밀번호]
producer_app: [생성된 비밀번호]
consumer_app: [생성된 비밀번호]
EOF
sudo chmod 600 /etc/rabbitmq/credentials.txt
```

### 8.2 백업 전략

#### 8.2.1 자동 백업 스크립트

```bash
sudo tee /usr/local/bin/rabbitmq-backup.sh <<'EOF'
#!/bin/bash
BACKUP_DIR=/backup/rabbitmq
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 정의 백업 (큐, Exchange, 바인딩)
rabbitmqctl export_definitions $BACKUP_DIR/definitions_$DATE.json

# 데이터 디렉토리 백업 (선택 - Durable Queue만 필요)
# tar -czf $BACKUP_DIR/data_$DATE.tar.gz /var/lib/rabbitmq

# 7일 이상 된 백업 삭제
find $BACKUP_DIR -name "definitions_*.json" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/definitions_$DATE.json"
EOF

sudo chmod +x /usr/local/bin/rabbitmq-backup.sh
```

#### 8.2.2 Cron 등록 (매일 새벽 2시)

```bash
sudo crontab -e
# 추가:
0 2 * * * /usr/local/bin/rabbitmq-backup.sh >> /var/log/rabbitmq-backup.log 2>&1
```

### 8.3 성능 튜닝

#### 8.3.1 메모리 최적화

```bash
# rabbitmq.conf 수정
sudo tee -a /etc/rabbitmq/rabbitmq.conf <<EOF
# 메모리 임계치 (40% → 60% 증가)
vm_memory_high_watermark.relative = 0.6

# Page 크기 최적화
vm_memory_high_watermark_paging_ratio = 0.75
EOF
```

#### 8.3.2 네트워크 튜닝

```bash
# OS 레벨 튜닝
sudo tee -a /etc/sysctl.conf <<EOF
# TCP 버퍼 크기
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# 연결 최적화
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 4096
EOF

sudo sysctl -p
```

### 8.4 로그 관리

```bash
# 로그 로테이션 설정
sudo tee /etc/logrotate.d/rabbitmq <<EOF
/var/log/rabbitmq/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
    postrotate
        rabbitmqctl rotate_logs > /dev/null
    endscript
}
EOF
```

### 8.5 업그레이드 절차

```bash
# 1. 백업
/usr/local/bin/rabbitmq-backup.sh

# 2. 한 번에 하나씩 업그레이드 (Node 3 → 2 → 1 순서)
# Node 3에서:
sudo yum update rabbitmq-server
sudo systemctl restart rabbitmq-server

# 클러스터 상태 확인
sudo rabbitmqctl cluster_status

# 정상 확인 후 Node 2, Node 1 순서대로 반복
```

### 8.6 일일 운영 체크리스트

- [ ] 클러스터 상태 확인 (`cluster_status`)
- [ ] 메모리/디스크 사용률 확인 (Grafana)
- [ ] 큐 메시지 적체 확인 (`list_queues`)
- [ ] 에러 로그 확인 (`/var/log/rabbitmq/`)
- [ ] 백업 성공 여부 확인
- [ ] Connection/Channel 수 모니터링
- [ ] Unacked 메시지 수 확인

---

## 9. 참고 자료

- [RabbitMQ Clustering Guide](https://www.rabbitmq.com/clustering.html)
- [RabbitMQ Production Checklist](https://www.rabbitmq.com/production-checklist.html)
- [RabbitMQ Quorum Queues](https://www.rabbitmq.com/quorum-queues.html)
- [RabbitMQ Monitoring](https://www.rabbitmq.com/monitoring.html)
- [Prometheus RabbitMQ Exporter](https://github.com/rabbitmq/rabbitmq-prometheus)

---

## 부록: 빠른 참조

### A. 주요 명령어

```bash
# 클러스터 상태
sudo rabbitmqctl cluster_status

# 큐 목록
sudo rabbitmqctl list_queues name messages consumers

# 연결 확인
sudo rabbitmqctl list_connections

# 노드 헬스체크
sudo rabbitmqctl node_health_check

# 메모리 상태
sudo rabbitmqctl status | grep memory
```

### B. 트러블슈팅

| 증상 | 확인 명령 | 해결 |
|------|-----------|------|
| 노드 연결 실패 | `ping rabbit-node1` | /etc/hosts 확인 |
| 클러스터 join 실패 | `cat .erlang.cookie` | Cookie 동기화 |
| 포트 접근 불가 | `firewall-cmd --list-all` | 방화벽 열기 |
| 메모리 알람 | `rabbitmqctl status` | Consumer 처리 개선 |
