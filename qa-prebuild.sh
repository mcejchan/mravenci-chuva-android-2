#!/bin/bash
set -e

echo "🔧 QA Prebuild Script Starting..."
echo "📅 $(date)"

# Navigate to app directory
cd hello-world

# Cache check - compare app.config.js and package.json hash
CACHE_FILE=".prebuild-cache"
CONFIG_HASH=$(sha256sum app.config.js package.json 2>/dev/null | sha256sum | cut -d' ' -f1)

# Check for --clean flag to force rebuild
if [[ "$1" == "--clean" ]]; then
    echo "🧹 --clean flag detected, forcing prebuild"
    rm -f "$CACHE_FILE"
fi

if [[ -f "$CACHE_FILE" && "$CONFIG_HASH" == "$(cat $CACHE_FILE 2>/dev/null)" ]]; then
    echo "✅ Native config unchanged, skipping prebuild"
    echo "🔍 Cache hit: $(cat $CACHE_FILE)"
    exit 0
fi

echo "🔄 Native config changed or no cache - running prebuild"
echo "📊 New config hash: $CONFIG_HASH"

# Clean previous build artifacts
echo "🧹 Cleaning previous build artifacts..."
rm -rf android/
rm -rf ios/

# Set environment for QA build (no dev-client)
export EXPO_USE_DEV_CLIENT=false

echo "⚙️ Environment:"
echo "  EXPO_USE_DEV_CLIENT=$EXPO_USE_DEV_CLIENT"
echo "  Node: $(node -v)"
echo "  Expo CLI: $(npx expo --version)"

# Run prebuild with error handling
echo "🏗️ Running expo prebuild..."
if ! npx expo prebuild -p android --clean; then
    echo "❌ Expo prebuild failed!"
    echo "This means android/ folder was not created"
    echo "Check above for errors and fix before retrying"
    exit 1
fi

# Verify android folder was created
if [[ ! -d "android" ]]; then
    echo "❌ Android folder was not created by prebuild"
    echo "Prebuild may have failed silently"
    exit 1
fi

# Verify no DevLauncher in manifest
MANIFEST_CHECK=$(find android/ -name "AndroidManifest.xml" -exec grep -l "DevLauncher" {} \; 2>/dev/null || true)
if [[ -n "$MANIFEST_CHECK" ]]; then
    echo "❌ Warning: DevLauncher still found in manifest:"
    echo "$MANIFEST_CHECK"
    echo "This may indicate dev-client wasn't properly excluded"
else
    echo "✅ DevLauncher successfully excluded from manifest"
fi

# Check main activity launcher
MAIN_LAUNCHER=$(find android/ -name "AndroidManifest.xml" -exec grep -l "android.intent.category.LAUNCHER" {} \; | head -1)
if [[ -n "$MAIN_LAUNCHER" ]]; then
    LAUNCHER_ACTIVITY=$(grep -A5 -B5 "android.intent.category.LAUNCHER" "$MAIN_LAUNCHER" | grep "android:name" | head -1)
    echo "📱 Main launcher activity: $LAUNCHER_ACTIVITY"
fi

# Add QA build type (expo prebuild removes it)
echo "🔧 Adding QA build type to app/build.gradle..."
QA_BUILD_TYPE='        qa {
            initWith debug
            debuggable false                 // KLÍČOVÉ: tím se JS zabundluje
            signingConfig signingConfigs.debug
            matchingFallbacks = ["debug"]    // reuse debug deps/resources
            // Expert bundled build optimizations
            minifyEnabled false
            shrinkResources false
        }'

if ! grep -q "qa {" android/app/build.gradle; then
    # Find buildTypes section and add qa after debug
    sed -i '/debug {/,/}/ { /}/a\
        qa {\
            initWith debug\
            debuggable false                 // KLÍČOVÉ: tím se JS zabundluje\
            signingConfig signingConfigs.debug\
            matchingFallbacks = ["debug"]    // reuse debug deps/resources\
            // Expert bundled build optimizations\
            minifyEnabled false\
            shrinkResources false\
        }
' android/app/build.gradle
    echo "✅ QA build type added to build.gradle"
else
    echo "✅ QA build type already present in build.gradle"
fi

# Save cache hash
echo "$CONFIG_HASH" > "$CACHE_FILE"
echo "💾 Cache updated: $CONFIG_HASH"

echo ""
echo "✅ QA Prebuild completed successfully!"
echo "📁 Android project generated at: android/"
echo "🎯 Ready for QA build without dev-client"
echo "⏰ Completed at: $(date)"