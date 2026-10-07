set -euo pipefail
HEALTH_URL="${HEALTH_URL:-http://localhost:8080/health}"
WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
WEBHOOK_TYPE="${ALERT_WEBHOOK_TYPE:-slack}"
echo "Checking StudyNow health..."
echo "URL: $HEALTH_URL"
HTTP_RESPONSE=$(curl -sS \
    -w "\n%{http_code}" \
    "$HEALTH_URL" || true)
HTTP_BODY=$(printf '%s\n' "$HTTP_RESPONSE" | sed '$d')
HTTP_STATUS=$(printf '%s\n' "$HTTP_RESPONSE" | tail -n 1)
echo "HTTP status: $HTTP_STATUS"
if [ "$HTTP_STATUS" = "200" ]; then
    echo "StudyNow health check: HEALTHY"
    printf '%s\n' "$HTTP_BODY"
    exit 0
fi
echo "StudyNow health check: UNHEALTHY"
printf '%s\n' "$HTTP_BODY"
if [ -z "$WEBHOOK_URL" ]; then
    echo "ALERT_WEBHOOK_URL is not configured."
    exit 1
fi
MESSAGE="StudyNow ALERT: health check failed. HTTP status: $HTTP_STATUS"
if [ "$WEBHOOK_TYPE" = "discord" ]; then
    curl -fsS \
      -H "Content-Type: application/json" \
      -d "{\"content\":\"$MESSAGE\"}" \
      "$WEBHOOK_URL"
else
    curl -fsS \
      -H "Content-Type: application/json" \
      -d "{\"text\":\"$MESSAGE\"}" \
      "$WEBHOOK_URL"
fi
echo ""
echo "Alert sent successfully."
exit 1
