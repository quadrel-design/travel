# Use Node.js latest LTS version
FROM node:18-slim

# Create app directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY . .

# Set environment variables
ENV NODE_ENV=production
ENV PORT=8080

# Expose the port
EXPOSE 8080

# Set the Google Cloud Project ID
ENV GOOGLE_CLOUD_PROJECT=splitbase-7ec0f

# Start the server
CMD ["node", "index.js"] 