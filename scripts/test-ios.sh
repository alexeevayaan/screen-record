#!/bin/sh
# Runs the tests of the iOS core (ios/Package.swift) on an iOS simulator: IOS_SIMULATOR_ID if it's set, else a booted
# iPhone simulator, else the first available one.
set -e

cd "$(dirname "$0")/../ios"

if [ -z "$IOS_SIMULATOR_ID" ]; then
  IOS_SIMULATOR_ID=$(xcrun simctl list devices available --json | node -e '
    const { devices } = JSON.parse(require("fs").readFileSync(0, "utf8"));
    const iPhones = Object.entries(devices)
      .filter(([runtime]) => runtime.includes("iOS"))
      .flatMap(([, list]) => list)
      .filter((device) => device.name.startsWith("iPhone"));
    const device = iPhones.find((d) => d.state === "Booted") ?? iPhones[0];
    if (!device) {
      console.error("No iPhone simulator available");
      process.exit(1);
    }
    console.log(device.udid);
  ')
fi

echo "Testing on simulator $IOS_SIMULATOR_ID"
xcodebuild test \
  -scheme ScreenRecordCore \
  -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
  -quiet
