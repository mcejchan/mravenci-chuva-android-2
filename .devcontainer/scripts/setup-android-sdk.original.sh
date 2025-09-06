#!/usr/bin/env bash
# Install Android commandline-tools and base packages inside the container.
set -euo pipefail

# Debug: Print environment
echo "==> Debug: Current user: $(whoami)"
echo "==> Debug: SDK_ROOT will be: ${ANDROID_SDK_ROOT:-/opt/android-sdk}"
echo "==> Debug: PATH: $PATH"
echo "==> Debug: JAVA_HOME: ${JAVA_HOME}"
echo "==> Debug: Java installation check:"
ls -la /usr/lib/jvm/ || echo "JVM directory not found"
java -version || echo "Java not found in PATH"

SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
CMD_TOOLS_ZIP="commandlinetools-linux-11076708_latest.zip"
CMD_TOOLS_URL="https://dl.google.com/android/repository/${CMD_TOOLS_ZIP}"

echo "==> Preparing Android SDK in ${SDK_ROOT}"
mkdir -p /tmp/android && cd /tmp/android

# Download commandline-tools (update version if needed)
if [ ! -f "${CMD_TOOLS_ZIP}" ]; then
  echo "==> Downloading Android cmdline-tools..."
  wget -q "${CMD_TOOLS_URL}" -O "${CMD_TOOLS_ZIP}"
fi

echo "==> Unzipping cmdline-tools..."
sudo mkdir -p "${SDK_ROOT}/cmdline-tools"
sudo unzip -q -o "${CMD_TOOLS_ZIP}" -d "${SDK_ROOT}/cmdline-tools"

# Normalize folder name to .../cmdline-tools/latest
if [ -d "${SDK_ROOT}/cmdline-tools/cmdline-tools" ]; then
  sudo rm -rf "${SDK_ROOT}/cmdline-tools/latest" || true
  sudo mv "${SDK_ROOT}/cmdline-tools/cmdline-tools" "${SDK_ROOT}/cmdline-tools/latest"
fi

export PATH="${PATH}:${SDK_ROOT}/cmdline-tools/latest/bin"

echo "==> Accepting licenses..."
# Temporarily disable exit on error for license acceptance
set +e
yes | sudo "${SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager" --licenses 2>/dev/null
LICENSES_EXIT_CODE=$?
set -e
echo "License acceptance completed (exit code: $LICENSES_EXIT_CODE)"

echo "==> Installing platform-tools, build-tools, and platforms..."
sudo "${SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager" \
  "platform-tools" \
  "platforms;android-35" \
  "build-tools;35.0.0" \
  "extras;google;m2repository" \
  "extras;android;m2repository"

echo "==> Setting permissions for vscode user..."
sudo chown -R vscode:vscode "${SDK_ROOT}"

echo "==> Done. ANDROID_SDK_ROOT=${SDK_ROOT}"
