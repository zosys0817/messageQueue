# Message Queue Project

> RabbitMQ 메시지큐 학습 | 인프라/DevOps 관점

## 메시지큐란?

**편의점 택배함**이라고 생각하면 됨

```
[보내는 사람] → [택배함] → [받는 사람]
  Producer       Queue      Consumer
```

| 용어 | 택배함 비유 | 실제 의미 |
|------|------------|----------|
| Queue | 택배함 | 메시지 임시 보관소 |
| Producer | 택배 보내는 사람 | 메시지 넣는 프로그램 |
| Consumer | 택배 받는 사람 | 메시지 꺼내는 프로그램 |
| pika | 택배함 열쇠 | Python용 RabbitMQ 클라이언트 |

**왜 씀?**
- 받는 쪽이 바빠도 메시지가 안 사라짐 (버퍼)
- 서로 기다릴 필요 없음 (비동기 처리)
- 한꺼번에 몰려도 순서대로 처리 (부하 분산)

## RabbitMQ 포트 정리

| 포트 | 용도 | 비유 |
|------|------|------|
| 5672 | 메시지 통신 | 택배 넣고 빼는 문 |
| 15672 | 관리 웹화면 | CCTV 모니터 |

## 인프라 관리자 체크리스트

| 단계 | 확인 항목 | 명령어/방법 |
|------|----------|------------|
| 1 | 컨테이너 실행 | `docker ps` |
| 2 | 포트 열림 | `netstat -an | grep 5672` |
| 3 | 웹UI 접속 | http://localhost:15672 |
| 4 | 연결 테스트 | Python 스크립트 |
| 5 | 메시지 흐름 | send → receive |

## Stack

- Python 3.11+ / pika (RabbitMQ 클라이언트)
- RabbitMQ 3.x (Docker)
- pytest (테스트)

## Commands

### 학습용 (Docker)

```bash
# 1. RabbitMQ 실행
docker-compose up -d

# 2. 상태 확인
docker ps
docker logs rabbitmq

# 3. Management UI
# http://localhost:15672 (guest/guest)

# 4. Python 의존성
pip install pika python-dotenv

# 5. 테스트
pytest -v
```

### 운영용 (클러스터)

```bash
# 1. 클러스터 설정 (3대 서버 각각)
sudo scripts/cluster/setup-cluster.sh [node1|node2|node3]

# 2. 클러스터 상태
sudo rabbitmqctl cluster_status

# 3. 헬스체크
sudo scripts/cluster/health-check.sh

# 4. 백업
sudo scripts/cluster/backup-rabbitmq.sh
```

## 테스트 시나리오

1. **연결**: RabbitMQ에 접속되는가?
2. **발행**: 큐에 메시지가 들어가는가?
3. **수신**: 큐에서 메시지를 꺼낼 수 있는가?

---

## 운영 환경 (클러스터)

### 구성

- **환경**: 온프레미스 RHEL/CentOS/Rocky Linux
- **노드**: 3대 서버 (192.168.1.11-13)
- **네트워크**: 같은 서브넷
- **데이터 지속성**: 하이브리드 (메모리 우선 + 디스크 옵션)
- **모니터링**: Prometheus + Grafana

### 가이드 문서

| 문서 | 내용 |
|------|------|
| [운영 클러스터 구성](../docs/rabbitmq-cluster-production-guide.md) | 전체 설정 가이드 |
| [rabbitmq.conf](../configs/cluster/rabbitmq.conf) | 클러스터 설정 템플릿 |
| [haproxy.cfg](../configs/cluster/haproxy.cfg) | 로드밸런서 설정 |

### 스크립트

| 스크립트 | 용도 |
|---------|------|
| setup-cluster.sh | 클러스터 자동 구성 |
| backup-rabbitmq.sh | 일일 백업 (Cron) |
| health-check.sh | 헬스체크 모니터링 |

### 학습용 vs 운영용 비교

| 항목 | 학습용 | 운영용 (클러스터) |
|------|--------|-----------------|
| 계정 | guest/guest | 별도 계정 생성 필수 |
| 노드 수 | 단일 노드 | 3노드 클러스터 |
| 데이터 | 컨테이너 볼륨 | 디스크 지속성 + 복제 |
| 고가용성 | 없음 | 자동 장애조치 |
| 모니터링 | 웹UI 수동 확인 | Prometheus + Grafana |
| 백업 | 없음 | 일일 자동 백업 |
| 로드밸런서 | 없음 | HAProxy |
