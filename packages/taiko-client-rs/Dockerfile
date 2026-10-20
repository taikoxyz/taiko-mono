FROM golang:1.27.2@sha256:820153096fda4de6ac1b7194d12e416b7dd8f4e9a33d17e0345b111b945162d8 AS signer-build
WORKDIR /signer
COPY packages/taiko-client-rs/tools/etna-signer/go.mod packages/taiko-client-rs/tools/etna-signer/go.sum ./
RUN go mod download
COPY packages/taiko-client-rs/tools/etna-signer/*.go ./
RUN CGO_ENABLED=0 go build -mod=readonly -trimpath -buildvcs=false -ldflags="-s -w -buildid=" -o /etna-signer .

FROM rust:1.95.0 AS build

WORKDIR /app

RUN apt-get update && \
  apt-get -y upgrade && \
  apt-get install -y git libclang-dev pkg-config curl build-essential && \
  rm -rf /var/lib/apt/lists/*

COPY packages/taiko-client-rs packages/taiko-client-rs

WORKDIR /app/packages/taiko-client-rs

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/app/packages/taiko-client-rs/target \
    cargo build --release --locked && \
    cp /app/packages/taiko-client-rs/target/release/taiko-client /tmp/taiko-client

FROM ubuntu:24.04

RUN apt-get update && \
  apt-get install -y jq curl && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /tmp/taiko-client ./taiko-client
COPY --from=signer-build /etna-signer ./etna-signer

ENTRYPOINT ["./taiko-client"]
