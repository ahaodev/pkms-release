# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Drone CI/CD release tool packaged as a Docker container. It's designed to automate the release process by generating changelogs and uploading release artifacts to a release system.

## Architecture

The project consists of three main components:

1. **Dockerfile** - Alpine-based container with curl, git, jq, and bash
2. **Release Script** (`scripts/pkms-release.sh`) - Integrated bash script that:
   - Generates changelogs from git commits using conventional commit categorization
   - Uploads release artifacts to a configured release system via HTTP API
   - Supports Drone CI environment variables for automation

## Key Commands

### Docker Build
```bash
docker build -t pkms-release:latest .
```

### Docker Run
```bash
# Basic usage
docker run --rm -v "$PWD:/workspace" -w /workspace \
  -e ACCESS_TOKEN=$TOKEN -e RELEASE_URL=$URL \
  pkms-release:latest /workspace/app.apk v1.0.0

# With custom artifact name, OS, and arch
docker run --rm -v "$PWD:/workspace" -w /workspace \
  -e ACCESS_TOKEN=$TOKEN -e RELEASE_URL=$URL \
  pkms-release:latest /workspace/app.apk v1.0.0 MyApp android arm64
```

### Script Direct Usage
```bash
# Make executable and run
chmod +x scripts/pkms-release.sh
./scripts/pkms-release.sh <file_path> <version> [artifact_name] [os] [arch]
```

## Configuration

### Required Environment Variables
- `ACCESS_TOKEN` - Release system access token (default: PKMS-9xuKyfbBvAJAwv42)
- `RELEASE_URL` - Release system endpoint (default: https://your-release-system.com/access/release)

### Optional Drone CI Variables
- `DRONE_TAG` - Current tag from Drone CI
- `DRONE_COMMIT` - Current commit hash from Drone CI  
- `DRONE_BRANCH` - Current branch from Drone CI

## Script Features

### Changelog Generation
- Automatically categorizes git commits using conventional commit prefixes:
  - `feat*` → ✨ New Features
  - `fix*` → 🐛 Bug Fixes
  - `docs*` → 📚 Documentation
  - `style*` → 💄 Style Changes
  - `refactor*` → ♻️ Code Refactoring
  - `perf*` → ⚡ Performance Improvements
  - `test*` → 🧪 Tests
  - `build*|ci*|cd*` → 🔧 Build System & CI/CD
  - `chore*` → 🔨 Maintenance
  - Others → 📝 Other Changes

### Release Upload
- Multi-part form upload with comprehensive metadata
- Retry logic with exponential backoff
- Docker-optimized error handling
- HTTP response validation

## File Structure
```
PKMS-RELEASE/
├── Dockerfile              # Alpine-based container definition
├── README.md              # Basic project info
├── scripts/
│   └── pkms-release.sh    # Main integrated release script
├── .gitignore
└── .idea/                 # IDE configuration
```