# Diagnostics Output for Expert Review

## Session: 2025-09-07

Expert requested detailed diagnostics to find root cause quickly. Running comprehensive checks as requested.

---

## A) Síť & porty (host ↔ kontejner ↔ emulátor)

### DNS a host.docker.internal
```
getent hosts host.docker.internal || cat /etc/hosts
# Result: 192.168.65.254  host.docker.internal
```

### IP routing
```
ip route  
# Result:
default via 172.17.0.1 dev eth0 
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.2
```

### Kdo naslouchá v kontejneru
```
ss -lntp | grep -E ':(8081|19000|19001)'
# Result:
LISTEN 0      0                  *:8081             *:*    users:(("node",pid=796,fd=23))
Cannot open netlink socket: Protocol not supported
# Note: Only port 8081 (Metro) is listening, ports 19000/19001 not visible
```

### Reverse mapy na zařízení
```
adb -s emulator-5554 reverse --list
# Result: ✅ All 3 ports properly mapped:
host-16 tcp:8081 tcp:8081
host-16 tcp:19000 tcp:19000  
host-16 tcp:19001 tcp:19001
```

### Z emulátoru k Expo/Metru
```
adb -s emulator-5554 shell 'curl -I http://127.0.0.1:19000' || true
# Result: /system/bin/sh: curl: inaccessible or not found

adb -s emulator-5554 shell 'curl -I http://127.0.0.1:8081' || true  
# Result: /system/bin/sh: curl: inaccessible or not found
# Note: curl not available on emulator (expected)
```

---

## B) Expo/Metro diagnostika

### Versions
```
npx expo --version
# Result: 0.24.21

node -v  
# Result: v20.19.5

npx expo-env-info || npx expo diagnostics || true
# Result:
expo-env-info 1.3.4 environment info:
    System:
      OS: Linux 6.10 Ubuntu 24.04.2 LTS 24.04.2 LTS (Noble Numbat)
      Shell: 5.2.21 - /bin/bash
    Binaries:
      Node: 20.19.5 - /usr/bin/node
      Yarn: 1.22.22 - /usr/bin/yarn
      npm: 10.8.2 - /usr/bin/npm
    SDKs:
      Android SDK:
        API Levels: 35, 36
        Build Tools: 35.0.0, 36.0.0
    npmPackages:
      expo: ~53.0.22 => 53.0.22 
      react: 19.0.0 => 19.0.0 
      react-native: 0.79.5 => 0.79.5 
    npmGlobalPackages:
      eas-cli: 16.18.0
    Expo Workflow: managed
```

### Current Expo Status (Running in Background)
```
# Metro bundler still stuck on:
"Starting Metro Bundler"
"warning: Bundler cache is empty, rebuilding (this may take a minute)"
"Waiting on http://localhost:8081"

# STATUS: Metro never finished rebuilding cache after ~1 hour
```

---

## C) ADB/emulátor stav

### ADB Version
```
adb version
# Result:
Android Debug Bridge version 1.0.41
Version 34.0.4-debian
Installed as /usr/lib/android-sdk/platform-tools/adb
Running on Linux 6.10.14-linuxkit (x86_64)
```

### Device Details
```
adb devices -l
# Result: emulator-5554 device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emu64a transport_id:1

adb -s emulator-5554 shell getprop ro.product.cpu.abi
# Result: arm64-v8a

adb -s emulator-5554 shell getprop ro.build.version.release  
# Result: 16

adb -s emulator-5554 shell settings get global http_proxy
# Result: null
```

---

## E) NPM/HTTP konektivita z kontejneru

### Network Connectivity
```
npm ping
# Result: npm notice PING https://registry.npmjs.org/
# npm notice PONG 903ms

curl -I https://registry.npmjs.org/ || true
# Result: HTTP/2 200 ✅ (successful connection)

curl -I https://dl.google.com/ || true  
# Result: HTTP/2 302 ✅ (successful connection)

env | grep -i -E 'http_proxy|https_proxy|no_proxy' || true
# Result: (no proxy environment variables set)
```

---

## F) Projektové detaily (Hello World)

### Package Configuration
```
cat package.json
# Result:
{
  "name": "hello-world",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "expo start",
    "android": "expo run:android",
    "ios": "expo run:ios",
    "web": "expo start --web"
  },
  "dependencies": {
    "expo": "~53.0.22",
    "expo-status-bar": "~2.2.3",
    "react": "19.0.0",
    "react-native": "0.79.5"
  },
  "devDependencies": {
    "@babel/core": "^7.20.0"
  },
  "private": true
}

ls -la app.* || true
# Result: -rw-r--r-- 1 vscode vscode 693 Sep  6 18:55 app.json
```

---

## CRITICAL FINDING: Metro Bundler Stuck

**🔴 MAIN ISSUE IDENTIFIED:**
- Metro bundler has been "rebuilding cache" for over 1 hour
- Never progresses past "Waiting on http://localhost:8081"
- Only port 8081 is listening, ports 19000/19001 never start
- Network connectivity is working (npm ping 903ms, all external URLs reachable)
- This explains why Expo Go shows infinite spinner - no dev server running on 19000

**Next Steps Needed:**
- D) Logcat analysis (requires opening Expo Go first)
- Investigate why Metro bundler cache rebuild is stuck
- Consider alternative Metro startup approaches

---

## EXPERT SOLUTION: Move node_modules to Docker Volume

**Problem Identified:** Bind-mount workspace causing slow node_modules access
**Solution:** Use Docker volumes for node_modules and cache, keep bind-mount only for source code

### Step 1: Update .devcontainer/devcontainer.json ✅
```json
"mounts": [
  "source=android-sdk-amd64,target=/opt/android-sdk,type=volume",
  "source=${localWorkspaceFolder}/.gradle,target=/home/vscode/.gradle,type=bind",
  "source=${localWorkspaceFolder}/.android,target=/home/vscode/.android,type=bind",
  
  // ⬇️ NEW: Fast volumes for node_modules and cache
  "type=volume,source=hello_world_node_modules,target=/workspaces/mravenci-chuva-android-amd64/hello-world/node_modules",
  "type=volume,source=expo_cache,target=/home/vscode/.cache/expo",
  "type=volume,source=metro_cache,target=/home/vscode/.cache/metro"
]
```
**Status:** ✅ devcontainer.json updated with new volume mounts

### Step 2: Instructions for Container Rebuild
**IMPORTANT:** Container needs to be rebuilt to apply new volume mounts.
User should:
1. Close VS Code
2. Reopen in Dev Container (will rebuild with new volumes)
3. Continue with Step 3 inside new container

### Step 3: Clean Reinstall in Fast Volumes
```bash
cd hello-world
rm -rf node_modules .expo .expo-shared  # Remove old bind-mounted data
npm ci                                   # Clean install to fast volume
```