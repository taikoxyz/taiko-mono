# builder image
FROM golang:1.19.3 as builder

RUN apt install git curl

ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.9.0/wait /wait
RUN chmod +x /wait

WORKDIR /taiko-mono/packages/relayer

COPY . .

RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux go build -o ./bin/relayer cmd/main.go

FROM alpine:latest

RUN apk add --no-cache ca-certificates

COPY --from=builder /taiko-mono/packages/relayer/bin/relayer /usr/local/bin/

ENTRYPOINT ["relayer"]