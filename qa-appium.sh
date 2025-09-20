#!/bin/bash

# QA Appium Test Runner
# Simple script for running Appium tests with connectivity checks
# Author: Claude Code
# Date: 2025-09-20

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 QA Appium Test Runner${NC}"
echo -e "${BLUE}=========================${NC}"

# Change to hello-world directory
cd "$(dirname "$0")/hello-world"

echo -e "${YELLOW}📂 Working directory: $(pwd)${NC}"

# 1. Check ADB connectivity
echo -e "\n${BLUE}🔗 Checking ADB connectivity...${NC}"
if env ADB_SERVER_SOCKET=tcp:host.docker.internal:5037 adb devices | grep -q "emulator-5554"; then
    echo -e "${GREEN}✅ ADB connection to emulator-5554 verified${NC}"
else
    echo -e "${RED}❌ ADB connection failed - emulator-5554 not found${NC}"
    echo -e "${YELLOW}💡 Make sure Android emulator is running on host${NC}"
    exit 1
fi

# 2. Check if Appium server is running
echo -e "\n${BLUE}🚀 Checking Appium server...${NC}"
if curl -s http://localhost:4723/status > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Appium server is running on localhost:4723${NC}"
else
    echo -e "${YELLOW}⚠️  Appium server not running${NC}"
    echo -e "${BLUE}ℹ️  Start with: npm run appium:start${NC}"
    exit 1
fi

# 3. Check if APK exists
echo -e "\n${BLUE}📱 Checking QA APK...${NC}"
APK_PATH="android/app/build/outputs/apk/qa/app-qa.apk"
if [[ -f "$APK_PATH" ]]; then
    echo -e "${GREEN}✅ QA APK found: $APK_PATH${NC}"
    echo -e "${BLUE}ℹ️  APK size: $(du -h "$APK_PATH" | cut -f1)${NC}"
else
    echo -e "${RED}❌ QA APK not found${NC}"
    echo -e "${YELLOW}💡 Build with: npm run build:bundled${NC}"
    exit 1
fi

# 4. Run Appium tests
echo -e "\n${BLUE}🧪 Running Appium tests...${NC}"
echo -e "${BLUE}========================================${NC}"

npm run test:appium

echo -e "\n${GREEN}🎉 Appium tests completed successfully!${NC}"