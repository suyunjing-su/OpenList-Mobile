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

# Fix gomobile bind dependencies for iOS - aggressive approach
echo "Fixing gomobile bind dependencies for iOS..."

# Set up Go environment explicitly
export GOPATH="${HOME}/go"
export PATH="${GOPATH}/bin:${PATH}"
echo "GOPATH set to: $GOPATH"
echo "PATH updated to include: ${GOPATH}/bin"

# Clean everything first
echo "Cleaning Go caches and gomobile..."
go clean -cache
go clean -modcache || true
rm -rf "${GOPATH}/pkg/mod/golang.org/x/mobile*" || true

# Save current directory
CURRENT_DIR=$(pwd)

# Create a clean temporary workspace
TEMP_DIR=$(mktemp -d)
echo "Using temporary directory: $TEMP_DIR"
cd "$TEMP_DIR"

# Set up a clean module environment
echo "Setting up clean module environment..."
go mod init temp-gomobile-fix

# Force install all mobile-related packages
echo "Force installing all golang.org/x/mobile packages..."
go get -u golang.org/x/mobile@latest
go get -u golang.org/x/mobile/cmd/gomobile@latest
go get -u golang.org/x/mobile/cmd/gobind@latest
go get -u golang.org/x/mobile/bind@latest
go get -u golang.org/x/mobile/bind/objc@latest

# Install tools to GOPATH/bin
echo "Installing tools to GOPATH/bin..."
go install golang.org/x/mobile/cmd/gomobile@latest
go install golang.org/x/mobile/cmd/gobind@latest

# Return to original directory
cd "$CURRENT_DIR"
rm -rf "$TEMP_DIR"

# Verify tools are in PATH
echo "Verifying tool installation..."
echo "gomobile path: $(which gomobile 2>/dev/null || echo 'NOT FOUND')"
echo "gobind path: $(which gobind 2>/dev/null || echo 'NOT FOUND')"

# Clean and reinitialize gomobile
echo "Reinitializing gomobile..."
gomobile clean 2>/dev/null || true
gomobile init || {
    echo "Failed to initialize gomobile"
    echo "Trying alternative initialization..."
    
    # Try to manually set up gomobile
    mkdir -p "${GOPATH}/pkg/gomobile"
    gomobile init -ndk="" || {
        echo "Alternative initialization also failed"
        exit 1
    }
}

echo "Gomobile setup completed"

# Check if this directory has Go files suitable for binding
if [ ! -f *.go ]; then
    echo "Warning: No Go files found in current directory"
    echo "Directory contents:"
    ls -la
fi

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
        cd ..
        go mod tidy
        go mod download
        cd openlistlib
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