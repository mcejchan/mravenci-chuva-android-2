# Android Expo & Maestro Testing Log

## Session Date: 2025-09-06

### Environment Setup
- **Container**: AMD64 Docker container with Android SDK
- **Host ADB**: Connected via `tcp:host.docker.internal:5037`
- **Emulator**: emulator-5554 (sdk_gphone64_arm64)
- **Android SDK**: `/opt/android-sdk` with Platform-tools 36.0.0

---

## Phase 1: Initial Setup and Hello World App Creation

### Step 1: Check Android SDK and Environment
```bash
# Check Android SDK installation
echo $ANDROID_SDK_ROOT
# Result: /opt/android-sdk

sdkmanager --list_installed
# Result: Successfully showed installed components:
# - build-tools;35.0.0 and 36.0.0
# - platform-tools 36.0.0
# - platforms;android-35 and android-36
```

### Step 2: Create Hello World Expo Project
```bash
npx create-expo-app hello-world --template blank
# Result: ✅ Project created successfully
# Dependencies installed: 651 packages

cd hello-world && ls -la
# Result: Standard Expo project structure with App.js, package.json, etc.
```

### Step 3: Setup ADB Reverse for Development
```bash
adb reverse --remove-all
adb reverse tcp:8081 tcp:8081    # Metro bundler
adb reverse tcp:19000 tcp:19000  # Expo dev server  
adb reverse tcp:19001 tcp:19001  # Expo logs/WebSocket
# Result: All ports successfully forwarded (returned port numbers)
```

### Step 4: First Attempt - Expo with Android Direct Connection
```bash
npx expo start --android
# Result: ❌ FAILED
# Error: could not connect to TCP port 5554: Connection refused
# Issue: Expo CLI couldn't connect to emulator's console port
```

### Step 5: Alternative Approach - Localhost with Manual Connection
```bash
EXPO_NO_MDNS=1 npx expo start --host=localhost
# Result: ✅ Metro bundler started on http://localhost:8081

adb shell am start -n host.exp.exponent/.experience.ExperienceActivity -d "exp://localhost:19000"
# Result: Intent started successfully but app showed loading spinner indefinitely
```

---

## Phase 2: Troubleshooting and Static Bundle Approach

### Step 6: Static Bundle Export (Attempt to Avoid Metro)
```bash
npx expo export --platform android
# Result: ✅ Bundle created successfully
# Output: Android bundle at _expo/static/js/android/index-[hash].hbc (1.76 MB)

cd dist && python3 -m http.server 19000
# Result: ✅ HTTP server started, but served directory listing instead of Expo manifest
```

### Step 7: Manifest Test
```bash
curl http://localhost:19000
# Result: ❌ Directory listing HTML instead of Expo manifest
# Issue: Python HTTP server not compatible with Expo Go expectations
```

---

## Phase 3: Native React Native Approach

### Step 8: Create Pure React Native Project
```bash
cd .. && npx @react-native-community/cli@latest init TestApp --skip-install
# Result: ✅ React Native 0.81.1 project created

cd TestApp && npm install
# Result: ✅ 852 packages installed successfully
```

### Step 9: Simplify App.tsx to Basic Hello World
```tsx
// Modified App.tsx to simple Hello World
import { StyleSheet, Text, View } from 'react-native';

function App() {
  return (
    <View style={styles.container}>
      <Text style={styles.text}>Hello World! 🌍</Text>
    </View>
  );
}
```

### Step 10: React Native Build Attempt
```bash
npx react-native run-android
# Result: ❌ INTERRUPTED - Gradle build taking extremely long
# Issue: Network problems downloading Gradle dependencies
```

---

## Phase 4: System Reset and Clean Test

### Step 11: Complete System Reset
```bash
# Kill all processes
pkill -f "expo\|metro\|react-native\|gradle"
# Result: Some processes killed

adb shell am force-stop host.exp.exponent
# Result: ✅ Expo Go stopped

adb reverse --remove-all
# Result: ✅ All reverse connections removed
```

### Step 12: Basic ADB Connectivity Test
```bash
adb devices
# Result: ✅ emulator-5554 device (connected)

adb shell am start -n host.exp.exponent/.LauncherActivity
# Result: ✅ Expo Go launcher opened successfully

adb shell input text "Hello World Test"
# Result: ✅ Text input works

adb shell pm list packages | head -10
# Result: ✅ Package listing works correctly
```

---

## Current Status: ✅ READY FOR MAESTRO TESTING

### Working Components:
- ✅ Android SDK fully installed and configured
- ✅ ADB connection container → host → emulator functional
- ✅ Expo Go app installed and responsive  
- ✅ Basic Android operations (app launching, text input, package management)
- ✅ System clean and ready for testing

### Issues Encountered:
- ❌ Metro bundler extremely slow/hanging (likely network issues in container)
- ❌ Gradle builds timing out (network dependency downloads)
- ❌ Expo development server manifest serving issues

### Next Steps:
- Test Maestro framework on clean Expo Go installation
- Create basic UI automation tests
- Document Maestro test results

---

## Phase 5: Maestro Testing Framework

### Step 13: Maestro Version Check
```bash
$HOME/.maestro/bin/maestro --version
# Result: ✅ 2.0.2
```

### Step 14: Create Basic Maestro Test
```yaml
# Created basic-expo-test.yaml
appId: host.exp.exponent
---
- launchApp
- assertVisible: "Expo Go"
- tapOn: "Continue"
- assertVisible: "Home"
```

### Step 15: First Maestro Test Attempt
```bash
$HOME/.maestro/bin/maestro test basic-expo-test.yaml
# Result: ❌ FAILED
# Error: Not enough devices connected (1) to run the requested number of shards (1)
# Issue: Maestro not detecting emulator device
```

### Step 16: Maestro with Explicit ADB Socket
```bash
ADB_SERVER_SOCKET=tcp:host.docker.internal:5037 $HOME/.maestro/bin/maestro test basic-expo-test.yaml
# Result: ❌ FAILED - Same error: Not enough devices connected
# Issue: Maestro still not detecting emulator

# Double check ADB works with explicit socket:
ADB_SERVER_SOCKET=tcp:host.docker.internal:5037 adb devices
# Result: ✅ emulator-5554 device (confirmed working)
```

### Step 17: Expert Analysis of Issues

**Problems Identified:**
1. `expo start --android` fails with "could not connect to TCP port 5554" - Expo CLI trying to reach emulator console port (not ADB)
2. Infinite spinner in Expo Go - using `localhost` instead of `127.0.0.1`
3. `expo export` + Python server - wrong approach, not for dev mode
4. Maestro "Not enough devices" - needs explicit connection to host ADB server

**Expert-Recommended Solution:**
```bash
# 0) Clean start
adb devices
adb reverse --remove-all

# 1) Setup reverse for THREE ports (not just 8081)
adb reverse tcp:8081 tcp:8081     # Metro
adb reverse tcp:19000 tcp:19000   # Expo dev server (manifest)  
adb reverse tcp:19001 tcp:19001   # WebSocket / logs

# 2) Start Expo without mDNS, host=localhost
EXPO_NO_MDNS=1 npx expo start --host=localhost --clear

# 3) Open in Expo Go with explicit 127.0.0.1 (NOT localhost)
adb shell am start -a android.intent.action.VIEW -d "exp://127.0.0.1:19000"
```

### Step 18: Implementing Expert Solution
```bash
# Clean start
adb devices
# Result: ✅ emulator-5554 device

adb reverse --remove-all
# Result: ✅ All reverse connections removed

# Setup ADB reverse for THREE ports
adb reverse tcp:8081 tcp:8081     # Metro
adb reverse tcp:19000 tcp:19000   # Expo dev server (manifest)  
adb reverse tcp:19001 tcp:19001   # WebSocket / logs
# Result: ✅ All three ports returned successfully (8081, 19000, 19001)

# Start Expo with correct flags
EXPO_NO_MDNS=1 npx expo start --host=localhost --clear
# Result: ✅ Started successfully, waiting on http://localhost:8081
# Status: Metro bundler rebuilding cache

# Open in Expo Go with 127.0.0.1 (KEY CHANGE!)
adb shell am start -a android.intent.action.VIEW -d "exp://127.0.0.1:19000"
# Result: ✅ Intent started successfully with 127.0.0.1
```

### Step 19: Testing Connectivity
```bash
# Test emulator connectivity (curl not available)
adb shell 'curl -I http://127.0.0.1:19000' 2>/dev/null || echo "curl not available on emulator"
# Result: curl not available on emulator (expected)

# Metro bundler status check
# Status: Still rebuilding cache - "warning: Bundler cache is empty, rebuilding (this may take a minute)"
```

### Step 20: Maestro Testing with Expert Configuration
```bash
# Set expert-recommended environment variables
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037
export MAESTRO_ADB_SERVER_HOST=host.docker.internal  
export MAESTRO_ADB_SERVER_PORT=5037

# Try Maestro device detection
$HOME/.maestro/bin/maestro devices
# Result: ❌ "devices" command not available in this version

# Try Maestro test with device flag
$HOME/.maestro/bin/maestro --device emulator-5554 test ../basic-expo-test.yaml
# Result: ❌ "Device emulator-5554 was requested, but it is not connected"
# Issue: Maestro still not seeing device despite ADB environment variables
```

### Step 21: Current Status - Expert Solution Partially Working
**Working:**
- ✅ ADB reverse connections established for all 3 ports
- ✅ Expo started with correct flags (EXPO_NO_MDNS=1, --host=localhost, --clear)
- ✅ Intent launched with 127.0.0.1 instead of localhost
- ✅ Metro bundler starting up (rebuilding cache)

**Still Issues:**
- ❌ Maestro not detecting emulator despite environment variables
- 🔄 Metro bundler taking very long to build cache (network issues)
- 🔄 App not yet loaded in Expo Go (waiting for Metro)

---

## Environment Details for Expert Review:

### Container Configuration:
- **Platform**: `--platform=linux/amd64` (via Rosetta on Apple Silicon)
- **Base Image**: Ubuntu 24.04 with Node.js 20, OpenJDK 17
- **Android SDK Path**: `/opt/android-sdk`
- **ADB Connection**: TCP socket `host.docker.internal:5037`

### Key Environment Variables:
- `ANDROID_SDK_ROOT=/opt/android-sdk`
- `ANDROID_HOME=/opt/android-sdk`  
- `JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`
- `ADB_SERVER_SOCKET=tcp:host.docker.internal:5037`

### Current Working Directory:
`/workspaces/mravenci-chuva-android-amd64`

### Available Projects:
- `hello-world/` - Expo project (blank template)
- `TestApp/` - React Native project (basic structure)