[![Golang](https://github.com/taikoxyz/taiko-mono/actions/workflows/golang.yml/badge.svg)](https://github.com/taikoxyz/taiko-mono/actions/workflows/golang.yml)
[![Relayer](https://codecov.io/gh/taikoxyz/taiko-mono/branch/main/graph/badge.svg?token=E468X2PTJC&flag=relayer)](https://codecov.io/gh/taikoxyz/taiko-mono)

# Relayer

A relayer for the Bridge to watch and sync event between Layer 1 and Taiko Layer 2.

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

| Path          | Description                                                                                                                              |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `bindings/`   | [Go contract bindings](https://geth.ethereum.org/docs/dapp/native-bindings) for Taiko smart contracts, and few related utility functions |
| `cmd/`        | Main executable for this project                                                                                                         |
| `db/`         | Database interfaces and connection methods.                                                                                              |
| `encoding/`   | Encoding helper utility functions for interacting with smart contract functions                                                          |
| `indexer/`    | Indexer sub-command                                                                                                                      |
| `metrics/`    | Metrics related                                                                                                                          |
| `migrations/` | Database migrations                                                                                                                      |
| `mock/`       | Mocks for testing                                                                                                                        |
| `proof/`      | Merkle proof generation service                                                                                                          |
| `queue/`      | Queue related interfaces and types, with implementations in subfolders                                                                   |
| `repo/`       | Database repository interaction layer                                                                                                    |

## API Doc

`/events?`.

Filter params:

Mandatory:
`address`: user's ethereum address who sent the message.

Optional:
`chainID`: chain ID of the source chain. Default: all chains. Options: any integer.
`msgHash`: filter events by message hash. Default: all msgHashes. Options: any hash.
`eventType`: filter events by event type. Default: all eventType. Options: Enum value, `0` for sendETH, `1` for sendERC20.
`event`: filter events by event name. Default: all event names. Options: `MessageSent`, `MessageStatusChanged`

Pagination:
`page`: page number to retrieve. Default: 0.
`size`: size to retrieve per page. Default: 100

Example:
`http://localhost:4101/events?page=3&address=0x79B9F64744C98Cd8cc20ADb79B6a297E964254cc&size=1&msgHash=0x47ce4d255907937aba12dfa09d87a0a707fea7eeac687924ac0a80fa291c3289&eventType=1`:

```ts
{"items":[{"id":4,"name":"MessageSent","data":{"Raw":{"data":"0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000007777000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000028c590000000000000000000000000000000000000000000000000000000000007a6800000000000000000000000079b9f64744c98cd8cc20adb79b6a297e964254cc0000000000000000000000005e506e2e0ead3ff9d93859a5879caa02582f77c300000000000000000000000079b9f64744c98cd8cc20adb79b6a297e964254cc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002625a000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000001a40c6fab82000000000000000000000000000000000000000000000000000000000000008000000000000000000000000079b9f64744c98cd8cc20adb79b6a297e964254cc00000000000000000000000079b9f64744c98cd8cc20adb79b6a297e964254cc00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000028c590000000000000000000000000000777700000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000035052450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e5072656465706c6f79455243323000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001243726f6e4a6f622053656e64546f6b656e730000000000000000000000000000","topics":["0x47866f7dacd4a276245be6ed543cae03c9c17eb17e6980cee28e3dd168b7f9f3","0x47ce4d255907937aba12dfa09d87a0a707fea7eeac687924ac0a80fa291c3289"],"address":"0x0000777700000000000000000000000000000004","removed":false,"logIndex":"0x4","blockHash":"0xee6437aee05f0d2f8680462c82269ce971df1040134b145d664609d9a06cc864","blockNumber":"0x5","transactionHash":"0xc79e67b30255bfee2bdf2f149aadf426613e8e0ab38aa79d8a2d186d096ec4a9","transactionIndex":"0x2"},"Message":{"Id":1,"To":"0x5e506e2e0ead3ff9d93859a5879caa02582f77c3","Data":"DG+rggAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAAAAAAAAAAAAAebn2R0TJjNjMIK23m2opfpZCVMwAAAAAAAAAAAAAAAB5ufZHRMmM2Mwgrbebail+lkJUzAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACjFkAAAAAAAAAAAAAAAAAAHd3AAAAAAAAAAAAAAAAAAAABQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAASAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA4AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADUFJFAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADlByZWRlcGxveUVSQzIwAAAAAAAAAAAAAAAAAAAAAAAA","Memo":"CronJob SendTokens","Owner":"0x79b9f64744c98cd8cc20adb79b6a297e964254cc","Sender":"0x0000777700000000000000000000000000000002","GasLimit":2500000,"CallValue":0,"SrcChainId":167001,"DestChainId":31336,"DepositValue":0,"ProcessingFee":0,"RefundAddress":"0x79b9f64744c98cd8cc20adb79b6a297e964254cc"},"MsgHash":[71,206,77,37,89,7,147,122,186,18,223,160,157,135,160,167,7,254,167,238,172,104,121,36,172,10,128,250,41,28,50,137]},"status":1,"eventType":1,"chainID":167001,"canonicalTokenAddress":"0x0000777700000000000000000000000000000005","canonicalTokenSymbol":"PRE","canonicalTokenName":"PredeployERC20","canonicalTokenDecimals":18,"amount":"1","msgHash":"0x47ce4d255907937aba12dfa09d87a0a707fea7eeac687924ac0a80fa291c3289","messageOwner":"0x79B9F64744C98Cd8cc20ADb79B6a297E964254cc"}],"page":3,"size":1,"max_page":3352,"total_pages":3353,"total":3353,"last":false,"first":false,"visible":1}
```
