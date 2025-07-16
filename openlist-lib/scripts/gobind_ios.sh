#!/bin/bash

# First check if we're in the right place
echo "Starting iOS build from: $(pwd)"

# For iOS, we need to find the bindable package directory, not just go.mod
# The original approach was correct - look for openlistlib directory
if [ -d ../openlistlib ]; then
    echo "Found openlistlib directory, using that for iOS build"
    cd ../openlistlib || exit
else
    echo "Searching for bindable package directory..."
    cd ../ || exit
    
    # Look for directories that might contain bindable packages
    if [ -d openlistlib ]; then
        echo "Found openlistlib in current directory"
        cd openlistlib || exit
    elif [ -d cmd/openlistlib ]; then
        echo "Found openlistlib in cmd directory"
        cd cmd/openlistlib || exit
    else
        echo "Error: Cannot find openlistlib directory for iOS binding"
        echo "Current directory: $(pwd)"
        echo "Directory contents:"
        ls -la
        echo "Looking for Go files that might be bindable..."
        find . -name "*.go" -type f | head -10
        exit 1
    fi
fi

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

# Verify Go version compatibility
echo "Checking Go version compatibility..."
GO_VERSION=$(go version | grep -o 'go[0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/go//')
echo "Current Go version: $GO_VERSION"

# Check if this directory has Go files suitable for binding
if ! ls *.go 1> /dev/null 2>&1; then
    echo "Warning: No Go files found in current directory"
    echo "Directory contents:"
    ls -la
fi

# Verify gomobile tools are available
echo "Verifying gomobile tools..."
echo "gomobile path: $(which gomobile 2>/dev/null || echo 'NOT FOUND')"
echo "gobind path: $(which gobind 2>/dev/null || echo 'NOT FOUND')"

# Check if we need to work with go modules
if [ -f go.mod ]; then
    echo "Go module info:"
    go mod tidy
    go list -m all | head -10
    
    # Ensure dependencies are downloaded
    echo "Downloading dependencies..."
    go mod download
else
    echo "No go.mod in current directory, checking parent..."
    if [ -f ../go.mod ]; then
        echo "Found go.mod in parent directory"
        PARENT_DIR=$(pwd)/..
        cd ..
        
        # Add mobile bind packages to the module
        echo "Adding mobile bind packages to module..."
        go get golang.org/x/mobile/bind@latest
        go get golang.org/x/mobile/bind/objc@latest
        
        go mod tidy
        go mod download
        
        # Verify bind packages are in module
        echo "Verifying bind packages in module:"
        go list -m golang.org/x/mobile || echo "mobile module not found"
        
        # Return to openlistlib but stay in module context
        cd openlistlib
        
        # Try to build from parent context
        echo "Building from parent module context..."
        cd ..
        
        # Build the openlistlib package from module root
        echo "Current directory for iOS build: $(pwd)"
        echo "Building package: ./openlistlib"
        
        # Set CGO environment for iOS
        export CGO_ENABLED=1
        
        # Build for iOS with more verbose output
        echo "Starting iOS build from module root..."
        echo "CGO_ENABLED: $CGO_ENABLED"
        gomobile bind -ldflags "-s -w" -v -target="ios" ./openlistlib 2>&1 | tee ios_build.log || {
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
        mkdir -p ios/Frameworks
        
        # Check if xcframework files exist before moving
        if ls *.xcframework 1> /dev/null 2>&1; then
            mv -f ./*.xcframework ios/Frameworks/
            echo "iOS framework build completed successfully"
            echo "Files in ios/Frameworks:"
            ls -la ios/Frameworks/
            exit 0
        else
            echo "Warning: No .xcframework files were generated"
            exit 1
        fi
    else
        echo "Warning: No go.mod found, proceeding without module operations"
    fi
fi

# Set CGO environment for iOS
export CGO_ENABLED=1

# Clean any previous builds
echo "Cleaning previous builds..."
go clean -cache
go clean -modcache || true

# Try a simple build first to check for issues
echo "Testing basic build..."
go build -v . || {
    echo "Error: Basic go build failed"
    echo "Trying to build from parent directory with module path..."
    cd ..
    go build -v ./openlistlib || {
        echo "Error: Build failed from parent directory too"
        exit 1
    }
    cd openlistlib
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