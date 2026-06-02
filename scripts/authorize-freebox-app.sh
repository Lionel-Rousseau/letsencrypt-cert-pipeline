#!/usr/bin/env bash
# Run this script from an interactive root shell.
# Validate the application authorization on the Freebox when prompted.
set +e
set +u

APP_ID="${1:-fr.example.freebox.certdeploy}"
APP_NAME="${2:-Freebox Cert Deploy}"
APP_VERSION="${3:-1.0.0}"
DEVICE_NAME="${4:-linux-host}"

debug=0
pretty=1

source /opt/freebox-api/fbx-delta-nba_bash_api.sh

authorize_application \
  "$APP_ID" \
  "$APP_NAME" \
  "$APP_VERSION" \
  "$DEVICE_NAME"

echo
echo "MY_APP_ID=${MY_APP_ID:-}"
echo "MY_APP_TOKEN_LENGTH=${#MY_APP_TOKEN}"
echo
echo "If MY_APP_TOKEN_LENGTH is non-zero, store MY_APP_TOKEN in:"
echo "  /root/.secrets/freebox/freebox-cert.env"
echo
echo "Do not paste the token in public logs or tickets."
