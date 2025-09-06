# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a pre-configured Dev Container setup for Android development using Expo/React Native with Java/Kotlin support. **This version is specifically configured to run on AMD64 architecture via Rosetta on Apple Silicon Macs** to ensure full compatibility with Android SDK tools.

## Key Architecture Components

### Dev Container Configuration (AMD64)
- **Platform**: Forced AMD64 via `--platform=linux/amd64` in both Dockerfile and devcontainer.json
- **Base**: Ubuntu 24.04 with Node.js 20, OpenJDK 17, and Android SDK CLI tools
- **Rosetta Translation**: Runs AMD64 containers on Apple Silicon via Docker's Rosetta integration
- **Additional Tools**: EAS CLI, Claude Code CLI (auto-installed), VS Code extensions
- **ADB Connection**: Container ADB client connects to host ADB server via `tcp:host.docker.internal:5037`
- **Persistent Storage**: Android SDK stored in Docker volume `android-sdk-amd64` (separate from ARM64 version)

### Environment Variables
- `ANDROID_SDK_ROOT` and `ANDROID_HOME`: `/opt/android-sdk`
- `ADB_SERVER_SOCKET`: `tcp:host.docker.internal:5037` (connects to host ADB)
- `JAVA_HOME`: `/usr/lib/jvm/java-17-openjdk-amd64` (AMD64 Java installation)

### Port Forwarding
- `8081`: Metro bundler (React Native)
- `19000-19002`: Expo development server

## Common Development Commands

### Android SDK Management
```bash
# List available packages
sdkmanager --list

# Install additional SDK components
sdkmanager "platforms;android-35" "build-tools;35.0.0"

# Check ADB connectivity to host devices
adb devices
```

### Expo/React Native Development
```bash
# Install dependencies
npm install

# Start Expo development server
npx expo start --tunnel              # for remote access
npx expo start                       # for local network

# Optimized startup (recommended for containers)
EXPO_NO_MDNS=1 npx expo start --host=localhost

# EAS Build (cloud builds)
eas build --platform android
```

### Gradle Builds (for native Android projects)
```bash
# Build debug APK
./gradlew assembleDebug

# Install to connected device
adb install app/build/outputs/apk/debug/app-debug.apk
```

## Prerequisites and Setup

### Host System Requirements
- Docker Desktop with Rosetta 2 enabled (on Apple Silicon)
- Android Studio with SDK and AVD (emulator) installed on host
- Optionally: Expo Go app on physical device

### Initial Setup
1. Copy `.devcontainer/` folder to project root
2. Open project in VS Code with "Dev Containers: Reopen in Container"
3. Wait for automatic Android SDK installation and Claude Code CLI installation
4. Verify ADB connectivity with `adb devices`

## Troubleshooting

### Architecture Issues
- This container runs AMD64 on Apple Silicon via Rosetta for maximum Android SDK compatibility
- All Android SDK tools should work without architecture-related crashes
- If experiencing performance issues, consider using the ARM64 version for non-Gradle tasks

### ADB Connection Issues
- Ensure host ADB server is running: `adb kill-server && adb start-server` (on host)
- Check firewall isn't blocking port 5037
- Verify container can reach host: `ping host.docker.internal`

### Expo/Metro Connection Issues
- **Recommended approach**: Use `EXPO_NO_MDNS=1 npx expo start --host=localhost`
- **Why**: Disables mDNS discovery, reduces "ghost" detection attempts
- **Alternative**: Use `--tunnel` for external network access
- **ADB reverse**: Container relies on `adb reverse` for device connectivity (preferred over network discovery)

### SDK Issues
- SDK components are installed to `/opt/android-sdk` via Docker volume `android-sdk-amd64`
- If SDK is corrupted, remove volume: `docker volume rm android-sdk-amd64`
- Re-run container to trigger fresh SDK installation

### Git Authentication
- GitHub token stored in `.claude/github_token.txt` (excluded from git)
- Remote configured with token authentication for seamless push/pull

## File Structure
```
.devcontainer/
├─ devcontainer.json       # Container configuration with AMD64 platform
├─ Dockerfile             # AMD64 Node.js, JDK, Android tools
└─ scripts/
   ├─ setup-android-sdk.sh # Android SDK installation
   └─ adb-notes.sh        # ADB connectivity helper
```

## AMD64 vs ARM64 Considerations

**Use this AMD64 version when:**
- Running Gradle builds (`./gradlew assembleDebug`)
- Using Android SDK tools that don't support ARM64
- Need maximum compatibility with Android development tools

**Use ARM64 version when:**
- Only doing Expo/React Native development
- Performance is more important than tool compatibility
- Not using Gradle or native Android builds