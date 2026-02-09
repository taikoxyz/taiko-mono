# syntax=docker/dockerfile:1.6

## Build stage: compile the overseer binary
FROM rust:1.90-slim AS builder

WORKDIR /app

# Install build dependencies (pkg-config, openssl headers not needed due to rustls) but maybe not necessary.
# Copy manifests first for caching dependencies.
COPY Cargo.toml Cargo.lock ./
COPY src ./src

# Build the binary in release mode
RUN cargo build --release

## Runtime stage: minimal image with the compiled binary
FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/overseer-rs /usr/local/bin/overseer

# Default command runs the monitor; CLI flags supplied at runtime.
ENTRYPOINT ["/usr/local/bin/overseer"]
