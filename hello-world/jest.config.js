// Jest Configuration for Appium Tests
module.exports = {
  // Test environment
  testEnvironment: 'node',

  // Test file patterns
  testMatch: [
    '**/tests/appium/**/*.test.js'
  ],

  // Timeout settings
  testTimeout: 30000,

  // Verbose output for debugging
  verbose: true,

  // Transform settings - ignore node_modules transformations
  transformIgnorePatterns: [
    'node_modules/'
  ]
};