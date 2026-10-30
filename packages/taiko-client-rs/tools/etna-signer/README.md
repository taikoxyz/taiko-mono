# Guarded native Etna signer

Build the standalone helper with Go 1.27.2 using `just signer` from
`packages/taiko-client-rs`. The host binary is
`target/etna-signer/etna-signer`; the production client image contains
`/app/etna-signer`. The module pins unmodified CometBFT v0.40.0.

## Bootstrap a new validator

Create a private directory outside the Comet home and every Comet mount. Run
these commands only for a new identity, before registration and genesis creation:

```sh
umask 077
mkdir ./private-validator
./target/etna-signer/etna-signer keygen \
  --priv-key ./private-validator/priv_validator_key.json \
  --priv-state ./private-validator/priv_validator_state.json
```

Success writes two exclusive, mode-0600, stock FilePV JSON files and prints one
JSON object with `publicKey` (0x-prefixed compressed 33-byte SEC1 key) and `address`
(0x-prefixed 20-byte Ethereum consensus address). Either existing output,
including a symlink, causes failure without replacing it. Parent directories must
already exist. Bootstrap uses stock OS-random `secp256k1eth` key generation. It
never exports a private key to stdout.

Create the registration proof for the actual owner, registry and L1 chain:

```sh
./target/etna-signer/etna-signer pop \
  --priv-key ./private-validator/priv_validator_key.json \
  --owner 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --registry 0x2222222222222222222222222222222222222222 \
  --l1-chain-id 1
```

Success prints one JSON object with `publicKey` and `signature`, both 0x-prefixed
hex. The signature is exactly 65 bytes `R || S || V`, with low S and V in {0,1}.
The EIP-712 domain is name `EtnaStakingRegistry`, version `1`, the full decimal
uint256 L1 chain ID and verifying registry. Its message is `Register(address
owner)`. The helper passes `0x1901 || domainSeparator || structHash` to stock
`secp256k1eth.Sign`, which applies legacy Keccak exactly once. PoP neither reads
nor writes consensus HRS state and can run offline. Registering on L1 is a separate
operator/deployment action.

## Serve using existing authoritative files

Keep the existing guarded serve flags:

```sh
./target/etna-signer/etna-signer \
  --comet-signer-addr unix:///absolute/path/run/comet-sign.sock \
  --trust-socket /absolute/path/app-store/checkpoint-trust.sock \
  --chain-id "$ETNA_CHAIN_ID" \
  --priv-key /absolute/private/priv_validator_key.json \
  --priv-state /absolute/private/priv_validator_state.json
```

Serve requires both existing regular files and a native `secp256k1eth` FilePV
identity with matching public metadata. It canonicalizes symlinks, refuses
hard-linked state and takes the existing state owner lock before loading the
stock FilePV. It never initializes or resets HRS. Preserve both signing files,
Comet WAL and app history on restart; never use `keygen` as a recovery action.

Use `script/start_etna_validator.sh` to supervise existing key/state paths and a
configured Comet home after starting the ABCI app. The script runs `cometbft start`
directly. Container callers must likewise invoke the stock binary directly with
`--entrypoint /usr/bin/cometbft`; the image's default entrypoint can initialize
files and must not be used for validator runtime. Its `priv_validator_laddr` is
mandatory. Keep the registered private key inaccessible to Comet. Node P2P and
SecretConnection transport identities remain separate Ed25519 keys.

Every transport connection opens a fresh closed trust session. Every signature,
including a cached same-HRS retry, checks that private session again. PubKey and
Ping remain available while closed. Trust schema 1 requires a canonical 32-byte
`target.comet_hash` alongside the EL checkpoint hash; absent, null, malformed,
unknown or duplicate fields fail closed. Denial never invokes FilePV signing.
Only stock FilePV writes signing state after authorization.

Run `just signer-test` for Go race/process/native interop tests. No Cargo build is
needed for this helper.

The supported supervisor adds `--denial-file <app-store>/signer-denial.json`.
It is a private atomic observation, not signing state or authorization: sequence zero
publishes a fresh session ID, and positive sequence increments capture every signing
refusal, including a local-control timeout while the app remains Ready. The supervisor
uses nonmutating schema-1 `observe`, waits for exact private Ready, then reaps Comet and
the signer with unchanged HRS/WAL/history. Stock Comet never retries a refused request;
only a restarted Comet's WAL replay asks for that step again. So the supervisor first
restarts the signer alone with `--await-trust`: it begins the fresh closed session for its
first transport and dials Comet only after that session passes the same check as every
signature. Until then each dial attempt fails and is retried on the same session; it begins
another only when the app reports a different current session, for example after an app
restart. Once `observe` reports the published session Ready, the supervisor starts Comet,
whose WAL replay then gets the refused step signed. Later reconnects of that process dial
at once, as without the flag: a request made while no signer is connected would fail
inside Comet unreported, whereas a refusal reaches the supervisor. Never pass
`--await-trust` on a first start: Comet's startup needs the signer connected, and a node
that is behind regains trust only after Comet syncs. Every new transport still begins a
closed session. Terminal trust/domain failures persist a latch and leave the supervisor
alive and quiescent, including after container restart. See the package README for the
supported combined image and separate app/supervisor container commands.
