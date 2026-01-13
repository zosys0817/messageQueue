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

## Quick Start

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

## 문서

| 문서 | 내용 |
|------|------|
| [인프라 구축 가이드](docs/rabbitmq-infra-guide.md) | DMZ/내부구간 구성, 하드웨어 사양, 방화벽 정책 |
| [TLS 인증서 가이드](docs/rabbitmq-tls-guide.md) | 인증서 발급, 서버 설정, 클라이언트 연결 |
| [운영 클러스터 구성 가이드](docs/rabbitmq-cluster-production-guide.md) | 온프레미스 3대 서버 클러스터, 데이터 지속성, 모니터링, 장애 복구 |

## Stack

- Python 3.11+ / pika (RabbitMQ 클라이언트)
- RabbitMQ 3.x (Docker)
- pytest (테스트)

## 프로젝트 구조

```
messageQueue/
├── docs/
│   ├── rabbitmq-infra-guide.md                    # 인프라 구축 가이드
│   ├── rabbitmq-tls-guide.md                      # TLS 인증서 가이드
│   └── rabbitmq-cluster-production-guide.md       # 운영 클러스터 구성 가이드
├── configs/
│   └── cluster/
│       ├── rabbitmq.conf                          # 클러스터 설정 파일
│       └── haproxy.cfg                            # 로드밸런서 설정
├── scripts/
│   └── cluster/
│       ├── setup-cluster.sh                       # 클러스터 자동 설정
│       ├── backup-rabbitmq.sh                     # 백업 스크립트
│       └── health-check.sh                        # 헬스체크 스크립트
├── src/message_queue/
│   ├── __init__.py
│   └── config.py                                  # RabbitMQ 연결 설정
├── tests/
│   └── test_connection.py                         # 연결 테스트
├── docker-compose.yml                             # RabbitMQ 컨테이너 (학습용)
├── pyproject.toml                                 # Python 프로젝트 설정
└── .env.example                                   # 환경변수 템플릿
```

## 테스트 시나리오

1. **연결**: RabbitMQ에 접속되는가?
2. **발행**: 큐에 메시지가 들어가는가?
3. **수신**: 큐에서 메시지를 꺼낼 수 있는가?

---

## 운영 클러스터 구성

온프레미스 환경에서 3대 서버로 고가용성 클러스터를 구성하는 방법은 [운영 클러스터 구성 가이드](docs/rabbitmq-cluster-production-guide.md)를 참조하세요.

**빠른 시작:**

```bash
# 1. 클러스터 자동 설정 (3대 서버 각각 실행)
sudo chmod +x scripts/cluster/setup-cluster.sh

# Node 1 (Master)
sudo ./scripts/cluster/setup-cluster.sh node1

# Node 2, 3 (Mirrors)
sudo ./scripts/cluster/setup-cluster.sh node2
sudo ./scripts/cluster/setup-cluster.sh node3

# 2. 클러스터 상태 확인
sudo rabbitmqctl cluster_status

# 3. 헬스체크 실행
sudo chmod +x scripts/cluster/health-check.sh
sudo ./scripts/cluster/health-check.sh

# 4. 백업 설정 (Cron)
sudo chmod +x scripts/cluster/backup-rabbitmq.sh
sudo crontab -e
# 추가: 0 2 * * * /path/to/backup-rabbitmq.sh
```

**주요 기능:**
- 3노드 클러스터 자동 구성
- HAProxy 로드밸런싱
- Prometheus + Grafana 모니터링
- 데이터 지속성 전략 (메모리/디스크/하이브리드)
- 자동 백업 및 복구
- 장애 대응 시나리오

---

## [DevOps] 학습용 vs 운영용 비교

| 항목 | 학습용 (현재) | 운영용 (클러스터) |
|------|-------------|-----------------|
| 계정 | guest/guest | 별도 계정 생성 필수 |
| 노드 수 | 단일 노드 | 3노드 클러스터 |
| 데이터 | 컨테이너 볼륨 | 디스크 지속성 + 복제 |
| 고가용성 | 없음 | 자동 장애조치 |
| 모니터링 | 웹UI 수동 확인 | Prometheus + Grafana |
| 백업 | 없음 | 일일 자동 백업 |
| 로드밸런서 | 없음 | HAProxy |
