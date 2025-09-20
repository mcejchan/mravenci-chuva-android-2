# Persistent Dev-Client Analysis Report

**Datum:** 2025-09-16
**Čas:** 14:20 UTC
**Status:** ❌ DEV-CLIENT POŘÁD PŘÍTOMEN I PO ODSTRANĚNÍ

## Problém

I po úplném odstranění `expo-dev-launcher` z package.json a regeneraci native kódu s `EXPO_USE_DEV_CLIENT=false`, aplikace stále zobrazuje "Development servers" launcher místo main content.

## Provedené úpravy

### ✅ Co bylo implementováno správně

1. **Kondicionální app.config.js:**
```js
export default ({ config }) => {
  const useDevClient = process.env.EXPO_USE_DEV_CLIENT === 'true';
  return {
    plugins: [
      ['expo-build-properties', { /* konfigurace */ }],
      ...(useDevClient ? ['expo-dev-client'] : []),  // ❌ Kondicionálně vyřazeno
      'expo-asset'
    ],
    // ... zbytek konfigurace
  };
};
```

2. **Package.json cleanup:**
```json
// ODSTRANĚNO:
"expo-dev-launcher": "5.1.16"

// ZŮSTÁVÁ (ale neměl by být používán):
"expo-dev-client": "~5.2.4"
```

3. **Prebuild s EXPO_USE_DEV_CLIENT=false:**
```bash
export EXPO_USE_DEV_CLIENT=false
npx expo prebuild -p android --clean
```

4. **QA build type správně nastaven:**
```gradle
qa {
    initWith debug
    debuggable false    // ✅ Pro bundling JS
    signingConfig signingConfigs.debug
    matchingFallbacks = ["debug"]
}
```

## Technical Analysis

### APK Verification
```bash
$ ls -la hello-world/android/app/build/outputs/apk/qa/app-qa.apk
-rw-r--r-- 1 vscode vscode 134584719 Sep 16 14:38 app-qa.apk  # NEJNOVĚJŠÍ BUILD

$ unzip -l app-qa.apk | grep -E "(bundle|devlauncher)"
  2115349  1981-01-01 01:01   assets/expo_dev_launcher_android.bundle  # ❌ DEV LAUNCHER BUNDLE!!
  1041844  1981-01-01 01:01   assets/index.android.bundle              # ✅ MAIN BUNDLE PŘÍTOMEN
```

### Installation Verification
```bash
$ adb shell dumpsys package com.anonymous.helloworld
lastUpdateTime=2025-09-16 16:40:20    # ✅ FRESH INSTALL (NEJNOVĚJŠÍ)
versionName=1.0.0
```

### Critical Finding: DEV LAUNCHER STILL EMBEDDED

**APK obsahuje oba bundly:**
- ✅ `assets/index.android.bundle` (1MB) - main aplikace
- ❌ `assets/expo_dev_launcher_android.bundle` (2MB) - dev launcher

## Root Cause Analysis

### 1. **expo-dev-client dependency přetrvává**
I když byla odstraněna `expo-dev-launcher`, `expo-dev-client` je stále v package.json a **automaticky táhne dev-launcher jako transitivní závislost**.

### 2. **Expo Autolinking ignoruje app.config.js excludes**
Expo autolinking prochází **všechny závislosti v package.json** a automaticky je linkuje, bez ohledu na podmíněné vyřazení z plugins.

### 3. **Runtime priorita dev-clientu**
Když APK obsahuje `expo_dev_launcher_android.bundle`, dev-client launcher má **vyšší prioritu** než main bundle při startu aplikace.

## Možná řešení

### ⭐ Řešení A: Úplné odstranění expo-dev-client
```bash
# Odstranit z package.json:
"expo-dev-client": "~5.2.4"

# Nový prebuild:
npm install
npx expo prebuild -p android --clean
```

**Riziko:** Může rozbít development workflow.

### ⭐ Řešení B: Separátní package.json pro QA
```bash
# Vytvořit package-qa.json bez dev-client dependencies
# Použít při QA buildu
```

### ⭐ Řešení C: Metro resolver excludes
```js
// metro.config.js
module.exports = {
  resolver: {
    blacklistRE: process.env.QA_BUILD ?
      /expo-dev-client|expo-dev-launcher/ : undefined
  }
};
```

### ⭐ Řešení D: Gradle excludes
```gradle
// android/app/build.gradle
android {
    packagingOptions {
        exclude '**/expo_dev_launcher_android.bundle'
    }
}
```

## Expert Questions

1. **Je možné vyřadit expo-dev-client pouze pro QA buildy** bez ovlivnění development workflow?

2. **Existuje způsob jak říct Expo autolinkingu** aby ignoroval konkrétní balíčky pro specifické build typy?

3. **Můžeme použít gradle packaging excludes** k odstranění dev launcher bundlu z APK?

4. **Je možné nastavit runtime prioritu** aby main bundle měl přednost před dev launcher bundlem?

## Current State

- ✅ **QA build funguje** - vytváří APK s embedded JS
- ✅ **Bundling works** - index.android.bundle je přítomen
- ❌ **Runtime issue** - dev launcher přebírá kontrolu nad startem
- ❌ **Appium not ready** - aplikace není offline, očekává Metro server

## Next Steps

Potřebujeme **radikální řešení** pro úplné vyřazení dev-client komponent z QA buildu, zatímco zachováme development workflow.

## Assets & Evidence

- **APK path:** `/workspaces/.../android/app/build/outputs/apk/qa/app-qa.apk`
- **Size:** 134MB
- **Build time:** Sep 16 14:15
- **Install time:** Sep 16 16:18
- **Contents:** Both main bundle + dev launcher bundle present