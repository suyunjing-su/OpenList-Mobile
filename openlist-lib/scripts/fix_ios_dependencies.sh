#!/bin/bash

echo "Fixing iOS incompatible dependencies..."

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

# Check for problematic dependencies
echo "Checking for iOS incompatible dependencies..."
go list -m all | grep -E "(go-m1cpu|gopsutil)" || echo "No problematic dependencies found in module list"

# Try to exclude problematic dependencies by replacing them with stubs
echo "Attempting to exclude iOS incompatible dependencies..."

# Replace go-m1cpu with a no-op version if it exists
if go list -m all | grep -q "go-m1cpu"; then
    echo "Found go-m1cpu dependency, attempting to exclude..."
    # Try to replace with a version that doesn't use iOS incompatible APIs
    go mod edit -replace github.com/shoenig/go-m1cpu=github.com/shoenig/go-m1cpu@v0.1.5 || true
fi

# Clean and rebuild
echo "Cleaning and rebuilding module..."
go mod tidy
go mod download

echo "Updated dependencies:"
go list -m all | grep -E "(mobile|m1cpu|gopsutil)" || echo "No relevant dependencies found"

echo "iOS dependency fix completed"