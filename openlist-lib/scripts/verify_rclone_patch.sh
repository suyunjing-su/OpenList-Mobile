#!/bin/bash

echo "Verifying rclone patch for iOS compatibility..."

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

# Check if local rclone copy exists
if [ -d "local_rclone" ]; then
    echo "✅ Local rclone copy found"
    
    OSVERSION_FILE="local_rclone/lib/buildinfo/osversion.go"
    if [ -f "$OSVERSION_FILE" ]; then
        echo "✅ osversion.go found in local copy"
        echo ""
        echo "Current content of osversion.go:"
        echo "================================"
        cat "$OSVERSION_FILE"
        echo "================================"
        echo ""
        
        # Check if it contains the expected patch
        if grep -q "//go:build !windows" "$OSVERSION_FILE" && grep -q "return$" "$OSVERSION_FILE"; then
            echo "✅ Patch successfully applied - file contains iOS-compatible code"
        else
            echo "❌ Patch not properly applied - file may still contain problematic code"
        fi
    else
        echo "❌ osversion.go not found in local copy at: $OSVERSION_FILE"
    fi
else
    echo "ℹ️  No local rclone copy found - checking if rclone is patched in module cache"
    
    # Try to find rclone in module cache
    RCLONE_PATH=$(go list -m -f '{{.Dir}}' github.com/rclone/rclone 2>/dev/null)
    
    if [ -n "$RCLONE_PATH" ]; then
        echo "Found rclone in module cache at: $RCLONE_PATH"
        
        OSVERSION_FILE="$RCLONE_PATH/lib/buildinfo/osversion.go"
        if [ -f "$OSVERSION_FILE" ]; then
            echo "osversion.go found in module cache"
            echo ""
            echo "Current content:"
            echo "================"
            cat "$OSVERSION_FILE" 2>/dev/null || echo "Cannot read file (may be read-only)"
            echo "================"
        else
            echo "osversion.go not found at: $OSVERSION_FILE"
        fi
    else
        echo "❌ Cannot locate rclone module"
    fi
fi

# Check go.mod for replace directives
echo ""
echo "Checking go.mod for rclone replace directives..."
if grep -q "github.com/rclone/rclone" go.mod; then
    echo "Found rclone references in go.mod:"
    grep "github.com/rclone/rclone" go.mod
else
    echo "No rclone references found in go.mod"
fi

echo ""
echo "Verification completed."