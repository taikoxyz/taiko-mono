FROM rust:1.93.1@sha256:ecbe59a8408895edd02d9ef422504b8501dd9fa1526de27a45b73406d734d659 AS build

WORKDIR /app

RUN apt-get update && \
  apt-get -y upgrade && \
  apt-get install -y git libclang-dev pkg-config curl build-essential && \
  rm -rf /var/lib/apt/lists/*

COPY packages/taiko-client-rs packages/taiko-client-rs
COPY packages/preconfirmation-p2p packages/preconfirmation-p2p

WORKDIR /app/packages/taiko-client-rs

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/app/packages/taiko-client-rs/target \
    cargo build --release --locked && \
    cp /app/packages/taiko-client-rs/target/release/taiko-client /tmp/taiko-client

FROM ubuntu:24.04@sha256:c4a8d5503dfb2a3eb8ab5f807da5bc69a85730fb49b5cfca2330194ebcc41c7b

RUN apt-get update && \
  apt-get install -y --no-install-recommends jq curl ca-certificates && \
  groupadd --system --gid 10001 taiko && \
  useradd --system --uid 10001 --gid taiko --home-dir /nonexistent --shell /usr/sbin/nologin --no-create-home taiko && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build --chown=taiko:taiko /tmp/taiko-client ./taiko-client

USER taiko:taiko

ENTRYPOINT ["./taiko-client"]
