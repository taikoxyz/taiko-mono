# geth-rpc-gateway

```sh
go build -o geth-rpc-gateway .
```

Build for Linux

```sh
GOOS=linux GOARCH=amd64 go build -o geth-rpc-gateway .
```

## How to test

### Example code

```
curl --location --request POST 'https://rpc.internal.taiko.xyz/' \
--header 'Content-Type: application/json' \
--data-raw '{
    "jsonrpc": "2.0",
    "id": 4,
    "method": "eth_blockNumber",
    "params": [
    ]
}'
```

```
'use strict'
const { ethers } = require('ethers');

// const provider = new ethers.providers.JsonRpcProvider("https://l1rpc.mainnet.taiko.xyz");

const provider = new ethers.providers.WebSocketProvider("wss://ws.internal.taiko.xyz");

async function main() {
  console.log(await provider.getBlock("latest"));
  process.exit(0);
}

main().catch(console.error);
```

```
curl -i -X POST \
   -H "Content-Type:application/json" \
   -d \
'[
  {"id":92471,"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0x832ef3260c46288e9596d0ddb61c4c9d5965f7da8d076483d08ac2d4265a69b8"]},
  {"id":91112,"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0xbaac413b4cbf6a2f19ef3da2f103f8298042cbba2820fba020a322f9602f8e58"]},
  {"id":48734,"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0x7c649da4df9bea4552c05d4710a1ffb16fed5be81c11912aceb568a8212213d6"]},
  {"id":45180,"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0xb23f58cb6b5155f792fa96c63962c44efba5280a4eed76400eca477e04c7456c"]},
  {"id":95408,"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0xab7e06e9666ba0c270fe06e45fe604316049232c4479f975db0a0ec16b4f9b38"]},
  {"id":193,"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0xd453488f5e14cfb3ac1057e42c1e3eb74420759fe0331894c59f3108e1c813b0"]}
]' \
 'https://rpc.hekla.taiko.xyz/'
```

```
curl -i -X POST \
   -H "Content-Type:application/json" \
   -d \
'[
  {"id":92471,"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0x832ef3260c46288e9596d0ddb61c4c9d5965f7da8d076483d08ac2d4265a69b8"]},
  {"id":91112,"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0xbaac413b4cbf6a2f19ef3da2f103f8298042cbba2820fba020a322f9602f8e58"]},
  {"id":48734,"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0x7c649da4df9bea4552c05d4710a1ffb16fed5be81c11912aceb568a8212213d6"]},
  {"id":45180,"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0xb23f58cb6b5155f792fa96c63962c44efba5280a4eed76400eca477e04c7456c"]},
  {"id":95408,"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0xab7e06e9666ba0c270fe06e45fe604316049232c4479f975db0a0ec16b4f9b38"]},
  {"id":193,"jsonrpc":"2.0","method":"eth_getTransactionReceipt","params":["0xd453488f5e14cfb3ac1057e42c1e3eb74420759fe0331894c59f3108e1c813b0"]}
]' \
 'http://localhost:8080'
```
