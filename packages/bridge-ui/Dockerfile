# syntax=docker/dockerfile:1.6

# Step 1: Build the application
FROM node:20-slim AS builder

ARG BUILDKIT_INLINE_CACHE=1

# Install pnpm
RUN npm install -g pnpm@latest

WORKDIR /app

# Copy all files (Docker will preserve node_modules if we install after)
COPY . .

# Install dependencies (will use existing node_modules if present, or create new)
RUN pnpm install

# Install adapter-node for Docker builds (Vercel adapter outputs to different directory)
RUN pnpm add -D @sveltejs/adapter-node@latest

# Temporarily replace adapter in svelte.config.js for Docker build
RUN sed -i "s/@sveltejs\/adapter-vercel/@sveltejs\/adapter-node/g" svelte.config.js && \
    sed -i 's/adapter-vercel/adapter-node/g' svelte.config.js && \
    sed -i 's/runtime: .nodejs20.x./isr: false/g' svelte.config.js

# Copy and export config, then build
# For Docker builds, skip env validation if config files don't exist
# Config can be provided at runtime via environment variables
RUN cp .env.example .env && \
    (pnpm export:config || true) && \
    SKIP_ENV_VALIDATION=true pnpm build

# Step 2: Set up the final production environment
FROM node:20-slim AS runtime

# Install pnpm globally
RUN npm install -g pnpm@latest && \
    npm cache clean --force

WORKDIR /app

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy only necessary files for production
COPY --from=builder --chown=appuser:appuser /app/package.json ./
COPY --from=builder --chown=appuser:appuser /app/pnpm-lock.yaml ./

# Install production dependencies only
RUN pnpm install --prod && \
    pnpm store prune && \
    npm cache clean --force

# Copy the build output
COPY --from=builder --chown=appuser:appuser /app/build ./build

USER appuser

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the SvelteKit app
CMD ["node", "build"]
