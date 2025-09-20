# bundleInDebug Property Error Report

**Datum:** 2025-09-15
**Čas:** 11:59 UTC
**Status:** CHYBA - bundleInDebug vlastnost není rozpoznána

## Problém

Při pokusu o implementaci bundled build varianty (APK s embedded JS) se opakovaně vyskytuje chyba:

```
* Where:
Build file '/workspaces/mravenci-chuva-android-amd64/hello-world/android/app/build.gradle' line: 40

* What went wrong:
A problem occurred evaluating project ':app'.
> Could not set unknown property 'bundleInDebug' for extension 'react' of type com.facebook.react.ReactExtension.
```

## Kontext

- **Cíl:** Vytvořit bundled build script, který vytvoří APK s embedded JavaScriptem (bez potřeby Metro serveru)
- **Expo SDK:** 53.0.0
- **React Native:** 0.79.5
- **Gradle:** 8.13

## Vyzkoušené přístupy

### Přístup 1: Přímé nastavení v react{} bloku
```gradle
react {
    // Expert bundled configuration - bundle JS in debug builds
    bundleInDebug = true
    hermesEnabled = true
}
```
**Výsledek:** `Could not set unknown property 'bundleInDebug'`

### Přístup 2: Podmíněné nastavení s environment variable
```gradle
react {
    // Expert bundled configuration - use bundleInDebug
    if (System.getenv('EXPO_BUNDLE_IN_DEBUG') == 'true') {
        bundleInDebug = true
    }
}
```
**Environment variable v scriptu:**
```bash
export EXPO_BUNDLE_IN_DEBUG=true
```
**Výsledek:** Stále `Could not set unknown property 'bundleInDebug'`

## Aktuální konfigurace

### app/build.gradle (react blok)
```gradle
react {
    entryFile = file(["node", "-e", "require('expo/scripts/resolveAppEntry')", projectRoot, "android", "absolute"].execute(null, rootDir).text.trim())
    reactNativeDir = new File(["node", "--print", "require.resolve('react-native/package.json')"].execute(null, rootDir).text.trim()).getParentFile().getAbsoluteFile()
    hermesCommand = new File(["node", "--print", "require.resolve('react-native/package.json')"].execute(null, rootDir).text.trim()).getParentFile().getAbsolutePath() + "/sdks/hermesc/%OS-BIN%/hermesc"
    codegenDir = new File(["node", "--print", "require.resolve('@react-native/codegen/package.json', { paths: [require.resolve('react-native/package.json')] })"].execute(null, rootDir).text.trim()).getParentFile().getAbsoluteFile()

    /* Bundling */
    //   A list containing the node command and its flags. Default is just 'node'.
    // nodeExecutableAndArgs = ["node"]

    //   The name of the generated asset file containing your JS bundle
    // bundleAssetName = "MyApplication.android.bundle"

    //   The entry file for bundle generation. Default is 'index.android.js' or 'index.js'
    // entryFile = file("../js/MyApplication.android.js")

    //   A list of extra flags to pass to the 'bundle' commands.
    //   See https://github.com/react-native-community/cli/blob/main/docs/commands.md#bundle
    // extraPackagerArgs = []

    /* Hermes Commands */
    //   The hermes compiler command to run. By default it is 'hermesc'
    // hermesCommand = "$rootDir/my-custom-hermesc/bin/hermesc"
    //
    //   The list of flags to pass to the Hermes compiler. By default is "-O", "-output-source-map"
    // hermesFlags = ["-O", "-output-source-map"]

    // Expert bundled configuration - use bundleInDebug
    if (System.getenv('EXPO_BUNDLE_IN_DEBUG') == 'true') {
        bundleInDebug = true
    }

    enableBundleCompression = (findProperty('android.enableBundleCompression') ?: false).toBoolean()
    // Use Expo CLI to bundle the app, this ensures the Metro config
    // works correctly with Expo projects.
    cliFile = new File(["node", "--print", "require.resolve('@expo/cli', { paths: [require.resolve('expo/package.json')] })"].execute(null, rootDir).text.trim())
    bundleCommand = "export:embed"

    /* Autolinking */
    autolinkLibrariesWithApp()
}
```

## Expert BOM kontext

Podle expertních doporučení byla implementována:
- Expert BOM dependency management (expo-asset je přítomno)
- Memory optimizations (6GB heap, 768MB metaspace)
- Environment variable EXPO_BUNDLE_IN_DEBUG=true pro aktivaci

## Otázky pro expertku

1. **Je `bundleInDebug` správný název vlastnosti** pro React Native 0.79.5 + Expo SDK 53?
2. **Existuje alternativní způsob** jak nastavit bundling v debug builds?
3. **Potřebuje se jiná konfigurace** pro Expo prebuild projekty?
4. **Má být bundleInDebug nastavena jinde** než v react{} bloku?

## Požadovaný výsledek

Cílem je vytvořit APK, který:
- Obsahuje embedded JavaScript bundle (index.android.bundle)
- Nevyžaduje běžící Metro server
- Je vhodný pro Appium testing a CI prostředí
- Použije Hermes engine

## Dostupné skripty

- `expert-bundled-build.sh` - základní verze
- `expert-bundled-build-monitored.sh` - s progress monitoringem
- Environment variable: `EXPO_BUNDLE_IN_DEBUG=true`

## Next Steps

Čekám na expertní doporučení pro správnou implementaci bundleInDebug vlastnosti nebo alternativní přístup k vytvoření bundled APK s embedded JavaScriptem.