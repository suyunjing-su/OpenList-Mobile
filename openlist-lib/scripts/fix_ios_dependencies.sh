#!/bin/bash

echo "Fixing iOS incompatible dependencies by patching rclone source..."

# Find the module root
if [ -f go.mod ]; then
    MODULE_ROOT="."
elif [ -f ../go.mod ]; then
    MODULE_ROOT=".."
    cd ..
else
    echo "Error: Cannot find go.mod"
    exit 1
fi

echo "Working in module root: $(pwd)"

# Check for rclone dependency
echo "Checking for rclone dependency..."
RCLONE_VERSION=$(go list -m all | grep "github.com/rclone/rclone" | awk '{print $2}' || echo "")

if [ -z "$RCLONE_VERSION" ]; then
    echo "No rclone dependency found, skipping patch"
    exit 0
fi

echo "Found rclone version: $RCLONE_VERSION"

# Download dependencies to get the source
echo "Downloading dependencies..."
go mod download

# Find the rclone module path
RCLONE_PATH=$(go list -m -f '{{.Dir}}' github.com/rclone/rclone 2>/dev/null)

if [ -z "$RCLONE_PATH" ]; then
    echo "Could not find rclone module path, trying alternative method..."
    # Try to find it in GOPATH/pkg/mod
    GOPATH_MOD=$(go env GOPATH)/pkg/mod
    RCLONE_PATH=$(find "$GOPATH_MOD" -name "rclone@$RCLONE_VERSION" -type d 2>/dev/null | head -1)
fi

if [ -z "$RCLONE_PATH" ]; then
    echo "Could not locate rclone source directory, skipping patch"
    exit 0
fi

echo "Found rclone source at: $RCLONE_PATH"

# Path to the problematic file
OSVERSION_FILE="$RCLONE_PATH/lib/buildinfo/osversion.go"

if [ ! -f "$OSVERSION_FILE" ]; then
    echo "osversion.go file not found at: $OSVERSION_FILE"
    echo "Checking if file exists with different structure..."
    find "$RCLONE_PATH" -name "osversion.go" -type f 2>/dev/null || echo "No osversion.go found in rclone source"
    exit 0
fi

echo "Found osversion.go at: $OSVERSION_FILE"

# Check if file is writable (some module caches are read-only)
if [ ! -w "$OSVERSION_FILE" ]; then
    echo "File is not writable, creating local copy..."
    
    # Create local copy of rclone module
    LOCAL_RCLONE_DIR="./local_rclone"
    mkdir -p "$LOCAL_RCLONE_DIR"
    
    echo "Copying rclone source to local directory..."
    cp -r "$RCLONE_PATH"/* "$LOCAL_RCLONE_DIR/" 2>/dev/null || {
        echo "Failed to copy rclone source, skipping patch"
        exit 0
    }
    
    # Update the file path to local copy
    OSVERSION_FILE="$LOCAL_RCLONE_DIR/lib/buildinfo/osversion.go"
    
    # Add replace directive to use local copy
    echo "Adding replace directive to use local rclone copy..."
    go mod edit -replace github.com/rclone/rclone="./local_rclone"
else
    echo "File is writable, patching in place..."
    chmod +w "$OSVERSION_FILE" 2>/dev/null || true
fi

# Backup original file
echo "Backing up original osversion.go..."
cp "$OSVERSION_FILE" "$OSVERSION_FILE.backup" 2>/dev/null || echo "Could not create backup"

# Replace the file content with iOS-compatible version using echo
echo "Patching osversion.go for iOS compatibility..."

echo "//go:build !windows" > "$OSVERSION_FILE"
echo "" >> "$OSVERSION_FILE"
echo "package buildinfo" >> "$OSVERSION_FILE"
echo "" >> "$OSVERSION_FILE"
echo "// GetOSVersion returns OS version, kernel and bitness" >> "$OSVERSION_FILE"
echo "func GetOSVersion() (osVersion, osKernel string) {" >> "$OSVERSION_FILE"
echo "	return" >> "$OSVERSION_FILE"
echo "}" >> "$OSVERSION_FILE"

echo "Successfully patched osversion.go"

# Verify the patch
if [ -f "$OSVERSION_FILE" ]; then
    echo "Verifying patch..."
    echo "New file content:"
    cat "$OSVERSION_FILE"
    echo ""
fi

# Clean and rebuild to apply changes
echo "Cleaning and rebuilding module with patched rclone..."
go mod tidy
go mod download

echo "iOS dependency fix completed by patching rclone source"
echo "The problematic gopsutil calls in rclone have been disabled for iOS builds"