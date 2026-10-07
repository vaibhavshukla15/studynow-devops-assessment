#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$PROJECT_DIR/backup-work"
RESTORE_DIR="$PROJECT_DIR/restore-evidence"
mkdir -p "$BACKUP_DIR" "$RESTORE_DIR"
ENCRYPTED_BACKUP="${1:-}"
if [ -z "$ENCRYPTED_BACKUP" ]; then
    echo "Usage:"
    echo "./scripts/restore.sh <encrypted-backup-file>"
    exit 1
fi
if [ ! -f "$ENCRYPTED_BACKUP" ]; then
    echo "ERROR: Backup file not found: $ENCRYPTED_BACKUP"
    exit 1
fi
ARCHIVE_NAME="restore.archive.gz"
echo "======================================"
echo "StudyNow MongoDB Restore"
echo "======================================"
START_TIME=$(date +%s)
echo "[1/5] Decrypting backup..."
docker run --rm \
  -v "$BACKUP_DIR:/work" \
  -v "$(dirname "$ENCRYPTED_BACKUP"):/backup:ro" \
  studynow-backup-tools \
  --batch \
  --yes \
  --pinentry-mode loopback \
  --passphrase "$BACKUP_PASSPHRASE" \
  --decrypt \
  -o "/work/$ARCHIVE_NAME" \
  "/backup/$(basename "$ENCRYPTED_BACKUP")"
echo "[2/5] Validating decrypted archive..."
docker run --rm \
  -v "$BACKUP_DIR:/backup" \
  alpine:3.20 \
  sh -c "apk add --no-cache gzip >/dev/null && gzip -t /backup/$ARCHIVE_NAME"
echo "[3/5] Restoring MongoDB..."
docker run --rm \
  --network container:studynow-mongo \
  -v "$BACKUP_DIR:/backup" \
  mongo:7 \
  mongorestore \
  --host 127.0.0.1 \
  --port 27017 \
  --username "${MONGO_ROOT_USER:-admin}" \
  --password "${MONGO_ROOT_PASSWORD}" \
  --authenticationDatabase admin \
  --archive="/backup/$ARCHIVE_NAME" \
  --gzip \
  --drop
echo "[4/5] Checking application health..."
sleep 5
curl -fsS http://localhost:8080/health
echo ""
END_TIME=$(date +%s)
RTO_SECONDS=$((END_TIME - START_TIME))
echo "[5/5] Restore completed."
echo ""
echo "======================================"
echo "RESTORE SUCCESSFUL"
echo "RTO: ${RTO_SECONDS} seconds"
echo "======================================"
cat > "$RESTORE_DIR/last-restore-result.txt" <<EOF
StudyNow MongoDB Restore Drill
Backup:
$(basename "$ENCRYPTED_BACKUP")
Restore Date:
$(date -u)
Restore Status:
SUCCESS
RTO:
${RTO_SECONDS} seconds
Application Health:
SUCCESS
Target RTO:
4 hours
Target RPO:
1 hour
EOF
echo "Evidence written to:"
echo "$RESTORE_DIR/last-restore-result.txt"
