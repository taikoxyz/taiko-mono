FROM --platform=$BUILDPLATFORM golang:1.21 AS builder
ARG TARGETOS
ARG TARGETARCH

RUN apt-get update && apt-get install -y git make g++-x86-64-linux-gnu libc6-dev-amd64-cross

WORKDIR /build

COPY go.mod go.sum ./

COPY packages/taiko-client/ packages/taiko-client/

WORKDIR /build/packages/taiko-client
RUN echo "TARGETOS=${TARGETOS}, TARGETARCH=${TARGETARCH}" && \
    if [ "$TARGETARCH" = "amd64" ]; then \
      CGO_ENABLED=1 CC=x86_64-linux-gnu-gcc GOOS=${TARGETOS} GOARCH=${TARGETARCH} make build; \
    else \
      make build; \
    fi

FROM alpine:latest

RUN apk add --no-cache ca-certificates libstdc++

COPY --from=builder /build/packages/taiko-client/bin/taiko-client /usr/local/bin/

EXPOSE 6060

ENTRYPOINT ["taiko-client"]
