#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Run as root" >&2
  exit 1
fi

apt update
apt install -y curl openssl jq coreutils file python3-venv python3-pip dnsutils

python3 -m venv /opt/certbot-infomaniak
/opt/certbot-infomaniak/bin/pip install --upgrade pip
/opt/certbot-infomaniak/bin/pip install certbot certbot-dns-infomaniak

/opt/certbot-infomaniak/bin/certbot plugins
