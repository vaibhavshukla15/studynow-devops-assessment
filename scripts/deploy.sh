#!/usr/bin/env bash
set -euo pipefail
ACTIVE_FILE=".active_color"
if [ -f "$ACTIVE_FILE" ]; then
    ACTIVE=$(cat "$ACTIVE_FILE")
else
    ACTIVE="blue"
    echo "blue" > "$ACTIVE_FILE"
fi
if [ "$ACTIVE" = "blue" ]; then
    TARGET="green"
else
    TARGET="blue"
fi
echo "======================================"
echo "Current environment : $ACTIVE"
echo "Target environment  : $TARGET"
echo "======================================"
rollback() {
    echo ""
    echo "======================================"
    echo "DEPLOYMENT FAILED - ROLLING BACK"
    echo "======================================"
    sed -i -E "s/server app_(blue|green):3000;/server app_$ACTIVE:3000;/" nginx/nginx.conf
    if docker compose exec -T nginx nginx -t; then
        docker compose exec -T nginx nginx -s reload || true
    fi
    docker compose stop "app_$TARGET" || true
    echo "$ACTIVE" > "$ACTIVE_FILE"
    echo "Traffic restored to: $ACTIVE"
}
trap rollback ERR
echo "[1/6] Building and starting $TARGET..."
docker compose up -d --build "app_$TARGET"
echo "[2/6] Waiting for $TARGET health..."
HEALTHY=false
for i in {1..30}; do
    STATUS=$(docker inspect \
        --format '{{.State.Health.Status}}' \
        "studynow-app-$TARGET" 2>/dev/null || true)
    echo "Health status: $STATUS"
    if [ "$STATUS" = "healthy" ]; then
        HEALTHY=true
        break
    fi
    sleep 2
done
if [ "$HEALTHY" != "true" ]; then
    echo "ERROR: $TARGET failed health check."
    docker compose logs --tail=100 "app_$TARGET"
    exit 1
fi
echo "[3/6] Switching NGINX traffic to $TARGET..."
sed -i -E "s/server app_(blue|green):3000;/server app_$TARGET:3000;/" nginx/nginx.conf
echo "[4/6] Validating NGINX configuration..."
docker compose exec -T nginx nginx -t
echo "[5/6] Reloading NGINX..."
docker compose exec -T nginx nginx -s reload
echo "[6/6] Verifying application..."
sleep 2
curl -fsS http://localhost:8080/health
echo "$TARGET" > "$ACTIVE_FILE"
trap - ERR
echo ""
echo "======================================"
echo "DEPLOYMENT SUCCESSFUL"
echo "======================================"
echo "Previous environment : $ACTIVE"
echo "Active environment   : $TARGET"
echo "======================================"
