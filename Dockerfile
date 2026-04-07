# Dockerfile for PMS Releaser Tool
# Based on alpine/curl with additional tools for changelog generation and release upload

FROM alpine/curl:latest

# Metadata
LABEL maintainer="CICD Team"
LABEL description="PMS Releaser CI/CD Tool with Changelog Generation"
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
COPY scripts/pms-releaser.sh /usr/local/bin/pms-releaser
RUN chmod +x /usr/local/bin/pms-releaser

# Create a symlink for backward compatibility
RUN ln -s /usr/local/bin/pms-releaser /usr/local/bin/pms-releaser.sh

# Set default environment variables
ENV ACCESS_TOKEN=""
ENV RELEASE_URL=""
ENV DRONE_TAG=""
ENV DRONE_COMMIT=""
ENV DRONE_BRANCH=""
ENV GITHUB_REF=""
ENV GITHUB_REF_NAME=""
ENV GITHUB_SHA=""

# Create non-root user for security
RUN addgroup -g 1000 pms && \
    adduser -u 1000 -G pms -s /bin/bash -D pms

# Set ownership of working directory
RUN chown -R pms:pms /workspace

# Switch to non-root user
USER pms

# Override alpine/curl's ENTRYPOINT so args are passed to pms-releaser
ENTRYPOINT ["pms-releaser"]

# Health check (optional)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD which pms-releaser && which curl && which git && which jq || exit 1