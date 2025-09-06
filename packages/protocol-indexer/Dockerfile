# Build stage
FROM rust:1.81 AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy everything and build
COPY . .
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
COPY rindexer.yaml ./
COPY abis ./abis
COPY migrations ./migrations

ENTRYPOINT ["protocol_indexer"]
