export default ({ config }) => {
  return {
    ...config,
    name: "hello-world",
    slug: "hello-world",
    scheme: "helloworld",
    version: "1.0.0",
    orientation: "portrait",
    icon: "./assets/icon.png",
    userInterfaceStyle: "light",
    splash: {
      image: "./assets/splash-icon.png",
      resizeMode: "contain",
      backgroundColor: "#ffffff"
    },
    ios: {
      supportsTablet: true
    },
    android: {
      package: "com.anonymous.helloworld",
      adaptiveIcon: {
        foregroundImage: "./assets/adaptive-icon.png",
        backgroundColor: "#ffffff"
      }
    },
    web: {
      favicon: "./assets/favicon.png"
    },
    plugins: [
      [
        "expo-build-properties",
        {
          android: {
            kotlinVersion: "2.0.21",
            compileSdkVersion: 35,
            targetSdkVersion: 35,
            minSdkVersion: 24
          }
        }
      ],
      "expo-asset"
    ],
    updates: {
      enabled: true,
      checkAutomatically: "ON_ERROR_RECOVERY",
      fallbackToCacheTimeout: 0,
    },
    runtimeVersion: "exposdk:53.0.0",
  };
};
