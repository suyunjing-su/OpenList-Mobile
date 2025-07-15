#!/bin/bash

echo "Initializing Web assets..."

mkdir -p dist

# Function to fetch release info with retries
fetch_release_info() {
    local attempt=1
    local max_attempts=3
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: Fetching release info..."
        
        RELEASE_INFO=$(curl -fsSL --max-time 10 \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/OpenListTeam/OpenList-Frontend/releases/latest" 2>/dev/null)
        
        local curl_exit_code=$?
        
        if [ $curl_exit_code -eq 0 ] && [ -n "$RELEASE_INFO" ]; then
            echo "Successfully fetched release info on attempt $attempt"
            return 0
        else
            echo "Attempt $attempt failed (exit code: $curl_exit_code)"
            if [ $attempt -lt $max_attempts ]; then
                echo "Waiting 5 seconds before retry..."
                sleep 5
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo "Failed to fetch release info after $max_attempts attempts"
    return 1
}

# Get release info from GitHub API with retries
echo "Fetching latest release information..."
if ! fetch_release_info; then
    echo "Error: Failed to fetch release info from GitHub API"
    exit 1
fi

# Parse download URL with better pattern matching
echo "Parsing download URL..."
if command -v jq >/dev/null 2>&1; then
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r '.assets[] | select(.browser_download_url | test("openlist-frontend-dist.*\\.tar\\.gz$") and (test("openlist-frontend-dist-lite") | not)) | .browser_download_url')
else
    # Fallback without jq - look for versioned filename
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | grep -o '"browser_download_url":"[^"]*openlist-frontend-dist-v[^"]*\.tar\.gz"' | grep -v 'lite' | head -1 | sed 's/.*"browser_download_url":"\([^"]*\)".*/\1/')
    
    # If versioned pattern doesn't work, try general pattern
    if [ -z "$DOWNLOAD_URL" ]; then
        DOWNLOAD_URL=$(echo "$RELEASE_INFO" | grep -o '"browser_download_url":"[^"]*openlist-frontend-dist[^"]*\.tar\.gz"' | grep -v 'lite' | head -1 | sed 's/.*"browser_download_url":"\([^"]*\)".*/\1/')
    fi
fi

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
    echo "Error: Could not determine download URL"
    exit 1
fi

echo "Download URL: $DOWNLOAD_URL"

# Function to download file with retries
download_file() {
    local url="$1"
    local output="$2"
    local attempt=1
    local max_attempts=3
    
    while [ $attempt -le $max_attempts ]; do
        echo "Download attempt $attempt/$max_attempts..."
        
        # Try download
        if curl -fsSL --max-time 30 -o "$output" "$url"; then
            echo "Download successful on attempt $attempt"
            return 0
        else
            local curl_exit_code=$?
            echo "Download attempt $attempt failed (exit code: $curl_exit_code)"
            
            # Remove partial file if it exists
            rm -f "$output"
            
            if [ $attempt -lt $max_attempts ]; then
                echo "Waiting 5 seconds before retry..."
                sleep 5
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo "Failed to download after $max_attempts attempts"
    return 1
}

# Download the file with retries
echo "Downloading web assets..."
if ! download_file "$DOWNLOAD_URL" "dist.tar.gz"; then
    echo "Error: Failed to download web assets after multiple attempts"
    exit 1
fi

# Extract and install
echo "Extracting web assets..."
tar -zxf dist.tar.gz -C dist || {
    echo "Error: Failed to extract archive"
    exit 1
}

echo "Installing web assets..."
rm -rf ../public/dist
mv -f dist ../public
rm -f dist.tar.gz

echo "Web assets initialization completed"