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
    chmod +x scripts/fix_ios_dependencies.sh
    ./scripts/fix_ios_dependencies.sh
    
    # Update mobile packages
    echo "Updating mobile packages..."
    go get -u golang.org/x/mobile/...
    go install golang.org/x/mobile/cmd/gobind@latest
    go install golang.org/x/mobile/cmd/gomobile@latest
    
    # Reinitialize gomobile
    echo "Reinitializing gomobile..."
    gomobile clean || true
    gomobile init
    
    # Check module dependencies
    echo "Checking module dependencies..."
    go list -m all | grep mobile || echo "No mobile dependencies found"
    
    # Verify gomobile tools
    echo "Verifying gomobile tools..."
    which gomobile
    which gobind
    gomobile version 2>/dev/null || echo "gomobile version failed"
    
    # Set CGO environment for iOS
    export CGO_ENABLED=1
    
    # Build for iOS with iOS-specific build tags to exclude incompatible packages
    echo "Starting iOS build from module root..."
    echo "CGO_ENABLED: $CGO_ENABLED"
    
    # Check what's in the openlistlib directory
    echo "Checking openlistlib directory contents:"
    ls -la openlistlib/
    
    # Try to build the package first to see if there are any issues
    echo "Testing basic build of openlistlib package..."
    go build -v ./openlistlib || {
        echo "Basic build failed, checking for issues..."
        go list -f '{{.ImportPath}}: {{.Error}}' ./openlistlib || true
    }
    
    # Use build tags to exclude problematic packages on iOS
    echo "Attempting gomobile bind with iOS tags..."
    gomobile bind -ldflags "-s -w" -v -target="ios" -tags="ios,mobile" ./openlistlib 2>&1 | tee ios_build.log
    
    # Check the exit status
    if [ $? -ne 0 ]; then
        echo "Error: gomobile bind failed"
        echo "=== Build log ==="
        cat ios_build.log 2>/dev/null || echo "No build log available"
        echo "=== End build log ==="
        
        # Try to get more specific error information
        echo "Checking for specific issues..."
        
        # Check if it's a dependency issue
        if grep -q "cannot find package\|no Go files\|build constraints exclude all Go files" ios_build.log; then
            echo "Detected dependency or build constraint issues"
            
            # Try with minimal tags
            echo "Retrying with minimal build tags..."
            gomobile bind -ldflags "-s -w" -v -target="ios" ./openlistlib 2>&1 | tee ios_build_minimal.log
            
            if [ $? -ne 0 ]; then
                echo "Minimal build also failed:"
                cat ios_build_minimal.log 2>/dev/null || echo "No minimal build log available"
                exit 1
            fi
        else
            echo "Unknown build error, exiting"
            exit 1
        fi
    fi
    
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