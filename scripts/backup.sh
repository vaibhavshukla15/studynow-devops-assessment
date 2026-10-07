#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$PROJECT_DIR/.env"
    set +a
fi

: "${MONGO_ROOT_USER:?MONGO_ROOT_USER is required}"
: "${MONGO_ROOT_PASSWORD:?MONGO_ROOT_PASSWORD is required}"
: "${BACKUP_PASSPHRASE:?BACKUP_PASSPHRASE is required}"

BACKUP_DIR="$PROJECT_DIR/backup-work"
PRIMARY_DIR="$PROJECT_DIR/backups"
OFFSITE_DIR="$PROJECT_DIR/offsite-backup"

TIMESTAMP="$(date -u +"%Y%m%d-%H%M%S")"
ARCHIVE_NAME="studynow-$TIMESTAMP.archive.gz"
ENCRYPTED_NAME="$ARCHIVE_NAME.gpg"

mkdir -p "$BACKUP_DIR" "$PRIMARY_DIR" "$OFFSITE_DIR"

cleanup() {
    rm -f "$BACKUP_DIR/$ARCHIVE_NAME"
}

trap cleanup EXIT

echo "======================================"
echo "StudyNow MongoDB Backup"
echo "======================================"
echo "Timestamp: $TIMESTAMP"

echo "[1/5] Creating MongoDB dump..."

docker run --rm \
  --network container:studynow-mongo \
  -v "$BACKUP_DIR:/backup" \
  mongo:7 \
  mongodump \
  --host 127.0.0.1 \
  --port 27017 \
  --username "$MONGO_ROOT_USER" \
  --password "$MONGO_ROOT_PASSWORD" \
  --authenticationDatabase admin \
  --db studynow \
  --archive="/backup/$ARCHIVE_NAME" \
  --gzip

echo "[2/5] Validating gzip archive..."

docker run --rm \
  -v "$BACKUP_DIR:/backup" \
  alpine:3.20 \
  sh -c "apk add --no-cache gzip >/dev/null && gzip -t /backup/$ARCHIVE_NAME"

echo "[3/5] Encrypting backup with GPG AES-256..."

docker run --rm \
  -v "$BACKUP_DIR:/work" \
  studynow-backup-tools \
  --batch \
  --yes \
  --pinentry-mode loopback \
  --passphrase "$BACKUP_PASSPHRASE" \
  --symmetric \
  --cipher-algo AES256 \
  -o "/work/$ENCRYPTED_NAME" \
  "/work/$ARCHIVE_NAME"

echo "[4/5] Copying encrypted backup to primary storage..."

cp "$BACKUP_DIR/$ENCRYPTED_NAME" \
   "$PRIMARY_DIR/$ENCRYPTED_NAME"

echo "[5/5] Copying encrypted backup to offsite storage..."

cp "$BACKUP_DIR/$ENCRYPTED_NAME" \
   "$OFFSITE_DIR/$ENCRYPTED_NAME"

echo ""
echo "Backup completed successfully."
echo "Encrypted backup: $ENCRYPTED_NAME"
echo "Primary: $PRIMARY_DIR/$ENCRYPTED_NAME"
echo "Offsite: $OFFSITE_DIR/$ENCRYPTED_NAME"
echo ""