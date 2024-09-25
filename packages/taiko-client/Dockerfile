FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder
ARG TARGETOS
ARG TARGETARCH

RUN apk update && apk add --no-cache --update gcc musl-dev linux-headers git make build-base

WORKDIR /build

COPY go.mod go.sum ./

COPY packages/taiko-client/ packages/taiko-client/

WORKDIR /build/packages/taiko-client
RUN if [ "$TARGETARCH" == "amd64" ]; then \
      echo "amd64: TARGETOS=${TARGETOS}, TARGETARCH=${TARGETARCH}"; \
      GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" \
      echo "amd64: GOOS=${GOOS}, GOARCH=${TARGETARCH}"; \
      GOOS=linux GOARCH=amd64 make build; \
    else \
      echo "arm64: TARGETOS=${TARGETOS}, TARGETARCH=${TARGETARCH}"; \
      GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" \
      echo "arm64: GOOS=${GOOS}, GOARCH=${TARGETARCH}"; \
      GOOS=linux GOARCH=arm64 make build; \
    fi

#FROM alpine:latest

#RUN apk add --no-cache ca-certificates libstdc++

#COPY --from=builder /build/packages/taiko-client/bin/taiko-client /usr/local/bin/

#EXPOSE 6060

#ENTRYPOINT ["taiko-client"]
