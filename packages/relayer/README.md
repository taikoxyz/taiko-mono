[![Relayer](https://codecov.io/gh/taikoxyz/taiko-mono/branch/main/graph/badge.svg?token=E468X2PTJC&flag=relayer)](https://codecov.io/gh/taikoxyz/taiko-mono)

# Relayer

A relayer for the Bridge to watch and sync events between Layer 1 and Taiko Layer 2.

## Build the Source

To build the source, ensure you have an updated Go compiler installed. Run the following command to compile the executable:

```sh
go build -o relayer ./cmd/
```

## Configuration

### Configure MySQL and RabbitMQ

Before configuring environment variables, ensure that you have MySQL and RabbitMQ instances running. Replace the `MYSQL_` environment variables with your specific configurations.

RabbitMQ can be installed using the provided script:

```sh
./scripts/install-rabbitmq.sh
```

Alternatively, use Docker Compose to set up MySQL and RabbitMQ in your local environment:

```sh
cd ./docker-compose
docker-compose up
```

To migrate the database schema in MySQL:

```sh
cd ./migrations
goose mysql "<user>:<password>@tcp(localhost:3306)/relayer" status
goose mysql "<user>:<password>@tcp(localhost:3306)/relayer" up
```

### Configure Environment Variables

Environment variables are crucial for the configuration of the Relayer’s processor and indexer. These variables are set in environment files, which are then loaded by the Relayer at runtime.

#### Setting up the Processor:

1. **Create the Environment File for the Processor**:
   Copy the example processor environment file to a new file:

   ```sh
   cp .l1processor.example.env .l1processor.env
   ```

   Modify `.l1processor.env` as necessary to suit your environment settings.

2. **Run the Processor**:
   Before running the processor, specify which environment file it should use by setting the `RELAYER_ENV_FILE` environment variable:
   ```sh
   export RELAYER_ENV_FILE=./.l1processor.env
   ```
   Now, you can run the processor:
   ```sh
   ./relayer processor
   ```

#### Setting up the Indexer:

1. **Create the Environment File for the Indexer**:
   Copy the example indexer environment file to a new file:

   ```sh
   cp .l1indexer.example.env .l1indexer.env
   ```

   Edit `.l1indexer.env` to reflect your specific configurations.

2. **Run the Indexer**:
   Set the `RELAYER_ENV_FILE` to point to the indexer's environment file:
   ```sh
   export RELAYER_ENV_FILE=./.l1indexer.env
   ```
   Execute the indexer:
   ```sh
   ./relayer indexer
   ```

### Keeping claims out of the public mempool

`processMessage` is permissionless and pays the processing fee to whoever lands it first. A claim
broadcast to the public mempool therefore hands competitors the message and merkle proof they need
to submit the same call, take the fee, and leave this relayer paying gas for a call that then
reverts.

Set `DEST_PRIVATE_RPC_URLS` to one or more endpoints that pass transactions to block builders
without gossiping them.

```sh
DEST_PRIVATE_RPC_URLS=https://rpc.flashbots.net?hint=hash,https://rpc.mevblocker.io/fullprivacy
```

Both endpoints above are free and take no service fee. Use their maximum-privacy settings, as shown:
the default on either shares transaction data with searchers, which is the opposite of what is
wanted here.

Only the broadcast goes private. Nonces, gas prices, receipts and every other read still come from
`DEST_RPC_URL`, so the relayer keeps one nonce source and its reads do not depend on a relay being
up or within its rate limit.

Endpoints are offered each transaction in the order given, with one exception: an endpoint is
offered last any transaction whose nonce is at or below the highest it has already accepted.
Accepting only means the relay received the transaction, never that a builder included it, and the
transaction manager only re-sends a nonce it has not seen confirmed — so the replacement is better
spent on a different builder. Claims are handled concurrently, so this is a high-water mark rather
than a record of each nonce; the cost is that a first send arriving out of order behind a higher
nonce is also offered last, which only reorders private endpoints against each other. Nothing is
charged for that reordering.

Plain `http://` is rejected for anything but a loopback or private-network host: a signed claim on
the wire in cleartext can be read and front-run, which is the exposure these endpoints exist to
remove, reached by another route.

Each endpoint also gets its own share of the time left on the send, so one that accepts the
connection and then never answers cannot spend the budget the endpoints behind it need.

Because it is the same signed
transaction every time, offering it to the next endpoint after one refuses is idempotent — at most
one of them can land it. An endpoint that refuses several sends in a row drops out of rotation for
`PRIVATE_RPC_RETRY_INTERVAL` (5 minutes by default), and comes back with a fresh budget once that
elapses. A relay that answers that it will not take one particular claim — one that would revert
because a competitor already processed the message, say — is charged once for it rather than on
every resubmission, so one such claim does not cost a healthy relay its turn. A timeout or a
transport failure always counts, even for the same transaction, since that is what an endpoint
being down looks like. Only once no endpoint is left in
rotation does a transaction go out through `DEST_RPC_URL`.

Three metrics are worth alerting on, all labelled or counted so they can be read without access to
the logs. `private_rpc_failures_ops_total` is labelled by the refusing endpoint's position in the
failover order, so it says which relay is unhealthy. `private_rpc_trips_ops_total`, labelled the
same way, counts an endpoint actually leaving the rotation rather than each refusal on the way
there — one fewer place to send privately. `private_rpc_unavailable_ops_total` counts transactions
that went out through `DEST_RPC_URL` while private endpoints were configured — that is the relayer
running exposed, and matters more than any individual refusal. Both transitions are logged as well,
`Private endpoint taken out of rotation` and `Private endpoint back in rotation`, each carrying the
endpoint's position.

A restart while a relay is holding an accepted transaction is worth knowing about. Nonces come from
`DEST_RPC_URL`, and a privately accepted transaction is never gossiped there, so a relayer that
restarts before that transaction is included sees its nonce as free and may sign a different claim
with it. Whichever lands first wins and the other becomes invalid, so no funds are at risk and the
losing message is redelivered by the queue and retried under a fresh nonce — but that claim is
delayed by a round, and its fee may be gone by then. `TX_SEND_TIMEOUT` bounds how long a single
send can be outstanding but does not help across a restart. The exposure is proportional to how
long a relay holds transactions, so it is smallest with relays that drop rather than queue.

**`TX_SEND_TIMEOUT` defaults to 5 minutes when private endpoints are configured**, rather than to
disabled. A relay can accept a transaction and never have it included — Flashbots Protect drops
would-revert transactions by design — and accepting is the only signal the relayer gets, since
receipts are polled through `DEST_RPC_URL`. Without a send timeout the transaction manager waits for
that receipt indefinitely, so the claim stalls and holds its worker.

Five minutes is where the relays themselves stop: about twenty-five Ethereum blocks, which is how
long Flashbots Protect keeps offering a transaction to builders, so a claim is given up only once
nobody is still trying to land it. It is also six fee bumps at the 48s `RESUBMISSION_TIMEOUT`
default, and it matches `PRIVATE_RPC_RETRY_INTERVAL`, so a stalled claim and a tripped endpoint come
back on the same timescale. Set `TX_SEND_TIMEOUT` to choose a different bound; the one value it
cannot take alongside private endpoints is no bound at all. Deployments that configure no private
endpoint are untouched — this timeout governs the public path too, and they have been running
without it.

Leave this unset when the destination chain is Taiko: private relays exist for Ethereum only, so
L1 to L2 claims keep using `DEST_RPC_URL`.

## Usage

To review all available sub-commands, use:

```sh
./relayer --help
```

To review each sub-command's command line flags, use:

```sh
./relayer <sub-command> --help
```

## Project structure

| Path          | Description                                                                                                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bindings/`   | [Go contract bindings](https://geth.ethereum.org/docs/developers/dapp-developer/native-bindings) for Taiko smart contracts, and few related utility functions |
| `cmd/`        | Main executable for this project                                                                                                                              |
| `db/`         | Database interfaces and connection methods.                                                                                                                   |
| `encoding/`   | Encoding helper utility functions for interacting with smart contract functions                                                                               |
| `indexer/`    | Indexer sub-command                                                                                                                                           |
| `metrics/`    | Metrics related                                                                                                                                               |
| `migrations/` | Database migrations                                                                                                                                           |
| `mock/`       | Mocks for testing                                                                                                                                             |
| `proof/`      | Merkle proof generation service                                                                                                                               |
| `queue/`      | Queue related interfaces and types, with implementations in subfolders                                                                                        |
| `repo/`       | Database repository interaction layer                                                                                                                         |

## API Doc

`/events?`.

Filter parameters:

Mandatory:
`address`: user's Ethereum address who sent the message.

Optional:
`chainID`: chain ID of the source chain. Default: all chains. Options: any integer.
`msgHash`: filter events by message hash. Default: all msgHashes. Options: any hash.
`eventType`: filter events by event type. Default: all event types. Options: Enum value, `0` for sendETH, `1` for sendERC20.
`event`: filter events by event name. Default: all event names. Options: `MessageSent`, `MessageStatusChanged`

Pagination:
`page`: page number to retrieve. Default: 0.
`size`: number of items to retrieve per page. Default: 100

Example:
`http://localhost:4101/events?page=3&address=0x79B9F64744C98Cd8cc20ADb79B6a297E964254cc&size=1&msgHash=0x47ce4d255907937aba12dfa09d87a0a707fea7eeac687924ac0a80fa291c3289&eventType=1`:

```ts
{"items":[{"id":4,"name":"MessageSent","data":{"Raw":{"data":"0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000007777000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000028c590000000000000000000000000000000000000000000000000000000000007a6800000000000000000000000079b9f64744c98cd8cc20adb79b6a297e964254cc0000000000000000000000005e506e2e0ead3ff9d93859a5879caa02582f77c300000000000000000000000079b9f64744c98cd8cc20adb79b6a297e964254cc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002625a000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000001a40c6fab82000000000000000000000000000000000000000000000000000000000000008000000000000000000000000079b9f64744c98cd8cc20adb79b6a297e964254cc00000000000000000000000079b9f64744c98cd8cc20adb79b6a297e964254cc00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000028c590000000000000000000000000000777700000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000035052450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e5072656465706c6f79455243323000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001243726f6e4a6f622053656e64546f6b656e730000000000000000000000000000","topics":["0x47866f7dacd4a276245be6ed543cae03c9c17eb17e6980cee28e3dd168b7f9f3","0x47ce4d255907937aba12dfa09d87a0a707fea7eeac687924ac0a80fa291c3289"],"address":"0x0000777700000000000000000000000000000004","removed":false,"logIndex":"0x4","blockHash":"0xee6437aee05f0d2f8680462c82269ce971df1040134b145d664609d9a06cc864","blockNumber":"0x5","transactionHash":"0xc79e67b30255bfee2bdf2f149aadf426613e8e0ab38aa79d8a2d186d096ec4a9","transactionIndex":"0x2"},"Message":{"Id":1,"To":"0x5e506e2e0ead3ff9d93859a5879caa02582f77c3","Data":"DG+rggAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAAAAAAAAebn2R0TJjNjMIK23m2opfpZCVMwAAAAAAAAAAAAAAAB5ufZHRMmM2Mwgrbebail+lkJUzAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACjFkAAAAAAAAAAAAAAAAAAHd3AAAAAAAAAAAAAAAAAAAABQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAASAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADUFJFAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADlByZWRlcGxveUVSQzIwAAAAAAAAAAAAAAAAAAAAAAAA","Memo":"CronJob SendTokens","Owner":"0x79b9f64744c98cd8cc20adb79b6a297e964254cc","Sender":"0x0000777700000000000000000000000000000002","GasLimit":2500000,"CallValue":0,"SrcChainId":167001,"DestChainId":31336,"DepositValue":0,"ProcessingFee":0,"RefundAddress":"0x79b9f64744c98cd8cc20adb79b6a297e964254cc"},"MsgHash":[71,206,77,37,89,7,147,122,186,18,223,160,157,135,160,167,7,254,167,238,172,104,121,36,172,10,128,250,41,28,50,137]},"status":1,"eventType":1,"chainID":167001,"canonicalTokenAddress":"0x0000777700000000000000000000000000000005","canonicalTokenSymbol":"PRE","canonicalTokenName":"PredeployERC20","canonicalTokenDecimals":18,"amount":"1","msgHash":"0x47ce4d255907937aba12dfa09d87a0a707fea7eeac687924ac0a80fa291c3289","messageOwner":"0x79B9F64744C98Cd8cc20ADb79B6a297E964254cc"}],"page":3,"size":1,"max_page":3352,"total_pages":3353,"total":3353,"last":false,"first":false,"visible":1}
```
