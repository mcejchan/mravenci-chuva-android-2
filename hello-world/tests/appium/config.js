// Appium Test Configuration
// Configures connection to Android emulator and app under test

const path = require('path');

const config = {
  // Test environment settings
  testTimeout: 30000,

  // Appium server configuration
  appiumServer: {
    host: 'localhost',
    port: 4723,
    path: '/'
  },

  // Android capabilities for emulator testing (W3C format for Appium 3.x)
  capabilities: {
    // W3C standard capabilities
    platformName: 'Android',
    'appium:automationName': 'UiAutomator2',

    // Appium-specific capabilities with vendor prefix
    'appium:deviceName': 'emulator-5554',
    'appium:udid': 'emulator-5554',

    // *** KLÍČOVÉ: ADB server na hostu ***
    'appium:remoteAdbHost': 'host.docker.internal',
    'appium:adbPort': 5037,
    'appium:suppressKillServer': true,

    'appium:app': path.resolve(__dirname, '../../android/app/build/outputs/apk/qa/app-qa.apk'),
    'appium:appPackage': 'com.anonymous.helloworld',
    'appium:appActivity': '.MainActivity',

    // Test optimization settings
    'appium:noReset': false,          // Fresh app install for each test
    'appium:fullReset': true,         // Complete cleanup between tests
    'appium:newCommandTimeout': 60,   // Wait up to 60s for commands

    // Performance settings
    'appium:autoGrantPermissions': true,
    'appium:ignoreHiddenApiPolicyError': true,
    'appium:systemPort': 8200,
    'appium:adbExecTimeout': 30000
  },

  // Test selectors and expected values
  selectors: {
    // Text elements
    appText: {
      // Multiple selector strategies for robust text finding
      byText: 'mravenčí chůva',
      byXPath: "//*[@text='mravenčí chůva']",
      byAccessibilityId: null  // Can be added if needed
    }
  },

  // Expected test outcomes
  expectations: {
    appLaunchTimeout: 10000,    // Max time for app to launch
    textDisplayTimeout: 5000,   // Max time for text to appear
    expectedText: 'mravenčí chůva'
  }
};

module.exports = config;