#!/bin/sh

mkdir -p bin && cd bin

SOLC_FILE_NAME=solc-static-linux

if [ "$(uname)" == 'Darwin' ]; then
  SOLC_FILE_NAME=solc-macos
fi

wget -O solc https://github.com/ethereum/solidity/releases/download/v0.8.9/$SOLC_FILE_NAME

chmod +x solc
