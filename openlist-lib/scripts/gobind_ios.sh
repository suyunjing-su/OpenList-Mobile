#!/bin/bash

cd ../openlistlib || exit

echo "Current directory: $(pwd)"
echo "Building OpenList for iOS..."

# Check if gomobile is available
if ! command -v gomobile &> /dev/null; then
    echo "Error: gomobile not found. Please run init_gomobile.sh first."
    exit 1
fi

# Check Go environment
echo "Go version: $(go version)"
echo "GOPATH: $GOPATH"
echo "GOROOT: $GOROOT"

# Check if go.mod exists
if [ ! -f go.mod ]; then
    echo "Error: go.mod not found in $(pwd)"
    echo "Directory contents:"
    ls -la
    exit 1
fi

echo "Go module info:"
go mod tidy
go list -m all | head -10

# Set CGO environment for iOS
export CGO_ENABLED=1

# Clean any previous builds
echo "Cleaning previous builds..."
go clean -cache
go clean -modcache || true

# Ensure dependencies are downloaded
echo "Downloading dependencies..."
go mod download

# Try a simple build first to check for issues
echo "Testing basic build..."
go build -v . || {
    echo "Error: Basic go build failed"
    exit 1
}

# Build for iOS with more verbose output
echo "Starting iOS build..."
echo "CGO_ENABLED: $CGO_ENABLED"
gomobile bind -ldflags "-s -w" -v -target="ios" 2>&1 | tee ios_build.log || {
    echo "Error: gomobile bind failed"
    echo "Build log:"
    cat ios_build.log 2>/dev/null || echo "No build log available"
    
    # Try to get more specific error information
    echo "Checking for common issues..."
    echo "Go environment:"
    go env
    echo "Available targets:"
    gomobile version 2>/dev/null || echo "gomobile version failed"
    
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