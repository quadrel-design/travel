# Use Node.js LTS version
FROM node:18-slim

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
COPY package*.json ./
RUN npm install

# Bundle app source
COPY . .

# Expose the port your app runs on
EXPOSE 8080

# Set the Google Cloud Project ID
ENV GOOGLE_CLOUD_PROJECT=splitbase-7ec0f

# Start the app
CMD [ "node", "index.js" ]

COPY service-account.json /usr/src/app/service-account.json 