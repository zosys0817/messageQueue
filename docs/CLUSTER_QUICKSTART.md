# RabbitMQ 클러스터 빠른 시작 가이드

> 15분 안에 3대 서버 클러스터 구성하기

## 전제조건

- RHEL/CentOS/Rocky Linux 8.x 서버 3대
- 서버 IP: 192.168.1.11, 192.168.1.12, 192.168.1.13
- Root 권한
- 서버 간 네트워크 통신 가능

## 1단계: 파일 준비 (3대 서버 공통)

```bash
# 프로젝트 클론 또는 파일 복사
cd /tmp
git clone https://github.com/your-repo/messageQueue.git
# 또는 scp로 파일 전송

cd messageQueue

# 스크립트 실행 권한 부여
chmod +x scripts/cluster/*.sh
```

## 2단계: 클러스터 구성

### Node 1 (192.168.1.11)

```bash
sudo scripts/cluster/setup-cluster.sh node1

# 출력 예시:
# [INFO] RabbitMQ Cluster Setup - node1
# [INFO] Setting hostname to rabbit-node1
# [INFO] Installing Erlang and RabbitMQ
# [INFO] Erlang Cookie: XMPLABCD...
# [INFO] Admin password: SecurePass...
# [INFO] Setup completed successfully!
```

**중요:** Erlang Cookie 저장! (다른 노드에서 사용)

```bash
# Erlang Cookie 확인
sudo cat /var/lib/rabbitmq/.erlang.cookie
```

### Node 2 (192.168.1.12)

```bash
# Node 1의 Erlang Cookie 환경변수로 설정
export ERLANG_COOKIE="[Node 1에서 복사한 Cookie]"

sudo scripts/cluster/setup-cluster.sh node2

# 출력 예시:
# [INFO] Joining cluster (node1)
# [INFO] Successfully joined cluster
```

### Node 3 (192.168.1.13)

```bash
# Node 1의 Erlang Cookie 환경변수로 설정
export ERLANG_COOKIE="[Node 1에서 복사한 Cookie]"

sudo scripts/cluster/setup-cluster.sh node3

# 출력 예시:
# [INFO] Successfully joined cluster
```

## 3단계: 클러스터 상태 확인

```bash
# 아무 노드에서 실행
sudo rabbitmqctl cluster_status

# 출력 예시:
# Cluster status of node rabbit@rabbit-node1 ...
# Disk Nodes:
# - rabbit@rabbit-node1
# - rabbit@rabbit-node2
# - rabbit@rabbit-node3
#
# Running Nodes:
# - rabbit@rabbit-node1
# - rabbit@rabbit-node2
# - rabbit@rabbit-node3
```

**확인 사항:**
- ✅ 3개 노드 모두 "Running Nodes"에 표시
- ✅ "Network Partitions" 없음

## 4단계: Management UI 접속

브라우저에서 접속:
- URL: http://192.168.1.11:15672
- 계정: admin
- 비밀번호: `/etc/rabbitmq/credentials.txt` 확인

```bash
# Node 1에서 비밀번호 확인
sudo cat /etc/rabbitmq/credentials.txt
```

## 5단계: 헬스체크 실행

```bash
# 아무 노드에서 실행
sudo scripts/cluster/health-check.sh

# 출력 예시:
# [INFO] RabbitMQ Health Check
# [INFO] ✓ RabbitMQ service is running
# [INFO] ✓ Node is healthy
# [INFO] ✓ All nodes are running (3/3)
# [INFO] ✓ No network partitions
# [INFO] Health check PASSED
```

## 6단계: 백업 설정 (선택)

```bash
# Cron 등록 (매일 새벽 2시)
sudo crontab -e

# 추가:
0 2 * * * /path/to/messageQueue/scripts/cluster/backup-rabbitmq.sh >> /var/log/rabbitmq-backup.log 2>&1
```

## 7단계: 애플리케이션 연결 테스트

```python
import pika

# 클러스터 연결 (단일 노드 연결)
connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host='192.168.1.11',  # 아무 노드나
        credentials=pika.PlainCredentials('producer_app', 'password')
    )
)

channel = connection.channel()

# Durable Queue 생성
channel.queue_declare(queue='test_cluster', durable=True)

# 메시지 발행
channel.basic_publish(
    exchange='',
    routing_key='test_cluster',
    body='Hello Cluster!',
    properties=pika.BasicProperties(delivery_mode=2)  # Persistent
)

print("Message sent to cluster!")
connection.close()
```

## 트러블슈팅

### 문제: Node 2/3이 클러스터에 참여하지 못함

**원인:** Erlang Cookie 불일치

**해결:**
```bash
# Node 2, 3에서 실행
sudo systemctl stop rabbitmq-server

# Node 1의 Cookie 복사
sudo tee /var/lib/rabbitmq/.erlang.cookie <<EOF
[Node 1의 Cookie 값]
EOF

sudo chmod 400 /var/lib/rabbitmq/.erlang.cookie
sudo chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie

# 재시도
sudo rabbitmqctl stop_app
sudo rabbitmqctl join_cluster rabbit@rabbit-node1
sudo rabbitmqctl start_app
```

### 문제: 포트 접근 불가

**원인:** 방화벽 차단

**해결:**
```bash
# 필수 포트 열기
sudo firewall-cmd --permanent --add-port=4369/tcp
sudo firewall-cmd --permanent --add-port=5672/tcp
sudo firewall-cmd --permanent --add-port=15672/tcp
sudo firewall-cmd --permanent --add-port=25672/tcp
sudo firewall-cmd --reload
```

### 문제: /etc/hosts 에러

**원인:** Hostname 해석 실패

**해결:**
```bash
# 3대 서버 모두 실행
sudo tee -a /etc/hosts <<EOF
192.168.1.11 rabbit-node1
192.168.1.12 rabbit-node2
192.168.1.13 rabbit-node3
EOF

# 연결 테스트
ping rabbit-node1
ping rabbit-node2
ping rabbit-node3
```

## 다음 단계

- [ ] HAProxy 로드밸런서 설정 ([가이드](rabbitmq-cluster-production-guide.md#haproxy-설정))
- [ ] Prometheus + Grafana 모니터링 설정 ([가이드](rabbitmq-cluster-production-guide.md#6-모니터링-설정))
- [ ] TLS 인증서 설정 ([TLS 가이드](rabbitmq-tls-guide.md))
- [ ] 운영 계정 추가 생성
- [ ] 장애 복구 테스트

## 참고 문서

- [운영 클러스터 구성 가이드](rabbitmq-cluster-production-guide.md) (전체 상세 가이드)
- [인프라 구축 가이드](rabbitmq-infra-guide.md) (네트워크 구성)
- [TLS 인증서 가이드](rabbitmq-tls-guide.md) (보안 통신)
