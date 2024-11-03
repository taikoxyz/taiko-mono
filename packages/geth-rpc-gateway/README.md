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
