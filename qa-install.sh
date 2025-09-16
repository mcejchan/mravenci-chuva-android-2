#!/bin/bash
set -e

echo "📱 QA APK Install Script Starting..."
echo "📅 $(date)"

# ADB environment (container → host)
export ANDROID_ADB_SERVER_ADDRESS=${ANDROID_ADB_SERVER_ADDRESS:-host.docker.internal}
export ANDROID_ADB_SERVER_PORT=${ANDROID_ADB_SERVER_PORT:-5037}

# APK path and package name
QA_APK="hello-world/android/app/build/outputs/apk/qa/app-qa.apk"
PACKAGE_NAME="com.anonymous.helloworld"

# Functions
check_emulator() {
    echo "🔍 Checking for available emulators..."

    # Check if ADB can connect
    if ! env ADB_SERVER_SOCKET=tcp:${ANDROID_ADB_SERVER_ADDRESS}:${ANDROID_ADB_SERVER_PORT} adb devices | grep -q "emulator"; then
        echo "❌ No emulator found. Please start an emulator first."
        echo "Available devices:"
        env ADB_SERVER_SOCKET=tcp:${ANDROID_ADB_SERVER_ADDRESS}:${ANDROID_ADB_SERVER_PORT} adb devices
        exit 1
    fi

    # Get first available emulator
    EMULATOR_ID=$(env ADB_SERVER_SOCKET=tcp:${ANDROID_ADB_SERVER_ADDRESS}:${ANDROID_ADB_SERVER_PORT} adb devices | grep emulator | head -1 | cut -f1)
    echo "✅ Found emulator: $EMULATOR_ID"
}

verify_apk() {
    echo "🔍 Verifying QA APK..."

    if [[ ! -f "$QA_APK" ]]; then
        echo "❌ QA APK not found at: $QA_APK"
        echo "Please run bundled build first: npm run build:bundled"
        exit 1
    fi

    # Check APK size and age
    APK_SIZE=$(du -h "$QA_APK" | cut -f1)
    APK_AGE_MINUTES=$(( ($(date +%s) - $(stat -c %Y "$QA_APK")) / 60 ))

    echo "✅ QA APK found: $APK_SIZE, ${APK_AGE_MINUTES}min old"

    # Verify bundle inside APK
    if unzip -l "$QA_APK" | grep -q "index.android.bundle"; then
        echo "✅ Bundled JS confirmed in APK"
    else
        echo "⚠️ Warning: index.android.bundle not found in APK"
    fi
}

uninstall_old() {
    echo "🗑️ Uninstalling old version..."

    if env ADB_SERVER_SOCKET=tcp:${ANDROID_ADB_SERVER_ADDRESS}:${ANDROID_ADB_SERVER_PORT} adb -s $EMULATOR_ID shell pm list packages | grep -q "$PACKAGE_NAME"; then
        echo "Removing existing package: $PACKAGE_NAME"
        env ADB_SERVER_SOCKET=tcp:${ANDROID_ADB_SERVER_ADDRESS}:${ANDROID_ADB_SERVER_PORT} adb -s $EMULATOR_ID uninstall $PACKAGE_NAME || echo "Uninstall failed, continuing..."
    else
        echo "No existing package found"
    fi
}

install_apk() {
    echo "📦 Installing QA APK..."

    env ADB_SERVER_SOCKET=tcp:${ANDROID_ADB_SERVER_ADDRESS}:${ANDROID_ADB_SERVER_PORT} adb -s $EMULATOR_ID install "$QA_APK"

    if [[ $? -eq 0 ]]; then
        echo "✅ Installation successful"
    else
        echo "❌ Installation failed"
        exit 1
    fi
}

launch_app() {
    echo "🚀 Launching application..."

    # Launch main activity
    env ADB_SERVER_SOCKET=tcp:${ANDROID_ADB_SERVER_ADDRESS}:${ANDROID_ADB_SERVER_PORT} adb -s $EMULATOR_ID shell am start -n "$PACKAGE_NAME/.MainActivity"

    if [[ $? -eq 0 ]]; then
        echo "✅ App launched successfully"
    else
        echo "⚠️ Launch may have failed, but app is installed"
    fi
}

verify_installation() {
    echo "🔍 Verifying installation..."

    # Check if package is installed
    if env ADB_SERVER_SOCKET=tcp:${ANDROID_ADB_SERVER_ADDRESS}:${ANDROID_ADB_SERVER_PORT} adb -s $EMULATOR_ID shell pm list packages | grep -q "$PACKAGE_NAME"; then
        echo "✅ Package confirmed installed: $PACKAGE_NAME"

        # Get app version info
        VERSION_INFO=$(env ADB_SERVER_SOCKET=tcp:${ANDROID_ADB_SERVER_ADDRESS}:${ANDROID_ADB_SERVER_PORT} adb -s $EMULATOR_ID shell dumpsys package $PACKAGE_NAME | grep versionName | head -1 | cut -d'=' -f2)
        echo "📋 Version: $VERSION_INFO"
    else
        echo "❌ Package not found after installation"
        exit 1
    fi
}

# Main execution
echo "🔧 Environment: ADB → ${ANDROID_ADB_SERVER_ADDRESS}:${ANDROID_ADB_SERVER_PORT}"

check_emulator
verify_apk
uninstall_old
install_apk
launch_app
verify_installation

echo ""
echo "🎉 QA APK installation completed successfully!"
echo "📱 App: $PACKAGE_NAME on $EMULATOR_ID"
echo "📦 APK: $QA_APK"
echo "⏰ Completed at: $(date)"