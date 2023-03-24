FROM golang:1.19.3 as builder

RUN apt install git curl

COPY . .

WORKDIR /taiko-mono/packages/relayer

RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux go build -o ./bin/relayer cmd/main.go

FROM alpine:latest

RUN apk add --no-cache ca-certificates

COPY --from=builder /taiko-mono/packages/relayer/bin/relayer /usr/local/bin/

ENTRYPOINT ["relayer"]