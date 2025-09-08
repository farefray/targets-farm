#!/usr/bin/env bash
set -euo pipefail

CERT_DIR=${CERT_DIR:-/etc/nginx/certs}
DOMAIN=${DOMAIN:-*.185-53-209-170.sslip.io}
CRT=${CERT_DIR}/wildcard.crt
KEY=${CERT_DIR}/wildcard.key

mkdir -p "${CERT_DIR}"

if [[ -f "${CRT}" && -f "${KEY}" ]]; then
  echo "TLS cert already present."
  exit 0
fi

echo "Generating self-signed cert for ${DOMAIN}"
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -subj "/CN=${DOMAIN}" \
  -addext "subjectAltName=DNS:${DOMAIN},DNS:*.185.53.209.170.sslip.io" \
  -keyout "${KEY}" -out "${CRT}"

chmod 600 "${KEY}"
echo "Done."
