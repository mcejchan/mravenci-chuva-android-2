# Plán: Přechod z Expo Go na Development Build + Appium

## Aktuální stav
- ✅ **Expo Go aplikace funguje** v emulátoru (SDK 53)
- ✅ **ADB připojení** kontejner → host → emulator-5554
- ✅ **Appium 3.0.2** + UiAutomator2 driver nainstalované
- ✅ **Metro bundler** běží a aplikace se načítá

## Cíl transformace
**Z**: Expo Go runtime (host.exp.exponent) - nelze testovat Appium  
**Na**: Development build APK (com.anonymous.helloworld) - plně testovatelné

---

## Fáze 1: Ověření prostředí (Prerequisites)
### 1.1 Java Development Kit
- ✅ **Zkontrolovat JDK 17** (Android Gradle vyžaduje 17)
- Příkaz: `java -version`
- Backup: `sudo apt-get install openjdk-17-jdk` pokud není

### 1.2 Android SDK Environment  
- ✅ **Ověřit ANDROID_SDK_ROOT** proměnnou
- ✅ **Zkontrolovat SDK licenses**: `yes | sdkmanager --licenses`
- ✅ **Ověřit build-tools**: `sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"`

---

## Fáze 2: Příprava projektu (Project Setup)
### 2.1 Git commit současného stavu
```bash
git add -A && git commit -m "chore: before android prebuild"
```

### 2.2 Instalace expo-dev-client
```bash
npm i -D expo-dev-client
npx expo install expo-dev-client
```

### 2.3 Ověření app.json konfigurace
- **Zkontrolovat** android.package name
- **Nastavit** scheme pokud chybí
- **Ověřit** permissions array

---

## Fáze 3: Generování nativního projektu (Prebuild)
### 3.1 Expo prebuild
```bash
npx expo prebuild -p android
```
**Výsledek**: Vytvoří `android/` složku s Gradle projektem

### 3.2 Ověření prebuild výsledku
- **Zkontrolovat** existenci `android/` složky
- **Ověřit** `android/app/build.gradle` konfiguraci
- **Potvrdit** applicationId matchuje app.json

---

## Fáze 4: Build debug APK (Gradle Assembly)
### 4.1 Gradle build
```bash
cd android
yes | $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager --licenses
./gradlew assembleDebug
```

### 4.2 Ověření APK
- **Lokace**: `android/app/build/outputs/apk/debug/app-debug.apk`
- **Velikost**: Měl by být ~20-50MB (ne 0 bytes)
- **Typ**: Android APK soubor

---

## Fáze 5: Instalace do emulátoru (APK Deploy)
### 5.1 ADB připojení
```bash
export ANDROID_ADB_SERVER_ADDRESS=host.docker.internal  
export ANDROID_ADB_SERVER_PORT=5037
adb devices  # emulator-5554 device
```

### 5.2 Instalace APK
```bash
adb -s emulator-5554 install -r android/app/build/outputs/apk/debug/app-debug.apk
```

### 5.3 Spuštění aplikace
```bash
adb -s emulator-5554 shell am start -n com.anonymous.helloworld/.MainActivity
```

---

## Fáze 6: Development workflow setup (Hot Reload)
### 6.1 Metro server pro dev build
```bash
# Jiný terminál - Metro pro development build
npm run start  # nebo: npx expo start --lan
```

### 6.2 Ověření hot reload
- **JS změny** se projeví bez reinstalace APK
- **Dev Menu**: `adb shell input keyevent 82` → Reload
- **Fallback**: Manuální restart aplikace

---

## Fáze 7: Appium/WebDriverIO konfigurace (E2E Setup)
### 7.1 WebDriverIO configuration
**Soubor**: `wdio.conf.js`
```javascript
capabilities: [{
  platformName: 'Android',
  'appium:automationName': 'UiAutomator2', 
  'appium:udid': 'emulator-5554',
  'appium:appPackage': 'com.anonymous.helloworld',
  'appium:appActivity': '.MainActivity',
  'appium:noReset': true
}]
```

### 7.2 Package.json scripts
```json
{
  "scripts": {
    "dev": "expo start --lan",
    "android:build": "cd android && ./gradlew assembleDebug", 
    "android:install": "adb -s emulator-5554 install -r android/app/build/outputs/apk/debug/app-debug.apk",
    "appium": "appium --log-level warn",
    "test:e2e": "wdio run wdio.conf.js",
    "ci:e2e": "npm run android:build && npm run android:install && npm run test:e2e"
  }
}
```

---

## Fáze 8: Demo E2E test (Proof of Concept)
### 8.1 Základní test soubor
**Lokace**: `test/e2e/basic.test.js`
```javascript
describe('Hello World App', () => {
  it('should launch and show main screen', async () => {
    // Test že se aplikace spustí a zobrazí obsah
    const app = await $('android=new UiSelector().packageName("com.anonymous.helloworld")');
    await expect(app).toExist();
  });
});
```

### 8.2 Test execution
```bash
# Terminal 1: Appium server
npm run appium

# Terminal 2: E2E testy
npm run test:e2e
```

---

## Fáze 9: Dokumentace a cleanup (Finalization)
### 9.1 Aktualizace CLAUDE.md
- **Přidat** development build workflow
- **Dokumentovat** Appium capabilities  
- **Zaznamenat** package.json scripts

### 9.2 Git commit výsledku
```bash
git add -A && git commit -m "feat: development build + Appium E2E setup"
```

---

## Očekávané výhody po migraci
- ✅ **Nativní testování**: Skutečná aplikace (ne Expo Go wrapper)
- ✅ **Čistý Appium setup**: Vlastní package name a activities
- ✅ **Rychlý development cyklus**: JS změny přes Metro hot reload
- ✅ **Production-ready**: Stejná architektura jako release build
- ✅ **AI automation friendly**: Claude může plně automatizovat test cykly

## Potenciální záseky a řešení
- **JDK != 17**: `sudo apt-get install openjdk-17-jdk`
- **Missing build-tools**: `sdkmanager "build-tools;34.0.0"`
- **License issues**: `yes | sdkmanager --licenses`
- **Metro polling**: `export CHOKIDAR_USEPOLLING=true`
- **Slow dev menu**: Vypnout animace v emulátoru settings