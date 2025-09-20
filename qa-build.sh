#!/bin/bash
set -e

echo "🏗️ QA Build Script Starting..."
echo "📅 $(date)"

# Navigate to android directory
cd hello-world/android

# Environment verification
echo "🔍 Environment:"
echo "CWD: $(pwd)"
echo "Java: $(java -version 2>&1 | head -1)"
free -h | grep Mem || true

# Check if prebuild was done
if [[ ! -f "build.gradle" || ! -d "app" ]]; then
    echo "❌ Android project not found!"
    echo "Please run prebuild first: npm run prebuild:qa"
    exit 1
fi

# Memory check (require at least 15GB total RAM)
TOTAL_MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [[ $TOTAL_MEM_GB -lt 15 ]]; then
  echo "⚠️ Warning: Low memory ($TOTAL_MEM_GB GB). Build may fail."
  echo "Expert recommendation: 15+ GB RAM required"
else
  echo "✅ Memory check passed ($TOTAL_MEM_GB GB available)"
fi

# Gradle daemon check
echo "🛠️ Stopping any running Gradle daemons..."
./gradlew --stop || true

echo "🔨 Starting QA build..."
echo "Expected: JS bundling + Android compilation"

BUILD_START_TIME=$(date +%s)
echo "Starting build at $(date)"

# QA build - assembles APK with embedded JS bundle
set +e
./gradlew :app:assembleQa \
  --no-daemon --no-parallel --max-workers=1 \
  --console=plain --info --stacktrace

RC=$?
set -e

BUILD_END_TIME=$(date +%s)
BUILD_DURATION=$(( (BUILD_END_TIME - BUILD_START_TIME) / 60 ))

echo "Build completed in ${BUILD_DURATION}m with exit code: $RC"

if [[ $RC -ne 0 ]]; then
  echo "❌ Build failed (rc=$RC)"
  echo "Memory status at failure:"
  free -h | grep Mem
  exit $RC
fi

# Verify QA APK
APK_PATH="app/build/outputs/apk/qa/app-qa.apk"
echo "🎯 Verifying APK at: $APK_PATH"

if [[ -f "$APK_PATH" ]]; then
  ls -lh "$APK_PATH"

  # Check APK freshness (must be newer than 5 minutes)
  echo "🕐 Checking APK freshness..."
  APK_AGE_MINUTES=$(( ($(date +%s) - $(stat -c %Y "$APK_PATH")) / 60 ))
  echo "APK age: ${APK_AGE_MINUTES} minutes"

  if [[ $APK_AGE_MINUTES -gt 5 ]]; then
    echo "⚠️ APK is older than 5 minutes - build may have failed silently"
    exit 1
  else
    echo "✅ APK is fresh (${APK_AGE_MINUTES} minutes old)"
  fi

  # Check for embedded JavaScript bundle
  echo "🔍 Checking for embedded JavaScript bundle..."
  if unzip -l "$APK_PATH" | grep -q "index.android.bundle"; then
    BUNDLE_SIZE=$(unzip -l "$APK_PATH" | grep "index.android.bundle" | awk '{print $1}')
    echo "✅ Bundled JS found: ${BUNDLE_SIZE} bytes"
  else
    echo "❌ index.android.bundle not found in APK"
    echo "This indicates bundling failed - APK will require Metro server"
    exit 1
  fi

  # Check for DevLauncher exclusion
  echo "🔍 Verifying DevLauncher exclusion..."
  if unzip -l "$APK_PATH" | grep -q -i "devlauncher"; then
    echo "⚠️ Warning: DevLauncher artifacts found in APK"
    unzip -l "$APK_PATH" | grep -i "devlauncher"
  else
    echo "✅ DevLauncher successfully excluded"
  fi

else
  echo "❌ APK not found at expected path"
  echo "Build may have failed silently"
  exit 1
fi

echo ""
echo "🎉 QA Build completed successfully!"
echo "📱 APK: $APK_PATH"
echo "📦 Embedded bundle: ✅ Ready for offline testing"
echo "🧪 Appium ready: No Metro server required"
echo "⏰ Build time: ${BUILD_DURATION}m"
echo "📅 Completed at: $(date)"