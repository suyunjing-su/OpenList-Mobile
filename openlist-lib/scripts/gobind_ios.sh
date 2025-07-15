#!/bin/bash

cd ../openlistlib || exit

echo "Building OpenList for iOS..."
gomobile bind -ldflags "-s -w" -v -target="ios"

echo "Moving xcframework to ios/Frameworks"
mkdir -p ../../ios/Frameworks
mv -f ./*.xcframework ../../ios/Frameworks/

echo "iOS framework build completed"