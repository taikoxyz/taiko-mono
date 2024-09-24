FROM --platform=$BUILDPLATFORM golang:1.21 AS builder
ARG TARGETOS
ARG TARGETARCH

RUN apt-get update && apt-get install -y git make g++-x86-64-linux-gnu libc6-dev-amd64-cross
#RUN apk update && apk add --no-cache --update gcc musl-dev linux-headers git make build-base

WORKDIR /build

COPY go.mod go.sum ./

COPY packages/taiko-client/ packages/taiko-client/

WORKDIR /build/packages/taiko-client

#RUN CGO_ENABLED=1 CC=x86_64-linux-gnu-gcc GOOS=${TARGETOS} GOARCH=${TARGETARCH} make build
echo "Building for ${TARGETOS}/${TARGETARCH}"
RUN CGO_ENABLED=1 GOOS=${TARGETOS} GOARCH=${TARGETARCH} make build


FROM alpine:latest

RUN apk add --no-cache ca-certificates libstdc++

COPY --from=builder /build/packages/taiko-client/bin/taiko-client /usr/local/bin/

EXPOSE 6060

ENTRYPOINT ["taiko-client"]
