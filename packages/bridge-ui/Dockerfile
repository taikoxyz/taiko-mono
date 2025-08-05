# Step 1: Build the application
FROM node:20 AS builder

RUN npm install -g pnpm

WORKDIR /app

# Install dependencies
COPY package.json ./

# Copy the app source code and build
COPY . .

RUN cp .env.example .env
RUN pnpm export:config

# Install dependencies without the lock file, generating a new one
RUN pnpm install

RUN pnpm build

# Step 2: Set up the final production environment
FROM node:20

# Install pnpm globally
RUN npm install -g pnpm

WORKDIR /app

# Copy only necessary build files
COPY --from=builder /app/package.json ./
COPY --from=builder /app/pnpm-lock.yaml ./
RUN pnpm install --prod

# Copy the build output
COPY --from=builder /app/build ./build

# Expose port
EXPOSE 3000

# Start the SvelteKit app
CMD ["node", "build"]
