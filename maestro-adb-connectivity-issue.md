# Maestro ADB Connectivity Issue

## Problem Summary

We have a working Expo Go Hello World app running on an Android emulator, but **Maestro cannot detect the emulator device** for automated testing, despite ADB working correctly for manual commands.

## Environment Setup

### Working Components
- **Container**: AMD64 Ubuntu 24.04.2 LTS 
- **Emulator**: ARM64 Android 16 API 35 (`emulator-5554`)
- **Expo Go**: Version 2.33.22 (SDK 53 compatible)
- **ADB**: v35.0.2-12147458 (x86-64 binary)
- **Maestro**: Latest version (just installed)

### Network Configuration
```bash
# Container connects to host ADB server via Docker bridge
ADB_SERVER_SOCKET=tcp:host.docker.internal:5037
```

## Current Status

### ✅ What Works
1. **ADB Connection**: Manual ADB commands work perfectly
   ```bash
   export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037
   adb devices
   # Output: emulator-5554	device
   ```

2. **App Control**: Can start/stop Expo Go remotely
   ```bash
   adb -s emulator-5554 shell am force-stop host.exp.exponent  # ✅ Works
   adb -s emulator-5554 shell dumpsys package host.exp.exponent  # ✅ Works
   ```

3. **Test File**: Ready to test "Hello World! 🌍" text
   ```yaml
   # hello-world-test.yaml
   appId: host.exp.exponent
   ---
   - launchApp:
       appId: "host.exp.exponent"
   - tapOn: "Enter URL manually"
   - inputText: "exp://127.0.0.1:19000"
   - tapOn: "Connect"
   - waitForAnimationToEnd
   - assertVisible: "Hello World! 🌍"
   ```

### ❌ What Fails
**Maestro Device Detection**:
```bash
maestro test hello-world-test.yaml
# Error: Not enough devices connected (1) to run the requested number of shards (1).
# Want to use 0 devices, which is not enough to run 1 shards. Missing 1 device(s).
```

## Root Cause Analysis

### Problem: ADB Client Isolation
1. **Our ADB Setup**: Uses `ADB_SERVER_SOCKET=tcp:host.docker.internal:5037` to connect container→host→emulator
2. **Maestro ADB**: Uses its own embedded ADB client that ignores our environment variables
3. **Port Conflict**: Maestro expects standard `localhost:5037`, but we need Docker bridge connection

### Failed Solutions Attempted

#### 1. Environment Variables
```bash
# Tried various combinations - all failed
ANDROID_ADB_SERVER_PORT=5037 ADB_SERVER_SOCKET=tcp:host.docker.internal:5037 maestro test
ADB_SERVER_SOCKET=tcp:host.docker.internal:5037 maestro test  
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037; maestro test
```

#### 2. Explicit Device ID
```bash
maestro --udid emulator-5554 test hello-world-test.yaml
# Error: Device emulator-5554 was requested, but it is not connected.
```

#### 3. Local ADB Server
```bash
# Started local ADB daemon in container
unset ADB_SERVER_SOCKET; adb devices
# Output: * daemon started successfully (but no devices visible)
```

## Technical Deep Dive

### ADB Architecture in Our Setup
```
┌─────────────────┐    tcp:5037    ┌─────────────────┐    usb/tcp    ┌─────────────────┐
│   Container     │──────────────→ │   Host System   │─────────────→ │   Emulator      │
│                 │                │                 │               │                 │
│ ADB Client      │                │ ADB Server      │               │ emulator-5554   │
│ (our commands)  │                │ (port 5037)     │               │ (arm64-v8a)     │
│                 │                │                 │               │                 │
│ Maestro ADB ❌  │    ????????    │                 │               │                 │
│ (can't connect) │                │                 │               │                 │
└─────────────────┘                └─────────────────┘               └─────────────────┘
```

### Evidence
1. **Manual ADB Works**:
   ```bash
   export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037
   adb devices → emulator-5554 device ✅
   ```

2. **Maestro ADB Fails**:
   ```bash
   maestro test → Not enough devices connected ❌
   ```

3. **Port Analysis**:
   ```bash
   netstat -tlnp | grep :5037
   # Shows local ADB daemon on 127.0.0.1:5037 (no devices)
   ```

## Potential Solutions (Not Yet Tested)

### Option 1: Port Forwarding
Create local proxy from `localhost:5037` → `host.docker.internal:5037`
```bash
socat tcp-listen:5037,reuseaddr,fork tcp:host.docker.internal:5037
```

### Option 2: Maestro Configuration
Investigate if Maestro has config options for custom ADB server endpoints

### Option 3: Container Network Mode
Switch dev container to `--network=host` mode (may require significant reconfiguration)

### Option 4: Host-Side Testing
Run Maestro directly on host system instead of container

## Questions for Expert

1. **Is this a known limitation** of Maestro in Docker environments?
2. **Best practice** for Maestro + containerized Android development?
3. **Alternative testing frameworks** that work better with our ADB bridge setup?
4. **Should we modify our container architecture** to accommodate Maestro?

## Test Verification Plan

Once device detection is resolved:
1. Run `maestro test hello-world-test.yaml`
2. Verify Maestro can:
   - Launch Expo Go
   - Navigate to manual URL entry
   - Input `exp://127.0.0.1:19000`
   - Connect to development server
   - Verify "Hello World! 🌍" text appears on screen

## Context
This is part of a pure Expo Go development workflow (no native builds) running in an AMD64 container with ARM64 emulator for rapid prototyping.