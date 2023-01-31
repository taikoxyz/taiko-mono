#!/bin/sh

set -e

mkdir -p bin && cd bin

if [ -f "solc" ]; then
  exit 0
fi

VERSION=v0.8.9

if [ "$(uname)" = 'Darwin' ]; then
  SOLC_FILE_NAME=solc-macos
elif [ "$(uname)" = 'Linux' ]; then
  SOLC_FILE_NAME=solc-static-linux
else
  echo "unsupported platform $(uname)"
  exit 1
fi

wget -O solc https://github.com/ethereum/solidity/releases/download/$VERSION/$SOLC_FILE_NAME

chmod +x solc
