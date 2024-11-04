FROM golang:1.21-alpine as builder

RUN apk update && apk add --no-cache --update gcc musl-dev linux-headers git make build-base

WORKDIR /build

COPY go.mod go.sum ./

COPY packages/relayer/ packages/relayer/

WORKDIR /build/packages/relayer

RUN CGO_CFLAGS="-O -D__BLST_PORTABLE__" CGO_CFLAGS_ALLOW="-O -D__BLST_PORTABLE__" go build -o bin/relayer cmd/main.go

FROM alpine:latest

RUN apk add --no-cache ca-certificates libstdc++

COPY --from=builder /build/packages/relayer/bin/relayer /usr/local/bin/

EXPOSE 6060

WORKDIR /usr/local/bin

ENTRYPOINT ["relayer"]
