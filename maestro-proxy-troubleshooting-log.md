# Maestro TCP Proxy Troubleshooting Log

## Implementation of Solution A: TCP Proxy via socat

Based on expert recommendation, implementing TCP proxy `localhost:5037` → `host.docker.internal:5037`

### ✅ Step 1: Stop Local ADB Server
```bash
adb kill-server || true
pkill -f 'adb.*server' || true
ss -lntp | grep 5037 || echo "Port 5037 is free"
```
**Result**: Port 5037 is free ✅

### ✅ Step 2: Install socat
```bash
sudo apt-get update && sudo apt-get install -y socat
```
**Result**: socat installed successfully ✅

### ✅ Step 3: Create TCP Proxy
```bash
nohup socat TCP-LISTEN:5037,reuseaddr,fork TCP:host.docker.internal:5037 >/tmp/socat5037.log 2>&1 &
sleep 1; ss -lntp | grep 5037
```
**Result**: 
```
LISTEN 0      0            0.0.0.0:5037       0.0.0.0:*    users:(("socat",pid=4798,fd=6))
```
Proxy is running ✅

### ✅ Step 4: Verify ADB Through Proxy
```bash
unset ADB_SERVER_SOCKET
adb devices
```
**Result**: 
```
List of devices attached
emulator-5554	device
```
**SUCCESS**: ADB can see emulator through proxy ✅

### ❌ Step 5: Test Maestro Device Detection
```bash
export PATH="$PATH":"$HOME/.maestro/bin"
maestro test hello-world-test.yaml
```
**Result**: 
```
Not enough devices connected (1) to run the requested number of shards (1).
Want to use 0 devices, which is not enough to run 1 shards. Missing 1 device(s).
```
**FAILED**: Maestro still cannot see device ❌

## Additional Troubleshooting Attempts

### Attempt 1: Full Path to Maestro
```bash
$HOME/.maestro/bin/maestro test hello-world-test.yaml
```
**Result**: Same error - no devices detected ❌

### Attempt 2: Explicit ANDROID_HOME
```bash
ANDROID_HOME=/opt/android-sdk $HOME/.maestro/bin/maestro test hello-world-test.yaml
```
**Result**: Same error - no devices detected ❌

### Attempt 3: Prioritize Android SDK ADB in PATH
```bash
PATH="/opt/android-sdk/platform-tools:/usr/bin:$PATH" $HOME/.maestro/bin/maestro test hello-world-test.yaml
```
**Result**: Same error - no devices detected ❌

## Current Status Analysis

### What Works ✅
- socat TCP proxy is running on `0.0.0.0:5037`
- Standard ADB commands can see `emulator-5554` through proxy
- Connection chain: `container:5037` → `socat` → `host.docker.internal:5037` → `emulator-5554`

### What Fails ❌
- Maestro cannot detect any devices
- Error consistently shows "Want to use 0 devices" - indicating Maestro sees zero devices

### Hypothesis
Maestro may be:
1. Using its own bundled ADB binary that ignores our proxy
2. Connecting to a different port or protocol
3. Requiring additional environment variables or configuration
4. Having issues with the socat proxy implementation

## Additional Troubleshooting - Round 2

### Attempt 4: Check socat Logs
```bash
cat /tmp/socat5037.log
```
**Result**: Empty log file - no traffic going through proxy

### Attempt 5: Verify Process on Port 5037
```bash
lsof -i :5037
```
**Result**: 
```
COMMAND  PID   USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
socat   4798 vscode    6u  IPv4 7951432      0t0  TCP *:5037 (LISTEN)
```
Proxy is listening correctly ✅

### Attempt 6: Check for Maestro's ADB Implementation  
```bash
find $HOME/.maestro -name "*adb*" -type f
```
**Result**: `/home/vscode/.maestro/lib/dadb-1.2.10.jar`

**DISCOVERY**: Maestro uses DADB (Direct ADB) Java library instead of system ADB! 🔍

### Attempt 7: Restart Proxy & Test Again
```bash
pkill socat; sleep 1
nohup socat TCP-LISTEN:5037,reuseaddr,fork TCP:host.docker.internal:5037 >/tmp/socat5037.log 2>&1 &
MAESTRO_CLI_NO_ANALYTICS=1 $HOME/.maestro/bin/maestro test hello-world-test.yaml
```
**Result**: Same error - no devices detected ❌

## Root Cause Analysis

### Key Discovery: DADB vs System ADB
- **System ADB**: Works through our socat proxy ✅
- **Maestro DADB**: Java-based ADB implementation in `dadb-1.2.10.jar` ❌
- **Problem**: DADB may have different connection logic than standard ADB

### Traffic Analysis
- socat proxy log is empty - suggests DADB isn't even trying to connect to port 5037
- DADB might be using different discovery mechanism
- Could be using USB-based discovery or different port

## Next Steps to Try
1. ~~Check if Maestro has embedded ADB~~ ✅ Confirmed: Uses DADB Java library
2. ~~Verify socat proxy is actually forwarding requests~~ ✅ No traffic, DADB not connecting
3. Research DADB connection behavior and configuration options
4. Try monitoring other ports DADB might use
5. Consider Java system properties for DADB configuration
6. Investigate if DADB respects ANDROID_ADB_SERVER_HOST/PORT environment variables

## Environment Details
- **Container**: AMD64 Ubuntu 24.04.2 LTS
- **socat**: v1.8.0.0-4build3  
- **ADB**: /usr/bin/adb and /opt/android-sdk/platform-tools/adb
- **Maestro**: Latest version (installed via curl script)
- **Target**: ARM64 emulator-5554 on host system

---

## Expert Solution Attempt - Round 3

### Expert Analysis: DADB vs ADB Connection Issue
**Expert insight**: Maestro doesn't use system ADB - uses DADB library that can either:
1. Connect directly to adbd (port 5555) 
2. Connect to ADB server on host via `--host` parameter

### ✅ Step 1: Host ADB Server with -a Flag (Completed)
```bash
# On host (macOS):
adb kill-server
adb -a -P 5037 nodaemon server
```
**Result**: 
```
09-08 22:48:04.055 10037 3195110 I adb     : udp_socket.cpp:170 AdbUdpSocket fd=9
...
09-08 22:48:04.056 10037 3195119 I adb     : transport.cpp:344 emulator-5554: read thread spawning
09-08 22:48:04.056 10037 3195120 I adb     : transport.cpp:315 emulator-5554: write thread spawning
```
ADB server listening on all interfaces with emulator-5554 connected ✅

### ✅ Step 2: Container ADB Connection Test (Completed)
```bash
# In container:
adb kill-server
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037
adb devices
```
**Result**: 
```
List of devices attached
emulator-5554	device
```
Container can see emulator through host ADB server ✅

### ❌ Step 3: Maestro with --host Parameter (Failed)
```bash
# Multiple attempts:
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037
MAESTRO_CLI_NO_ANALYTICS=1 maestro --host host.docker.internal test hello-world-test.yaml
MAESTRO_CLI_NO_ANALYTICS=1 maestro --host host.docker.internal --device emulator-5554 test hello-world-test.yaml
MAESTRO_CLI_NO_ANALYTICS=1 maestro --host 192.168.65.254 test hello-world-test.yaml
```
**Result**: All attempts failed with:
```
Not enough devices connected (1) to run the requested number of shards (1).
Want to use 0 devices, which is not enough to run 1 shards. Missing 1 device(s).
```

### Analysis
- **System ADB**: Works perfectly through `tcp:host.docker.internal:5037` ✅
- **Maestro DADB**: Cannot see devices despite `--host` parameter ❌  
- **Host ADB Server**: Running correctly, shows no incoming connections from Maestro
- **Issue**: DADB library in Maestro 2.0.2 not connecting to specified host

### Current Status: Expert Solution Partially Works
- ✅ Host ADB server accessible from container
- ✅ Standard ADB commands work  
- ❌ Maestro/DADB still cannot discover devices despite --host parameter
- ❌ No traffic visible in host ADB server logs when Maestro runs

### Next Investigation Required
Need to determine why DADB is not connecting to the specified host:5037 server.

---

## Critical Discovery - Round 4

### 🚨 MAJOR FINDING: --host Flag Does NOT Exist!

#### Maestro Version & Flags Check
```bash
maestro -v
# 2.0.2

maestro --help | head -20
```
**Result**: Main help shows no `--host` flag:
```
Usage: maestro [-hv] [--[no-]ansi] [--verbose] [-p=<platform>] [--udid=<deviceId>] [COMMAND]
  --udid, --device=<deviceId>
                  (Optional) Device ID to run on explicitly
```

```bash
maestro test --help
```
**Result**: Test subcommand also has **NO --host parameter** ❌
- Available flags: `--config`, `--debug-output`, `--format`, `--shards`, etc.
- **Missing**: `--host`, `--adb-host`, `--adb-server-host`, or any remote connection flag

#### DNS Resolution Check
```bash
getent hosts host.docker.internal
```
**Result**: `192.168.65.254  host.docker.internal` ✅

#### Verbose Device Detection
```bash
MAESTRO_CLI_NO_ANALYTICS=1 maestro --verbose test hello-world-test.yaml
```
**Result**: 
```
[INFO] Maestro Version: 2.0.2
[INFO] OS Name: Linux
[INFO] Architecture: amd64
[INFO] Java Version: 17
[DEBUG] Using SLF4J as the default logging framework

Not enough devices connected (1) to run the requested number of shards (1).
Want to use 0 devices, which is not enough to run 1 shards. Missing 1 device(s).
```

### Root Cause Identified: Wrong Maestro Version/Build
**Problem**: Maestro 2.0.2 build does **NOT** have `--host` parameter that expert documentation mentions!

- Expert referenced GitHub and docs.maestro.dev for WSL with `--host <HOST_IP>`
- Our Maestro 2.0.2 was installed via curl script
- This version apparently lacks remote ADB server connection capability

### Hypothesis
Either:
1. **Different Maestro builds**: WSL/Windows version has `--host`, Linux version doesn't
2. **Version mismatch**: Documentation refers to newer/different version  
3. **Installation method**: Official docs assume different installation (e.g., npm, brew)
4. **Feature removed**: `--host` was removed in recent versions

### Next Steps Required
1. **Verify Maestro installation method and available versions**
2. **Check if different installation provides `--host` flag** 
3. **Research alternative DADB connection methods without --host**
4. **Contact expert about version discrepancy**

---

## Expert Solution B: Direct adbd Connection - Round 5

### Alternative Approach: Bypass ADB Server Completely
**Expert suggestion**: Since `--host` flag doesn't exist, connect DADB directly to adbd via TCP.

#### ✅ Step 1: Host socat Proxy Setup (Completed)
```bash
# On host (macOS):
lsof -iTCP:5556 -sTCP:LISTEN || echo "Port 5556 is free"
sudo socat TCP-LISTEN:5556,reuseaddr,fork TCP:127.0.0.1:5555
```
**Result**: Host proxy `5556 → 127.0.0.1:5555` running ✅

#### ✅ Step 2: Verify Emulator TCP Mode
```bash
# In container:
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037
adb -s emulator-5554 shell getprop service.adb.tcp.port
```
**Result**: `5555` - Emulator in TCP mode ✅

#### ❌ Step 3: Direct Maestro Connection (Failed)
```bash
# Multiple attempts:
maestro --device host.docker.internal:5556 test hello-world-test.yaml
maestro --udid host.docker.internal:5556 test hello-world-test.yaml  
maestro --udid 192.168.65.254:5556 test hello-world-test.yaml
```
**Result**: All failed with:
```
Device host.docker.internal:5556 was requested, but it is not connected.
Device 192.168.65.254:5556 was requested, but it is not connected.
```

#### ❌ Step 4: ADB Direct Connection Test
```bash
adb connect host.docker.internal:5556  # DNS resolution failed
adb connect 192.168.65.254:5556        # Connection timed out
```
**Results**: 
- DNS: `failed to resolve host: 'host.docker.internal'`
- IP: `failed to connect to '192.168.65.254:5556': Operation timed out`

### Analysis
**Connection Chain Issues**:
- ✅ Emulator: `127.0.0.1:5555` (TCP mode active)
- ✅ Host socat: `5556 → 127.0.0.1:5555` (proxy running)  
- ❌ Container→Host: `host.docker.internal:5556` (connection fails)

**Possible Problems**:
1. **Host firewall**: macOS blocking incoming connections to port 5556
2. **Docker networking**: `host.docker.internal` not exposing custom ports properly
3. **socat binding**: Proxy might be listening on wrong interface
4. **DADB implementation**: Maestro 2.0.2 DADB might not support TCP device strings

### Current Status: Both Expert Solutions Failed
- ❌ **Solution A**: `--host` parameter doesn't exist in Maestro 2.0.2
- ❌ **Solution B**: Direct TCP connection fails (network/firewall issues)

### Root Problem Remains
Maestro 2.0.2 in container cannot connect to emulator on host, despite:
- Standard ADB working perfectly via ADB server proxy
- Emulator being in TCP mode
- Multiple connection methods attempted