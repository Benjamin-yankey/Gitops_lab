# Use the latest LTS Node.js 22 Alpine image as the base
FROM node:22-alpine

# Set the working directory inside the container
WORKDIR /app

# Patch OS vulnerabilities and install required tools
RUN apk upgrade --no-cache && \
    apk add --no-cache curl jq

# Copy package.json and package-lock.json to install dependencies
COPY package*.json ./
# Install only production dependencies for a smaller image size
RUN npm ci --only=production

# Copy the application source code
COPY app.js .

# Expose the application port (5000)
EXPOSE 5000

# Configure a health check to monitor the application status
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:5000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Switch to a non-privileged user for better security
USER node

# Define the command to start the application
CMD ["npm", "start"]
