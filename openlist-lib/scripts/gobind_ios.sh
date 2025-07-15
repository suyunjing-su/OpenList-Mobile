#!/bin/bash

cd ../openlistlib || exit

echo "Current directory: $(pwd)"
echo "Building OpenList for iOS..."

# Check if gomobile is available
if ! command -v gomobile &> /dev/null; then
    echo "Error: gomobile not found. Please run init_gomobile.sh first."
    exit 1
fi

# Build for iOS
gomobile bind -ldflags "-s -w" -v -target="ios" || {
    echo "Error: gomobile bind failed"
    exit 1
}

echo "Listing generated files:"
ls -la *.xcframework 2>/dev/null || echo "No .xcframework files found"

echo "Moving xcframework to ios/Frameworks"
mkdir -p ../../ios/Frameworks

# Check if xcframework files exist before moving
if ls *.xcframework 1> /dev/null 2>&1; then
    mv -f ./*.xcframework ../../ios/Frameworks/
    echo "iOS framework build completed successfully"
    echo "Files in ios/Frameworks:"
    ls -la ../../ios/Frameworks/
else
    echo "Warning: No .xcframework files were generated"
    exit 1
fi