#!/usr/bin/env bash
# Source this file in a Codex cloud shell before using Flutter or Gradle.
export MOCKAREEL_TOOLS="${MOCKAREEL_TOOLS:-/workspace/.tooling}"
export ANDROID_SDK_ROOT="$MOCKAREEL_TOOLS/android-sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_USER_HOME="$MOCKAREEL_TOOLS/android-user"
export GRADLE_USER_HOME="$MOCKAREEL_TOOLS/gradle-user"
export PUB_CACHE="$MOCKAREEL_TOOLS/pub-cache"
export XDG_CONFIG_HOME="$MOCKAREEL_TOOLS/config"
export ANALYZER_STATE_LOCATION_OVERRIDE="$MOCKAREEL_TOOLS/analyzer"
export FLUTTER_SUPPRESS_ANALYTICS=true
export JAVA_HOME="$MOCKAREEL_TOOLS/jdk-21.0.13+9"
export PATH="$JAVA_HOME/bin:$MOCKAREEL_TOOLS/flutter/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/19.0/bin:$PATH"
if [ -f "$MOCKAREEL_TOOLS/java-truststore" ]; then
  case "${JAVA_TOOL_OPTIONS:-}" in
    *"-Djavax.net.ssl.trustStore=$MOCKAREEL_TOOLS/java-truststore"*) ;;
    *) export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Djavax.net.ssl.trustStore=$MOCKAREEL_TOOLS/java-truststore" ;;
  esac
fi
