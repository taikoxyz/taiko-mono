FROM rust:1.88 AS build

WORKDIR /app

RUN apt-get update && \
  apt-get -y upgrade && \
  apt-get install -y git libclang-dev pkg-config curl build-essential && \
  rm -rf /var/lib/apt/lists/*

COPY packages/taiko-client-rs packages/taiko-client-rs
COPY packages/preconfirmation-p2p packages/preconfirmation-p2p

WORKDIR /app/packages/taiko-client-rs

RUN cargo build --release

FROM ubuntu:22.04

RUN apt-get update && \
  apt-get install -y jq curl && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /app/packages/taiko-client-rs/target/release/taiko-client ./

ENTRYPOINT ["./taiko-client"]
