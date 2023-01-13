#!/bin/sh

mkdir -p bin
cd bin
wget https://github.com/ethereum/solidity/releases/download/v0.8.17/solc-static-linux
chmod +x solc-static-linux