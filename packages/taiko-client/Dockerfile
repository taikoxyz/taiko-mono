ARG BUILDPLATFORM=linux/amd64
FROM --platform=${BUILDPLATFORM} golang:1.21-alpine as builder

RUN apk update && apk add --no-cache --update gcc musl-dev linux-headers git make build-base

WORKDIR /taiko-client

COPY . .

RUN cd /taiko-client && \
  go mod init github.com/taikoxyz/taiko-mono && \
  go mod tidy

ARG TARGETOS
ARG TARGETARCH
RUN cd /taiko-client && GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    make build

FROM alpine:latest

RUN apk add --no-cache ca-certificates libstdc++

COPY --from=builder /taiko-client/bin/taiko-client /usr/local/bin/

EXPOSE 6060

ENTRYPOINT ["taiko-client"]
