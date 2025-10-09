# ---------- builder ----------
FROM rust:1.88-slim-bookworm AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy ejector package files (build context is packages/ejector)
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY bin ./bin

# Build the ejector binary
RUN cargo build --release --bin ejector

FROM debian:bookworm-slim AS runtime
RUN useradd -m -u 10001 appuser && \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates tzdata libssl3 && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /app/target/release/ejector /usr/local/bin/ejector
USER appuser
ENV RUST_LOG=info
ENTRYPOINT ["ejector"]
