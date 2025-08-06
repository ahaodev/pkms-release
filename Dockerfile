# Dockerfile for PKMS Release Tool
# Based on alpine/curl with additional tools for changelog generation and release upload

FROM alpine/curl:latest

# Metadata
LABEL maintainer="CICD Team"
LABEL description="PKMS CI/CD Release Tool with Changelog Generation"
LABEL version="1.0.0"

# Install required packages
RUN apk add --no-cache \
    bash \
    git \
    jq \
    ca-certificates \
    tzdata

# Set timezone (optional, can be overridden)
ENV TZ=Asia/Shanghai

# Create working directory
WORKDIR /workspace

# Copy the integrated release script
COPY scripts/pkms-release.sh /usr/local/bin/pkms-release
RUN chmod +x /usr/local/bin/pkms-release

# Create a symlink for backward compatibility
RUN ln -s /usr/local/bin/pkms-release /usr/local/bin/pkms-release.sh

# Set default environment variables
ENV ACCESS_TOKEN=""
ENV RELEASE_URL=""
ENV DRONE_TAG=""
ENV DRONE_COMMIT=""
ENV DRONE_BRANCH=""

# Create non-root user for security
RUN addgroup -g 1000 pkms && \
    adduser -u 1000 -G pkms -s /bin/bash -D pkms

# Set ownership of working directory
RUN chown -R pkms:pkms /workspace

# Switch to non-root user
USER pkms

# Default command
CMD ["pkms-release", "--help"]

# Health check (optional)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD which pkms-release && which curl && which git && which jq || exit 1