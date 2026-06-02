#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Run as root" >&2
  exit 1
fi

mkdir -p /opt/freebox-api
chmod 750 /opt/freebox-api

curl -fsSL \
  https://github.com/nbanb/fbx-delta-nba_bash_api.sh/raw/nbanb-freebox-api/fbx-delta-nba_bash_api.sh \
  -o /opt/freebox-api/fbx-delta-nba_bash_api.sh

chmod 700 /opt/freebox-api/fbx-delta-nba_bash_api.sh
