#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <PUBLIC_IP>" >&2
    exit 1
fi

PUBLIC_IP="$1"
BASE_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
COMPOSE_DIR="$BASE_DIR/compose"

echo "Validating Docker status..."
cd "$COMPOSE_DIR"
docker compose ps

if [ ! -f "$BASE_DIR/targets.txt" ]; then
    echo "ERROR: targets.txt not found. Run setup.sh first."
    exit 1
fi

TARGET_COUNT=$(wc -l < "$BASE_DIR/targets.txt")
if [ "$TARGET_COUNT" -ne 1000 ]; then
    echo "WARNING: Expected 1000 targets, got $TARGET_COUNT."
else
    echo "PASS: 1000 targets verified."
fi

echo "Running endpoint tests..."
IP="$PUBLIC_IP"
tests=(
    "ok-001.$IP.sslip.io/get:200"
    "redirect-001.$IP.sslip.io/:302"
    "rl-001.$IP.sslip.io/:200"
    "delay1s-001.$IP.sslip.io/:200"
    "big-001.$IP.sslip.io/bytes/1048576:200"
    "err-001.$IP.sslip.io/:500"
    "waf-001.$IP.sslip.io/?q=union%20select:403"
    "waf-001.$IP.sslip.io/:200"
)

for test in "${tests[@]}"; do
    endpoint="${test%%:*}"
    expected="${test##*:}"
    code=$(curl -s -o /dev/null -w "%{http_code}" "http://$endpoint")
    if [ "$code" = "$expected" ]; then
        echo "PASS: $endpoint -> $code"
    else
        echo "FAIL: $endpoint -> $code (expected $expected)"
    fi
done

echo "Validation complete!"