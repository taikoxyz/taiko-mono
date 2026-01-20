# syntax=docker/dockerfile:1.6

FROM golang:1.24-alpine AS builder

ARG BUILDKIT_INLINE_CACHE=1

# Install build dependencies
RUN apk add --no-cache --update \
    gcc \
    musl-dev \
    linux-headers \
    git \
    make \
    build-base

WORKDIR /build

# Copy go mod files first for better layer caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY packages/taiko-client/ ./packages/taiko-client/

WORKDIR /build/packages/taiko-client

# Build the application
RUN make build

FROM alpine:latest AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    libstdc++ && \
    addgroup -g 10001 -S appuser && \
    adduser -u 10001 -S appuser -G appuser

WORKDIR /app

# Copy binary from builder
COPY --from=builder --chown=appuser:appuser /build/packages/taiko-client/bin/taiko-client /usr/local/bin/taiko-client

USER appuser

# Expose port
EXPOSE 6060

# Health check (checks if process is running)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD pgrep -f taiko-client > /dev/null || exit 1

ENTRYPOINT ["taiko-client"]
