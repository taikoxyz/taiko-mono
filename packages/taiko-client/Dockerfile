ARG TARGETOS
ARG TARGETARCH
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder

RUN apk update && apk add --no-cache --update gcc musl-dev linux-headers git make build-base

WORKDIR /build

COPY go.mod go.sum ./

COPY packages/taiko-client/ packages/taiko-client/

WORKDIR /build/packages/taiko-client
RUN echo "TARGETOS=$TARGETOS, TARGETARCH=$TARGETARCH" && \
    if [ $TARGETARCH == 'amd64' ]; then \
      GOOS=$TARGETOS GOARCH=$TARGETARCH make build; \
    elif [ $TARGETARCH == 'arm64' ]; then \
      GOOS=$TARGETOS GOARCH=$TARGETARCH make build; \
    else \
      echo "Unsupported architecture, ${TARGETOS}/${TARGETARCH}"; \
    fi

FROM alpine:latest

RUN apk add --no-cache ca-certificates libstdc++

COPY --from=builder /build/packages/taiko-client/bin/taiko-client /usr/local/bin/

EXPOSE 6060

ENTRYPOINT ["taiko-client"]
