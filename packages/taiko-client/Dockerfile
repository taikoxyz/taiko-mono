FROM golang:1.26-alpine@sha256:f85330846cde1e57ca9ec309382da3b8e6ae3ab943d2739500e08c86393a21b1 AS builder

RUN apk update && apk add --no-cache --update gcc musl-dev linux-headers git make build-base

WORKDIR /build

COPY go.mod go.sum ./

COPY packages/taiko-client/ packages/taiko-client/

WORKDIR /build/packages/taiko-client

RUN make build

FROM alpine:latest@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11

RUN apk add --no-cache ca-certificates libstdc++ && \
  addgroup -S -g 10001 taiko && \
  adduser -S -D -H -u 10001 -G taiko -h /nonexistent -s /sbin/nologin taiko

COPY --from=builder /build/packages/taiko-client/bin/taiko-client /usr/local/bin/

EXPOSE 6060

USER taiko:taiko

ENTRYPOINT ["taiko-client"]
