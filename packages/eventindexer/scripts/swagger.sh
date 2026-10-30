#!/bin/sh
set -eu

go run github.com/swaggo/swag/cmd/swag init -g server.go -d pkg/http --parseDependency
