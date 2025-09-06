#!/usr/bin/env bash
# Helper notes: connect container ADB client to host ADB server (recommended).
# Requires devcontainer.json runArg: --add-host=host.docker.internal:host-gateway

set -e
echo "ADB_SERVER_SOCKET is set to: ${ADB_SERVER_SOCKET:-tcp:host.docker.internal:5037}"
echo "Listing devices via host ADB server..."
adb devices
