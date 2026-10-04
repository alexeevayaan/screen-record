#!/bin/sh
# Runs the JVM unit tests of the Android code (android/src/test) through the example app's Gradle project, generating
# it first if it isn't there.
set -e

cd "$(dirname "$0")/.."

if [ ! -d example/android ]; then
  yarn example expo prebuild --platform android
fi

cd example/android
./gradlew :react-native-screen-record:testDebugUnitTest
