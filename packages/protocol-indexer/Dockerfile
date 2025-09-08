# Build stage
# Use Rust 1.89+ which supports edition2024 feature required by alloy-chains
FROM rust:1.89-bookworm AS builder

# Install dependencies including Node.js (required by rindexer build)
RUN apt-get update && apt-get install -y \
    git \
    pkg-config \
    libssl-dev \
    curl \
    && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy only Cargo files first for better caching
COPY packages/protocol-indexer/Cargo.toml packages/protocol-indexer/Cargo.lock ./

# Create dummy main.rs to build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# Copy the actual source code and build
COPY packages/protocol-indexer/src ./src
COPY packages/protocol-indexer/abis ./abis
RUN touch src/main.rs && cargo build --release

# Runtime stage
FROM ubuntu:22.04

# Install runtime dependencies including PostgreSQL client
RUN apt-get update && apt-get install -y \
    ca-certificates \
    postgresql-client \
    lsof \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy binary and configs
COPY --from=builder /app/target/release/protocol_indexer /usr/local/bin/
COPY packages/protocol-indexer/rindexer.yaml ./
COPY packages/protocol-indexer/abis ./abis
COPY packages/protocol-indexer/migrations ./migrations
COPY packages/protocol-indexer/docker-entrypoint.sh /usr/local/bin/

# Make entrypoint executable
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["--indexer", "--graphql"]
