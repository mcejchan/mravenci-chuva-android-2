# 🎯 Complete Guide: Expo SDK 53 Development Build (Expert BOM Method)

**Pro junior vývojáře** - Kompletní návod na sestavení Expo SDK 53 development buildu

---

## 📋 Úvod

Tento guide dokumentuje **úspěšnou implementaci Expert BOM (Bill of Materials) přístupu** pro sestavení Expo SDK 53 development buildu. Metoda byla vyvinuta po mnoha neúspěšných pokusech s manuálním version managementem.

### 🎯 Co dosáhneme:
- ✅ Funkční Expo SDK 53 development build APK
- ✅ Vyřešené Kotlin compilation konflikty
- ✅ Stabilní build process bez OOM crashes
- ✅ Plně funkční expo-dev-client prostředí

---

## 🔧 Požadavky a Prerequisites

### System Requirements:
- **Docker Desktop** s min. 12GB RAM
- **Android Emulator** (API 35, Android 15)
- **Node.js 20+**
- **Git**

### Container Environment:
```bash
# Dev Container: Ubuntu 24.04 AMD64
# Java: OpenJDK 17
# Android SDK: CLI tools + SDK 35
# Memory: 12GB container, 6GB swap
```

---

## 🚨 KRITICKÉ PRAVIDLA - CO NEDĚLAT

### ❌ NIKDY nepoužívejte tyto přístupy:

1. **Manuální version pinning v gradle souborech**
   ```gradle
   // ❌ ŠPATNĚ - nikdy neměňte ručně
   kotlinVersion = "1.9.0"
   compileSdk = 34
   ```

2. **npm install místo expo install**
   ```bash
   # ❌ ŠPATNĚ
   npm install expo-dev-client
   
   # ✅ SPRÁVNĚ
   expo install expo-dev-client
   ```

3. **Ruční editace build.gradle pro AGP/Gradle verze**
   ```gradle
   // ❌ ŠPATNĚ - nechte Expo prebuild zvládnout
   classpath('com.android.tools.build:gradle:8.1.0')
   ```

4. **Používání ^ ve verzích při manuálním přístupu**
   ```json
   // ❌ ŠPATNĚ když děláte manuální setup
   "expo": "^53.0.0"
   ```

5. **Ignorování memory limitů**
   ```bash
   # ❌ ŠPATNĚ - způsobí daemon crash
   export GRADLE_OPTS="-Xmx8g"  # Příliš mnoho pro 12GB container
   ```

---

## 🎯 Expert BOM Method - Krok za krokem

### Krok 1: Příprava projektu

```bash
# Navigace do projektu
cd hello-world

# Backup současných souborů
cp package.json package.json.backup
cp app.json app.json.backup
```

### Krok 2: Implementace Expert BOM v package.json

**Nahraďte dependencies section:**

```json
{
  "dependencies": {
    "expo": "~53.0.0",
    "react": "19.0.0",
    "react-native": "0.79.5",
    "expo-dev-client": "~5.2.4",
    "expo-dev-launcher": "~5.1.16",
    "expo-modules-core": "~2.5.0",
    "expo-updates": "~0.28.17"
  },
  "devDependencies": {
    "@expo/cli": "0.24.21",
    "@babel/core": "^7.25.2"
  }
}
```

**🔍 Klíčové verze (OVĚŘENÉ):**
- Expo SDK: `~53.0.0` (ne ^, používejte ~)
- React Native: `0.79.5` (oficiální mapování pro SDK 53)
- React: `19.0.0` (kompatibilní s RN 0.79.5)
- @expo/cli: `0.24.21` (vyřešuje exportEmbedAsync problém)

### Krok 3: Expert Build Configuration v app.json

**Přidejte plugins section:**

```json
{
  "expo": {
    "plugins": [
      [
        "expo-build-properties",
        {
          "android": {
            "kotlinVersion": "2.0.21",
            "compileSdkVersion": 35,
            "targetSdkVersion": 35,
            "minSdkVersion": 24
          }
        }
      ],
      "expo-dev-client"
    ]
  }
}
```

**🔍 Kritické nastavení:**
- **kotlinVersion: "2.0.21"** - Vyřešuje Kotlin compilation konflikty
- **compileSdkVersion: 35** - SDK 53 kompatibilní
- **expo-build-properties plugin** - Lepší než manuální gradle edity

### Krok 4: Clean Install s Expo Management

```bash
# 1. Vyčištění všech dependency managerů
rm -rf node_modules package-lock.json yarn.lock pnpm-lock.yaml

# 2. Základní npm install
npm install --timeout=300000

# 3. KRITICKÉ: Expo install --fix pro alignment
npx expo install --fix

# 4. Explicitní install expo-dev-client
npx expo install expo-dev-client
```

**⚠️ DŮLEŽITÉ:** Krok 3 a 4 nechají Expo automaticky upravit verze na kompatibilní!

### Krok 5: Clean Prebuild

```bash
# Odstranění předchozích build artefaktů
rm -rf android ios

# Clean prebuild s expert konfigurací
npx expo prebuild -p android --clean
```

**✅ Očekávaný výsledek:**
- gradle.properties obsahuje kotlinVersion=2.0.21
- build.gradle používá Expo's AGP verzi (ne manuální)
- AndroidManifest správně konfigurován pro dev-client

### Krok 6: Memory-Optimized Build

```bash
# Navigace do android složky
cd android

# Expert memory nastavení (3GB heap)
export GRADLE_OPTS="-Dorg.gradle.daemon=false -Dorg.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=512m"

# Build s optimalizovanými parametry
./gradlew :app:assembleDebug --no-daemon --max-workers=1 --console=plain
```

**🔍 Memory Strategy:**
- **3GB heap** místo 6GB (prevence daemon crash)
- **512MB metaspace** (dostatečné pro kompilaci)
- **--max-workers=1** (stabilita před rychlostí)
- **--no-daemon** (žádné background procesy)

---

## 📊 Ověření úspěchu

### Build Success Indicators:

1. **Kotlin Compilation úspěch:**
   ```
   > Task :expo-modules-core:compileDebugKotlin UP-TO-DATE
   > Task :expo-dev-client:compileDebugKotlin NO-SOURCE
   > Task :expo-dev-launcher:compileDebugKotlin UP-TO-DATE
   ```

2. **C++ Compilation úspěch:**
   ```
   > Task :app:buildCMakeDebug[arm64-v8a]
   > Task :expo-modules-core:buildCMakeDebug[arm64-v8a]
   ```

3. **APK Generation:**
   ```bash
   # Ověření APK existence
   ls -la android/app/build/outputs/apk/debug/app-debug.apk
   # Očekávaná velikost: ~136MB
   ```

---

## 🚀 Testing a Deployment

### Instalace do emulátoru:

```bash
# 1. Clean Expo Go cache
env ADB_SERVER_SOCKET=tcp:host.docker.internal:5037 adb -s emulator-5554 shell pm clear host.exp.exponent

# 2. Install APK
env ADB_SERVER_SOCKET=tcp:host.docker.internal:5037 adb -s emulator-5554 install android/app/build/outputs/apk/debug/app-debug.apk

# 3. Launch app
env ADB_SERVER_SOCKET=tcp:host.docker.internal:5037 adb -s emulator-5554 shell am start -n com.anonymous.helloworld/.MainActivity
```

### Development Server:

```bash
# Návrat do root projektu
cd ..

# Start Metro bundler
EXPO_NO_MDNS=1 npx expo start --host=localhost --clear
```

---

## 🔍 Troubleshooting Guide

### Problem: "Gradle build daemon disappeared unexpectedly"
**Řešení:**
```bash
# Snižte memory allocation
export GRADLE_OPTS="-Xmx2g -XX:MaxMetaspaceSize=256m"
```

### Problem: "exportEmbedAsync module not found"
**Řešení:**
```bash
# Install @expo/cli explicitly
npm install --save-dev @expo/cli@0.24.21
```

### Problem: Kotlin compilation errors
**Řešení:**
```json
// Ověřte app.json obsahuje:
"kotlinVersion": "2.0.21"
// A že používáte expo-build-properties plugin
```

### Problem: APK se nenainstaluje
**Řešení:**
```bash
# Zkontrolujte správný package name v app.json
"android": {
  "package": "com.anonymous.helloworld"
}
```

---

## 📈 Performance Tips

### Build Optimalizace:

1. **Memory Management:**
   - 12GB container minimum
   - 3GB heap pro Gradle
   - Monitorujte swap usage

2. **Parallel Processing:**
   - `--max-workers=1` pro stabilitu
   - `--no-parallel` při problémech

3. **Cache Strategy:**
   - Nekachujte Gradle daemon (`--no-daemon`)
   - Metro cache vyčistěte při problémech (`--clear`)

### Development Workflow:

1. **First Build:** Vždy `--clean` prebuild
2. **Incremental:** Pouze pokud žádné dependency změny
3. **Debugging:** Používejte `--console=plain` pro čitelné logy

---

## 🎓 Klíčové poznatky pro juniory

### Co dělá Expert BOM lepší:

1. **Automatické version alignment** místo guess-work
2. **Expo-managed compatibility** místo manuálních konfliktů  
3. **Official plugin system** místo hack-ů v gradle
4. **Memory-conscious approach** místo brute-force

### Časté chyby juniorů:

1. **Přeskakování `expo install --fix`** - Nejdůležitější krok!
2. **Editace gradle souborů ručně** - Nechte Expo pracovat
3. **Ignorování memory limitů** - Způsobí random crashes
4. **Míchání npm a expo install** - Konsistence je klíč

### Expert mindset:

- **Trust the toolchain** - Expo ví líp než vy jaké verze jdou dohromady
- **Memory is finite** - Container limits respektujte
- **Clean builds work** - Když nevíte, začněte čistě
- **Verify everything** - APK existence != APK funkčnost

---

## ⏱️ Očekávané časy a benchmarky

### Typické build časy (12GB container):
- **Clean prebuild**: 2-3 minuty
- **First build**: 35-45 minut (Kotlin + C++ compilation)
- **Incremental build**: 3-5 minut
- **Metro bundler start**: 1-2 minuty (first time)

### Paměťové požadavky:
```bash
# Monitoring během buildu
free -h  # Swap usage by měl být < 50%
df -h    # Disk space min 10GB free
```

---

## 🔒 Production Ready Checklist

### Před nasazením do produkce:

1. **APK Testing:**
   ```bash
   # Test instalace na real device
   adb install app-debug.apk
   
   # Test basic functionality
   adb shell am start -n com.anonymous.helloworld/.MainActivity
   
   # Monitor crashes
   adb logcat | grep -E "(FATAL|AndroidRuntime)"
   ```

2. **Performance Validation:**
   ```bash
   # APK size check (měl by být < 150MB)
   ls -lh android/app/build/outputs/apk/debug/app-debug.apk
   
   # Memory usage in emulator
   adb shell dumpsys meminfo com.anonymous.helloworld
   ```

3. **Development Server Connection:**
   ```bash
   # Test hot reload
   # Změňte App.js a ověřte auto-refresh
   
   # Test network connectivity
   adb shell ping localhost  # Should work from emulator
   ```

---

## 🚀 Advanced Tips pro experienced vývojáře

### Build Optimization hacks:

1. **Gradle parallel processing (risky ale rychlejší):**
   ```bash
   # Pouze pokud máte 16GB+ RAM
   export GRADLE_OPTS="-Xmx4g -XX:MaxMetaspaceSize=768m"
   ./gradlew :app:assembleDebug --parallel --max-workers=2
   ```

2. **Selective architecture build:**
   ```json
   // app.json - pro testing pouze
   "android": {
     "architectures": ["arm64-v8a"]  // Pouze arm64, rychlejší build
   }
   ```

3. **Development vs Production configs:**
   ```json
   // development: fast builds
   "newArchEnabled": false,
   "hermesEnabled": false
   
   // production: optimized
   "newArchEnabled": true,
   "hermesEnabled": true
   ```

---

## 🐛 Known Issues & Workarounds

### Issue: "Could not resolve all files for configuration"
```bash
# Clear Gradle cache
rm -rf ~/.gradle/caches
./gradlew clean
```

### Issue: Metro bundler timeout
```bash
# Increase timeout
EXPO_NO_MDNS=1 npx expo start --host=localhost --max-workers=1
```

### Issue: Development build nenavazuje na server
```bash
# ADB port forwarding (fallback)
adb reverse tcp:8081 tcp:8081
adb reverse tcp:19000 tcp:19000
```

### Issue: Emulator performance
```bash
# GPU acceleration check
emulator -avd Pixel_7_API_35 -gpu host
```

---

## 📝 Maintenance a Updates

### Weekly maintenance:
```bash
# Update Expo CLI
npm update -g @expo/cli

# Check for SDK updates  
npx expo install --check
```

### Monthly maintenance:
```bash
# Deep clean
rm -rf node_modules android ios
npm install
npx expo install --fix
npx expo prebuild --clean
```

### Version upgrade path:
1. **Minor updates**: Pouze `npx expo install --fix`
2. **SDK upgrades**: Follow Expo upgrade guide
3. **Major RN updates**: Často vyžadují nový BOM

---

## 📚 Reference Links

- [Expo SDK 53 Release Notes](https://blog.expo.dev/expo-sdk-53-is-now-available-b32d7e4d1b07)
- [expo-build-properties Documentation](https://docs.expo.dev/versions/latest/sdk/build-properties/)
- [Development Builds Guide](https://docs.expo.dev/development/introduction/)
- [React Native 0.79 Changelog](https://github.com/facebook/react-native/releases/tag/v0.79.0)

---

**🎯 Vytvořeno na základě úspěšné implementace dne 13.9.2025**  
**📧 Expert BOM Method - First successful Expo SDK 53 development build**