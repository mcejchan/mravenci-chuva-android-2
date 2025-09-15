# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a **pure Expo Go development environment** optimized for rapid mobile app prototyping. **No native builds required** - the Expo Go app on your device handles all native code execution.

### Current Architecture: Expo Go Only
- **Development Model**: JavaScript/TypeScript code runs in Expo Go app
- **No Native Builds**: No Gradle, no Kotlin compilation, no APK generation needed  
- **Hot Reload**: Instant code updates via network connection to development server
- **Cross-Platform**: Same codebase for iOS and Android via Expo Go

## Key Architecture Components

### Dev Container Configuration (AMD64)
- **Platform**: Forced AMD64 via `--platform=linux/amd64` in both Dockerfile and devcontainer.json
- **Base**: Ubuntu 24.04 with Node.js 20, OpenJDK 17, and Android SDK CLI tools
- **Rosetta Translation**: Runs AMD64 containers on Apple Silicon via Docker's Rosetta integration
- **Additional Tools**: EAS CLI, Claude Code CLI (auto-installed), VS Code extensions
- **ADB Connection**: Container ADB client connects to host ADB server via `tcp:host.docker.internal:5037`
- **Persistent Storage**: Android SDK stored in Docker volume `android-sdk-amd64` (separate from ARM64 version)

### Environment Variables
- `JAVA_HOME`: `/usr/lib/jvm/java-17-openjdk-amd64` (for Expo CLI tools)

### Port Forwarding
- `19000-19002`: Expo development server

## Common Development Commands

### Expo Go Development
```bash
# Navigate to app directory
cd hello-world

# Install dependencies
npm install

# Start Expo development server (recommended)
EXPO_NO_MDNS=1 npx expo start --host=localhost

# Alternative methods
npx expo start --tunnel              # for remote access over internet
npx expo start                       # for local network discovery
```

### Workspace Structure - IMPORTANT FOR CLAUDE CODE!
```
/workspaces/mravenci-chuva-android-amd64/     # ROOT - Working directory
├── hello-world/                             # Main Expo application directory 
│   ├── android/                             # Android native build folder (after expo prebuild)
│   │   ├── gradlew                         # Gradle wrapper script
│   │   ├── build.gradle                    # Root Android build file
│   │   ├── gradle.properties               # Gradle configuration
│   │   ├── app/                            # Android app module
│   │   │   ├── build.gradle                # App build configuration
│   │   │   └── src/                        # Android native source
│   │   └── gradle/                         # Gradle wrapper files
│   ├── App.js                               # Root React component
│   ├── app.json                            # Expo configuration
│   ├── package.json                        # Dependencies (Expo SDK ~53.0.0)
│   └── assets/                             # App icons, splash screens
├── 01-development-build-progress-report.md   # Build reports (chronological)
├── 02-gradle-build-analysis-report.md
├── 03-gradle-build-breakthrough-report.md
└── CLAUDE.md                               # This file

CRITICAL PATHS FOR GRADLE BUILDS:
- Current working directory: /workspaces/mravenci-chuva-android-amd64/hello-world/
- Gradle wrapper: ./android/gradlew (run from hello-world/)
- Android configs: ./android/build.gradle, ./android/gradle.properties
- App module: ./android/app/build.gradle
```

### App Structure (Expo)

## Prerequisites and Setup

### Host System Requirements
- Docker Desktop
- **Expo Go app** installed on your mobile device (iOS App Store / Google Play)
- Mobile device on same network as development container

### Initial Setup
1. Open project in VS Code with "Dev Containers: Reopen in Container"
2. Wait for container startup and Expo CLI installation  
3. Navigate to `hello-world` directory
4. Run `EXPO_NO_MDNS=1 npx expo start --host=localhost`
5. Scan QR code with Expo Go app

## Troubleshooting

### Expo Go Connection Issues
- **Recommended approach**: Use `EXPO_NO_MDNS=1 npx expo start --host=localhost`  
- **Why**: Disables mDNS discovery, ensures reliable connection
- **Alternative**: Use `--tunnel` for remote access over internet
- **Network**: Ensure mobile device and container are on same network

### Common Issues
- **"Couldn't connect to development server"**: Check network connectivity, try `--tunnel` flag
- **QR code not working**: Manually type the displayed URL into Expo Go app
- **Hot reload not working**: Restart Expo server, check for JavaScript errors

### Workspace Structure
```
/workspaces/mravenci-chuva-android-amd64/
├── hello-world/               # 📱 Main Expo Go application
├── app design/               # 📋 Design requirements and mockups  
├── .devcontainer/            # 🐳 Docker container configuration
├── .claude/                  # 🤖 Claude Code settings
├── CLAUDE.md                 # 📖 This documentation
└── README.md                 # 📄 Project overview
```

### Files Purpose
- **`hello-world/`**: Pure Expo application - no native code, runs in Expo Go
- **`app design/`**: UI/UX specifications for future development
- **`.devcontainer/`**: Development environment with Expo CLI pre-installed
- **`guide/`**: Tested and verified guide files for project workflows and procedures
- **Legacy removed**: All React Native native build files, Gradle configs, Android SDK artifacts

## CRITICAL BUILD VERIFICATION RULE

⚠️ **ALWAYS verify build results after every build command!**

**After running any Gradle build (`./gradlew assembleDebug`, etc.):**

1. **Check exit code**: `echo $?` - must be 0 for success
2. **Find APK location**: `find android/ -name "*.apk" -type f -exec ls -la {} \;`
3. **Check for errors**: `tail -50 build.log` and search for "FAILED", "ERROR", "CompilationErrorException"
4. **Verify APK was created**: Look in `android/app/build/outputs/apk/debug/`

**If build shows exit code 0 but no APK exists = COMPILATION FAILED!**

## CRITICAL DEPLOYMENT LOG ANALYSIS RULE

⚠️ **ALWAYS analyze logs after every deployment for errors!**

**After any deployment (Metro bundler, dev server, app launch):**

1. **Check Metro bundler logs**: Look for bundle success/failure, module count, warnings
2. **Check ADB/device logs**: `adb logcat -s ReactNativeJS:V -t 20` for JavaScript errors
3. **Check network connectivity**: Verify manifest and bundle endpoints are accessible
4. **Search for error patterns**: "FAILED", "ERROR", "Exception", "Global was not installed"
5. **Verify successful connection**: Look for successful module bundling and dev-client initialization
6. **Take emulator screenshot**: Capture current app state for visual verification
7. **Analyze screenshot**: Check for error screens, loading states, successful app launch

**Critical log patterns to watch:**
- Bundle completion: `"Bundled XXXms index.js (### modules)"`
- Network errors: Connection refused, timeout, unreachable
- JavaScript errors: ReferenceError, TypeError, missing imports
- Dev-client errors: "Global was not installed", initialization failures

**Screenshot analysis checklist:**
- App successfully loaded vs error screens
- Dev-client launcher vs main app content
- Network connectivity indicators
- Any visible JavaScript errors or warnings

## GUIDE FILES REFERENCE

⚠️ **ALWAYS reference verified guide files before implementing complex workflows!**

**Location**: `/guide/` directory contains tested and verified procedures:

- **`expo-development-build-guide.md`**: Complete development build workflow from Expo Go to native APK
- **`expo-complete-troubleshooting-guide.md`**: Comprehensive troubleshooting procedures for common issues
- **`07-expert-bom-complete-guide.md`**: Expert BOM (Bill of Materials) approach for SDK compatibility

**Usage**: These guides contain step-by-step procedures that have been tested and validated. Always consult them before implementing new features or resolving complex issues.

## Development Workflow

### Daily Development
1. **Start Development Server**:
   ```bash
   cd hello-world
   EXPO_NO_MDNS=1 npx expo start --host=localhost
   ```

2. **Connect Device**: Scan QR code with Expo Go app

3. **Code & Test**: Edit `App.js`, changes appear instantly on device

4. **Debug**: Use Chrome DevTools or Expo debugging tools

### When to Use This Setup
- **Perfect for**: Rapid prototyping, learning React Native, UI/UX testing
- **Not suitable for**: Apps needing native modules, custom native code, or store deployment
- **Next step**: When ready for production, use `expo eject` or EAS Build