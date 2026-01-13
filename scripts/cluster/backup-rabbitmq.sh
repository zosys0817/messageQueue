#!/bin/bash
# RabbitMQ 백업 스크립트
# 용도: 큐 정의 및 데이터 백업
# 실행: sudo ./backup-rabbitmq.sh

set -e

# 설정
BACKUP_DIR=/backup/rabbitmq
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# 색상
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Root 권한 확인
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (sudo)"
    exit 1
fi

log_info "========================================="
log_info "RabbitMQ Backup - $DATE"
log_info "========================================="

# 백업 디렉토리 생성
mkdir -p $BACKUP_DIR

# 1. 정의 백업 (큐, Exchange, 바인딩, 정책)
log_info "Step 1: Backing up definitions (queues, exchanges, bindings)"
rabbitmqctl export_definitions $BACKUP_DIR/definitions_$DATE.json

if [ $? -eq 0 ]; then
    log_info "Definitions backup completed: definitions_$DATE.json"

    # 파일 크기 출력
    SIZE=$(du -h $BACKUP_DIR/definitions_$DATE.json | awk '{print $1}')
    log_info "Backup size: $SIZE"
else
    log_error "Definitions backup failed"
    exit 1
fi

# 2. 데이터 백업 (선택 - Durable Queue만 필요)
# 주의: 데이터 디렉토리가 클 수 있음 (수십GB)
# 운영 환경에서는 스냅샷 또는 LVM 백업 권장

BACKUP_DATA=${BACKUP_DATA:-false}

if [ "$BACKUP_DATA" = "true" ]; then
    log_info "Step 2: Backing up data directory (this may take time)"

    # RabbitMQ 서비스 일시 정지 (선택)
    # systemctl stop rabbitmq-server

    tar -czf $BACKUP_DIR/data_$DATE.tar.gz /var/lib/rabbitmq/mnesia

    # 서비스 재시작 (정지했을 경우)
    # systemctl start rabbitmq-server

    if [ $? -eq 0 ]; then
        SIZE=$(du -h $BACKUP_DIR/data_$DATE.tar.gz | awk '{print $1}')
        log_info "Data backup completed: data_$DATE.tar.gz (Size: $SIZE)"
    else
        log_error "Data backup failed"
    fi
else
    log_info "Step 2: Skipping data backup (set BACKUP_DATA=true to enable)"
fi

# 3. 설정 파일 백업
log_info "Step 3: Backing up configuration files"
mkdir -p $BACKUP_DIR/config_$DATE
cp -r /etc/rabbitmq/* $BACKUP_DIR/config_$DATE/ 2>/dev/null || true

if [ -d $BACKUP_DIR/config_$DATE ]; then
    log_info "Configuration backup completed: config_$DATE"
fi

# 4. 클러스터 상태 저장
log_info "Step 4: Saving cluster status"
rabbitmqctl cluster_status > $BACKUP_DIR/cluster_status_$DATE.txt
rabbitmqctl list_queues name messages consumers durable > $BACKUP_DIR/queues_$DATE.txt
rabbitmqctl list_users > $BACKUP_DIR/users_$DATE.txt

# 5. 백업 파일 압축
log_info "Step 5: Compressing backup files"
cd $BACKUP_DIR
tar -czf rabbitmq_backup_$DATE.tar.gz \
    definitions_$DATE.json \
    cluster_status_$DATE.txt \
    queues_$DATE.txt \
    users_$DATE.txt \
    config_$DATE

# 압축 성공 시 원본 삭제
if [ $? -eq 0 ]; then
    rm -f definitions_$DATE.json cluster_status_$DATE.txt queues_$DATE.txt users_$DATE.txt
    rm -rf config_$DATE

    BACKUP_FILE="rabbitmq_backup_$DATE.tar.gz"
    SIZE=$(du -h $BACKUP_DIR/$BACKUP_FILE | awk '{print $1}')
    log_info "Compressed backup: $BACKUP_FILE (Size: $SIZE)"
fi

# 6. 오래된 백업 삭제
log_info "Step 6: Cleaning up old backups (>$RETENTION_DAYS days)"
find $BACKUP_DIR -name "rabbitmq_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "data_*.tar.gz" -mtime +$RETENTION_DAYS -delete

REMAINING=$(ls -1 $BACKUP_DIR/rabbitmq_backup_*.tar.gz 2>/dev/null | wc -l)
log_info "Remaining backups: $REMAINING files"

# 7. 원격 백업 (선택 - S3, NFS 등)
REMOTE_BACKUP=${REMOTE_BACKUP:-false}

if [ "$REMOTE_BACKUP" = "true" ]; then
    log_info "Step 7: Uploading to remote storage"

    # S3 예시 (AWS CLI 필요)
    # aws s3 cp $BACKUP_DIR/$BACKUP_FILE s3://my-bucket/rabbitmq-backups/

    # rsync 예시 (원격 서버)
    # rsync -avz $BACKUP_DIR/$BACKUP_FILE backup-server:/backup/rabbitmq/

    log_warn "Remote backup not configured (set REMOTE_BACKUP=true and configure)"
else
    log_info "Step 7: Skipping remote backup"
fi

log_info "========================================="
log_info "Backup completed successfully!"
log_info "========================================="
log_info "Backup location: $BACKUP_DIR/$BACKUP_FILE"
log_info ""
log_info "To restore:"
log_info "  1. Extract: tar -xzf $BACKUP_FILE"
log_info "  2. Import: rabbitmqctl import_definitions definitions_$DATE.json"
log_info ""

# 슬랙/이메일 알림 (선택)
# curl -X POST -H 'Content-type: application/json' \
#   --data '{"text":"RabbitMQ backup completed: '$BACKUP_FILE'"}' \
#   YOUR_SLACK_WEBHOOK_URL
