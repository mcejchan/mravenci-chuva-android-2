# Maestro Direct adbd Connection - Troubleshooting Log

## Expert Recommendation Test

**Expert advice**: Na hostu běží proxy a Maestro směřovat přímo na adbd:
```bash
# neměj spuštěný lokální ADB server v kontejneru
adb kill-server || true

# jednoduchý smoke test konektivity:
nc -vz host.docker.internal 5556

# Maestro přímo na adbd:
maestro --device host.docker.internal:5556 devices
maestro --device host.docker.internal:5556 test hello-world-test.yaml
```

## Test Results

### ✅ Step 1: Kill Local ADB Server
```bash
adb kill-server || true
```
**Result**: Local ADB server stopped successfully ✅

### ✅ Step 2: Network Connectivity Test
```bash
nc -vz host.docker.internal 5556
```
**Result**: 
```
Connection to host.docker.internal (192.168.65.254) 5556 port [tcp/freeciv] succeeded!
```
**SUCCESS**: Network connection to host port 5556 works perfectly ✅

### ❌ Step 3: Maestro Device Detection
```bash
maestro --device host.docker.internal:5556 devices
```
**Result**: 
```
Unmatched argument at index 2: 'devices'
Did you mean: start-device or test or download-samples?
```
**NOTE**: Maestro doesn't have `devices` command, only `test`, `start-device`, etc.

### ❌ Step 4: Maestro Test Execution
```bash
maestro --device host.docker.internal:5556 test hello-world-test.yaml
maestro --udid host.docker.internal:5556 test hello-world-test.yaml
```
**Result**: Both attempts failed with:
```
Device host.docker.internal:5556 was requested, but it is not connected.
```

## Analysis

### What Works ✅
- Network connectivity: Container can reach `host.docker.internal:5556` 
- Host proxy should be running: `socat TCP-LISTEN:5556,reuseaddr,fork TCP:127.0.0.1:5555`
- Port 5556 is accessible from container

### What Fails ❌
- Maestro cannot recognize `host.docker.internal:5556` as connected device
- Both `--device` and `--udid` parameters fail with same error
- DADB library doesn't see the TCP device as "connected"

## Current Status

**Connection Chain:**
- ✅ Emulator: `127.0.0.1:5555` (adbd in TCP mode)
- ✅ Host proxy: `socat TCP-LISTEN:5556 → TCP:127.0.0.1:5555` 
- ✅ Network: `container → host.docker.internal:5556` (nc test successful)
- ❌ DADB: Cannot recognize `host.docker.internal:5556` as connected device

## Hypothesis

The issue appears to be with how Maestro's DADB library handles TCP device connections:

1. **DADB Device Discovery**: DADB may require devices to be "registered" or "paired" before use
2. **Connection Format**: Format `host.docker.internal:5556` might not be valid for DADB
3. **TCP vs USB Detection**: DADB might distinguish between USB and TCP devices differently
4. **Missing Device Handshake**: TCP devices might need ADB handshake before DADB recognizes them

## Potential Next Steps

1. **Check if host proxy is actually running and forwarding**
2. **Try standard ADB connect to verify TCP device works**: `adb connect host.docker.internal:5556`
3. **Research DADB TCP device connection requirements**
4. **Check Maestro logs for more detailed error information**
5. **Contact expert about DADB-specific TCP device connection process**

## Environment Details
- **Container**: AMD64 Ubuntu 24.04.2 LTS
- **Network**: `host.docker.internal` → `192.168.65.254`
- **Maestro**: v2.0.2 (with DADB Java library)
- **Target**: ARM64 emulator via TCP proxy on port 5556