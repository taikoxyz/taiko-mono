FROM --platform=$BUILDPLATFORM golang:1.21-alpine as builder
ARG TARGETOS
ARG TARGETARCH

RUN apk update && apk add --no-cache --update gcc musl-dev linux-headers git make build-base

WORKDIR /build

COPY go.mod go.sum ./

COPY packages/taiko-client/ packages/taiko-client/

WORKDIR /build/packages/taiko-client

RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} make build

FROM alpine:latest

RUN apk add --no-cache ca-certificates libstdc++

COPY --from=builder /build/packages/taiko-client/bin/taiko-client /usr/local/bin/

EXPOSE 6060

ENTRYPOINT ["taiko-client"]
