# ---------- builder ----------
FROM rust:1.88-slim-bookworm AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy package files (build context is packages/reorg-monitor)
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY bin ./bin

# Build the reorg-monitor binary
RUN cargo build --release --bin reorg-monitor

FROM debian:bookworm-slim AS runtime
RUN useradd -m -u 10001 appuser && \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates tzdata libssl3 && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /app/target/release/reorg-monitor /usr/local/bin/reorg-monitor
USER appuser
ARG RUST_LOG=info
ENV RUST_LOG=${RUST_LOG}
ENTRYPOINT ["reorg-monitor"]
