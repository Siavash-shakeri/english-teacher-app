#!/bin/bash
# Build the English Teacher release APK with the persistent keystore
# (same cert every time so updates install cleanly over previous versions).
# Required env: ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD
# (keystore file: ./english-teacher-release.keystore)
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/flutter-sdk/flutter/bin:$HOME/android-sdk/cmdline-tools/latest/bin:$HOME/android-sdk/platform-tools:$PATH"
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export JAVA_TOOL_OPTIONS="-Djava.net.preferIPv4Stack=true -Xmx2g"
: "${ANDROID_KEYSTORE_PASSWORD:?set ANDROID_KEYSTORE_PASSWORD}"
: "${ANDROID_KEY_ALIAS:?set ANDROID_KEY_ALIAS}"
: "${ANDROID_KEY_PASSWORD:?set ANDROID_KEY_PASSWORD}"
export ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_BASE64="$(base64 -w0 english-teacher-release.keystore)"
flutter build apk --release --split-per-abi 2>&1
echo "BUILD DONE: $(date -u)"
ls -la build/app/outputs/flutter-apk/
