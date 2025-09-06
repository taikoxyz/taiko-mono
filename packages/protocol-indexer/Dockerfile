# Build stage
FROM rust:1.83-bookworm AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the protocol-indexer package files
COPY packages/protocol-indexer/ .
RUN cargo build --release

# Runtime stage
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy binary and configs
COPY --from=builder /app/target/release/protocol_indexer /usr/local/bin/
COPY packages/protocol-indexer/rindexer.yaml ./
COPY packages/protocol-indexer/abis ./abis
COPY packages/protocol-indexer/migrations ./migrations

ENTRYPOINT ["protocol_indexer"]
