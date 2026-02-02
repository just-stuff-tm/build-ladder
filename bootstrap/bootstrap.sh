#!/usr/bin/env bash
set -e

PREFIX="/data/data/com.termux/files/usr"
STATE="$HOME/.build-ladder"
SDK="$HOME/android-sdk"
JAVA_HOME="$PREFIX/lib/jvm/java-17-openjdk"

pkg install -y openjdk-17 wget unzip git jq android-tools imagemagick gradle

export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p "$SDK"
cd "$SDK"

if [[ ! -d cmdline-tools/latest ]]; then
  TMP="$(mktemp -d)"
  wget -q -O "$TMP/tools.zip" https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q "$TMP/tools.zip" -d "$TMP"
  mkdir -p cmdline-tools/latest
  mv "$TMP/cmdline-tools/"* cmdline-tools/latest/
  rm -rf "$TMP"
fi

yes | cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

mkdir -p "$STATE"
touch "$STATE/BOOTSTRAP_DONE"

echo "✅ Build Ladder bootstrap complete"
echo "🙏 Optional donations: \$yuptm"
