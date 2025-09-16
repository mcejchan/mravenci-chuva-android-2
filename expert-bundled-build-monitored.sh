#!/bin/bash
# Expert Bundled Build Script - Monitored Version
# Creates APK with bundled JS (no Metro needed)
# Now with comprehensive monitoring and progress reporting
set -euo pipefail

# Check if we're being called by the monitoring wrapper
if [[ "${MONITORED_PROCESS:-}" != "true" ]]; then
    # Delegate to monitoring wrapper
    WRAPPER_SCRIPT="$(dirname "$0")/monitoring-wrapper.sh"
    if [[ -x "$WRAPPER_SCRIPT" ]]; then
        echo "🔄 Delegating to monitoring wrapper for better progress tracking..."
        export MONITORED_PROCESS="true"
        exec "$WRAPPER_SCRIPT" -n "bundled-build" -i 30 -t 1800 -- "$0" "$@"
    else
        echo "⚠️ Monitoring wrapper not found at $WRAPPER_SCRIPT - running without monitoring"
    fi
fi

echo "🚀 Expert Bundled Build Script Starting..."
echo "📅 $(date)"

# ADB to host (emulator is on host)
export ANDROID_ADB_SERVER_ADDRESS=${ANDROID_ADB_SERVER_ADDRESS:-host.docker.internal}
export ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT:-5037}

echo "💾 Memory:"
free -h

# Step 1: Environment verification
echo "🔍 Env"
echo "CWD: $(pwd)"
echo "Java: $(java -version 2>&1 | head -1)"
free -h | grep Mem || true

REQUIRED_GB=${REQUIRED_GB:-15}
TOTAL_MEM_GB=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}')
echo "Total memory: ${TOTAL_MEM_GB}GB (required >= ${REQUIRED_GB}GB)"
if [[ $TOTAL_MEM_GB -lt $REQUIRED_GB ]]; then
  echo "❌ Not enough memory for stable build"
  exit 1
fi

# Step 2: Project root
cd hello-world

# Step 3: Ensure expo-asset is present (native module must be in APK)
echo "📦 Checking expo-asset"
if node -p "require('expo-asset/package.json').version" >/dev/null 2>&1; then
  echo "✅ expo-asset present"
else
  echo "ℹ️ Installing expo-asset aligned with SDK"
  npx expo install expo-asset
fi

# Step 4: gradle.properties guard (light)
echo "⚙️ gradle.properties"
GP=android/gradle.properties
mkdir -p android
touch "$GP"
grep -q '^org.gradle.jvmargs=-Xmx6144m' "$GP" || echo 'org.gradle.jvmargs=-Xmx6144m -XX:MaxMetaspaceSize=768m -Dfile.encoding=UTF-8 -XX:+HeapDumpOnOutOfMemoryError' >> "$GP"
grep -q '^org.gradle.daemon=' "$GP" || echo 'org.gradle.daemon=false' >> "$GP"
grep -q '^org.gradle.parallel=' "$GP" || echo 'org.gradle.parallel=false' >> "$GP"
grep -q '^org.gradle.workers.max=' "$GP" || echo 'org.gradle.workers.max=1' >> "$GP"

# Step 5: Build (bundle JS + install)
echo "🔨 Bundling + install"
export EXPO_BUNDLE_IN_DEBUG=true
cd android
./gradlew --stop || true
pkill -f gradle || true
sleep 2

# Start build with progress monitoring
BUILD_START_TIME=$(date +%s)
echo "Starting build at $(date)"
echo "Expected: JS bundling + Android compilation + APK installation"

set +e
# Expert QA build type - non-debuggable variant for bundled JS
echo "Building QA variant (debuggable=false for JS bundling)..."
./gradlew :app:assembleQa :app:installQa \
  --no-daemon --no-parallel --max-workers=1 \
  --console=plain --info --stacktrace &

BUILD_PID=$!

# Monitor build progress
while kill -0 $BUILD_PID 2>/dev/null; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - BUILD_START_TIME))
    MINUTES=$((ELAPSED / 60))
    SECONDS=$((ELAPSED % 60))

    if [[ $((ELAPSED % 60)) -eq 0 ]]; then  # Every minute
        echo "⏱️  Build progress: ${MINUTES}m ${SECONDS}s elapsed - bundling JS and compiling Android"
        free -h | grep Mem | head -1
    fi
    sleep 10
done

wait $BUILD_PID
RC=$?
set -e

if [[ $RC -ne 0 ]]; then
  echo "❌ Build/install failed (rc=$RC)"
  echo "Memory status at failure:"
  free -h | grep Mem
  exit $RC
fi

# Step 6: Verify QA APK + embedded JS (stay in android/)
APK_PATH="app/build/outputs/apk/qa/app-qa.apk"
echo "🎯 Verify APK at: $APK_PATH"
if [[ -f "$APK_PATH" ]]; then
  ls -lh "$APK_PATH"

  # Check APK freshness (must be newer than 5 minutes)
  echo "🕐 Checking APK freshness..."
  APK_AGE_MINUTES=$(( ($(date +%s) - $(stat -c %Y "$APK_PATH")) / 60 ))
  echo "APK age: ${APK_AGE_MINUTES} minutes"

  if [[ $APK_AGE_MINUTES -gt 5 ]]; then
    echo "⚠️ APK is older than 5 minutes - build may have failed silently"
    echo "Expected: fresh APK from this build run"
    exit 1
  else
    echo "✅ APK is fresh (${APK_AGE_MINUTES} minutes old)"
  fi

  echo "🔍 Checking for index.android.bundle inside APK"
  if unzip -l "$APK_PATH" | grep -q "index.android.bundle"; then
    echo "✅ Bundled JS present – Metro not required"
  else
    echo "⚠️ index.android.bundle not found – build is not bundled"
    exit 1
  fi
else
  echo "❌ APK not found"
  exit 1
fi

BUILD_END_TIME=$(date +%s)
TOTAL_BUILD_TIME=$((BUILD_END_TIME - BUILD_START_TIME))
TOTAL_MINUTES=$((TOTAL_BUILD_TIME / 60))
TOTAL_SECONDS=$((TOTAL_BUILD_TIME % 60))

echo ""
echo "🎉 Done – APK installed and ready for Appium"
echo "⏱️  Total build time: ${TOTAL_MINUTES}m ${TOTAL_SECONDS}s"
echo "📱 APK: $APK_PATH"