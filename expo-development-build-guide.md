# Expo Development Build Guide - Complete Walkthrough

Podrobný návod pro vytvoření development APK z Expo projektu v Docker kontejneru (AMD64).

## 📋 Přehled

Tento návod vás provede celým procesem vytvoření development APK buildu z Expo aplikace v Docker kontejneru. Postup je otestovaný a fungující po mnoha pokusech a optimalizacích.

### Výsledek
- ✅ **Funkční development APK** (~50-100MB)
- ✅ **Stabilní build proces** (~30-45 minut)
- ✅ **Optimalizovaná paměť** (12GB RAM, 6GB heap)
- ✅ **Podpora všech architektur** (arm64, armeabi-v7a, x86, x86_64)

---

## 🚨 Kritická upozornění

### ⚠️ DŮLEŽITÉ: Paměťové požadavky
- **Minimálně 12GB RAM** pro Docker Desktop
- **AMD64 emulace** zvyšuje paměťovou náročnost o ~30%
- Build může trvat **30-45 minut** - buďte trpěliví!

### ⚠️ Časté chyby které NESMÍTE udělat:
1. **Nikdy nepoužívejte paralelní buildy** (`--parallel`) 
2. **Nikdy neaktivujte Gradle daemon** (`--daemon`)
3. **Nikdy nezačínejte s méně než 10GB RAM**
4. **Nikdy nepoužívejte Gradle cache** v kontejneru
5. **Nikdy nepřerušujte build před dokončením**

---

## 📋 Předpoklady

### Docker Desktop nastavení
```bash
# Docker Desktop → Settings → Resources
RAM: 12GB (minimum 10GB)
CPU: 4+ cores
Disk: 20GB+ volného místa
```

### Projekt struktura
```
project-root/
├── hello-world/          # Expo aplikace
│   ├── android/          # Vygenerované přes expo prebuild
│   ├── app.json         
│   ├── package.json
│   └── App.js
└── .devcontainer/       # Docker konfigurace
```

---

## 🛠 Krok za krokem

### 1. Příprava Expo projektu

```bash
# V hlavním adresáři Expo aplikace
cd hello-world

# Ujistěte se, že máte development build konfiguraci
npx expo install expo-dev-client

# Vygenerujte Android nativní kód
npx expo prebuild --platform android --clean
```

### 2. Docker kontejner setup

Ujistěte se, že máte správnou `.devcontainer/devcontainer.json`:
```json
{
  "build": {
    "dockerfile": "Dockerfile",
    "args": {
      "PLATFORM": "linux/amd64"
    }
  },
  "runArgs": [
    "--platform=linux/amd64"
  ]
}
```

### 3. Gradle optimalizace (KRITICKÉ!)

**android/gradle.properties** - přepište celý soubor:
```properties
# Expert recommended Gradle memory optimization for 12GB container
org.gradle.daemon=false
org.gradle.parallel=false
org.gradle.workers.max=1
org.gradle.caching=false

# Increased Gradle heap for 12GB RAM container
org.gradle.jvmargs=-Xmx6144m -XX:MaxMetaspaceSize=768m -Dfile.encoding=UTF-8 -XX:+HeapDumpOnOutOfMemoryError

# Kotlin compiler: keep conservative and in-process
kotlin.daemon.jvmargs=-Xmx512m -XX:MaxMetaspaceSize=384m
kotlin.compiler.execution.strategy=in-process

# Standard Android properties
android.useAndroidX=true
android.enablePngCrunchInReleaseBuilds=true
reactNativeArchitectures=armeabi-v7a,arm64-v8a,x86,x86_64
newArchEnabled=true
hermesEnabled=true

# Expo properties
expo.gif.enabled=true
expo.webp.enabled=true
expo.webp.animated=false
EX_DEV_CLIENT_NETWORK_INSPECTOR=true
expo.useLegacyPackaging=false
expo.edgeToEdgeEnabled=false
```

### 4. SDK unifikace

```bash
# Přijměte všechny licence
yes | sdkmanager --licenses

# Nainstalujte konzistentní sadu SDK (Android 35)
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"
```

### 5. Build proces

```bash
# Přejděte do Android adresáře
cd hello-world/android

# Zastavte všechny Gradle daemony
./gradlew --stop || true

# Nastavte čistý Gradle home
export GRADLE_USER_HOME=/home/vscode/.gradle-local
mkdir -p "$GRADLE_USER_HOME" && chmod -R 700 "$GRADLE_USER_HOME"

# Spusťte build (30-45 minut!)
export GRADLE_USER_HOME=/home/vscode/.gradle-local && \
./gradlew :app:clean :app:assembleDebug \
  --no-daemon --no-parallel --max-workers=1 \
  --info --stacktrace
```

---

## 📊 Časová osa buildu

| Fáze | Čas | Popis | Indikátory úspěchu |
|------|-----|-------|-------------------|
| **Inicializace** | 0-2 min | Gradle setup, daemon start | `Starting Build`, `Gradle 8.13` |
| **Plugin resolution** | 2-5 min | Načítání React Native, Expo pluginů | `Evaluating project`, `Using Kotlin` |
| **Dependency download** | 5-15 min | Stahování z Maven Central, Google Maven | `Downloading https://` |
| **Project configuration** | 15-20 min | Nastavení všech modulů | `Configure project` |
| **Compilation** | 20-35 min | Kotlin, Java, C++ kompilace | `compileDebugKotlin`, `buildCMake` |
| **Packaging** | 35-40 min | Sestavení APK | `packageDebug`, `assembleDebug` |
| **Dokončení** | 40-45 min | Finalizace | `BUILD SUCCESSFUL` |

### ⚡ Kontrolní body
- **5 min:** Pokud build crashnul → problém s pamětí
- **15 min:** Pokud visí na dependency download → síťový problém
- **30 min:** Pokud crashnul při kompilaci → SDK problém
- **45 min:** Pokud úspěšný → APK je hotové!

---

## 🐛 Řešení problémů

### Problem: "Daemon disappeared unexpectedly"
**Příčina:** Nedostatek paměti
**Řešení:**
```bash
# Zkontrolujte paměť
free -h
# Zvyšte Docker RAM na 12GB+
# Restartujte Docker Desktop
```

### Problem: Build visí na "Downloading..."
**Příčina:** Síťové připojení
**Řešení:**
```bash
# Zkontrolujte připojení
curl -I https://repo.maven.apache.org/maven2/
# Restartujte network v Docker
docker network prune
```

### Problem: "SDK not found"
**Příčina:** Nekonzistentní SDK verze
**Řešení:**
```bash
# Reinstalujte SDK
sdkmanager --uninstall "platforms;android-35"
sdkmanager "platforms;android-35" "build-tools;35.0.0"
```

### Problem: Build crashnul po 20+ minutách
**Příčina:** Kotlin compiler OOM
**Řešení:**
```bash
# Snižte Kotlin heap v gradle.properties
kotlin.daemon.jvmargs=-Xmx384m -XX:MaxMetaspaceSize=256m
```

### Problem: "No space left on device"
**Příčina:** Nedostatek místa
**Řešení:**
```bash
# Vyčistěte Gradle cache
rm -rf /home/vscode/.gradle-local/caches/*
rm -rf android/.gradle
```

---

## 🎯 Výsledek buildu

### Lokace APK
```bash
# APK bude v:
android/app/build/outputs/apk/debug/app-debug.apk
```

### Kontrola APK
```bash
# Velikost (~50-100MB)
ls -lh android/app/build/outputs/apk/debug/app-debug.apk

# Info o APK
aapt dump badging android/app/build/outputs/apk/debug/app-debug.apk | head -5
```

### Instalace na emulator
```bash
# Pokud máte emulator spuštěný
adb install android/app/build/outputs/apk/debug/app-debug.apk
```

---

## 📈 Optimalizace výkonu

### Paměťové nastavení (testované)
```properties
# Hlavní Gradle heap
org.gradle.jvmargs=-Xmx6144m -XX:MaxMetaspaceSize=768m

# Kotlin compiler
kotlin.daemon.jvmargs=-Xmx512m -XX:MaxMetaspaceSize=384m

# Single worker only
org.gradle.workers.max=1
```

### Docker optimalizace
```bash
# Vyčistit Docker cache před buildem
docker system prune -f
docker volume prune -f

# Restart Docker Desktop před dlouhým buildem
```

---

## ⏱ Časové odhady

### Různé konfigurace

| Konfigurace | RAM | Workers | Cache | Čas |
|-------------|-----|---------|-------|-----|
| **Doporučené** | 12GB | 1 | Off | 30-45 min |
| Nedostatečná paměť | 8GB | 1 | Off | Crash po ~20 min |
| Paralelní (špatně) | 12GB | 4 | Off | Crash po ~10 min |
| S cache (špatně) | 12GB | 1 | On | Nestabilní |

### První vs. opakované buildy
- **První build:** 40-50 minut (dependency download)
- **Opakovaný build:** 25-35 minut (dependencies cached)
- **Clean build:** 30-45 minut (vždy stejný čas)

---

## 🔧 Debugging nástroje

### Monitoring během buildu
```bash
# Sledování paměti
watch -n 5 "free -h && echo '---' && ps aux | grep gradle | head -3"

# Sledování build logu
tail -f /tmp/gradle-build.log | grep -E "BUILD|ERROR|Task|Download"

# Sledování disk space
df -h | grep docker
```

### Při problémech
```bash
# Gradle daemon log
cat /home/vscode/.gradle-local/daemon/8.13/daemon-*.out.log

# Android build log
find android -name "*.log" -exec echo "=== {} ===" \; -exec cat {} \;

# System resources
docker stats
```

---

## 📋 Checklist před buildem

### ✅ Pre-build kontrola
- [ ] Docker Desktop má 12GB+ RAM
- [ ] Volných 20GB+ disk space
- [ ] Expo projekt má `expo-dev-client` nainstalovaný
- [ ] `android/` adresář existuje (po `expo prebuild`)
- [ ] `gradle.properties` má správné nastavení
- [ ] Síťové připojení funguje

### ✅ Build kontrola
- [ ] Používáte `--no-daemon --no-parallel --max-workers=1`
- [ ] Build běží v `android/` adresáři
- [ ] `GRADLE_USER_HOME` je nastavené
- [ ] Timeout je nastavený na 45+ minut

### ✅ Post-build kontrola
- [ ] APK existuje v `android/app/build/outputs/apk/debug/`
- [ ] APK má rozumnou velikost (50-100MB)
- [ ] APK se dá nainstalovat na zařízení/emulátor

---

## 🎉 Úspěch!

Pokud jste došli až sem a máte funkční APK, gratulujeme! 

### Co jste získali:
- ✅ **Development APK** s Expo Dev Client
- ✅ **Hot reload** přes síť s Metro serverem  
- ✅ **Debugging** možnosti
- ✅ **Native modules** support
- ✅ **Optimalizovaný build process**

### Další kroky:
1. **Testování APK** na fyzickém zařízení
2. **Nastavení Metro serveru** pro hot reload
3. **Appium testing** setup
4. **CI/CD integrace** pro automatické buildy

---

## 📚 Reference

### Užitečné příkazy
```bash
# Quick build status check
ps aux | grep gradle

# Memory usage
free -h && docker stats --no-stream

# Clean everything
./gradlew clean && rm -rf .gradle && docker system prune -f

# Expert build command (copy-paste ready)
export GRADLE_USER_HOME=/home/vscode/.gradle-local && \
mkdir -p "$GRADLE_USER_HOME" && chmod -R 700 "$GRADLE_USER_HOME" && \
./gradlew :app:clean :app:assembleDebug \
  --no-daemon --no-parallel --max-workers=1 \
  --info --stacktrace
```

### Časté cesty
```bash
# APK output
android/app/build/outputs/apk/debug/app-debug.apk

# Build logs
/tmp/gradle-build.log
/home/vscode/.gradle-local/daemon/8.13/daemon-*.out.log

# Gradle cache
/home/vscode/.gradle-local/caches/
```

---

**Autor:** Vytvořeno na základě úspěšného buildu po mnoha pokusech a expertních optimalizacích
**Datum:** Září 2024
**Verze:** 1.0 - Testováno a funkční

**⚡ TIP:** Uložte si tento návod - process může trvat dlouho a detaily jsou kritické pro úspěch!