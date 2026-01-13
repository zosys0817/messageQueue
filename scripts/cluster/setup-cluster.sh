#!/bin/bash
# RabbitMQ 클러스터 자동 설정 스크립트
# 용도: 3대 서버에서 클러스터 구성 자동화
# 실행: sudo ./setup-cluster.sh [node1|node2|node3]

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 사용법 출력
usage() {
    cat <<EOF
Usage: sudo $0 [node1|node2|node3]

Example:
  Node 1: sudo $0 node1
  Node 2: sudo $0 node2
  Node 3: sudo $0 node3

Environment Variables (optional):
  NODE1_IP=192.168.1.11
  NODE2_IP=192.168.1.12
  NODE3_IP=192.168.1.13
  ERLANG_COOKIE=<your-cookie>
EOF
    exit 1
}

# Root 권한 확인
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (sudo)"
    exit 1
fi

# 인자 확인
if [ $# -ne 1 ]; then
    usage
fi

NODE_TYPE=$1

# 노드 타입 검증
if [[ ! "$NODE_TYPE" =~ ^(node1|node2|node3)$ ]]; then
    log_error "Invalid node type: $NODE_TYPE"
    usage
fi

# 환경변수 기본값
NODE1_IP=${NODE1_IP:-192.168.1.11}
NODE2_IP=${NODE2_IP:-192.168.1.12}
NODE3_IP=${NODE3_IP:-192.168.1.13}
ERLANG_COOKIE=${ERLANG_COOKIE:-$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)}

# Hostname 설정
HOSTNAMES=(
    [node1]="rabbit-node1"
    [node2]="rabbit-node2"
    [node3]="rabbit-node3"
)

CURRENT_HOSTNAME=${HOSTNAMES[$NODE_TYPE]}

log_info "========================================="
log_info "RabbitMQ Cluster Setup - $NODE_TYPE"
log_info "========================================="

# 1. Hostname 설정
log_info "Step 1: Setting hostname to $CURRENT_HOSTNAME"
hostnamectl set-hostname $CURRENT_HOSTNAME

# 2. /etc/hosts 설정
log_info "Step 2: Configuring /etc/hosts"
cat > /etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain
$NODE1_IP   rabbit-node1
$NODE2_IP   rabbit-node2
$NODE3_IP   rabbit-node3
EOF

# 3. 방화벽 설정
log_info "Step 3: Configuring firewall"
if systemctl is-active --quiet firewalld; then
    # 클러스터 통신 포트
    firewall-cmd --permanent --add-port=4369/tcp    # EPMD
    firewall-cmd --permanent --add-port=5672/tcp    # AMQP
    firewall-cmd --permanent --add-port=5671/tcp    # AMQPS
    firewall-cmd --permanent --add-port=15672/tcp   # Management UI
    firewall-cmd --permanent --add-port=25672/tcp   # Inter-node
    firewall-cmd --permanent --add-port=15692/tcp   # Prometheus

    firewall-cmd --reload
    log_info "Firewall rules added"
else
    log_warn "Firewalld not running, skipping firewall configuration"
fi

# 4. Erlang & RabbitMQ 설치
log_info "Step 4: Installing Erlang and RabbitMQ"

# Erlang 저장소
if [ ! -f /etc/yum.repos.d/rabbitmq_erlang.repo ]; then
    cat > /etc/yum.repos.d/rabbitmq_erlang.repo <<'EOF'
[rabbitmq_erlang]
name=rabbitmq_erlang
baseurl=https://packagecloud.io/rabbitmq/erlang/el/8/$basearch
repo_gpgcheck=1
gpgcheck=1
enabled=1
gpgkey=https://packagecloud.io/rabbitmq/erlang/gpgkey
       https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF
fi

# RabbitMQ 저장소
if [ ! -f /etc/yum.repos.d/rabbitmq_server.repo ]; then
    cat > /etc/yum.repos.d/rabbitmq_server.repo <<'EOF'
[rabbitmq_server]
name=rabbitmq_server
baseurl=https://packagecloud.io/rabbitmq/rabbitmq-server/el/8/$basearch
repo_gpgcheck=1
gpgcheck=1
enabled=1
gpgkey=https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey
       https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOF
fi

# 설치
yum install -y erlang rabbitmq-server

# 5. Erlang Cookie 설정
log_info "Step 5: Setting Erlang Cookie"
systemctl stop rabbitmq-server 2>/dev/null || true

echo "$ERLANG_COOKIE" > /var/lib/rabbitmq/.erlang.cookie
chmod 400 /var/lib/rabbitmq/.erlang.cookie
chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie

log_info "Erlang Cookie: $ERLANG_COOKIE"

# 6. RabbitMQ 설정 파일
log_info "Step 6: Creating rabbitmq.conf"
cat > /etc/rabbitmq/rabbitmq.conf <<EOF
# Cluster Configuration
cluster_name = production-cluster
cluster_partition_handling = autoheal

# Logging
log.console.level = info
log.file.level = info

# Memory
vm_memory_high_watermark.relative = 0.4
vm_memory_high_watermark_paging_ratio = 0.75

# Disk
disk_free_limit.absolute = 5GB

# Network
listeners.tcp.default = 5672
management.tcp.port = 15672
management.tcp.ip = 0.0.0.0

# Heartbeat
heartbeat = 60

# Performance
tcp_listen_options.backlog = 128
tcp_listen_options.nodelay = true
tcp_listen_options.sndbuf = 196608
tcp_listen_options.recbuf = 196608
EOF

# 7. 서비스 시작
log_info "Step 7: Starting RabbitMQ"
systemctl enable rabbitmq-server
systemctl start rabbitmq-server

# 플러그인 활성화
log_info "Step 8: Enabling plugins"
sleep 5  # RabbitMQ 시작 대기
rabbitmq-plugins enable rabbitmq_management
rabbitmq-plugins enable rabbitmq_prometheus

# 8. 클러스터 구성 (Node 2, 3만)
if [ "$NODE_TYPE" != "node1" ]; then
    log_info "Step 9: Joining cluster (node1)"

    # Node 1 연결 확인
    log_info "Checking connectivity to rabbit-node1..."
    if ! ping -c 1 rabbit-node1 &>/dev/null; then
        log_error "Cannot reach rabbit-node1. Check network and /etc/hosts"
        exit 1
    fi

    # 클러스터 참여
    rabbitmqctl stop_app
    rabbitmqctl reset
    rabbitmqctl join_cluster rabbit@rabbit-node1
    rabbitmqctl start_app

    log_info "Successfully joined cluster"
else
    log_info "Step 9: Skipped (This is node1 - master node)"
fi

# 9. 클러스터 상태 확인
log_info "Step 10: Checking cluster status"
sleep 2
rabbitmqctl cluster_status

# 10. 기본 계정 처리 (Node 1만)
if [ "$NODE_TYPE" == "node1" ]; then
    log_info "Step 11: Setting up users (node1 only)"

    # Admin 계정 생성
    ADMIN_PASS=$(openssl rand -base64 32)
    rabbitmqctl add_user admin "$ADMIN_PASS" 2>/dev/null || true
    rabbitmqctl set_user_tags admin administrator
    rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"

    log_info "Admin password: $ADMIN_PASS"
    echo "admin:$ADMIN_PASS" > /etc/rabbitmq/credentials.txt
    chmod 600 /etc/rabbitmq/credentials.txt

    log_warn "IMPORTANT: Save admin password from /etc/rabbitmq/credentials.txt"

    # guest 계정 삭제 (운영 환경)
    # rabbitmqctl delete_user guest
fi

log_info "========================================="
log_info "Setup completed successfully!"
log_info "========================================="
log_info ""
log_info "Next steps:"
if [ "$NODE_TYPE" == "node1" ]; then
    log_info "1. Run this script on node2 and node3"
    log_info "2. Access Management UI: http://$NODE1_IP:15672"
    log_info "3. Admin credentials: /etc/rabbitmq/credentials.txt"
else
    log_info "1. Verify cluster status: sudo rabbitmqctl cluster_status"
    log_info "2. Check Management UI: http://$NODE1_IP:15672"
fi
log_info ""
log_info "Erlang Cookie: $ERLANG_COOKIE"
log_info "(Save this for future node additions)"
