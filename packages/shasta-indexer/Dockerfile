# Build stage
FROM rust:1.81-slim AS builder

# Install dependencies for building
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy manifests
COPY Cargo.toml Cargo.lock ./

# Build dependencies - this is the caching layer
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# Copy source code
COPY src ./src
COPY rindexer.yaml ./

# Build application
RUN touch src/main.rs && \
    cargo build --release

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash indexer

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/target/release/shasta_indexer /usr/local/bin/shasta_indexer
COPY --from=builder /app/rindexer.yaml ./

# Change ownership
RUN chown -R indexer:indexer /app

USER indexer

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD pgrep shasta_indexer || exit 1

# Run the binary
ENTRYPOINT ["shasta_indexer"]
CMD ["start", "all"]