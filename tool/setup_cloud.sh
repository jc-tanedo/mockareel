#!/usr/bin/env bash
# Pinned, verified SDK bootstrap for the managed Linux development environment.
set -euo pipefail
mockareel_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$mockareel_root/tool/cloud_env.sh"
mkdir -p "$MOCKAREEL_TOOLS"

if [ ! -x "$JAVA_HOME/bin/javac" ]; then
  mockareel_jdk_url='https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13%2B9'
  mockareel_jdk_archive=OpenJDK21U-jdk_x64_linux_hotspot_21.0.13_9.tar.gz
  curl -fsSL --retry 2 "$mockareel_jdk_url/$mockareel_jdk_archive.sha256.txt" -o "$MOCKAREEL_TOOLS/jdk.sha256"
  curl -fsSL --retry 2 "$mockareel_jdk_url/$mockareel_jdk_archive" -o "$MOCKAREEL_TOOLS/$mockareel_jdk_archive"
  (cd "$MOCKAREEL_TOOLS" && sha256sum -c jdk.sha256)
  tar -xzf "$MOCKAREEL_TOOLS/$mockareel_jdk_archive" -C "$MOCKAREEL_TOOLS"
fi
cp /etc/ssl/certs/java/cacerts "$MOCKAREEL_TOOLS/java-truststore"
if [ -f /usr/local/share/ca-certificates/environment-proxy-ca.crt ]; then
  "$JAVA_HOME/bin/keytool" -importcert -noprompt -alias mockareel-environment-proxy \
    -file /usr/local/share/ca-certificates/environment-proxy-ca.crt \
    -keystore "$MOCKAREEL_TOOLS/java-truststore" -storepass changeit
fi
source "$mockareel_root/tool/cloud_env.sh"

if [ ! -x "$MOCKAREEL_TOOLS/flutter/bin/flutter" ]; then
  curl -fsSL --retry 2 https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.7-stable.tar.xz -o "$MOCKAREEL_TOOLS/flutter.tar.xz"
  printf '%s  %s\n' af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230 "$MOCKAREEL_TOOLS/flutter.tar.xz" | sha256sum -c -
  tar -xJf "$MOCKAREEL_TOOLS/flutter.tar.xz" -C "$MOCKAREEL_TOOLS"
fi

# Pin the Java-based tools. Newer command-line-tools launch a separate CLI.
if [ ! -x "$ANDROID_SDK_ROOT/cmdline-tools/19.0/bin/sdkmanager" ]; then
  curl -fsSL --retry 2 https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip -o "$MOCKAREEL_TOOLS/android-tools-19.zip"
  # Google's SDK repository publishes a SHA-1 checksum for this archive.
  printf '%s  %s\n' 5fdcc763663eefb86a5b8879697aa6088b041e70 "$MOCKAREEL_TOOLS/android-tools-19.zip" | sha1sum -c -
  mkdir -p "$MOCKAREEL_TOOLS/android-tools-19" "$ANDROID_SDK_ROOT/cmdline-tools"
  unzip -q "$MOCKAREEL_TOOLS/android-tools-19.zip" -d "$MOCKAREEL_TOOLS/android-tools-19"
  mv "$MOCKAREEL_TOOLS/android-tools-19/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/19.0"
fi
if [ ! -e "$ANDROID_SDK_ROOT/cmdline-tools/latest" ]; then
  ln -s 19.0 "$ANDROID_SDK_ROOT/cmdline-tools/latest"
fi

# Java tools need explicit proxy settings; preserve TLS verification and trust.
mkdir -p "$GRADLE_USER_HOME"
python3 - <<'PY'
import os
from pathlib import Path
from urllib.parse import urlparse

proxy = urlparse(os.environ.get('HTTPS_PROXY', ''))
settings = Path(os.environ['GRADLE_USER_HOME']) / 'gradle.properties'
if not settings.exists():
    lines = ['org.gradle.workers.max=2']
    if proxy.hostname:
        for scheme in ['http', 'https']:
            lines += [f'systemProp.{scheme}.proxyHost={proxy.hostname}',
                      f'systemProp.{scheme}.proxyPort={proxy.port or 8080}']
        lines += ['systemProp.http.nonProxyHosts=localhost|127.*|[::1]']
    settings.write_text('\n'.join(lines) + '\n')
PY

mockareel_proxy_args=()
if [ -n "${HTTPS_PROXY:-}" ]; then
  read -r mockareel_proxy_host mockareel_proxy_port < <(python3 - <<'PY'
import os
from urllib.parse import urlparse
p = urlparse(os.environ['HTTPS_PROXY'])
print(p.hostname, p.port or 8080)
PY
)
  mockareel_proxy_args=(--proxy=http "--proxy_host=$mockareel_proxy_host" "--proxy_port=$mockareel_proxy_port")
fi
mockareel_answers="$(mktemp)"
trap 'rm -f "$mockareel_answers"' EXIT
python3 -c 'print("y\n" * 100)' > "$mockareel_answers"
sdkmanager --sdk_root="$ANDROID_SDK_ROOT" "${mockareel_proxy_args[@]}" --licenses < "$mockareel_answers"
sdkmanager --sdk_root="$ANDROID_SDK_ROOT" "${mockareel_proxy_args[@]}" \
  'platform-tools' 'platforms;android-34' 'platforms;android-35' 'platforms;android-36' \
  'build-tools;36.0.0' 'ndk;28.2.13676358' 'cmake;3.22.1' < "$mockareel_answers"

flutter --version
# Dart's native build hooks invoke the SDK directly and need this initial config.
if [ ! -f "$HOME/.dart-tool/dart-flutter-telemetry.config" ]; then
  dart --disable-analytics
fi
flutter precache --android
cd "$mockareel_root"
flutter pub get --enforce-lockfile
