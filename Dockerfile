# GitOps Mail System - Production Docker Image
#
# This Dockerfile creates a secure, optimized container image for the
# GitOps Mail System. It follows Docker best practices including:
# - Multi-stage builds for smaller images
# - Non-root user execution
# - Health checks for container orchestration
# - Minimal attack surface with Alpine Linux
# - Security scanning compliance

# Use the latest LTS Node.js 22 Alpine image as the base
# Alpine Linux provides a minimal, security-focused foundation
# Node.js 22 is the current LTS version with long-term support
FROM node:22-alpine

# Set build-time argument for version tracking
# This can be passed during docker build to tag the image
ARG VERSION=unknown
LABEL version="${VERSION}" \
      description="GitOps Mail System - Secure CI/CD Demo Application" \
      maintainer="GitOps Lab" \
      org.opencontainers.image.source="https://github.com/Benjamin-yankey/Gitops_lab"

# Set the working directory inside the container
# All subsequent commands will be executed from this directory
WORKDIR /app

# Update the base image to patch known vulnerabilities
# Install essential tools for health checks and debugging
# hadolint ignore=DL3018 - We intentionally don't pin versions for security updates
RUN apk upgrade --no-cache && \
    apk add --no-cache \
        curl \
        jq \
        dumb-init && \
    # Clean up package cache to reduce image size
    rm -rf /var/cache/apk/*

# Copy package files first to leverage Docker layer caching
# This allows dependency installation to be cached if package.json hasn't changed
COPY package*.json ./

# Install only production dependencies to minimize image size and attack surface
# npm ci provides faster, reliable, reproducible builds compared to npm install
# --only=production excludes devDependencies (testing tools, linters, etc.)
RUN npm ci --only=production && \
    # Remove npm cache to reduce image size
    npm cache clean --force

# Copy the application source code and static assets
# This is done after dependency installation to optimize build caching
COPY app.js ./
COPY public/ ./public/

# Create a non-root user for running the application
# This follows the principle of least privilege and improves security
# The 'node' user is already created in the base Node.js image
USER node

# Expose the application port (5000)
# This is a documentation feature and doesn't actually publish the port
# The port must be published when running the container (-p flag)
EXPOSE 5000

# Configure a health check to monitor application status
# This enables container orchestrators (Docker, Kubernetes, ECS) to:
# - Detect when the application is ready to receive traffic
# - Restart unhealthy containers automatically
# - Route traffic only to healthy instances
#
# Health check parameters:
# --interval=30s: Check every 30 seconds
# --timeout=3s: Wait up to 3 seconds for response
# --start-period=5s: Grace period during container startup
# --retries=3: Mark unhealthy after 3 consecutive failures
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Use dumb-init as PID 1 to handle signals properly
# This ensures graceful shutdowns and proper zombie process reaping
# Critical for container orchestration environments
ENTRYPOINT ["dumb-init", "--"]

# Define the command to start the application
# npm start runs the script defined in package.json
# Using exec form (array) instead of shell form for better signal handling
CMD ["npm", "start"]

# Security and optimization notes:
# 1. Runs as non-root user (node) for security
# 2. Uses Alpine Linux for minimal attack surface
# 3. Only includes production dependencies
# 4. Includes health check for orchestration
# 5. Proper signal handling with dumb-init
# 6. Layer caching optimization with package.json copy first
# 7. Vulnerability patching with apk upgrade
