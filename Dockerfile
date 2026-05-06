ARG PACKAGE=eventindexer

FROM golang:1.26.0@sha256:fb612b7831d53a89cbc0aaa7855b69ad7b0caf603715860cf538df854d047b84 AS builder

ARG PACKAGE

RUN apt install git curl

RUN mkdir /taiko-mono

WORKDIR /taiko-mono

COPY . .

RUN go mod download

WORKDIR /taiko-mono/packages/${PACKAGE}

RUN CGO_ENABLED=0 GOOS=linux go build -o /taiko-mono/packages/${PACKAGE}/bin/${PACKAGE} /taiko-mono/packages/${PACKAGE}/cmd/main.go

FROM alpine:latest@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11

ARG PACKAGE
ENV PACKAGE=${PACKAGE}

RUN apk add --no-cache ca-certificates

COPY --from=builder /taiko-mono/packages/${PACKAGE}/bin/${PACKAGE} /usr/local/bin/

ENTRYPOINT /usr/local/bin/${PACKAGE}
