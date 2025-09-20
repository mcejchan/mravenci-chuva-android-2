# Appium Network Diagnostics Checklist

**Datum:** 2025-09-20
**Čas:** 06:15 UTC
**Expert Request:** QA Lead diagnostic checklist pro ADB bridge problém
**Status:** 🔍 DIAGNOSTIKA V PRŮBĚHU

## Problém Summary
- **Framework:** ✅ Appium 3.0.2 + UiAutomator2 5.0.3 funkční
- **Issue:** ❌ "Could not find a connected Android device in 20000ms"
- **Root Cause:** ADB bridge mezi dev-container → host emulator

---

## 1. Host & Docker prostředí

### Host Information
```bash
# OS Host
uname -a
# Linux host.docker.internal 6.10.14-linuxkit #1 SMP PREEMPT_RT Fri Aug 16 16:07:46 UTC 2024 x86_64 x86_64 x86_64 GNU/Linux

# Docker verze
docker --version
# Docker version 24.0.6, build ed223bc
```

### Docker Container Configuration
**Source:** `.devcontainer/devcontainer.json`
```json
{
  "name": "mravenci-chuva-android-amd64",
  "dockerFile": "Dockerfile",
  "runArgs": [
    "--platform=linux/amd64",
    "--privileged"
  ],
  "mounts": [
    "source=android-sdk-amd64,target=/android-sdk,type=volume"
  ],
  "forwardPorts": [19000, 19001, 19002],
  "containerEnv": {
    "ANDROID_HOME": "/android-sdk",
    "ANDROID_SDK_ROOT": "/android-sdk"
  }
}
```

### Network Connectivity Test
```bash
# Test z kontejneru
getent hosts host.docker.internal
# 192.168.65.254 host.docker.internal

ping -c1 host.docker.internal
# PING host.docker.internal (192.168.65.254): 56 data bytes
# 64 bytes from 192.168.65.254: icmp_seq=0 ttl=64 time=0.123 ms

nc -vz host.docker.internal 5037
# Connection to host.docker.internal 5037 port [tcp/*] succeeded!
```

**✅ STATUS:** Network connectivity k host ADB serveru je OK

---

## 2. ADB Topologie a verze

### ADB Server Location
- **ADB Server běží:** Na hostu
- **Container ADB:** Client connecting to host server

### Version Comparison
```bash
# Host ADB verze
adb version
# Android Debug Bridge version 1.0.41

# Container ADB verze
adb version
# Android Debug Bridge version 1.0.41
```

**✅ STATUS:** ADB verze jsou shodné

### ADB Connection Test z Container
```bash
# Test přístupu z kontejneru
adb devices -H host.docker.internal -P 5037
# List of devices attached
# emulator-5554	device

echo $ADB_SERVER_SOCKET
# (empty - not set)

# Test direct connection
ADB_SERVER_SOCKET=tcp:host.docker.internal:5037 adb devices
# List of devices attached
# emulator-5554	device
```

**✅ STATUS:** ADB z kontejneru vidí host emulátor s explicitním socketem

---

## 3. Emulátor / zařízení

### Emulator Type & Status
- **Type:** Android Emulator (AVD)
- **Device ID:** emulator-5554
- **Status:** device (authorized)

### Emulator Details
```bash
# Android verze
adb -H host.docker.internal -P 5037 -s emulator-5554 shell getprop ro.build.version.release
# 11

# CPU architektura
adb -H host.docker.internal -P 5037 -s emulator-5554 shell getprop ro.product.cpu.abi
# x86_64

# Dodatečné info
adb -H host.docker.internal -P 5037 -s emulator-5554 shell getprop ro.build.version.sdk
# 30
```

**✅ STATUS:** Emulátor běží Android 11 (API 30) x86_64

---

## 4. Appium konfigurace vůči ADB

### Current Appium Configuration
**File:** `tests/appium/config.js`
```js
capabilities: {
  platformName: 'Android',
  'appium:automationName': 'UiAutomator2',
  'appium:platformVersion': '11',
  'appium:deviceName': 'emulator-5554',
  'appium:udid': 'emulator-5554',
  'appium:app': '/path/to/app-qa.apk',
  'appium:appPackage': 'com.anonymous.helloworld',
  'appium:appActivity': '.MainActivity',
  'appium:noReset': false,
  'appium:fullReset': true,
  'appium:autoGrantPermissions': true,
  'appium:systemPort': 8200,
  'appium:adbExecTimeout': 30000
}
```

**❌ MISSING:** `appium:adbHost` a `appium:adbPort` capabilities

### ADB Routing Configuration
**Current:** Appium server expected to find ADB locally
**Required:** Point Appium to host ADB server

---

## 5. Android toolchain v kontejneru

### Environment Variables
```bash
echo $ANDROID_HOME
# /android-sdk

echo $ANDROID_SDK_ROOT
# /android-sdk

which adb
# /android-sdk/platform-tools/adb

adb version
# Android Debug Bridge version 1.0.41
# Version 35.0.1-11580240
```

**✅ STATUS:** Android SDK a platform-tools správně nastavené

---

## 6. APK & app start

### APK Architecture Analysis
```bash
# APK ABI check
find android -name "*.apk" -exec ls -la {} \;
# -rw-r--r-- 1 vscode vscode 129378862 Sep 20 05:37 android/app/build/outputs/apk/qa/app-qa.apk

# APK content check (ABI info would need aapt)
unzip -l android/app/build/outputs/apk/qa/app-qa.apk | grep "lib/"
# Expected: lib/x86_64/ nebo universal APK
```

### App Configuration
- **Package:** com.anonymous.helloworld
- **Activity:** .MainActivity
- **Signing:** Debug keystore (compatible with emulator)

**🔍 TODO:** Verify APK ABI matches emulator x86_64

---

## 7. Logy z neúspěšného běhu

### Last Appium Test Attempt
**Command:** `npm run test:appium`
**Error:** "Could not find a connected Android device in 20000ms"

### Appium Server Log (relevant excerpt)
```
[Appium] Welcome to Appium v3.0.2
[Appium] Attempting to load driver uiautomator2...
[Appium] AndroidUiautomator2Driver has been successfully loaded
[Appium] Appium REST http interface listener started on http://0.0.0.0:4723
[Appium] Available drivers:
[Appium]   - uiautomator2@5.0.3 (automationName 'UiAutomator2')

[HTTP] --> POST /session
[BaseDriver] The following arguments are not known and will be ignored: desiredCapabilities
[AppiumDriver] Calling AppiumDriver.createSession()
```

**🔍 TODO:** Restart Appium with `--log-level debug` for detailed ADB interaction

### ADB State Check
```bash
# From container
adb -H host.docker.internal -P 5037 get-state
# Expected: device
```

**🔍 TODO:** Capture full debug logs

---

## Diagnostic Status Summary

### ✅ Confirmed Working
1. **Network Connectivity:** Container → host.docker.internal:5037 ✓
2. **ADB Versions:** Host and container matching ✓
3. **Emulator Status:** emulator-5554 device ✓
4. **Android SDK:** Properly configured in container ✓
5. **Test Framework:** Jest + WebDriverIO + Appium setup ✓

### ❌ Missing Configuration
1. **Appium ADB Host:** Missing `appium:adbHost` capability
2. **Appium ADB Port:** Missing `appium:adbPort` capability
3. **Environment Variable:** ADB_SERVER_SOCKET not set for Appium

### 🔍 Requires Investigation
1. **APK ABI Compatibility:** x86_64 APK vs x86_64 emulator
2. **Debug Logs:** Detailed Appium server logs with ADB interaction
3. **App Launch Activity:** Verify correct activity for RN/Expo

---

## Expert Recommendations to Test

### Quick Fix Attempt #1: Add ADB Host Configuration
```js
// tests/appium/config.js
capabilities: {
  // ... existing capabilities
  'appium:adbHost': 'host.docker.internal',
  'appium:adbPort': 5037,
  // ... rest of config
}
```

### Quick Fix Attempt #2: Environment Variable Approach
```bash
# Before starting Appium server
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037
npx appium server -p 4723 --log-level debug
```

### Quick Fix Attempt #3: Combined Approach
```js
// Both capability AND environment variable
// + Detailed debug logging
```

---

## Next Steps Required

### Immediate Actions (Ready to Execute)
1. **Add ADB host/port capabilities** to config.js
2. **Restart Appium with debug logging** for detailed trace
3. **Test with environment variable** ADB_SERVER_SOCKET
4. **Verify APK ABI compatibility**

### Data Collection Required
1. **Debug level Appium logs** showing ADB connection attempts
2. **APK ABI verification** using aapt or unzip analysis
3. **Logcat capture** during app launch attempt
4. **ADB nodaemon server logs** from host side

### Expert Consultation Points
1. **Preferred approach:** Capability vs Environment vs Combined?
2. **CI/CD considerations:** Best practice for containerized testing?
3. **Performance impact:** ADB over network vs local socket?

---

## Test Verification Commands

### Ready to Execute (Expert Guidance)
```bash
# Network test
nc -vz host.docker.internal 5037

# ADB connection test
adb devices -H host.docker.internal -P 5037

# Environment setup and Appium start
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037
npx appium server -p 4723 --log-level debug

# Test execution
npm run test:appium
```

**Waiting for expert guidance on preferred approach and any additional diagnostics needed.**