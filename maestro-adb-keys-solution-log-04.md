# Log 04: Maestro ADB Keys Solution - Expert Implementation

## Expert Strategy: ADB Keys + TCP Connection

**Expert recommendation**: The main issue is ADB authorization. Share ADB keys from host to container, then use local ADB server to connect via TCP proxy.

### Expected Flow:
1. ✅ Copy ADB keys from host to container `~/.android/`
2. ✅ Start clean local ADB server in container  
3. ✅ Test network connectivity to `192.168.65.254:5556`
4. ❌ `adb connect 192.168.65.254:5556` (should work with shared keys)
5. ❌ Maestro test with connected TCP device

## Implementation Results

### ✅ Step 1: ADB Keys Available
```bash
ls -la /workspaces/mravenci-chuva-android-amd64/.android/
```
**Result**: 
```
-rw------- 1 vscode vscode 1704 Sep 10 17:00 adbkey
-rw-r--r-- 1 vscode vscode  725 Sep 10 17:00 adbkey.pub
```
**SUCCESS**: ADB keys from host are available in workspace ✅

**Note**: Keys were copied to workspace root by user, not `~/.android/`. Container's `~/.android/` appears to be mounted and cannot be modified.

### ✅ Step 2: Clean ADB Server Setup
```bash
export ANDROID_USER_HOME=/workspaces/mravenci-chuva-android-amd64
unset ADB_SERVER_SOCKET ANDROID_ADB_SERVER_ADDRESS ANDROID_ADB_SERVER_PORT
pkill adb; adb start-server
```
**Result**: Local ADB server started with shared keys configuration ✅

### ✅ Step 3: Network Connectivity Test
```bash
nc -vz 192.168.65.254 5556
```
**Result**: `Connection to 192.168.65.254 5556 port [tcp/freeciv] succeeded!` ✅

### ❌ Step 4: ADB TCP Connect (Failed)
```bash
export ANDROID_USER_HOME=/workspaces/mravenci-chuva-android-amd64
adb connect 192.168.65.254:5556
```
**Result**: `failed to connect to '192.168.65.254:5556': Operation timed out` ❌

**Analysis**: 
- Network connectivity works (nc test passes)
- ADB shared keys are available  
- But ADB handshake still times out

### ✅ Step 5: Current ADB Device Status
```bash
adb devices -l
```
**Result**: 
```
List of devices attached
emulator-5554          device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emu64a transport_id:1
```
**Observation**: ADB still sees `emulator-5554` via some other connection path (likely leftover from previous tests)

### ❌ Step 6: Maestro Test Attempts
```bash
export ANDROID_SERIAL=emulator-5554
maestro test hello-world-test.yaml
```
**Result**: 
```
Not enough devices connected (1) to run the requested number of shards (1).
Want to use 0 devices, which is not enough to run 1 shards. Missing 1 device(s).
```

```bash
maestro --device emulator-5554 test hello-world-test.yaml
```
**Result**: `Device emulator-5554 was requested, but it is not connected.` ❌

## Current Status Analysis

### What Works ✅
- **ADB keys**: Shared between host and container via workspace mount
- **Network**: Container can reach host proxy on port 5556
- **Local ADB server**: Running with proper environment configuration
- **Standard ADB**: Can see and communicate with emulator-5554

### What Still Fails ❌
- **TCP Connect**: `adb connect 192.168.65.254:5556` times out despite network connectivity
- **Maestro DADB**: Still cannot recognize emulator-5554 that standard ADB sees
- **Device Visibility**: DADB reports "0 devices" while ADB shows "emulator-5554"

## Root Cause Hypothesis

### ADB Connect Timeout Issue
Despite shared keys and network connectivity, `adb connect` fails. Possible causes:
1. **Host socat proxy**: May not be running or configured correctly
2. **ADB protocol mismatch**: TCP handshake differs from network connectivity test
3. **Firewall/Security**: Host macOS blocking ADB protocol specifically
4. **Port forwarding**: Container→Host networking issue specific to ADB

### Persistent DADB Problem  
Even with `emulator-5554` visible to standard ADB, Maestro's DADB library cannot see it:
- **Different protocols**: DADB vs standard ADB use different device discovery
- **Java library issue**: DADB-1.2.10.jar may have bugs or config requirements
- **Environment variables**: DADB might need specific Java properties

## Next Steps for Expert

Based on expert's troubleshooting suggestions:

### Host-side Diagnostics Needed
```bash
# On host (macOS):
lsof -nP -iTCP:5556 -sTCP:LISTEN    # Verify socat proxy running
tail -n 100 /tmp/socat-5556.log     # Check proxy logs for handshake attempts
```

### Alternative Approaches to Consider
1. **Run Maestro on Host**: Use container for app/server only, Maestro on host where ADB already works
2. **Different Maestro Version**: Try version with working `--host` parameter
3. **Direct Port Forward**: Use Docker port forwarding instead of socat proxy
4. **USB Passthrough**: If possible, pass USB devices directly to container

## Environment Details
- **Container**: AMD64 Ubuntu 24.04.2 LTS, user `vscode`
- **ADB Keys**: Shared via `ANDROID_USER_HOME=/workspaces/mravenci-chuva-android-amd64`
- **Local ADB**: Running on 127.0.0.1:5037 with clean environment
- **Maestro**: v2.0.2 with DADB library (persistent issue)
- **Network**: `192.168.65.254:5556` reachable but ADB connect fails
- **Current State**: Standard ADB works, DADB doesn't recognize same devices