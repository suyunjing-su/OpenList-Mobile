#!/bin/bash

echo "Initializing Web assets for iOS build..."

# Create dist directory
mkdir -p dist

# Use a more reliable approach for iOS
# First, try to get the latest release info with better error handling
echo "Fetching latest release information..."

# Method 1: Try with curl and better error handling
RELEASE_INFO=$(curl -fsSL --max-time 10 \
    -H "Accept: application/vnd.github.v3+json" \
    -H "User-Agent: OpenList-iOS-Builder" \
    "https://api.github.com/repos/OpenListTeam/OpenList-Frontend/releases/latest" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$RELEASE_INFO" ]; then
    echo "Failed to fetch release info from GitHub API, trying alternative method..."
    
    # Method 2: Use a fallback URL pattern (assuming latest version)
    echo "Using fallback download method..."
    DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList-Frontend/releases/latest/download/openlist-frontend-dist.tar.gz"
else
    echo "Successfully fetched release info, parsing download URL..."
    
    # Check if jq is available
    if command -v jq >/dev/null 2>&1; then
        DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r '.assets[] | select(.browser_download_url | test("openlist-frontend-dist") and (test("openlist-frontend-dist-lite") | not)) | .browser_download_url')
    else
        echo "jq not available, using grep/sed to parse JSON..."
        # Fallback parsing without jq
        DOWNLOAD_URL=$(echo "$RELEASE_INFO" | grep -o '"browser_download_url":"[^"]*openlist-frontend-dist[^"]*"' | grep -v 'lite' | head -1 | sed 's/.*"browser_download_url":"\([^"]*\)".*/\1/')
    fi
fi

# Validate download URL
if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
    echo "Error: Could not determine download URL"
    echo "Trying direct latest release URL..."
    DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList-Frontend/releases/latest/download/openlist-frontend-dist.tar.gz"
fi

echo "Download URL: $DOWNLOAD_URL"

# Download the file
echo "Downloading web assets..."
if curl -fsSL --max-time 30 -o dist.tar.gz "$DOWNLOAD_URL"; then
    echo "Download successful"
else
    echo "Download failed, trying alternative approach..."
    # Try without following redirects first
    if curl -fsS --max-time 30 -o dist.tar.gz "$DOWNLOAD_URL"; then
        echo "Download successful with alternative method"
    else
        echo "Error: Failed to download web assets"
        echo "All download methods failed"
        exit 1
    fi
fi

# Verify the downloaded file
if [ ! -f dist.tar.gz ] || [ ! -s dist.tar.gz ]; then
    echo "Error: Downloaded file is empty or missing"
    exit 1
fi

echo "Downloaded file size: $(ls -lh dist.tar.gz | awk '{print $5}')"

# Extract the archive
echo "Extracting web assets..."
if tar -zxf dist.tar.gz -C dist 2>/dev/null; then
    echo "Extraction successful"
else
    echo "Error: Failed to extract archive"
    echo "File info:"
    file dist.tar.gz 2>/dev/null || echo "file command not available"
    ls -la dist.tar.gz
    exit 1
fi

# Move to final location
echo "Installing web assets..."
rm -rf ../public/dist
if [ -d dist ]; then
    mv dist ../public/
    echo "Web assets installed successfully"
else
    echo "Error: Extracted directory not found"
    exit 1
fi

# Cleanup
rm -f dist.tar.gz

echo "Web assets initialization completed"