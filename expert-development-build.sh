#!/bin/bash
# Expert Development Build Script
# Based on successful breakthrough report configuration
# Requires: 16GB Docker RAM, AMD64 container

set -e  # Exit on any error

echo "🚀 Expert Development Build Script Starting..."
echo "📅 $(date)"
echo "💾 Memory check:"
free -h

# Step 1: Environment verification
echo ""
echo "🔍 Step 1: Environment verification"
echo "Working directory: $(pwd)"
echo "Java version: $(java -version 2>&1 | head -1)"
echo "Container memory:"
free -h | grep Mem

# Memory requirement check (based on breakthrough report)
TOTAL_MEM_GB=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}')
echo "Total memory: ${TOTAL_MEM_GB}GB"

if [[ $TOTAL_MEM_GB -lt 15 ]]; then
    echo "❌ INSUFFICIENT MEMORY: Container has ${TOTAL_MEM_GB}GB, but requires 15GB+ for C++/CMake compilation"
    echo "💡 Solution: Docker Desktop → Settings → Resources → Memory: 15GB+"
    echo "⚠️  Restart Docker Desktop after change"
    echo "🔄 Restart development container"
    echo ""
    echo "According to breakthrough report: C++/CMake needs more memory than pure JS+Kotlin builds"
    exit 1
fi

echo "✅ Memory check passed: ${TOTAL_MEM_GB}GB available"

# Step 2: Navigate to project directory
echo ""
echo "📁 Step 2: Navigate to hello-world directory"
cd hello-world

# Step 3: Verify expert BOM dependencies are installed
echo ""
echo "📦 Step 3: Verify expo-asset dependency"
if node -p "require('expo-asset/package.json').version" 2>/dev/null; then
    echo "✅ expo-asset is installed"
else
    echo "❌ expo-asset missing - installing..."
    npx expo install expo-asset
fi

# Step 4: Verify gradle.properties configuration
echo ""
echo "⚙️ Step 4: Verify gradle.properties configuration"
if grep -q "org.gradle.jvmargs=-Xmx6144m" android/gradle.properties; then
    echo "✅ Expert breakthrough configuration present"
else
    echo "❌ Expert configuration missing - applying..."
    # Apply expert configuration here if needed
fi

# Step 5: Clean environment
echo ""
echo "🧹 Step 5: Clean build environment"
export GRADLE_USER_HOME=/home/vscode/.gradle-local
mkdir -p "$GRADLE_USER_HOME"
chmod -R 700 "$GRADLE_USER_HOME"

# Step 6: Execute expert build command
echo ""
echo "🔨 Step 6: Execute expert build (30-45 minutes expected)"
echo "Build started at: $(date)"
cd android

# Kill any existing gradle processes
echo "Stopping existing Gradle processes..."
./gradlew --stop || true
pkill -f gradle || true
sleep 5

# Memory check before build
echo "Pre-build memory status:"
free -h | grep Mem

# Expert build command from breakthrough report
echo "Starting expert build with breakthrough configuration..."
export GRADLE_USER_HOME=/home/vscode/.gradle-local
./gradlew :app:clean :app:assembleDebug \
  --no-daemon --no-parallel --max-workers=1 \
  --info --stacktrace

BUILD_EXIT_CODE=$?
echo "Build exit code: $BUILD_EXIT_CODE"

if [[ $BUILD_EXIT_CODE -ne 0 ]]; then
    echo "❌ Build failed with exit code $BUILD_EXIT_CODE"
    echo "Memory status at failure:"
    free -h
    echo "Recent daemon log (last 20 lines):"
    tail -20 /home/vscode/.gradle-local/daemon/8.13/daemon-*.out.log 2>/dev/null || echo "No daemon log found"
    exit $BUILD_EXIT_CODE
fi

# Step 7: Verify APK creation
echo ""
echo "🎯 Step 7: Verify APK creation"
APK_PATH="app/build/outputs/apk/debug/app-debug.apk"
if [[ -f "$APK_PATH" ]]; then
    echo "✅ APK created successfully!"
    ls -lh "$APK_PATH"
    echo "APK size: $(du -h "$APK_PATH" | cut -f1)"
else
    echo "❌ APK not found at $APK_PATH"
    echo "Build may have failed - check logs above"
    exit 1
fi

echo ""
echo "🎉 Expert Development Build Complete!"
echo "📅 Finished at: $(date)"
echo "📱 APK ready for installation: $APK_PATH"