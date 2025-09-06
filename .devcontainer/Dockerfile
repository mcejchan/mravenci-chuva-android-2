# Devcontainer for Android + Node (Expo / React Native) development
# Host runs Android Studio + emulator; container provides consistent CLI env.
FROM --platform=linux/amd64 mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG NODE_VERSION=20
ARG USERNAME=vscode

# Base packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip zip git ca-certificates bash-completion build-essential \
    libgcc-s1 libstdc++6 openssh-client wget python3 python3-pip gnupg \
    && rm -rf /var/lib/apt/lists/*

# Node.js (NodeSource) with retry logic
RUN for i in {1..3}; do \
        curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
        apt-get update && apt-get install -y nodejs && break || \
        (echo "Attempt $i failed, waiting..." && sleep 10); \
    done \
    && npm i -g yarn pnpm

# OpenJDK 17
RUN apt-get update && apt-get install -y openjdk-17-jdk && rm -rf /var/lib/apt/lists/*

# Install native AMD64 ADB from Ubuntu repository (before SDK installation)
RUN for i in {1..3}; do \
        apt-get update && apt-get install -y adb android-sdk-platform-tools-common && break || \
        (echo "ADB install attempt $i failed, waiting..." && sleep 5); \
    done \
    && rm -rf /var/lib/apt/lists/*

# Android SDK location
ENV ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_HOME=/opt/android-sdk
RUN mkdir -p /opt/android-sdk && chown -R ${USERNAME}:${USERNAME} /opt/android-sdk

# Add Android tools to PATH (cmdline-tools added by setup script)
# Note: Native ADB from /usr/bin will take precedence over SDK ADB
ENV PATH=/usr/bin:/opt/android-sdk/platform-tools:/opt/android-sdk/cmdline-tools/latest/bin:$PATH

# EAS CLI (optional, for Expo cloud builds)
RUN npm i -g eas-cli

# Copy helper scripts
COPY scripts /tmp/scripts
RUN chmod +x /tmp/scripts/*.sh

# Switch to non-root
USER ${USERNAME}
WORKDIR /workspaces