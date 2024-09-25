FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder
ARG TARGETOS
ARG TARGETARCH

RUN apk update && apk add --no-cache --update gcc musl-dev linux-headers git make build-base

WORKDIR /build

COPY go.mod go.sum ./

COPY packages/taiko-client/ packages/taiko-client/

WORKDIR /build/packages/taiko-client
RUN if [ "$TARGETARCH" == "amd64" ]; then \
      echo "amd64: TARGETOS=${TARGETOS}, TARGETARCH=${TARGETARCH}"; \
    else \
      echo "arm64: TARGETOS=${TARGETOS}, TARGETARCH=${TARGETARCH}"; \
    fi

#FROM alpine:latest

#RUN apk add --no-cache ca-certificates libstdc++

#COPY --from=builder /build/packages/taiko-client/bin/taiko-client /usr/local/bin/

#EXPOSE 6060

#ENTRYPOINT ["taiko-client"]
