# ---------- builder ----------
FROM rust:1.88-slim-bookworm AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev ca-certificates && \
    rm -rf /var/lib/apt/lists/*
COPY Cargo.toml Cargo.lock ./
COPY packages ./packages
RUN cargo build -p ejector --release

# Use the repo root as build context so we can copy the workspace files:
# (This lets cargo resolve all path deps and workspace members.)
COPY Cargo.toml Cargo.lock ./
COPY packages ./packages

# Build just this crate
RUN cargo build -p ejector --release

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
