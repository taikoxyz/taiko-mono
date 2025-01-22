#!/bin/sh

set -e

rm -rf /root/.ethereum

geth init --datadir /root/.ethereum /data/genesis.json

cp /host/keyfile.json /root/.ethereum/keystore

geth --datadir /root/.ethereum \
  --nodiscover \
  --http \
  --http.addr 0.0.0.0 \
  --http.api debug,eth,net,web3,txpool,miner \
  --allow-insecure-unlock \
  --password /host/password \
  --miner.etherbase 0xdf08f82de32b8d460adbe8d72043e3a7e25a3b39 \
  --unlock 0xdf08f82de32b8d460adbe8d72043e3a7e25a3b39 \
  --mine
