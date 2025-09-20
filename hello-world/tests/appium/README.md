# Appium Tests for Hello World App

Tento adresář obsahuje automatizované testy pro ověření funkcionality QA buildu aplikace pomocí Appium.

## Přehled testů

### `textVerification.test.js`
Hlavní test, který ověřuje:
- ✅ Zobrazení správného textu "mravenčí chůva" na obrazovce
- ✅ Offline provoz aplikace (žádné Metro/dev server komponenty)
- ✅ Správné spuštění a funkčnost APK

## Předpoklady

### 1. Appium Server
Musí být spuštěn Appium server na `localhost:4723`:

```bash
# Instalace Appium (globálně)
npm install -g appium

# Instalace UiAutomator2 driver
appium driver install uiautomator2

# Spuštění Appium serveru
appium server --port 4723
```

### 2. Android Emulator
Emulator musí být spuštěn a dostupný jako `emulator-5554`:

```bash
# Ověření dostupnosti emulátoru
adb devices

# Měl by zobrazit:
# emulator-5554	device
```

### 3. Test Dependencies
```bash
# V hello-world/ adresáři
npm install
```

## Spuštění testů

### Rychlé testování (jen test)
```bash
cd hello-world/
npm run test:appium
```

### Plný cyklus (build + install + test)
```bash
cd hello-world/
npm run test:full-cycle
```

### Watch mode pro vývoj testů
```bash
cd hello-world/
npm run test:appium:watch
```

## Výstup testů

### ✅ Úspěšný test
```
Text Verification Test
  ✅ should display "mravenčí chůva" text on screen
  ✅ should verify app is running offline (no Metro connection)

Test Suites: 1 passed, 1 total
Tests:       2 passed, 2 total
```

### ❌ Neúspěšný test
```
Text Verification Test
  ❌ should display "mravenčí chůva" text on screen
    Error: Text "mravenčí chůva" not found within 5000ms
```

## Konfigurace

### `config.js`
Centrální konfigurace obsahující:
- **Appium server** nastavení (host, port)
- **Android capabilities** (device, app package)
- **Test selectors** pro hledání elementů
- **Timeouts** a očekávané hodnoty

### Úprava pro jiný text
Pro test jiného textu změňte v `config.js`:
```js
expectations: {
  expectedText: 'váš nový text'  // Změňte zde
}
```

## Troubleshooting

### 1. "Connection refused to localhost:4723"
```bash
# Zkontrolujte, zda běží Appium server
appium server --port 4723
```

### 2. "App failed to launch"
```bash
# Zkontrolujte, zda existuje APK
ls -la android/app/build/outputs/apk/qa/app-qa.apk

# Zkontrolujte emulator
adb devices
```

### 3. "Text not found"
- Zkontrolujte, zda je text v App.js správně nastaven
- Rebuild aplikace: `npm run build:bundled`
- Reinstall: `npm run install:qa`

### 4. Test timeout
- Zvyšte timeout v `config.js`:
```js
expectations: {
  appLaunchTimeout: 15000,  // Zvyšte z 10000
  textDisplayTimeout: 8000  // Zvyšte z 5000
}
```

## Pokročilé použití

### Debug mode
Pro ladění testů můžete přidat screenshot:
```js
// V testu přidejte:
const screenshot = await driver.takeScreenshot();
console.log('Screenshot:', screenshot);
```

### Více test případů
Vytvořte nové `.test.js` soubory v `tests/appium/` adresáři.

### CI/CD integrace
```bash
# Pro automatizované prostředí
npm run test:full-cycle
```

## Struktura souborů

```
tests/appium/
├── README.md              # Tato dokumentace
├── config.js              # Centrální konfigurace
├── textVerification.test.js # Hlavní test
└── jest.config.js         # Jest konfigurace (v root)
```