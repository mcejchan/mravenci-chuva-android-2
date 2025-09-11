# Maestro Local ADB Server Solution - Expert Test Results

## Expert Recommendation Implementation

**Expert Strategy**: Use local ADB server in container to connect emulator, then Maestro connects to local server without needing `--host` parameter.

### Expected Flow:
1. Local ADB server in container (127.0.0.1:5037)
2. `adb connect host.docker.internal:5556` to register emulator via host proxy
3. Maestro uses local ADB server automatically
4. Maestro sees emulator as standard device

## Test Results

### ✅ Step 1: Start Local ADB Server
```bash
adb start-server
```
**Result**: Local ADB server started successfully ✅

### ❌ Step 2: Connect via Host Proxy
```bash
adb connect host.docker.internal:5556
adb connect 192.168.65.254:5556
```
**Result**: 
```bash
failed to resolve host: 'host.docker.internal': nodename nor servname provided, or not known
failed to connect to '192.168.65.254:5556': Operation timed out
```
**However**: Network connectivity test passes:
```bash
nc -vz 192.168.65.254 5556
# Connection to 192.168.65.254 5556 port [tcp/freeciv] succeeded!
```

### ✅ Step 3: Verify Device Connection (Alternative Route)
```bash
unset ADB_SERVER_SOCKET
adb kill-server; adb start-server
adb devices -l
```
**Result**: 
```
List of devices attached
emulator-5554          device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emu64a transport_id:1
```
**SUCCESS**: Local ADB server can see emulator-5554 ✅
**Note**: This suggests there's still an active connection to host ADB server

### ❌ Step 4: Test Maestro Without --host
```bash
maestro test hello-world-test.yaml
```
**Result**: 
```
Not enough devices connected (1) to run the requested number of shards (1).
Want to use 0 devices, which is not enough to run 1 shards. Missing 1 device(s).
```

### ❌ Step 5: Test Maestro with Explicit Device
```bash
maestro --device emulator-5554 test hello-world-test.yaml
```
**Result**: 
```
Device emulator-5554 was requested, but it is not connected.
```

### ✅ Sanity Check: ADB Communication
```bash
adb -s emulator-5554 shell getprop ro.product.model
```
**Result**: `sdk_gphone64_arm64` ✅
**SUCCESS**: Standard ADB commands work perfectly with emulator

## Analysis

### What Works ✅
- **Local ADB Server**: Running in container on 127.0.0.1:5037
- **Device Detection**: `adb devices` shows `emulator-5554` as connected
- **ADB Communication**: Can execute shell commands on emulator
- **Network**: Container can reach host proxy on port 5556

### What Fails ❌
- **ADB TCP Connect**: Cannot establish `adb connect` to host proxy
- **Maestro Device Recognition**: DADB library cannot see emulator-5554
- **Maestro Test Execution**: Both automatic and explicit device selection fail

## Root Cause Analysis

### ADB vs DADB Discrepancy
- **Standard ADB**: Successfully communicates with emulator-5554 ✅
- **Maestro DADB**: Cannot recognize the same device ❌

### Connection Route Mystery
The fact that local ADB can see `emulator-5554` without explicit `adb connect` suggests:
1. **Persistent Connection**: There may be a background connection to host ADB server
2. **Environment Variables**: Some ADB environment variable still pointing to host
3. **ADB Bridge**: Local ADB might be bridging to host ADB server automatically

### DADB Library Issue
Maestro's DADB Java library (`dadb-1.2.10.jar`) appears to:
- Use different device discovery mechanism than standard ADB
- Not recognize devices that standard ADB can see
- Potentially require different device registration process

## Current Status: Partial Success

**Progress Made:**
- ✅ Local ADB server operational
- ✅ Device visible to standard ADB
- ✅ ADB communication functional

**Still Blocked:**
- ❌ Maestro/DADB cannot see connected devices
- ❌ TCP proxy connection method unsuccessful
- ❌ No working path to run Maestro tests

## Hypothesis for Expert

The issue appears to be fundamental incompatibility between:
1. **Standard ADB protocol/discovery** (works with emulator)
2. **DADB library device recognition** (cannot see same devices)

**Possible Solutions to Investigate:**
1. **DADB Configuration**: Missing environment variables or config for DADB
2. **Device Registration**: DADB requires different device registration process
3. **Maestro Version**: Try different Maestro version with working `--host` support
4. **Alternative Approach**: Use Maestro on host system instead of container

## Environment Details
- **Container**: AMD64 Ubuntu 24.04.2 LTS
- **ADB Server**: Local 127.0.0.1:5037 (started successfully)
- **Maestro**: v2.0.2 with DADB Java library
- **Target**: ARM64 emulator-5554 (visible to ADB, invisible to DADB)
- **Network**: Container↔Host connectivity confirmed