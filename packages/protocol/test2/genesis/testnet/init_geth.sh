#!/bin/sh

set -e

rm -rf /root/.ethereum

geth init --datadir /root/.ethereum /data/genesis.json

geth --datadir /root/.ethereum \
  --nodiscover \
  --allow-insecure-unlock \
  --exec 'personal.importRawKey("'2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501200'", null)' console

geth --datadir /root/.ethereum \
  --nodiscover \
  --http \
  --http.addr 0.0.0.0 \
  --http.api debug,eth,net,web3,txpool,miner \
  --allow-insecure-unlock \
  --password /dev/null \
  --unlock 0xdf08f82de32b8d460adbe8d72043e3a7e25a3b39 \
  --mine
