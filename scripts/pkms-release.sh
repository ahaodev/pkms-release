#!/bin/bash

# Integrated script for Drone CI/CD: Generate changelog and upload release
# Combines generate-changelog.sh and release-upload.sh for Docker image usage
# Usage: ./pkms-release.sh <file_path> <version> [artifact_name] [os] [arch]

set -e
set -o pipefail

# Configuration
FILE_PATH="$1"
VERSION="$2"
ARTIFACT_NAME="${3:-$(basename "$FILE_PATH" 2>/dev/null || echo "app")}"
OS="${4:-android}"
ARCH="${5:-universal}"
ACCESS_TOKEN="${ACCESS_TOKEN:-PKMS-9xuKyfbBvAJAwv42}"
RELEASE_URL="${RELEASE_URL:-https://your-release-system.com/client-access/release}"

# Drone CI environment variables
DRONE_TAG="${DRONE_TAG}"
DRONE_COMMIT="${DRONE_COMMIT}"
DRONE_BRANCH="${DRONE_BRANCH}"

# Function to print usage
print_usage() {
    echo "Usage: $0 <file_path> <version> [artifact_name] [os] [arch]"
    echo ""
    echo "Arguments:"
    echo "  file_path      - Path to the release artifact file"
    echo "  version        - Release version (e.g., v1.0.0)"
    echo "  artifact_name  - Name of the artifact (default: filename)"
    echo "  os             - Target OS (default: android)"
    echo "  arch           - Target architecture (default: universal)"
    echo ""
    echo "Environment variables:"
    echo "  ACCESS_TOKEN   - Release system access token"
    echo "  RELEASE_URL    - Release system URL"
    echo "  DRONE_TAG      - Current tag from Drone CI"
    echo "  DRONE_COMMIT   - Current commit from Drone CI"
    echo "  DRONE_BRANCH   - Current branch from Drone CI"
    echo ""
    echo "Docker example: docker run --rm -v \$PWD:/workspace pkms-release:latest ./app.apk v1.0.0"
}

# Validate inputs
if [ -z "$FILE_PATH" ] || [ -z "$VERSION" ]; then
    print_usage
    exit 1
fi

if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File '$FILE_PATH' not found"
    exit 1
fi

echo "🚀 Starting release: $VERSION ($FILE_PATH)"

# ============================================================================
# CHANGELOG GENERATION SECTION
# ============================================================================

echo ""
echo "📝 Generating changelog..."

# Function to get the latest tag
get_latest_tag() {
    if [ -n "$1" ]; then
        echo "$1"
        return
    fi
    
    # Use DRONE_TAG if available, otherwise get most recent tag
    if [ -n "$DRONE_TAG" ]; then
        echo "$DRONE_TAG"
    else
        git tag --sort=-version:refname | head -1 2>/dev/null || echo ""
    fi
}

# Function to get the previous tag
get_previous_tag() {
    if [ -n "$1" ]; then
        echo "$1"
        return
    fi
    
    # Get the second most recent tag
    git tag --sort=-version:refname | head -2 | tail -1 2>/dev/null || echo ""
}

# Function to categorize commits for changelog
categorize_commit() {
    local commit_msg="$1"
    local commit_hash="$2"
    
    case "$commit_msg" in
        feat*|feature*) echo "### ✨ New Features" ;;
        fix*|bugfix*) echo "### 🐛 Bug Fixes" ;;
        docs*|doc*) echo "### 📚 Documentation" ;;
        style*|format*) echo "### 💄 Style Changes" ;;
        refactor*) echo "### ♻️ Code Refactoring" ;;
        perf*|performance*) echo "### ⚡ Performance Improvements" ;;
        test*) echo "### 🧪 Tests" ;;
        build*|ci*|cd*) echo "### 🔧 Build System & CI/CD" ;;
        chore*) echo "### 🔨 Maintenance" ;;
        *) echo "### 📝 Other Changes" ;;
    esac
}

# Generate changelog
generate_changelog() {
    # Validate git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Warning: Not in a git repository, using minimal changelog" >&2
        echo "## $VERSION"
        echo ""
        echo "### 🎉 Release"
        echo ""
        echo "- Release $VERSION"
        return 0
    fi

    # Get tags
    CURRENT_TAG=$(get_latest_tag "$VERSION")
    PREVIOUS_TAG=$(get_previous_tag "")

    # Use provided version if no tags found
    if [ -z "$CURRENT_TAG" ]; then
        CURRENT_TAG="$VERSION"
    fi

    # Generate changelog header
    echo "## ${CURRENT_TAG}"
    echo ""

    # Get commits between tags
    if [ -n "$PREVIOUS_TAG" ] && [ "$PREVIOUS_TAG" != "$CURRENT_TAG" ]; then
        COMMITS_RAW=$(git log --pretty=format:"%s|%h" ${PREVIOUS_TAG}..${CURRENT_TAG} 2>/dev/null || echo "")
    elif [ -n "$CURRENT_TAG" ] && git rev-parse --verify "$CURRENT_TAG" > /dev/null 2>&1; then
        COMMITS_RAW=$(git log --pretty=format:"%s|%h" ${CURRENT_TAG} 2>/dev/null || echo "")
    else
        # Fallback: get recent commits
        COMMITS_RAW=$(git log --pretty=format:"%s|%h" -n 10 HEAD 2>/dev/null || echo "")
    fi

    if [ -n "$COMMITS_RAW" ]; then
        # Arrays to store categorized commits
        declare -A categories
        declare -A commit_lists
        
        # Process each commit
        while IFS='|' read -r msg hash; do
            [ -z "$msg" ] && continue
            category=$(categorize_commit "$msg" "$hash")
            if [ -z "${categories[$category]}" ]; then
                categories[$category]=1
                commit_lists[$category]=""
            fi
            commit_lists[$category]+="- $msg ($hash)"$'\n'
        done <<< "$COMMITS_RAW"
        
        # Output categorized commits in order
        for category in "### ✨ New Features" "### 🐛 Bug Fixes" "### 📚 Documentation" "### 💄 Style Changes" "### ♻️ Code Refactoring" "### ⚡ Performance Improvements" "### 🧪 Tests" "### 🔧 Build System & CI/CD" "### 🔨 Maintenance" "### 📝 Other Changes"; do
            if [ -n "${commit_lists[$category]}" ]; then
                echo "$category"
                echo ""
                echo -n "${commit_lists[$category]}"
                echo ""
            fi
        done
    else
        echo "### 🎉 Initial Release"
        echo ""
        echo "- Initial release"
    fi
}

# Generate the changelog
CHANGELOG_FILE="/tmp/changelog.md"
if generate_changelog > "$CHANGELOG_FILE" 2>/tmp/changelog-error.log; then
    CHANGELOG=$(cat "$CHANGELOG_FILE")
    echo "✅ Changelog generated successfully"
else
    echo "⚠️  Failed to generate changelog, using default"
    if [ -f /tmp/changelog-error.log ]; then
        echo "Changelog generation errors:"
        cat /tmp/changelog-error.log
    fi
    CHANGELOG="## $VERSION

### 🎉 Release

- Release $VERSION"
fi

echo "📋 Changelog preview:"
echo "---"
echo "$CHANGELOG" | head -15
echo "---"
echo ""

# ============================================================================
# RELEASE UPLOAD SECTION
# ============================================================================

echo "📤 Uploading: $ARTIFACT_NAME ($OS/$ARCH) to $RELEASE_URL"

# Test connectivity
if ! curl --connect-timeout 5 --max-time 10 -s -I "$RELEASE_URL" >/dev/null 2>&1; then
    echo "⚠️  Connectivity test failed - continuing anyway"
fi

# Prepare upload with enhanced error handling for Docker environments
echo "📤 Uploading release artifact..."

# Create response and error log files
RESPONSE_FILE="/tmp/release-response.json"
ERROR_FILE="/tmp/curl-error.log"

# Perform the upload with comprehensive error handling
HTTP_CODE=$(curl -X POST "$RELEASE_URL" \
    -H "x-access-token: $ACCESS_TOKEN" \
    -H "User-Agent: PKMS-Release-Script/1.0" \
    -F "file=@$FILE_PATH" \
    -F "version=$VERSION" \
    -F "artifact=$ARTIFACT_NAME" \
    -F "os=$OS" \
    -F "arch=$ARCH" \
    -F "changelog=$CHANGELOG" \
    -F "drone_tag=$DRONE_TAG" \
    -F "drone_commit=$DRONE_COMMIT" \
    -F "drone_branch=$DRONE_BRANCH" \
    --connect-timeout 30 \
    --max-time 600 \
    --retry 3 \
    --retry-delay 5 \
    --show-error \
    --fail-with-body \
    --write-out "%{http_code}" \
    --output "$RESPONSE_FILE" 2>"$ERROR_FILE" || echo "0")

echo ""

# Check the response
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo "🎉 Release upload successful! (HTTP $HTTP_CODE)"
    echo "📋 Response:"
    if command -v jq >/dev/null 2>&1; then
        cat "$RESPONSE_FILE" | jq . 2>/dev/null || cat "$RESPONSE_FILE"
    else
        cat "$RESPONSE_FILE"
    fi
    echo ""
    echo "✅ Release $VERSION completed!"
    
    # Cleanup temporary files
    rm -f "$RESPONSE_FILE" "$ERROR_FILE" "$CHANGELOG_FILE" /tmp/changelog-error.log
    
else
    if [ "$HTTP_CODE" = "0" ]; then
        echo "❌ Upload failed - Network/Connection error"
    else
        echo "❌ Upload failed with HTTP code: $HTTP_CODE"
        cat "$RESPONSE_FILE" 2>/dev/null || echo "No response available"
    fi
    echo "Error details:"
    cat "$ERROR_FILE" 2>/dev/null || echo "No error details available"
    exit 1
fi