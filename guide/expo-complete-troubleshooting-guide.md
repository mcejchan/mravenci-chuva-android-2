# Expo Go Hello World - Kompletní troubleshooting guide

*Vytvořeno: 2025-09-08 na základě úspěšného rozběhnutí Hello World aplikace*

## 🎯 Cíl
Spustit "Hello World! 🌍" aplikaci v Expo Go na Android emulátoru v AMD64 Docker kontejneru.

## 📋 Stručný přehled řešení
**Klíčový problém**: SDK version mismatch mezi Expo Go aplikací a projektem  
**Řešení**: Stáhnout správnou verzi Expo Go kompatibilní s vaším SDK z `expo.dev/go`

## 🖥️ Verified Working Configuration

### Dev Container Environment (AMD64)
- **OS**: Ubuntu 24.04.2 LTS (Noble Numbat)
- **Architecture**: x86_64 (AMD64) 
- **Node.js**: v20.19.5 (x64 architecture)
- **NPM**: 10.8.2
- **Expo CLI**: 0.24.21 (Node.js script)
- **Java**: OpenJDK 17.0.16 (x86-64 architecture)
- **JAVA_HOME**: `/usr/lib/jvm/java-17-openjdk-amd64`
- **ADB**: v35.0.2-12147458 (x86-64 binary)

### Project Dependencies (Working)
```json
{
  "expo": "53.0.22",           // Exact installed version
  "expo-status-bar": "2.2.3", 
  "react": "19.0.0",
  "react-native": "0.79.5",
  "@babel/core": "7.28.4"
}
```

### Android Emulator (ARM64)
- **Device**: `emulator-5554`
- **Android Version**: 16 (API 35)
- **Architecture**: `arm64-v8a` (ARM64)
- **Target SDK**: 35 (minSdk: 24)
- **CPU ABI**: arm64-v8a (confirmed via `adb shell getprop ro.product.cpu.abi`)

### Expo Go (Working Version)
- **Version Name**: `2.33.22`
- **Version Code**: `379`
- **SDK Compatibility**: SDK 53
- **APK Source**: `https://expo.dev/go?device=false&platform=android&sdkVersion=53`
- **APK Size**: ~181MB
- **Architecture Support**: arm64-v8a + x86_64

### DevContainer Configuration
```json
{
  "runArgs": ["--add-host=host.docker.internal:host-gateway"],
  "mounts": [
    "source=android-sdk-amd64,target=/opt/android-sdk,type=volume",
    "source=hello_world_node_modules,target=/workspaces/.../node_modules,type=volume",
    "source=expo_cache,target=/home/vscode/.cache/expo,type=volume",
    "source=metro_cache,target=/home/vscode/.cache/metro,type=volume"
  ],
  "containerEnv": {
    "ANDROID_SDK_ROOT": "/opt/android-sdk"
  }
}
```

### Network Configuration
- **ADB Connection**: `tcp:host.docker.internal:5037`
- **Port Forwarding**: 8081, 19000, 19001
- **Expo Server**: `http://localhost:19000`
- **Metro Bundler**: `http://localhost:8081`

### Environment Variables (Critical)
```bash
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037    # ADB connection
export NODE_OPTIONS="--max_old_space_size=4096"           # Metro memory
export CHOKIDAR_USEPOLLING=1                              # File watching
export CHOKIDAR_INTERVAL=100                              # Polling interval
export ANDROID_SDK_ROOT=/opt/android-sdk                  # SDK path
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64      # Java path
```

### Performance Characteristics (AMD64 Container)
- **Metro Bundle Time**: ~56 seconds (677 modules)
- **Metro Startup Time**: 30-90 seconds (varies by system)
- **Cache Rebuild**: 1-2 minutes on first run
- **Docker Volumes**: Used for `node_modules`, expo cache, metro cache (performance critical)

---

## 🏗️ Architecture Analysis: AMD64 vs ARM64

**KRITICKÉ**: Tato konfigurace kombinuje AMD64 dev container s ARM64 emulátorem.

### 🖥️ Dev Container Components (AMD64 Architecture)
All development tools run in x86-64 (AMD64) architecture:

**System Components**:
- **Container OS**: Ubuntu 24.04.2 LTS (x86-64)
- **Java**: OpenJDK 17.0.16 (x86-64)
  - Binary: `/usr/lib/jvm/java-17-openjdk-amd64/bin/java`
  - Architecture: `ELF 64-bit LSB pie executable, x86-64`
- **Node.js**: v20.19.5 (x64)
  - Binary: `/usr/bin/node`  
  - Architecture: `ELF 64-bit LSB executable, x86-64`

**Android Development Tools**:
- **ADB**: v35.0.2-12147458 (x86-64)
  - Binary: `/opt/android-sdk/platform-tools/adb`
  - Architecture: `ELF 64-bit LSB pie executable, x86-64`
- **Android SDK CLI Tools**: Shell scripts (architecture-agnostic)
  - sdkmanager, avdmanager: `sh script, ASCII text executable`

**JavaScript/Node.js Tools**:
- **Expo CLI**: v0.24.21 (Node.js script, runs on x64 Node.js)
  - Type: `Node.js script executable, ASCII text`
- **npm packages**: All JavaScript/TypeScript (architecture-agnostic)

### 📱 Android Emulator Components (ARM64 Architecture)  
The emulator runs ARM64 architecture:

- **Emulator Target**: arm64-v8a (ARM64)
- **Android System**: Android 16 API 35 (ARM64)
- **Expo Go APK**: Built for arm64-v8a architecture
  - Type: `Android package (APK), with gradle app-metadata.properties`
  - Primary ABI: arm64-v8a (confirmed via `adb shell getprop ro.product.cpu.abi`)
- **React Native Bridge**: ARM64 native components in Expo Go

### 🔄 Cross-Architecture Communication
- **ADB Connection**: AMD64 ADB client → ARM64 emulator (via TCP socket)
- **Metro Bundler**: AMD64 Node.js serves JavaScript → ARM64 Expo Go executes
- **Network Bridge**: `tcp:host.docker.internal:5037` for container→host→emulator communication
- **Hot Reload**: JavaScript code (architecture-agnostic) → ARM64 JavaScript engine

### ⚠️ Performance Implications  
- **Metro Bundler**: ~30-90 seconds startup time (AMD64 overhead + cross-arch communication)
- **Hot Reload**: Normal speed (~1-2 seconds) - JavaScript is architecture-agnostic
- **APK Installation**: Slower due to cross-architecture ADB communication
- **File System Access**: Docker volume mounts provide good performance for `node_modules`

### 🧩 Why This Configuration Works
1. **JavaScript Layer**: React Native/Expo apps are primarily JavaScript (architecture-agnostic)
2. **Native Bridge**: Expo Go provides the native ARM64 runtime
3. **Development Tools**: All AMD64 tools communicate via network protocols
4. **Docker Rosetta**: Docker Desktop handles AMD64→ARM64 emulation transparently

---

## 🚨 Hlavní problémy a řešení (chronologicky)

### 1. Problém: "Metro bundler se nespouští na portu 8081"

**Symptom**: 
```bash
curl -I http://localhost:8081
# Connection refused
```

**Původní diagnóza**: Metro bundler failure  
**Skutečná příčina**: Metro bundler startuje pomalu (30-60 sekund v AMD64 kontejneru)

**✅ Řešení**:
```bash
# 1. Vyčistit cache
rm -rf .expo .expo-shared

# 2. Spustit s patience a správnými parametry
export NODE_OPTIONS="--max_old_space_size=4096"
export CHOKIDAR_USEPOLLING=1
export CHOKIDAR_INTERVAL=100
EXPO_NO_MDNS=1 npx expo start --host=localhost --clear

# 3. Počkat 30-90 sekund až se Metro spustí
# Waiting on http://localhost:19000 -> Metro bundler se spouští
```

**Diagnostické příkazy**:
```bash
# Ověřit, že Metro běží
ss -lntp | grep -E ':(8081|19000|19001)'
# LISTEN 0 0 *:8081 *:* users:(("node",pid=XXX,fd=23)) ✅

# Test Metro odpovědi
curl -I http://localhost:8081  # HTTP/1.1 200 OK ✅
curl -I http://localhost:19000 # HTTP/1.1 200 OK ✅
```

### 2. Problém: "This project requires a newer version of Expo Go"

**Symptom na emulátoru**:
```
ERROR Project is incompatible with this version of Expo Go
• The installed version of Expo Go is for SDK 54.
• The project you opened uses SDK 53.
```

**Příčina**: SDK version mismatch  
- Expo Go: SDK 54 (nejnovější z Google Play)
- Náš projekt: SDK 53

**✅ Řešení**: Stáhnout správnou Expo Go verzi z `expo.dev/go`

```bash
# Krok 1: Odebrat současnou Expo Go
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037
adb -s emulator-5554 uninstall host.exp.exponent

# Krok 2: Stáhnout správnou verzi pro SDK 53
SDK=53

# Pro ARM64 emulátor (device=true)
APK_URL=$(curl -fsSL "https://expo.dev/go?device=true&platform=android&sdkVersion=$SDK" \
  | grep -Eo 'https://[^"]+\.apk' | head -1)

# Fallback pro x86_64 emulátor (device=false) - často funguje lépe
if [ -z "$APK_URL" ]; then
  APK_URL=$(curl -fsSL "https://expo.dev/go?device=false&platform=android&sdkVersion=$SDK" \
    | grep -Eo 'https://[^"]+\.apk' | head -1)
fi

echo "APK URL: $APK_URL"
curl -fL "$APK_URL" -o ExpoGo-SDK${SDK}-correct.apk

# Krok 3: Ověřit stažený APK
ls -la ExpoGo-SDK${SDK}-correct.apk  # Měl by mít ~170-200MB

# Ověřit architekturu (volitelné)
unzip -l ExpoGo-SDK${SDK}-correct.apk | grep -E 'lib/(arm64-v8a|x86_64)/' | head -5

# Krok 4: Nainstalovat správnou verzi
adb -s emulator-5554 install -r ExpoGo-SDK${SDK}-correct.apk

# Krok 5: Ověřit verzi
adb -s emulator-5554 shell dumpsys package host.exp.exponent | grep versionName
# versionName=2.33.22  (pro SDK 53)
```

### 3. Problém: ADB connection issues

**Symptom**: 
```bash
adb devices
# List of devices attached
# (prázdné)
```

**✅ Řešení**:
```bash
# V AMD64 Docker kontejneru vždy použít:
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037

# Pak všechny ADB příkazy:
adb -s emulator-5554 devices
adb -s emulator-5554 install app.apk
adb -s emulator-5554 shell "command"
```

### 4. Problém: Port forwarding issues

**Symptom**: Aplikace se připojí, ale zobrazuje connection errors

**✅ Řešení**: Správné nastavení port forwarding
```bash
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037

# 1. Vyčistit existující forwarding
adb -s emulator-5554 reverse --remove-all

# 2. Nastavit všechny potřebné porty
for p in 8081 19000 19001; do 
  adb -s emulator-5554 reverse tcp:$p tcp:$p
done

# 3. Ověřit nastavení
adb -s emulator-5554 reverse --list
```

### 5. Problém: Cache corruption

**Symptom**: Aplikace se načítá, ale zobrazuje staré chyby nebo se chová nepředvídatelně

**✅ Řešení**: Vyčistit všechny cache
```bash
# Expo cache
rm -rf .expo .expo-shared

# Metro cache 
npx metro clean-cache  # nebo npx expo start --clear

# Emulátor cache (pokud potřeba)
adb -s emulator-5554 shell pm clear host.exp.exponent
```

---

## 📱 Kompletní working workflow

Toto je funkční postup od nuly do běžící aplikace:

```bash
# === PŘÍPRAVA PROSTŘEDÍ ===
cd hello-world
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037

# === KROK 1: VYČISTIT VSE ===
# Cache
rm -rf .expo .expo-shared

# Pokud máš starou Expo Go
adb -s emulator-5554 uninstall host.exp.exponent || true

# === KROK 2: STÁHNOUT SPRÁVNOU EXPO GO ===
# Získat SDK verzi z package.json
SDK=$(grep '"expo"' package.json | sed 's/.*"~\([0-9]*\)\..*/\1/')
echo "Detected SDK: $SDK"

# Stáhnout správnou verzi
APK_URL=$(curl -fsSL "https://expo.dev/go?device=false&platform=android&sdkVersion=$SDK" \
  | grep -Eo 'https://[^"]+\.apk' | head -1)

if [ -n "$APK_URL" ]; then
  echo "Downloading: $APK_URL"
  curl -fL "$APK_URL" -o ExpoGo-SDK${SDK}.apk
  
  # Nainstalovat
  adb -s emulator-5554 install -r ExpoGo-SDK${SDK}.apk
  
  # Ověřit verzi
  VERSION=$(adb -s emulator-5554 shell dumpsys package host.exp.exponent | grep versionName)
  echo "Installed: $VERSION"
else
  echo "ERROR: Could not find APK URL for SDK $SDK"
  exit 1
fi

# === KROK 3: NASTAVIT PORT FORWARDING ===
adb -s emulator-5554 reverse --remove-all
for p in 8081 19000 19001; do 
  adb -s emulator-5554 reverse tcp:$p tcp:$p
done

# === KROK 4: SPUSTIT EXPO SERVER ===
export NODE_OPTIONS="--max_old_space_size=4096"
export CHOKIDAR_USEPOLLING=1
export CHOKIDAR_INTERVAL=100

echo "Starting Expo server (this may take 30-90 seconds)..."
EXPO_NO_MDNS=1 npx expo start --host=localhost --clear &
EXPO_PID=$!

# Počkat až se Metro spustí
echo "Waiting for Metro bundler to start..."
for i in {1..180}; do
  if curl -s http://localhost:8081 > /dev/null 2>&1; then
    echo "✅ Metro bundler is running on port 8081"
    break
  fi
  if [ $i -eq 180 ]; then
    echo "❌ Metro bundler failed to start after 3 minutes"
    kill $EXPO_PID 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

# === KROK 5: SPUSTIT APLIKACI ===
echo "Launching app on emulator..."
adb -s emulator-5554 shell am start -a android.intent.action.VIEW -d "exp://127.0.0.1:19000"

echo "✅ App launched! Check emulator for 'Hello World! 🌍'"
```

---

## 🔧 Diagnostické příkazy

### Ověřit stav služeb
```bash
# Metro bundler běží?
curl -I http://localhost:8081
# HTTP/1.1 200 OK ✅

# Expo server běží?
curl -I http://localhost:19000  
# HTTP/1.1 200 OK ✅

# Které porty naslouchají?
ss -lntp | grep -E ':(8081|19000|19001)'

# Procesy
ps -ef | grep -E 'node.*(expo|metro)' | grep -v grep
```

### Ověřit emulátor
```bash
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037

# Emulátor připojen?
adb devices
# emulator-5554	device ✅

# Expo Go nainstalované?
adb -s emulator-5554 shell pm list packages | grep host.exp.exponent
# package:host.exp.exponent ✅

# Verze Expo Go
adb -s emulator-5554 shell dumpsys package host.exp.exponent | grep versionName

# Port forwarding správně?
adb -s emulator-5554 reverse --list

# Co běží na emulátoru?
adb -s emulator-5554 shell dumpsys activity activities | grep -A5 -B5 expo
```

### Debug aplikace
```bash
# Expo logy
npx expo start --host=localhost --clear

# Aplikace se načítá?
# Sleduj výstup: "Android ./index.js ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░ 97.6%"

# Crash logy z emulátoru
adb -s emulator-5554 logcat | grep -i expo
```

---

## 📚 Slepé uličky (vyhni se jim)

### ❌ Co NEFUNGUJE:
1. **Upgrading to non-existent SDK versions**: SDK 54 nebyl dostupný v npm
2. **Using wrong APK sources**: Direct GitHub releases často 404
3. **Installing ARM64 APK on x86_64 emulator**: Architecture mismatch  
4. **Skipping cache cleanup**: Staré cache způsobuje weird behavior
5. **Impatience with Metro startup**: Metro v AMD64 kontejneru trvá 30-90s
6. **Wrong ADB socket**: V Docker kontejneru musíš použít `host.docker.internal:5037`

### ❌ Co jsme zkoušeli ale NEPOMOHLO:
```bash
# Tyto příkazy byly neúčinné:
npx expo install expo@~54.0.0  # SDK neexistoval
curl github.com/expo/direct-releases  # 404 errors  
adb install rychle-bez-cekani  # Architecture mismatch
rm pouze .expo  # Cache bylo víc míst
expo eject  # Úplně změnilo architekturu
```

---

## 🏁 Finální ověření úspěchu

Pokud vše funguje, měl bys vidět:

### Terminál Output (SUCCESS):
```bash
Starting project at /workspaces/mravenci-chuva-android-amd64/hello-world
Starting Metro Bundler
warning: Bundler cache is empty, rebuilding (this may take a minute)
Waiting on http://localhost:19000
Logs for your project will appear below.

# Pozor: Může se objevit error message o SDK (ignoruj ho):
ERROR Project is incompatible with this version of Expo Go
• The installed version of Expo Go is for SDK 54.
• The project you opened uses SDK 53.

# Ale potom začne bundling (to je správně!):
Android ./index.js ▓░░░░░░░░░░░░░░░  9.5% ( 4/13)
Android ./index.js ▓▓▓░░░░░░░░░░░░░ 19.8% ( 33/144)
...
Android ./index.js ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░ 99.7% (676/677)
Android ./index.js ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░ 99.9% (677/677)

# ÚSPĚCH! 🎉
Android Bundled 56601ms index.js (677 modules)
```

### Emulátor Screen:
```
┌─────────────────────────┐
│                         │
│                         │
│     Hello World! 🌍     │
│                         │
│                         │
└─────────────────────────┘
```

### HTTP Endpoints:
```bash
curl -I http://localhost:8081
# HTTP/1.1 200 OK (Metro bundler)

curl -I http://localhost:19000  
# HTTP/1.1 200 OK (Expo dev server)

curl http://localhost:19000
# {"id":"278c6b66-4ab7...","expo":{"name":"hello-world"...}}
```

### Verification Commands:
```bash
# Ověř Expo Go verzi
adb -s emulator-5554 shell dumpsys package host.exp.exponent | grep versionName
# versionName=2.33.22 ✅

# Ověř running aplikaci
adb -s emulator-5554 shell dumpsys activity activities | grep -i expo
# topResumedActivity: host.exp.exponent/...MainActivity ✅ (ne ErrorActivity!)

# Ověř port forwarding
adb -s emulator-5554 reverse --list
# 8081 -> 8081
# 19000 -> 19000  
# 19001 -> 19001 ✅
```

---

## 🎯 Klíčové poznatky pro budoucí projekty

1. **Vždy kontroluj SDK compatibility** mezi projektem a Expo Go
2. **Používej `expo.dev/go` pro stahování** správných verzí, ne GitHub releases
3. **V Docker kontejnerech počítej s pomalým startupem** Metro bundleru (30-90s)
4. **Cache cleanup je kritický** při troubleshootingu
5. **ADB v kontejneru** vyžaduje `host.docker.internal:5037`
6. **Port forwarding musí být kompletní** (8081, 19000, 19001)

---

**Status**: ✅ **COMPLETE GUIDE** - Tento postup dovede Hello World aplikaci od nuly do funkčního stavu bez slepých uliček.