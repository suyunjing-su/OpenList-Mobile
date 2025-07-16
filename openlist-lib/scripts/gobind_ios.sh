#!/bin/bash

echo "Starting iOS build from: $(pwd)"

# Find openlistlib directory
if [ -d ../openlistlib ]; then
    cd ../openlistlib || exit
elif [ -d openlistlib ]; then
    cd openlistlib || exit
else
    echo "Error: Cannot find openlistlib directory"
    exit 1
fi

echo "Current directory: $(pwd)"

# Check if gomobile is available
if ! command -v gomobile &> /dev/null; then
    echo "Error: gomobile not found. Please run init_gomobile.sh first."
    exit 1
fi

echo "Go version: $(go version)"

# Work from module root if go.mod exists in parent
if [ -f ../go.mod ]; then
    echo "Found go.mod in parent directory"
    cd ..
    
    # Fix iOS incompatible dependencies
    echo "Fixing iOS incompatible dependencies..."
    go get -u golang.org/x/mobile/...
    go install golang.org/x/mobile/cmd/gobind@latest
    go install golang.org/x/mobile/cmd/gomobile@latest
    chmod +x scripts/fix_ios_dependencies.sh
    ./scripts/fix_ios_dependencies.sh
    
    # Set CGO environment for iOS
    export CGO_ENABLED=1
    
    # Build for iOS with iOS-specific build tags to exclude incompatible packages
    echo "Starting iOS build from module root..."
    echo "CGO_ENABLED: $CGO_ENABLED"
    
    # Use build tags to exclude problematic packages on iOS
    gomobile bind -ldflags "-s -w" -v -target="ios" -tags="ios mobile" ./openlistlib 2>&1 | tee ios_build.log || {
        echo "Error: gomobile bind failed"
        echo "Build log:"
        cat ios_build.log 2>/dev/null || echo "No build log available"
        
        # Try with different build tags to exclude problematic dependencies
        echo "Retrying with different build tags..."
        gomobile bind -ldflags "-s -w" -v -target="ios" -tags="ios,mobile,!darwin,!cgo" ./openlistlib 2>&1 | tee ios_build_retry.log || {
            echo "Retry also failed"
            cat ios_build_retry.log 2>/dev/null || echo "No retry log available"
            exit 1
        }
    }
    
    echo "Listing generated files:"
    ls -la *.xcframework 2>/dev/null || echo "No .xcframework files found"
    
    echo "Moving xcframework to ios/Frameworks"
    mkdir -p ios/Frameworks
    
    # Check if xcframework files exist before moving
    if ls *.xcframework 1> /dev/null 2>&1; then
        mv -f ./*.xcframework ios/Frameworks/
        echo "iOS framework build completed successfully"
        echo "Files in ios/Frameworks:"
        ls -la ios/Frameworks/
    else
        echo "Warning: No .xcframework files were generated"
        exit 1
    fi
else
    echo "Error: No go.mod found in parent directory"
    exit 1
fi