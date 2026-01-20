# syntax=docker/dockerfile:1.6

FROM golang:1.24-alpine AS builder

ARG PACKAGE=relayer
ARG BUILDKIT_INLINE_CACHE=1

# Install build dependencies
RUN apk add --no-cache git make

WORKDIR /build

# Copy go mod files first for better layer caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY packages/${PACKAGE} ./packages/${PACKAGE}

# Build the application
WORKDIR /build/packages/${PACKAGE}

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -trimpath \
    -o /build/bin/${PACKAGE} \
    ./cmd/main.go

FROM alpine:latest AS runtime

ARG PACKAGE=relayer

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata && \
    addgroup -g 10001 -S appuser && \
    adduser -u 10001 -S appuser -G appuser

WORKDIR /app

# Copy binary from builder
COPY --from=builder --chown=appuser:appuser /build/bin/${PACKAGE} /usr/local/bin/${PACKAGE}

USER appuser

ENTRYPOINT ["/usr/local/bin/${PACKAGE}"]
