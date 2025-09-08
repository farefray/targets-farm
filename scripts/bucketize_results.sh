#!/usr/bin/env bash
set -euo pipefail
OUTFILE="${1:-results.jsonl}"

# Bucket name is the leftmost label (ok-, rl-, delay1s-, etc.)
echo "Findings by bucket:"
awk -F'"' '/host/ {print $4}' "$OUTFILE" \
 | sed -E 's|https?://([^/]+).*|\1|' \
 | sed -E 's|^([a-z0-9]+)-[0-9]+\.|\1|' \
 | sort | uniq -c | sort -nr

echo
echo "HTTP codes distribution (from proxy logs):"
docker logs tf-proxy 2>&1 \
 | awk '{print $2}' \
 | sort | uniq -c | sort -nr | head -20