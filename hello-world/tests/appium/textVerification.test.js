// Appium Test: Verify "mravenčí chůva" text is displayed
// This test validates that our QA APK correctly shows the expected text

const { remote } = require('webdriverio');
const config = require('./config');

describe('Text Verification Test', () => {
  let driver;

  beforeAll(async () => {
    console.log('🚀 Starting Appium test session...');

    // Initialize WebDriver with our configuration
    driver = await remote({
      hostname: config.appiumServer.host,
      port: config.appiumServer.port,
      path: config.appiumServer.path,
      capabilities: config.capabilities
    });

    console.log('✅ Connected to Appium server');
    console.log('📱 Installing and launching app...');

    // Wait for app to launch
    await driver.waitUntil(
      async () => {
        const contexts = await driver.getContexts();
        return contexts.length > 0;
      },
      {
        timeout: config.expectations.appLaunchTimeout,
        timeoutMsg: 'App failed to launch within timeout'
      }
    );

    console.log('✅ App launched successfully');
  }, config.testTimeout);

  afterAll(async () => {
    if (driver) {
      console.log('🔚 Closing test session...');
      await driver.deleteSession();
      console.log('✅ Test session closed');
    }
  });

  test('should display "mravenčí chůva" text on screen', async () => {
    console.log('🔍 Looking for expected text...');

    // Strategy 1: Find by exact text match
    try {
      const textElement = await driver.$(config.selectors.appText.byXPath);

      // Wait for element to be displayed
      await textElement.waitForDisplayed({
        timeout: config.expectations.textDisplayTimeout,
        timeoutMsg: `Text "${config.expectations.expectedText}" not found within ${config.expectations.textDisplayTimeout}ms`
      });

      // Verify element is displayed
      const isDisplayed = await textElement.isDisplayed();
      expect(isDisplayed).toBe(true);

      // Get and verify text content
      const actualText = await textElement.getText();
      expect(actualText).toBe(config.expectations.expectedText);

      console.log(`✅ Success: Found expected text "${actualText}"`);

    } catch (error) {
      console.log('❌ Strategy 1 (XPath) failed, trying alternative...');

      // Strategy 2: Find by UIAutomator text selector
      try {
        const textElement = await driver.$(`android=new UiSelector().text("${config.expectations.expectedText}")`);

        await textElement.waitForDisplayed({
          timeout: config.expectations.textDisplayTimeout
        });

        const isDisplayed = await textElement.isDisplayed();
        expect(isDisplayed).toBe(true);

        const actualText = await textElement.getText();
        expect(actualText).toBe(config.expectations.expectedText);

        console.log(`✅ Success (Strategy 2): Found expected text "${actualText}"`);

      } catch (error2) {
        console.log('❌ Strategy 2 (UISelector) failed, trying page source...');

        // Strategy 3: Check page source for text presence
        const pageSource = await driver.getPageSource();
        console.log('📄 Page source snippet:', pageSource.substring(0, 500) + '...');

        const containsText = pageSource.includes(config.expectations.expectedText);
        expect(containsText).toBe(true);

        if (containsText) {
          console.log(`✅ Success (Strategy 3): Text "${config.expectations.expectedText}" found in page source`);
        } else {
          throw new Error(`Text "${config.expectations.expectedText}" not found anywhere on screen`);
        }
      }
    }
  }, config.testTimeout);

  test('should verify app is running offline (no Metro connection)', async () => {
    console.log('🔍 Verifying app runs offline...');

    // Check that we don't see "Development servers" or Metro-related text
    const pageSource = await driver.getPageSource();

    // Negative assertions - these should NOT be present
    const devServerIndicators = [
      'Development servers',
      'Metro',
      'Connect to development server',
      'Unable to connect'
    ];

    for (const indicator of devServerIndicators) {
      const hasDevIndicator = pageSource.includes(indicator);
      expect(hasDevIndicator).toBe(false);

      if (hasDevIndicator) {
        console.log(`❌ Found development indicator: "${indicator}"`);
      }
    }

    // Positive assertion - our content should be present
    const hasOurContent = pageSource.includes(config.expectations.expectedText);
    expect(hasOurContent).toBe(true);

    console.log('✅ App is running offline with bundled content');
  }, config.testTimeout);
});