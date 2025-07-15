#!/bin/bash

# First check if we're in the right place
echo "Starting Android build from: $(pwd)"

# Try to find the correct directory with go.mod
if [ -f ../go.mod ]; then
    echo "Found go.mod in parent directory, using that"
    cd ../ || exit
elif [ -f ../openlist/go.mod ]; then
    echo "Found go.mod in openlist directory"
    cd ../openlist/ || exit
elif [ -f ../openlistlib/go.mod ]; then
    echo "Found go.mod in openlistlib directory"
    cd ../openlistlib/ || exit
else
    echo "Searching for go.mod in parent directories..."
    cd ../ || exit
    find . -name "go.mod" -type f | head -5
    
    # Try the most likely location
    if [ -f go.mod ]; then
        echo "Using go.mod in current directory: $(pwd)"
    else
        echo "Error: Cannot find go.mod file"
        echo "Current directory: $(pwd)"
        echo "Directory contents:"
        ls -la
        exit 1
    fi
fi

echo "Current directory: $(pwd)"
echo "Building OpenList for Android..."

# Verify go.mod exists
if [ ! -f go.mod ]; then
    echo "Error: go.mod not found in $(pwd)"
    echo "Directory contents:"
    ls -la
    exit 1
fi

if [ "$1" == "debug" ]; then
  gomobile bind -ldflags "-s -w" -v -androidapi 19 -target="android/arm64"
else
  gomobile bind -ldflags "-s -w" -v -androidapi 19
fi

echo "Moving aar and jar files to android/app/libs"
mkdir -p ../../android/app/libs
mv -f ./*.aar ../../android/app/libs
mv -f ./*.jar ../../android/app/libs
