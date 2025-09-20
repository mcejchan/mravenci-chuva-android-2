# Bundled Build Implementation Report

**Datum:** 2025-09-15
**Čas:** 19:50 UTC
**Status:** ČÁSTEČNĚ ÚSPĚŠNÝ - APK se vytváří, ale bez bundled JavaScriptu

## Cíl

Implementovat bundled build variantu pro Expo SDK 53 development build, která vytvoří APK s embedded JavaScript bundlem (bez potřeby Metro serveru) pro Appium testing a CI prostředí.

## Kontext projektu

- **Expo SDK:** 53.0.0
- **React Native:** 0.79.5
- **Gradle:** 8.13
- **Java:** OpenJDK 17.0.16
- **Architektura:** AMD64 container s 16GB RAM
- **Expo prebuild:** Ano (Android native kód přítomen)

## Implementované řešení

### 1. Odstranění neplatné bundleInDebug konfigurace

**Problém:** bundleInDebug vlastnost neexistuje v React Native 0.79
```gradle
// ODSTRANĚNO z app/build.gradle
if (System.getenv('EXPO_BUNDLE_IN_DEBUG') == 'true') {
    bundleInDebug = true
}
```

**Řešení:** Kompletně odstraněno podle expertního doporučení

### 2. Expertní Varianta A - Explicitní bundlovací tasky

**Vyzkoušené přístupy:**

#### A1: bundleDebugJsAndAssets (neexistuje)
```bash
./gradlew :app:bundleDebugJsAndAssets :app:installDebug
```
**Výsledek:** `task 'bundleDebugJsAndAssets' not found`

#### A2: createBundleDebugJsAndAssets (existuje, ale nefunkční)
```bash
./gradlew :app:createBundleDebugJsAndAssets :app:installDebug
```
**Výsledek:**
- Task se najde: `Task path ':app:createBundleDebugJsAndAssets' matched project ':app'`
- Ale selže s: `task 'createBundleDebugJsAndAssets' not found`
- **Paradox:** Task existuje ale není spustitelný

#### A3: Pouze assembleDebug
```bash
./gradlew :app:assembleDebug
```
**Výsledek:** ✅ **ÚSPĚCH**
- APK se vytvoří: `app-debug.apk` (132MB)
- Build dokončen za 20m 43s
- ❌ **PROBLÉM:** APK neobsahuje `index.android.bundle`

#### A4: assembleDebug s NODE_ENV=production
```bash
export NODE_ENV=production
./gradlew :app:assembleDebug
```
**Výsledek:** ✅ **ÚSPĚCH**
- APK se vytvoří: `app-debug.apk` (132MB)
- Build dokončen za 3m 39s (rychlejší díky cache)
- ❌ **PROBLÉM:** APK stále neobsahuje `index.android.bundle`

## Aktuální stav

### ✅ Co funguje
1. **Basic development build:** `assembleDebug` úspěšně vytváří APK
2. **Expertní konfigurace:** Gradle memory settings (6GB heap), NDK, dependencies
3. **Monitoring:** Kompletní progress tracking a error reporting
4. **APK validace:** Automatická kontrola velikosti, stáří, existence

### ❌ Co nefunguje
1. **JavaScript bundling:** APK neobsahuje embedded `index.android.bundle`
2. **Explicitní bundle tasks:** `createBundleDebugJsAndAssets` není spustitelný
3. **Metro independence:** APK vyžaduje běžící Metro server

### 🤔 Klíčový problém

APK se vytváří úspěšně, ale **neobsahuje bundled JavaScript**. V aktuální konfiguraci:
- Debug builds automaticky neincludují bundled JS
- Spoléhají na Metro server pro hot-reload development
- Pro bundled variantu je potřeba jiný approach

## Vyzkoušené řešení scripts

### expert-bundled-build-monitored.sh
```bash
# Aktuální konfigurace
export NODE_ENV=production
./gradlew :app:assembleDebug \
  --no-daemon --no-parallel --max-workers=1 \
  --console=plain --info --stacktrace
```

### Výsledek validation
```bash
🎯 Verify APK at: app/build/outputs/apk/debug/app-debug.apk
-rw-r--r-- 1 vscode vscode 132M Sep 15 19:43 app/build/outputs/apk/debug/app-debug.apk
🕐 Checking APK freshness... ✅ APK is fresh (4 minutes old)
🔍 Checking for index.android.bundle inside APK
⚠️ index.android.bundle not found – build is not bundled
```

## Otázky pro expertku

1. **Je možné vynutit bundling v debug builds** v Expo SDK 53 + RN 0.79?

2. **Existují speciální Gradle properties nebo tasks** pro explicitní JS bundling?

3. **Měli bychom použít jiný build typ** než debug (např. custom debugBundled variant)?

4. **Je potřeba modifikovat react{} blok** v app/build.gradle jinak než bundleInDebug?

5. **Funguje bundling pouze v release builds** v této verzi RN/Expo?

## Důležité pozorování

- **createBundleDebugJsAndAssets task existuje** (gradle ho nalezne)
- Ale **nelze ho spustit** (task selection exception)
- Možná je **závislý na jiných podmínkách** nebo konfiguraci

## Dostupné soubory

- `expert-bundled-build-monitored.sh` - aktuální implementace
- `app/build.gradle` - vyčištěno od bundleInDebug
- `package.json` - obsahuje `"build:bundled": "../expert-bundled-build-monitored.sh"`
- Monitoring logy v `/tmp/monitoring-logs/`

## Požadovaný výsledek

APK obsahující `index.android.bundle`, který:
- Nezbytuje běžící Metro server
- Obsahuje všechny JS assets
- Je vhodný pro Appium testing
- Funguje v CI prostředí