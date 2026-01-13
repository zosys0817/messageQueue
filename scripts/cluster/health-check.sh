#!/bin/bash
# RabbitMQ 클러스터 헬스체크 스크립트
# 용도: 클러스터 상태 모니터링 및 알림
# 실행: ./health-check.sh (일반 사용자)
# Cron: */5 * * * * /path/to/health-check.sh

set -e

# 설정
ALERT_EMAIL=${ALERT_EMAIL:-""}
ALERT_SLACK=${ALERT_SLACK:-""}
LOG_FILE="/var/log/rabbitmq/health-check.log"

# 색상
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 종료 코드
EXIT_CODE=0

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a $LOG_FILE
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a $LOG_FILE
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a $LOG_FILE
    EXIT_CODE=1
}

send_alert() {
    local message="$1"

    # 이메일 알림
    if [ -n "$ALERT_EMAIL" ]; then
        echo "$message" | mail -s "[RabbitMQ Alert] Health Check Failed" $ALERT_EMAIL
    fi

    # Slack 알림
    if [ -n "$ALERT_SLACK" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data '{"text":"'"$message"'"}' \
            $ALERT_SLACK
    fi
}

echo "=========================================" | tee -a $LOG_FILE
echo "RabbitMQ Health Check - $(date)" | tee -a $LOG_FILE
echo "=========================================" | tee -a $LOG_FILE

# 1. RabbitMQ 서비스 상태 확인
log_info "Check 1: RabbitMQ Service Status"
if sudo systemctl is-active --quiet rabbitmq-server; then
    log_info "✓ RabbitMQ service is running"
else
    log_error "✗ RabbitMQ service is NOT running"
    send_alert "RabbitMQ service is down on $(hostname)"
fi

# 2. 노드 헬스체크
log_info "Check 2: Node Health"
if sudo rabbitmqctl node_health_check &>/dev/null; then
    log_info "✓ Node is healthy"
else
    log_error "✗ Node health check failed"
    send_alert "RabbitMQ node health check failed on $(hostname)"
fi

# 3. 클러스터 상태 확인
log_info "Check 3: Cluster Status"
CLUSTER_STATUS=$(sudo rabbitmqctl cluster_status 2>&1)

# 3-1. Running Nodes 확인
RUNNING_NODES=$(echo "$CLUSTER_STATUS" | grep -A 10 "Running Nodes" | grep -c "rabbit@" || echo "0")
log_info "Running nodes: $RUNNING_NODES/3"

if [ "$RUNNING_NODES" -lt 3 ]; then
    log_error "✗ Not all nodes are running ($RUNNING_NODES/3)"
    send_alert "RabbitMQ cluster has only $RUNNING_NODES/3 nodes running"
else
    log_info "✓ All nodes are running"
fi

# 3-2. Network Partitions 확인
PARTITIONS=$(echo "$CLUSTER_STATUS" | grep -A 5 "Network Partitions" | grep -c "rabbit@" || echo "0")
if [ "$PARTITIONS" -gt 0 ]; then
    log_error "✗ Network partition detected!"
    send_alert "RabbitMQ network partition detected on $(hostname)"
else
    log_info "✓ No network partitions"
fi

# 4. 메모리 사용률 확인
log_info "Check 4: Memory Usage"
MEMORY_INFO=$(sudo rabbitmqctl status 2>/dev/null | grep -A 10 "Memory")
MEMORY_ALARM=$(echo "$MEMORY_INFO" | grep "vm_memory_high_watermark" || echo "")

if echo "$MEMORY_ALARM" | grep -q "true"; then
    log_error "✗ Memory alarm is active!"
    send_alert "RabbitMQ memory alarm on $(hostname)"
else
    log_info "✓ Memory usage is normal"
fi

# 5. 디스크 공간 확인
log_info "Check 5: Disk Space"
DISK_FREE=$(df -h /var/lib/rabbitmq | awk 'NR==2 {print $4}')
DISK_PERCENT=$(df -h /var/lib/rabbitmq | awk 'NR==2 {print $5}' | tr -d '%')

log_info "Disk free: $DISK_FREE (Used: $DISK_PERCENT%)"

if [ "$DISK_PERCENT" -gt 90 ]; then
    log_error "✗ Disk usage is too high (${DISK_PERCENT}%)"
    send_alert "RabbitMQ disk usage > 90% on $(hostname)"
elif [ "$DISK_PERCENT" -gt 80 ]; then
    log_warn "⚠ Disk usage is high (${DISK_PERCENT}%)"
else
    log_info "✓ Disk space is sufficient"
fi

# 6. 큐 메시지 적체 확인
log_info "Check 6: Queue Messages"
QUEUE_INFO=$(sudo rabbitmqctl list_queues name messages 2>/dev/null)

# 메시지 10,000개 이상 큐 확인
LARGE_QUEUES=$(echo "$QUEUE_INFO" | awk '$2 > 10000 {print $1": "$2}')

if [ -n "$LARGE_QUEUES" ]; then
    log_warn "⚠ Large queues detected (>10,000 messages):"
    echo "$LARGE_QUEUES" | while read line; do
        log_warn "  - $line"
    done
else
    log_info "✓ No large queues"
fi

# 7. Unacked 메시지 확인
log_info "Check 7: Unacked Messages"
UNACKED_INFO=$(sudo rabbitmqctl list_queues name messages_unacknowledged 2>/dev/null)

# Unacked 100개 이상 큐 확인
UNACKED_QUEUES=$(echo "$UNACKED_INFO" | awk '$2 > 100 {print $1": "$2}')

if [ -n "$UNACKED_QUEUES" ]; then
    log_warn "⚠ High unacked messages (>100):"
    echo "$UNACKED_QUEUES" | while read line; do
        log_warn "  - $line"
    done
    send_alert "RabbitMQ high unacked messages on $(hostname): $UNACKED_QUEUES"
else
    log_info "✓ Unacked messages are normal"
fi

# 8. 연결 수 확인
log_info "Check 8: Connections"
CONNECTIONS=$(sudo rabbitmqctl list_connections 2>/dev/null | wc -l)
log_info "Active connections: $CONNECTIONS"

if [ "$CONNECTIONS" -gt 1000 ]; then
    log_warn "⚠ High number of connections ($CONNECTIONS)"
else
    log_info "✓ Connection count is normal"
fi

# 9. Management UI 접근 확인
log_info "Check 9: Management UI"
if curl -s -u guest:guest http://localhost:15672/api/overview &>/dev/null; then
    log_info "✓ Management UI is accessible"
else
    log_warn "⚠ Management UI check failed (may need credentials)"
fi

# 결과 요약
echo "=========================================" | tee -a $LOG_FILE
if [ $EXIT_CODE -eq 0 ]; then
    log_info "Health check PASSED - All checks OK"
else
    log_error "Health check FAILED - See errors above"
fi
echo "=========================================" | tee -a $LOG_FILE

exit $EXIT_CODE
