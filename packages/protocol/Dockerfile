# syntax=docker/dockerfile:1.6

FROM node:22-slim AS builder

ARG BUILDKIT_INLINE_CACHE=1

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    git \
    curl \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install Foundry
RUN curl -L https://foundry.paradigm.xyz | bash

ENV PATH="/root/.foundry/bin:$PATH"

# Install Foundry version
RUN foundryup -i 1.2.3

# Copy package files first for better layer caching
COPY package.json pnpm-lock.yaml* ./

# Install pnpm and dependencies
# Use --frozen-lockfile only if lockfile exists, otherwise install normally
RUN npm install -g pnpm@latest && \
    if [ -f pnpm-lock.yaml ]; then \
      pnpm install --frozen-lockfile; \
    else \
      pnpm install; \
    fi

# Copy source code
COPY . .

# Initialize git repository for forge install (required by Foundry)
# forge install uses git to manage dependencies as submodules
RUN git init

# Install Foundry dependencies
RUN forge install

# Make scripts executable
RUN find /app/script -type f -name "*.sh" -exec chmod +x {} \;

FROM node:22-slim AS runtime

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    git \
    curl \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install Foundry
RUN curl -L https://foundry.paradigm.xyz | bash

ENV PATH="/root/.foundry/bin:$PATH"

# Install Foundry version
RUN foundryup -i 1.2.3

# Copy everything from builder
COPY --from=builder /app ./

# Install pnpm
RUN npm install -g pnpm@latest

CMD ["sh", "-c", "echo Please verify the environment variables and command."]