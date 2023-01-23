#!/bin/sh

set -e

mkdir -p bin && cd bin

if [ -f "solc" ]; then
    exit 0
fi

SOLC_FILE_NAME=solc-static-linux
VERSION=v0.8.9

if [ "$(uname)" == 'Darwin' ]; then
  SOLC_FILE_NAME=solc-macos
fi

wget -O solc https://github.com/ethereum/solidity/releases/download/$VERSION/$SOLC_FILE_NAME

chmod +x solc
