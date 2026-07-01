# ---------- builder ----------
FROM rust:1.88-slim-bookworm AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy package files (build context is packages/rollup-monitor)
COPY Cargo.toml Cargo.lock ./
COPY src ./src
COPY bin ./bin

# Build the rollup-monitor binary
RUN cargo build --release --bin rollup-monitor

FROM debian:bookworm-slim AS runtime
RUN useradd -m -u 10001 appuser && \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates tzdata libssl3 curl && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /app/target/release/rollup-monitor /usr/local/bin/rollup-monitor
USER appuser
ARG RUST_LOG=info
ENV RUST_LOG=${RUST_LOG}
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8080/healthz || exit 1
ENTRYPOINT ["rollup-monitor"]
