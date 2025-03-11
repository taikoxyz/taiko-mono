ARG PACKAGE=eventindexer

FROM golang:1.23.5 AS builder

ARG PACKAGE

RUN apt install git curl

RUN mkdir /taiko-mono

WORKDIR /taiko-mono

COPY . .

RUN go mod download

WORKDIR /taiko-mono/packages/${PACKAGE}

RUN CGO_ENABLED=0 GOOS=linux go build -o /taiko-mono/packages/${PACKAGE}/bin/${PACKAGE} /taiko-mono/packages/${PACKAGE}/cmd/main.go

FROM alpine:latest

ARG PACKAGE
ENV PACKAGE=${PACKAGE}

RUN apk add --no-cache ca-certificates

COPY --from=builder /taiko-mono/packages/${PACKAGE}/bin/${PACKAGE} /usr/local/bin/

ENTRYPOINT /usr/local/bin/${PACKAGE}
