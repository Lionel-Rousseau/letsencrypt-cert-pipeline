#!/usr/bin/env bash
# Run this script from an interactive root shell.
# Validate the application authorization on the Freebox when prompted.
set +e
set +u

LIB="${FREEBOX_API_LIB:-/opt/freebox-api/fbx-delta-nba_bash_api.sh}"

if [[ ! -r "$LIB" ]]; then
  echo "[ERROR] Freebox API library not found: $LIB" >&2
  echo "[ERROR] Run scripts/install-freebox-api-lib.sh first." >&2
  exit 1
fi

APP_ID="${1:-fr.example.freebox.certdeploy}"
APP_NAME="${2:-Freebox Cert Deploy}"
APP_VERSION="${3:-1.0.0}"
DEVICE_NAME="${4:-linux-host}"

debug=0
pretty=1

source "$LIB"

authorize_application \
  "$APP_ID" \
  "$APP_NAME" \
  "$APP_VERSION" \
  "$DEVICE_NAME"

echo

if [[ -n "${MY_APP_TOKEN:-}" ]]; then
  echo "Authorization successful. Copy the following into:"
  echo "  /root/.secrets/freebox/freebox-cert.env"
  echo
  echo "FREEBOX_APP_ID=\"${MY_APP_ID:-$APP_ID}\""
  echo "FREEBOX_APP_TOKEN=\"${MY_APP_TOKEN}\""
else
  echo "[ERROR] MY_APP_TOKEN is empty — authorization may have failed or timed out."
  echo "Check that you validated the request on the Freebox screen."
  exit 1
fi

echo
echo "Do not paste this token in public logs or tickets."
