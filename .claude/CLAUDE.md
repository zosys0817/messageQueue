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

## 테스트 시나리오

1. **연결**: RabbitMQ에 접속되는가?
2. **발행**: 큐에 메시지가 들어가는가?
3. **수신**: 큐에서 메시지를 꺼낼 수 있는가?

---

## [DevOps] 운영 시 추가 고려사항

> 학습 단계에서는 무시해도 됨. 운영 배포 전 체크

| 항목 | 학습용 | 운영용 |
|------|--------|--------|
| 계정 | guest/guest | 별도 계정 생성 필수 |
| 데이터 | 컨테이너 볼륨 | 외부 스토리지 or 클러스터 |
| 고가용성 | 단일 노드 | 클러스터 (3노드 권장) |
| 모니터링 | 웹UI 수동 확인 | Prometheus + Grafana |
| 백업 | 없음 | 정책 수립 필요 |
