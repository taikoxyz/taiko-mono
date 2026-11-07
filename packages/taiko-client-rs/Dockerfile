ARG ALETHIA_RETH_IMAGE=execution-source

FROM rust:1.99.0-bookworm AS execution-build
RUN apt-get update && apt-get install -y git libclang-dev pkg-config build-essential && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /execution
RUN git init . && git remote add origin https://github.com/taikoxyz/alethia-reth.git && \
    git fetch --depth=1 origin 20a9282a24b14567ebad82c427f8ceeeaf40aab4 && \
    git checkout --detach FETCH_HEAD && \
    test "$(git rev-parse HEAD)" = 20a9282a24b14567ebad82c427f8ceeeaf40aab4
ARG CARGO_BUILD_JOBS=2
ARG TARGETARCH
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,id=etna-execution-bookworm-${TARGETARCH},target=/execution/target \
    CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" cargo build --release --locked -p alethia-reth-bin && \
    cp target/release/alethia-reth /alethia-reth

FROM debian:bookworm-slim AS execution-source
RUN apt-get update && apt-get install -y jq curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=execution-build /alethia-reth ./alethia-reth

FROM ${ALETHIA_RETH_IMAGE} AS execution-runtime

# The official v0.40.0 arm64 image contains an amd64 Comet executable.
# Build its exact unmodified stock source for the declared target instead.
FROM golang:1.27.2@sha256:820153096fda4de6ac1b7194d12e416b7dd8f4e9a33d17e0345b111b945162d8 AS comet
ARG TARGETPLATFORM
ARG TARGETARCH
WORKDIR /cometbft
RUN test "$TARGETPLATFORM" = "linux/$TARGETARCH" && \
    case "$TARGETARCH" in amd64|arm64) ;; *) exit 1 ;; esac && \
    git init . && \
    git remote add origin https://github.com/cometbft/cometbft.git && \
    git fetch --depth=1 origin 0880b4d378f347ab16e54ec677ff50d803f37d62 && \
    git checkout --detach FETCH_HEAD && \
    test "$(git rev-parse HEAD)" = 0880b4d378f347ab16e54ec677ff50d803f37d62 && \
    test -z "$(git status --porcelain)" && \
    TARGETPLATFORM="$TARGETPLATFORM" GOOS=linux GOARCH="$TARGETARCH" CGO_ENABLED=0 make build-linux && \
    test -z "$(git status --porcelain)"

FROM golang:1.27.2@sha256:820153096fda4de6ac1b7194d12e416b7dd8f4e9a33d17e0345b111b945162d8 AS signer-build
WORKDIR /signer
COPY packages/taiko-client-rs/tools/etna-signer/go.mod packages/taiko-client-rs/tools/etna-signer/go.sum ./
RUN go mod download
COPY packages/taiko-client-rs/tools/etna-signer/*.go ./
COPY packages/taiko-client-rs/tools/etna-signer/cmd ./cmd
COPY packages/taiko-client-rs/tools/etna-signer/internal ./internal
RUN CGO_ENABLED=0 go build -mod=readonly -trimpath -buildvcs=false -ldflags="-s -w -buildid=" -o /etna-signer . && \
    CGO_ENABLED=0 go build -mod=readonly -trimpath -buildvcs=false -ldflags="-s -w -buildid=" -o /etna-comet-inspect ./cmd/etna-comet-inspect && \
    CGO_ENABLED=0 go build -mod=readonly -trimpath -buildvcs=false -ldflags="-s -w -buildid=" -o /etna-comet-import ./cmd/etna-comet-import

FROM rust:1.99.0-bookworm AS build

WORKDIR /app

RUN apt-get update && \
  apt-get -y upgrade && \
  apt-get install -y git libclang-dev pkg-config curl build-essential && \
  rm -rf /var/lib/apt/lists/*

COPY packages/taiko-client-rs packages/taiko-client-rs

WORKDIR /app/packages/taiko-client-rs

ARG CARGO_BUILD_JOBS=2
# Native archives depend on the build image's libc/C++ ABI as well as the architecture.
ARG TARGETARCH
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,id=taiko-client-rs-bookworm-${TARGETARCH},target=/app/packages/taiko-client-rs/target \
    CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" cargo build --release --locked && \
    cp /app/packages/taiko-client-rs/target/release/taiko-client /tmp/taiko-client && \
    CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" cargo build --release --locked --manifest-path tools/etna-el-import/Cargo.toml --target-dir /app/packages/taiko-client-rs/target --bin etna-el-import && \
    cp /app/packages/taiko-client-rs/target/release/etna-el-import /tmp/etna-el-import

FROM ubuntu:24.04 AS runtime-tools

RUN apt-get update && \
  apt-get install -y jq curl python3 libstdc++6 && \
  rm -rf /var/lib/apt/lists/* && \
  groupadd --gid 10001 etna-comet && \
  useradd --uid 10001 --gid 10001 --no-create-home etna-comet

WORKDIR /app

COPY --from=signer-build /etna-signer ./etna-signer
COPY --from=signer-build /etna-comet-inspect ./etna-comet-inspect
COPY --from=signer-build /etna-comet-import ./etna-comet-import
COPY --from=execution-runtime /app/alethia-reth ./alethia-reth
COPY --from=build /tmp/etna-el-import ./etna-el-import

COPY --from=comet /cometbft/build/cometbft /usr/bin/cometbft
COPY packages/taiko-client-rs/script/etna_validator.py /app/script/etna_validator.py
COPY packages/taiko-client-rs/script/etna_import_guard.py /app/script/etna_import_guard.py
COPY packages/taiko-client-rs/script/start_etna_validator.sh /app/script/start_etna_validator.sh
COPY packages/taiko-client-rs/script/start_etna_full_node.py /app/script/start_etna_full_node.py
ENV ETNA_SIGNER_BIN=/app/etna-signer ETNA_EL_IMPORT_BIN=/app/etna-el-import ETNA_EL_BIN=/app/alethia-reth ETNA_COMET_UID=10001 ETNA_COMET_GID=10001

FROM runtime-tools
COPY --from=build /tmp/taiko-client ./taiko-client
ENTRYPOINT ["./taiko-client"]
