# Expo Go Setup - Aktuální stav

## 🎯 Cíl
Spustit "Hello World! 🌍" aplikaci v Expo Go na emulátoru `emulator-5554`.

## ✅ Co funguje
1. **Emulátor**: `emulator-5554` připojen + má Google Play Services
2. **Expo Go APK**: Úspěšně nainstalován (ARM64 + x86_64 podporu)
3. **Port forwarding**: 8081, 19000, 19001 správně nastaveny
4. **Expo dev server**: Port 19000 odpovídá HTTP/1.1 200 OK
5. **Deep link**: Intent se úspěšně spouští

## ❌ Kritický problém: Metro bundler se nespouští

**Metro bundler na portu 8081 se nespustil** - bez něj se JavaScript bundle nevytvoří a aplikace se nemůže načíst.

### Aktuální stav serveru:
```bash
# Expo server běží správně
curl -I http://localhost:19000
# HTTP/1.1 200 OK ✅

# Metro bundler neběží  
curl -I http://localhost:8081  
# Connection refused ❌

# Expo log
npx expo start --host=localhost --port=19000
# Starting Metro Bundler
# Waiting on http://localhost:19000  <- server čeká, Metro se nespustil
```

### Co se děje na emulátoru:
```bash
adb -s emulator-5554 shell dumpsys activity activities | grep -i expo
# topResumedActivity: host.exp.exponent/.experience.ErrorActivity
# ^ Expo Go zobrazuje error místo aplikace
```

## 🔧 Funkční příkazy (hotové)
```bash
# 1. Stažení a instalace Expo Go
SDK=53
APK_URL=$(curl -fsSL "https://expo.dev/go?device=true&platform=android&sdkVersion=$SDK" \
  | grep -Eo 'https://[^"]+\.apk' | head -1)
curl -fL "$APK_URL" -o ExpoGo.apk
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037
adb -s emulator-5554 install -r ExpoGo.apk

# 2. Port forwarding
adb -s emulator-5554 reverse --remove-all
for p in 8081 19000 19001; do adb -s emulator-5554 reverse tcp:$p tcp:$p; done

# 3. Spuštění aplikace
adb -s emulator-5554 shell am start -a android.intent.action.VIEW -d "exp://127.0.0.1:19000"
```

## 🚫 Potřeba vyřešit: Metro bundler

**Metro bundler je klíčový** - vytváří JavaScript bundle, bez něj aplikace nemůže běžet.

### Otázky pro diagnostiku:
1. **Proč se Metro nespouští?** - Expo log ukazuje "Waiting on http://localhost:19000" ale Metro bundler se nikdy nestartuje
2. **Container performance?** - Je AMD64 via Rosetta příliš pomalé pro Metro bundler?
3. **Memory/resources?** - Metro potřebuje více paměti nebo času?
4. **Alternative approach?** - Použít jiný způsob spuštění Metro bundleru?

### Současný problém:
**Expo Go je připraveno, ale nemá co načíst** - zobrazuje ErrorActivity protože Metro bundler nedodává JavaScript kód.

---

**Status**: Expo Go setup dokončen, čeká na vyřešení Metro bundler problému pro zobrazení "Hello World! 🌍"