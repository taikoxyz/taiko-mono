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

   `.l1processor.example.env` is the L1 to L2 direction. For L2 to L1 — the direction that lands
   claims on Ethereum, and the only one where `DEST_PRIVATE_RPC_URLS` applies — start from
   `.l2processor.example.env` instead.

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

### Upgrading: the processing queue wants a dead-letter routing key

This release asks for `x-dead-letter-routing-key` on the main processing queue. Without it a message
rejected for good keeps the routing key it was published with — the queue's own name — while
`dlx-<queue>` is bound with the `-process` key, and a direct exchange discards what it cannot route.
Messages negatively acknowledged with no requeue were therefore destroyed rather than parked, and
the permanently empty `dlx-<queue>` looked like evidence that none had been.

A durable queue's arguments are fixed once it exists, so an existing queue cannot simply take the
new one: the broker answers a redeclare carrying different arguments with `406 PRECONDITION_FAILED`.
**The relayer does not insist.** A queue that accepts the argument is correct from that moment; one
that refuses keeps the arguments it has, the relayer starts as before, and it logs at error level
what is still wrong and how to fix it. Both binaries declare this queue, so insisting would have
stopped the whole relayer on rollout — and the only in-band repair, deleting the queue, destroys the
claims still in it.

To fix an existing queue, either is enough:

- Set `dead-letter-routing-key` to `<queue>-process` with a broker policy on that queue. Policies
  are not part of the declare-equivalence check, so this needs no redeclare, can be applied while the
  queue is running, and takes effect for messages already enqueued — nothing has to be drained. This
  is the one to prefer.

  ```sh
  rabbitmqctl set_policy dlrk "^<queue>$" \
    '{"dead-letter-routing-key":"<queue>-process"}' --apply-to queues --priority 1
  ```
- Drain the queue and delete it, so the next start declares it afresh. This loses anything still
  queued, so drain first.

### Retrying a claim that failed for a transient reason

A processing failure that may resolve on its own — an RPC timeout, a connection reset, a source
transaction not yet confirmed — does not cost the claim. The message is republished to a
`<queue>-transient` sibling queue that no consumer reads, with
`TRANSIENT_ERROR_QUEUE_EXPIRATION` on it, and the original delivery is acknowledged. That value is
**milliseconds**, as every AMQP expiration is, and defaults to `30000`. It is checked at startup: a
duration string such as `30s` is accepted by the publish and then closes the channel, which the
relayer would otherwise survive only as a reconnect loop. When the expiration elapses the broker
dead-letters it back onto the processing queue and it is tried again.

The wait is what makes this safe to repeat. `QUEUE_PREFETCH_COUNT` defaults to 1 and a delivery is
acknowledged only after processing, so exactly one message is in flight per replica: negatively
acknowledging a failure back onto the queue returns it to the head immediately, and a claim that
keeps failing would then be all that replica ever looks at. Parking it puts the rest of the queue
ahead of it instead.

It does not make such a claim free. The slot is still held for however long the failing attempt
takes before the park — for a source transaction that will never confirm, that is the whole
`CONFIRMATIONS_TIMEOUT`, several times the expiration — so a claim behind it waits minutes rather
than forever. What this buys is ordering under a backlog, not a claim that costs nothing: the
replica works through everything else between attempts instead of spinning on one message. Making
the attempt itself cheap means telling "receipt never seen" apart from "still confirming" in
`waitForConfirmations`, which is a separate change.

Attempts are not capped. A transient failure says nothing about whether the claim is good, and a
claim this relayer could land must not be skipped, so the message keeps coming back;
`message_sent_events_requeued_transient_ops_total` and the `TimesRequeued` count carried on the
message are what make one that never resolves visible.

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
offered **first** any transaction whose nonce is at or below the highest it has already accepted. A
relay replaces a transaction the way a mempool does — same nonce, higher fee — so the endpoint
already holding a nonce is the one place a resend achieves something, retiring the stale low-fee
variant. Offering it elsewhere leaves both variants live in different builders' pools with nothing
to enforce one transaction per nonce. Claims are handled concurrently, so this is a high-water mark
rather than a record of each nonce; the cost is that a first send arriving out of order behind a
higher nonce is treated as a resend, which only reorders private endpoints against each other.
Nothing is charged for that reordering.

Plain `http://` is rejected unless the host is the name `localhost` or an IP literal in a loopback,
private or link-local range: a signed claim on the wire in cleartext can be read and front-run,
which is the exposure these endpoints exist to remove, reached by another route. Names are not
resolved to decide this, so a private name such as `mev-relay.default.svc.cluster.local` is rejected
even where it resolves inside the cluster — give the address as a literal, or serve the relay over
`https://`. Resolving would make a cleartext decision depend on what DNS answers at that moment.

Errors returned from a send have any URL and any configured host removed from their text, so an
endpoint's API key and name stay out of the logs. Addresses the resolver produced — the IP a dial
reports, or the resolver's own `host:port` — are not removed, so a relay's provider can still be
inferred from a failing deployment's logs.

Each endpoint also gets its own share of the time left on the attempt, so one that accepts the
connection and then never answers cannot spend the budget the endpoints behind it need. That budget
is `RPC_TIMEOUT` (12 seconds by default), not `TX_SEND_TIMEOUT`: the transaction manager calls the
backend once per publish under its network timeout, and the share is that divided by the endpoints
still to try. Lowering `RPC_TIMEOUT` or configuring many endpoints therefore shrinks each attempt,
and an endpoint that spends its whole share without answering is charged with a failure.

The share has a floor of a second. Below that an attempt is too short for a relay to answer in, so
the endpoint would fail on the budget rather than on its health — and a timeout is charged with no
deduplication, which is how endpoints flap in and out of rotation for no reason of their own. When
the share would fall below the floor the attempt takes the whole remaining budget instead, and the
endpoints behind it are skipped **without being charged**, since they never got a usable context. At
the 12 second default this only bites past a dozen endpoints, or when `RPC_TIMEOUT` has been
lowered.

Because it is the same signed
transaction every time, offering it to the next endpoint after one refuses is idempotent — at most
one of them can land it. An endpoint that refuses several sends in a row drops out of rotation for
`PRIVATE_RPC_RETRY_INTERVAL` (5 minutes by default), and comes back with a fresh budget once that
elapses. A relay that answers that it will not take one particular claim — one that would revert
because a competitor already processed the message, say — is charged once for it rather than on
every resubmission, so one such claim does not cost a healthy relay its turn. That is judged by
nonce, not by transaction hash: once any endpoint accepts a send the transaction manager bumps the
fee before resending, so every resubmission of one claim carries a new hash while remaining one
claim.

Two answers are not charged at all. A relay that already holds the nonce replies `replacement
transaction underpriced` or `already known`, which reads as a refusal but says the opposite — it is
carrying the claim, which is what steering the resend to it was for. Those are counted by
`private_rpc_held_nonce_ops_total`. An answer for a nonce the endpoint has demonstrably taken is
free, however many claims it is carrying at once, as is one repeat of the last nonce it answered
for; anything beyond that counts towards the consecutive ceiling, so an endpoint answering this way
for a succession of claims it never took cannot keep its place indefinitely. An endpoint given a
share of the budget too small to answer in is not charged either; see below. A timeout or a
transport failure always counts, even for the same transaction, since that is what an endpoint
being down looks like. Only once no endpoint is left in
rotation does a transaction go out through `DEST_RPC_URL`.

One claim can be refused by every endpoint without any of them being unhealthy — each is charged
once for it, so none trips, and the claim would otherwise loop until `TX_SEND_TIMEOUT` while the
relays go on serving everything else. After three consecutive sends that every endpoint in rotation
*answered* with a refusal, that claim is broadcast publicly and
`private_rpc_all_refused_ops_total` counts it.

That probation is served once per claim, not once per exposure. Once a claim has been broadcast it
stays in the public pool on every subsequent send, until a private endpoint takes it back and clears
the run. Restarting the count there would withhold the next two fee-bumped resubmissions from a pool
that already holds the stale low-fee variant of the same claim: there is no privacy left to save by
then, and the replacement would be kept from the only place that can mine it.

The run belongs to the claim rather than to the nonce it was sent under, because nonces are reused.
A claim abandoned at `TX_SEND_TIMEOUT` leaves its count behind — only an accepted send clears one —
and the next message signed with that nonce would otherwise inherit a probation it had served none
of, and be broadcast on its first refusal instead of its third. The claim is identified by its
calldata, which is the message and its proof: unchanged by the fee bumps that change everything else
about the transaction, and different for every other claim.

Two answers do not count towards this. A timeout or transport failure means the endpoint is down,
which tripping handles, and counting it here would push claims into the open during an outage before
the rotation had a chance to empty. An endpoint answering that it already holds the nonce does not
count either — the claim is already where it needs to be, so broadcasting it would leak one every
relay is carrying. Broadcasting publicly gives a
competitor the message and proof, so it is deliberately the last resort — but a claim that never
lands is worth less than one landed in the open.

Five metrics are worth alerting on, all labelled or counted so they can be read without access to
the logs. `private_rpc_failures_ops_total` is labelled by the refusing endpoint's position in the
failover order, so it says which relay is unhealthy. `private_rpc_trips_ops_total`, labelled the
same way, counts an endpoint actually leaving the rotation rather than each refusal on the way
there — one fewer place to send privately. `private_rpc_unavailable_ops_total` counts transactions
that went out through `DEST_RPC_URL` while private endpoints were configured — that is the relayer
running exposed, and matters more than any individual refusal.

Two more count the other way a claim reaches the public mempool: not because the rotation was empty,
but because every endpoint in it refused this one claim. `private_rpc_all_refused_attempts_ops_total`
counts each time such a claim was offered to `DEST_RPC_URL`, and `private_rpc_all_refused_ops_total`
counts the times that endpoint took it. Both count sends rather than distinct claims, so a claim
refused for long enough is counted once per broadcast. Read together: attempts climbing while
broadcasts do not means the public endpoint is failing as well and the claim is reaching nobody. Alongside them,
`private_rpc_sends_ops_total`, labelled the same way, counts the transactions each endpoint
accepted. It is not an alert on its own; it is what turns the refusals into a rate, which is what
separates a busy relay turning down a few claims from one that has started turning down most of
them. `private_rpc_in_rotation` is 1 while an endpoint is in the rotation and 0 while it is out:
trips are monotonic and cannot say what the rotation looks like now, and this can. Every series is
created at startup for every configured endpoint, so the first trip is a rise from zero rather than
a series appearing from nothing — which `increase()` would have read as no change at all. Both
transitions are logged as well,
`Private endpoint taken out of rotation` and `Private endpoint back in rotation`, each carrying the
endpoint's position.

A restart while a relay is holding an accepted transaction is worth knowing about. Nonces come from
`DEST_RPC_URL`, and a privately accepted transaction is never gossiped there, so a relayer that
restarts before that transaction is included sees its nonce as free and may sign a different claim
with it. Whichever lands first wins and the other becomes invalid, so no funds are at risk, and the
losing claim is retried: its send ends with `nonce too low`, which counts as transient, so the
message waits on the transient queue and comes back to be signed under a fresh nonce. That claim is
delayed by a round, and its fee may be gone by then. `TX_SEND_TIMEOUT` bounds how long a single
send can be outstanding but does not help across a restart. The exposure is proportional to how
long a relay holds transactions, so it is smallest with relays that drop rather than queue.

**`TX_SEND_TIMEOUT` defaults to 5 minutes when private endpoints are configured**, rather than to
disabled. A relay can accept a transaction and never have it included — Flashbots Protect drops
would-revert transactions by design — and accepting is the only signal the relayer gets, since
receipts are polled through `DEST_RPC_URL`. Without a send timeout the transaction manager waits for
that receipt indefinitely, so the claim stalls and holds its worker.

Five minutes is a bound the relayer chooses, not the point at which the relays give up. Their
roughly twenty-five block window runs per transaction submitted, and every fee bump submits a new
one, so the newest variant of a claim is still being offered past this — with the 48s
`RESUBMISSION_TIMEOUT` default the tail runs to around ten minutes. The value is chosen for being
six fee bumps at that default, so a merely underpriced claim has had several chances to catch up,
and for matching `PRIVATE_RPC_RETRY_INTERVAL`, so a stalled claim and a tripped endpoint come back
on the same timescale. It is a ceiling rather than the usual exit: a send no endpoint will take ends
earlier, at the transaction manager's two-minute `TxNotInMempoolTimeout`, because no publish ever
succeeded. Set `TX_SEND_TIMEOUT` to choose a different bound; the one value it
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
