# blob-storage

Repo for BLOB storage (archive and serve data)

## how to run ?

Prerequisite is to have docker engine up and running.

1. Start the mongoDB

```bash
cd local_docker && docker-compose up -d
```

2. Start the `blob-catcher`

```bash
cd cmd/blob_catcher && go run .
```

By default the above command starts the app from the latest block height. If we want to specifiy a previous blockheight, we can run it like:

```bash
cd cmd/blob_catcher && go run . -past_events=true -start_block=117452
```

2. Start the `server` - by default it listens on port `27001` (sets in `config.go`)

```bash
cd cmd/server && go run .
```

It uses the config from `internal/logic/config.go`.

## how to test / use ?

When the `DB`, `blob-catcher` and `server` is running, the `blob-catcher` is outputting the `blobHash` to the terminal (with the `networkName` variable too, tho it is not written into the DB). Use that `blobHash` (including the 0x) in

1. Either in a curl command like this (you can query multiple blobHashes - comma separated - with one go and the result will be a respective array):

```bash
curl -X GET "http://localhost:27001/getBlob?blobHash=0x01a2a1cdc7ad221934061642a79a760776a013d0e6fa1a1c6b642ace009c372a,0xWRONG_HASH"
```

The result will be something like this:

```bash
{"data":[{"blob":"0x123...00","kzg_commitment":"0xabd68b406920aa74b83cf19655f1179d373b5a8cba21b126b2c18baf2096c8eb9ab7116a89b375546a3c30038485939e"}, {"blob":"NOT_FOUND","kzg_commitment":"NOT_FOUND"}]}
```

2. Or to backtest, use the simple python script below, after overwriting the `blob_hash` variable:

```bash
python3 python_query.py
```

## todos

What is still missing is:

- small refinements and DevOps (prod-grade DB with creditentials, proper containerization)
