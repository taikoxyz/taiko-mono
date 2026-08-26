#!/bin/sh

set -e

rm -rf /root/.ethereum

geth init --datadir /root/.ethereum /data/genesis.json

geth --datadir /root/.ethereum \
  --nodiscover \
  --http \
  --http.addr 0.0.0.0 \
  --http.api debug,eth,net,web3
