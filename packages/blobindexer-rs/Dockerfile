# syntax=docker/dockerfile:1.6

FROM rust:1.90-slim-bookworm AS builder
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy manifest files first to leverage Docker layer caching
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY bin ./bin
COPY migrations ./migrations

RUN cargo build --release --bin blobindexer

FROM debian:bookworm-slim AS runtime
RUN useradd -m -u 10001 appuser && \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates tzdata && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/target/release/blobindexer /usr/local/bin/blobindexer
COPY --from=builder /app/migrations ./migrations

USER appuser
ENV RUST_LOG=info
ENTRYPOINT ["blobindexer"]
