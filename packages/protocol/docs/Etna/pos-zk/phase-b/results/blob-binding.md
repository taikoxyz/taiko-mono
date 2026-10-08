# S4 — blob binding and data availability, established from public data

**Status:** substitution report for Phase B spike S4. The spike as specified in
[S4-blob-binding-review.md](../S4-blob-binding-review.md) is a measurement on
hardware plus an independent cryptographic review. There is no hardware, no
testnet and no reviewer in this substitution. What follows is what public data
answers, and — stated as plainly — what it does not.

**Date of collection:** 2026-10-07 (Asia/Singapore). Ethereum L1 head at start of
collection: block **26,140,717** (2026-10-07T13:09:59Z). All figures are from
commands recorded here and in the raw directory; nothing is estimated unless the
label says so.

**Raw evidence:** [raw/s4-blob-binding/](./raw/s4-blob-binding/) — every raw
response, the scripts, their logs, `summary.json`, and `COMMANDS.md`.

---

## 0. The split, stated first

S4 has two halves, and only one of them is reachable from public data.

| Half of S4 | Reachable from public data? | What this report does |
|---|---|---|
| What Taiko actually publishes on L1 (DA mode, blob counts, blob prices, on-chain binding checks, the EIP-4844 parameters actually in force) | **Yes** | measured and reported below |
| In-guest cost of the blob polynomial evaluation (S4 §5, gate T5) | **No** — needs the guest on the pinned zkVM backends; no public data contains it | §4 item 1 |
| Contract/guest challenge identity, 10,000-journal differential test (S4 gate T2) | **No** — needs the harness built and run | §4 item 2 |
| Rejection-case matrix, V1–V4 conventions (S4 gate T1) | **No** — needs the harness and a deployed Etna contract | §4 item 3 |
| The independent cryptographic review of the joint-event fixed-point argument, the transcript, canonicality and cheaper attacks (S4 gates T3/T4, claims 1–5) | **No** — this is a human review of the proof statement, not a data question | §4 item 4 |

The on-chain half can confirm that the *carried* binding checks the design
specifies are implementable and are exercised in production; it cannot make the
cryptographic half smaller. No amount of L1 data substitutes for a reviewer
attacking the fixed-point argument.

---

## 1. Scope and question

### 1.1 What S4 specified

S4 asks whether the whole-blob commitment, the on-chain challenge, the KZG
opening and the in-guest evaluation work end to end and survive independent
cryptographic review ([DA-03](../spec/04-l1-integration.html#DA-03) in full,
[PRF-07(b)](../spec/05-proof-statement.html#PRF-07)), and it fixes the blob half
of the L1 cost model that S3 consumes. Its decision is *sound and reviewable →
blobs usable* versus *unsound or unreviewable → calldata-only*.

### 1.2 The four questions this report answers from public data

1. Which DA mode Taiko's L1 rollup transactions actually use over a stated
   window — calldata, blobs, or both — and how that has changed over time.
2. For blob-carrying transactions: blob count per transaction, blob base fee,
   resulting blob cost, and whether the KZG commitments are present and
   well-formed (at minimum, the versioned-hash check).
3. The EIP-4844 parameters in force over the window, from primary sources, not
   from memory.
4. What the independent cryptographic review still requires.

### 1.3 What is out of scope here

The Ethereum-mainnet *simulation* question, the Etna contract's own gas
(the contract is not deployed), and the L2 side of Taiko's data flow are out of
scope. Every claim below is about the chain this environment serves, at the
stated block range, retrieved on the stated date.

---

## 2. Sources and method

### 2.1 Networks, endpoints, contracts

| Role | Endpoint / address | Notes |
|---|---|---|
| Ethereum L1 RPC (primary) | `https://rpc.mevblocker.io` | logs, transactions, receipts, block headers |
| Ethereum L1 RPC (fallbacks) | `https://eth.blockscout.com/api/eth-rpc`, `https://0xrpc.io/eth`, `https://ethereum-rpc.publicnode.com` | publicnode serves only recent blocks for `eth_getLogs`; blockscout rate-limits (HTTP 429) |
| Beacon API | `https://ethereum-beacon-api.publicnode.com` | `/eth/v1/config/spec`, `/eth/v1/beacon/blob_sidecars/{slot}`; reports `Lighthouse/v8.2.3`, version `fulu` |
| Rollup contract (current) | proxy `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f`, impl `0x5253D4C91e80b880DdB54B78E74082Abe066F6b9` | Shasta era; `MainnetInbox`; proxy deployed 2026-03-04, Unzen impl 2026-08-03 (repo deployment log) |
| Rollup contract (pre-Shasta) | proxy `0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a` | TaikoL1 (May 2024) → Pacaya TaikoInbox (2025) → retired by the Shasta deployment |
| Proposer wrapper(s) | `0x68d30f47F19c07bCCEf4Ac7FAE2Dc12FCa3e0dC9` (`labprovers.taiko.eth`; 2024-08/2025-06 samples) and `0xd5aa0e20e8a6e9b04f080cf8797410fafaa9688a` (2025-09/2026-02 samples) | top-level sender of pre-Shasta proposals; the rollup proxy emits the logs |
| Reference KZG library | `ckzg` Python binding, `c-kzg-4844` line, trusted setup `src/trusted_setup.txt` | SHA-256 of the setup file: `d39b9f2d047cc9dca2de58f264b6a09448ccd34db967881a6713eacacf0f26b7` |
| Primary parameter sources | EIP-4844, EIP-7691, EIP-7892 texts; `ethereum/consensus-specs` `configs/mainnet.yaml` | fetched 2026-10-07; saved under `raw/s4-blob-binding/sources/` |

The deployed `MainnetInbox` source was taken from Blockscout's verified
contract record, and tied to the on-chain bytecode: `eth_getCode(impl)` is
23,067 bytes with SHA-256
`8bd0b01798c5ffa09c86c4c61577f2cd1f4ee50668c9629482abedff41aae423`, identical
to Blockscout's `deployed_bytecode`; the proxy's EIP-1967 implementation slot
reads `0x…5253d4c9…`.

### 2.2 Windows

| Window | Blocks | Time (UTC) | Kind |
|---|---|---|---|
| Shasta era, full census | 24,792,175 – 26,140,714 | 2026-04-02T13:18:23Z – 2026-10-07T13:09:23Z | complete `eth_getLogs` scan of the `Proposed` event |
| Shasta era, tx sample | every 1000th proposal | same | 41 proposals verified transaction-by-transaction |
| Blob-fee formula check | 24 blocks spread across the era | same | block header + all receipts |
| Blob-sidecar sample | 5 blocks: 26,140,717; 26,135,739; 26,120,000; 26,100,000; 26,000,002 | 2026-10-07 – 2026-09-18 | 15 sidecars fully checked |
| Earlier-era samples | 10,000-block windows listed in §3 F7 | 2024-08, 2025-02, 2025-06, 2025-09, 2026-02 | event counts + 20–30 transactions each |

### 2.3 Labels

Every figure carries one of: **[on-chain measured]** (a command was run against
an Ethereum L1/beacon endpoint and the response is in the raw directory);
**[derived; inputs on-chain measured]** (arithmetic over measured values, shown);
**[third-party reported — source, methodology]** (a named external source and how
it obtains the number); **[bounded — the bound and its assumption]**;
**[not establishable from public data]**.

### 2.4 Scripts

All under `raw/s4-blob-binding/`: `scan_chunks.py`, `finish_scan2.py`
(proposal-log census), `decode_proposed.py` (event decoder → CSVs),
`verify_tx_sample.py`, `blobfee_check.py`, `sample_sidecars.py`,
`verify_blob.py` (c-kzg + Python evaluation + `0x0A` call),
`header_sample.py`, `blob_content.py`, `era_check.py`, `era_events.py`,
`rpc.py`. Exact commands: `raw/s4-blob-binding/COMMANDS.md`.

---

## 3. Findings

### F1. The current production DA mode is blobs: every proposal is a type-3 blob transaction

**[on-chain measured]** Full census of the `Proposed` event
(`0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213`) from the
`MainnetInbox` proxy over blocks 24,792,175–26,140,714:

| Quantity | Value |
|---|---|
| proposal events (logs) | 40,474 |
| of which the genesis event (id 0, proposer 0x0, 0 blobs) | 1 |
| proposal transactions with ≥1 blob | 40,473 (100 % of proposals) |
| proposals with exactly 1 blob | 40,465 (99.98 % of proposals) |
| proposals with 2 / 4 / 5 blobs | 4 / 2 / 2 |
| total blobs published | 40,491 |
| total blob bytes (× 131,072) | 5,307,236,352 B ≈ 5.31 GB **[derived]** |
| proposals per month 2026-04 … 2026-10 | 6,403 / 6,976 / 4,955 / 6,981 / 6,985 / 6,700 / 1,474 |

Method: `python3 scan_chunks.py 24792175 26140717 .` plus
`python3 finish_scan2.py 25922175 26140717 .`, then
`python3 decode_proposed.py .`; raw responses in `logs/chunk-*.json`
(135 chunks, each with its request metadata). The genesis log is at block
24,792,175, tx `0x3a7c8a84…`, and is the only log whose transaction is not a
proposal.

**Transaction-level check.** **[on-chain measured]** 41 proposals sampled every
1000th row (`python3 verify_tx_sample.py .`): the 40 real proposals are all
EIP-2718 **type `0x3`**; the only type-`0x2` row is the genesis event. For all
40, the transaction's `blobVersionedHashes` equal the event's recorded
`blobHashes` element-wise and in order, `to` is the inbox proxy, and
`receipt.blobGasUsed == 131,072 × nblobs`. Calldata is a constant 164 bytes —
the encoded `ProposeInput` (blob reference + deadline), not batch data.

**Contract-level check.** **[third-party reported — Blockscout verified
`MainnetInbox` source, methodology: verified source tied to on-chain bytecode by
SHA-256]** The deployed contract has no data-carrying calldata proposal path:
`ProposeInput` contains only a `LibBlobs.BlobReference`, and
`LibBlobs.validateBlobReference` requires `blobhash(i) != 0` for every blob in
the referenced range, reverting `BlobNotFound()` otherwise. There is no
`publish` entry point in the deployed ABI (function list: `propose`, `prove`,
`saveForcedInclusion`, …), i.e. **DA-07's permissionless publication record has
no production counterpart**; the only data path in production is the carried
blob reference inside `propose`.

### F2. Per-proposal blob counts: one blob of 131,072 bytes, with rare multi-blob proposals

**[on-chain measured]** From the same census, the event carries each source's
ordered `blobHashes`: 40,465 proposals reference exactly 1 blob, 4 reference 2,
2 reference 4, 2 reference 5. Two proposals carry two `DerivationSource`s
(2 sources: 2 events). One blob is 131,072 bytes (4096 field elements) by
EIP-4844; at one blob per proposal, production publishes 128 KiB per batch
regardless of how much of it is used (see F8).

### F3. Blob base fee and blob cost: the fee formula in force, and what a blob cost

**[on-chain measured]** For 24 blocks spread across the window (24,792,175 → 26,084,522, mean gap 56,189 blocks), the measured `blobGasPrice` in every blob transaction's receipt equals
`fake_exponential(1, excessBlobGas, 11,684,671)` and no other candidate
fraction: 18 of 18 blocks that contained blob transactions matched the BPO2
fraction; 0 matched the Cancun (3,338,477), Prague (5,007,716) or BPO1
(8,346,193) fractions. Command: `python3 blobfee_check.py . <24 blocks>`;
raw: `blobfee-check.json`. *(PB-AR-15: the probe's last block is 26,084,522 while the era's last proposal block is 26,140,714, so its final 56,192 blocks — ≈7.8 days at 12 s — were not probed; the 18/18 formula match is unaffected. Re-derived in [`f3_sample_and_probe.py`](./raw/s4-blob-binding/f3_sample_and_probe.py).)*

**[on-chain measured]** The in-force *parameters* are those of BPO2
(target 14 / max 21 blobs per block, base-fee update fraction 11,684,671) — see
F6 for the sources.

Blob base fee over the sampled proposal blocks (price per blob gas, wei), and
the resulting single-blob cost:

| Statistic | price (wei/blob gas) | cost of one blob (ETH) |
|---|---|---|
| min | 1,668,134 | 2.186e-7 |
| median | 6,991,223 | 9.164e-7 |
| p90 | 33,430,313 | 4.382e-6 |
| max | 675,350,452 | 8.852e-5 |

Source: proposal-block headers, `header_sample.py` (systematic sample, every
20th block of the 40,474 **distinct proposal blocks in `proposals_by_tx.csv`**, a 2,024-block set ending at 26,140,297; the committed `headers-sample.jsonl` holds **2,020** of them and ends at 26,137,748 — the 4 last sampled blocks, from 26,138,386, are absent, and the last ≈9.9 h of the era are unsampled). The price is computed by the EIP-4844 formula and the BPO2 fraction that F3 verified against receipts. The quoted **p90 = 33,430,313 wei is the artifact's own index rule** `sorted[int(0.9·n)]`; nearest-rank gives **33,158,382** and linear interpolation **33,185,575** — a 0.8 % method sensitivity the report did not state. **Re-running the committed `blob_price_stats.py` now combines the sample with `headers-late.jsonl` and `headers-sample-rev.jsonl` and yields n = 2,162, p50 6,838,873, p90 32,784,583**; the 2,020-row figures reproduce from `headers-sample.jsonl` alone under the same index rule ([`f3_sample_and_probe.py`](./raw/s4-blob-binding/f3_sample_and_probe.py) → [`f3-sample-and-probe.json`](./raw/s4-blob-binding/f3-sample-and-probe.json)). The EIP-4844 minimum (1 wei/blob gas) is **not** the operative price in this window: the measured fee is between ~6 and ~9 orders of magnitude above it. *(PB-AR-05: the earlier text attributed the 2,020 headers to the committed census's every-20th set and quoted p90 without naming the convention; min/median/max reproduce exactly, p90 is convention-dependent, and neither the stated sampling rule nor the committed script regenerates the sample.)*

### F4. KZG commitments: present, and consistent with the blob bytes — but the openings served by the public beacon API are placeholders

**[on-chain measured]** 15 beacon sidecars across 5 blocks
(`python3 sample_sidecars.py . /tmp/trusted_setup.txt 26140717 26135739 26120000 26110000 26000002`):

| Check | Result |
|---|---|
| `0x01 ‖ sha256(kzg_commitment)[1:]` equals the block's ordered blob versioned hash | **15 / 15 match** |
| commitment recomputed from the blob with c-kzg + mainnet trusted setup equals the sidecar commitment | **15 / 15 match** |
| sidecar opening proof `kzg_proof` verifies for (blob, commitment) | **0 / 15** |
| a proof freshly computed from the same blob verifies | **15 / 15** |
| `kzg_proof` is the constant `0xc0‖0…0` (compressed point at infinity) | **15 / 15** |

**[on-chain measured]** The full check on a Taiko proposal blob (block
26,135,739, proposal tx `0x280a53ed…`, blob ordinal 0) additionally:

* recomputed `y = p_D(z)` in Python using the bit-reversed evaluation form
  (element `j` evaluated at `ω^{brp12(j)}`) and it equals c-kzg's `y` for the
  same `z` — the convention the S4 harness must implement is confirmed against
  the reference library on a real blob;
* called the mainnet EIP-4844 point-evaluation precompile `0x0A` by
  `eth_call` with `(versioned_hash, z, y, commitment, proof)`; it returned
  `abi.encode(4096, BLS_MODULUS)` as specified.

**Interpretation, stated carefully.** From this public endpoint the
commitment↔blob and commitment↔versioned-hash bindings are verifiable and hold,
but the *served opening proof* is a placeholder and cannot be verified. The
on-chain `0x0A` check does verify a proof computed from the same blob, so the
precompile and the data are sound in that direction; what public data does
**not** show is that production blobs carry valid openings. (The constant
`0xc0‖0…0` is the compressed encoding of the point at infinity; this is a
property of the data the endpoint serves, not an inference about Ethereum's
consensus rules.) See §4 item 5.

### F5. The blob data path in production is blobhash-equality only; there is no on-chain KZG check

**[third-party reported — verified `MainnetInbox` source, methodology: fetched
by address from Blockscout, bytecode hash matched to on-chain code]** Searching
the 42 verified source files of the deployed implementation for
`pointEvaluation`, `0x0A`, `KZG` and `verifyKzgProof` yields **zero** hits. The
only blob check is `blobhash(i) != 0` in `LibBlobs.validateBlobReference`,
plus recording the hashes in the `Proposed` event. The Etna design's DA-03(ii)
on-chain opening check therefore has no production precedent; the deployed
protocol relies on the versioned hash alone for the carried path.

### F6. EIP-4844 parameters in force over the window (primary sources)

**[third-party reported]** Live beacon-node configuration
(`/eth/v1/config/spec`, Lighthouse v8.2.3, fetched 2026-10-07):

| Constant | Value |
|---|---|
| `MAX_BLOBS_PER_BLOCK` (Deneb) | 6 |
| `MAX_BLOBS_PER_BLOCK_ELECTRA` | 9 |
| `BLOB_SCHEDULE` | epoch 412672 → max 15; epoch 419072 → max 21 |
| `FIELD_ELEMENTS_PER_BLOB` | 4096 |
| `VERSIONED_HASH_VERSION_KZG` | 1 |
| `MIN_EPOCHS_FOR_BLOB_SIDECARS_REQUESTS` | 4096 (≈ 18.2 days) |

**[third-party reported — `ethereum/consensus-specs` `configs/mainnet.yaml`,
fetched 2026-10-07]** Same schedule with the fork dates in comments: BPO1
(2025-12-09) max 15; BPO2 (2026-01-07) max 21; Electra max 9.

**[third-party reported — EIP texts, fetched 2026-10-07]**

| Parameter | EIP-4844 (Cancun) | EIP-7691 (Prague) | EIP-7892 BPO1 | EIP-7892 BPO2 |
|---|---|---|---|---|
| target blobs/block | 3 | 6 | 10 | 14 |
| max blobs/block | 6 | 9 | 15 | 21 |
| base-fee update fraction | 3,338,477 | 5,007,716 | 8,346,193 | 11,684,671 |
| blob gas per blob | 131,072 | — | — | — |
| min blob base fee | 1 wei/blob gas | — | — | — |
| point-evaluation precompile | `0x0A`, 50,000 gas | — | — | — |

The EIP-7892 values are the specification's BPO table (that EIP presents the schedule as illustrative; the live node config above independently confirms the **max** values and epochs, and F3 confirms the BPO2 base-fee update fraction on chain — the **target** values rest on the EIP-7892 table). The **window 2026-04-02 →
2026-10-07 is entirely post-BPO2**: the parameter set in force is target 14 /
max 21 / fraction 11,684,671, and F3 confirms the fraction on chain. S4's pin
("Blob limits 6/9, EIP-7691") and S3's `n_blobs` sweep ceiling of 9 are
**stale by two forks**.

**[on-chain measured, bounded]** The block-level cap is a consensus parameter;
what the chain *used* is observable. In a systematic sample of the era's
blocks, the maximum number of blobs observed in one block was **21**
(3 of the 400 sampled blocks; full histogram in `network-blob-usage-sample.json`) — a lower
bound on the enforced maximum, not the maximum itself.

### F7. How the DA mode changed over time: blobs throughout, with a rare calldata path pre-Pacaya

**[on-chain measured, sampled windows]** 10,000-block windows, proposal events
of each era's contract and 20–30 transactions classified per window:

| Window (start block) | Contract / event | proposals | tx types sampled | blobs per tx | calldata bytes |
|---|---|---|---|---|---|
| 2024-08 (20,402,317) | TaikoL1 `BlockProposed` | 5,341 | 20 × `0x3` | 1 | 516 |
| 2024-08 `CalldataTxList` | TaikoL1 calldata path | **0** | — | — | — |
| 2025-02 (21,727,117) | TaikoL1 `BlockProposedV2` | 5,460 | 20 × `0x3` | 1 | 388–516 |
| 2025-02 `CalldataTxList` | TaikoL1 calldata path | **12** | 12 × `0x2` | **0** | 23,908–103,460 |
| 2025-06 (22,591,117) | Pacaya `BatchProposed` | 1,920 | 30 × `0x3` | 1 | 964 |
| 2025-09 (23,253,517) | Pacaya `BatchProposed` | 341 | 30 × `0x3` | 1–3 | 1,604–58,116 |
| 2026-02 (24,355,117) | Pacaya `BatchProposed` | 211 | 30 × `0x3` | 1 | 5,284–27,684 |
| 2026-04 → 10 (24,792,175) | Shasta `Proposed` | 40,474 | 40 × `0x3` | 1 (rare 2–5) | 164 |

(`CalldataTxList` topic `0xa07bc5e8…` identified in the repo's ontake bindings.
The 2025-02 window contains 40,048 logs in total at the old inbox; the proposal
event of that era is `BlockProposedV2`, and `CalldataTxList` fires on 12 of
them.) **Reading:** in every era sampled, blobs carry the batch data; the
calldata path exists as a rare fallback before Pacaya (≈0.2 % of proposals in
the one window where it appears) and is **absent** from the deployed Shasta
contract altogether. Public data therefore says Taiko's production DA mode is
blob-first, not "calldata with occasional blobs".

### F8. What the blobs contain, and how much of each blob is used

**[on-chain measured, bounded]** For the four most recent proposals
(`python3 blob_content.py .`): the event's blob-slice offset is 0 for all four;
non-zero bytes occupy 2,350–6,350 of the 131,072 bytes (1.8 %–4.8 %). The
highest non-zero 32-byte word index is **75 / 125 / 200 / 148** of the 4,096
words, so **the used prefixes are at most 2,432 / 4,032 / 6,432 / 4,768 bytes
(element 200 is the maximum) and the remainder of the blob is all zero** for
these proposals (`python3 sidecar_word_prefix.py .` →
[`blob-word-prefix.json`](./raw/s4-blob-binding/blob-word-prefix.json)). *(Correction
(PB-L-02): the earlier text read "the highest non-zero 32-byte word is element
148 or lower, so the used prefix is at most 4,768 bytes" — it took the last of
the four samples as the maximum of the four, and the claim had no supporting
artifact at all: `blob-content.json` records non-zero byte counts, not element
indices, and `git grep` found the figure only in this report and the synthesis.
The 6,350 non-zero bytes of the third blob alone exceed a 4,768-byte prefix,
which is what exposed it.)* The blob bytes after that prefix are nevertheless
inside the KZG commitment (the commitment over the whole blob recomputes from
the full 131,072 bytes, F4), which is exactly what DA-03(0) requires ("the
unused remainder of a blob MUST be committed too"). The framing inside the non-zero
region was **not** decoded — the deployed Shasta layout is not the Etna
PRF-07(0) payload framing, and a length-prefix interpretation at offset 0 did
not hold for these blobs; the payload-size claims above are therefore bounds on
the extent, not measurements of the payload.

### F9. Blob retrievability from public endpoints

**[on-chain measured]** Beacon sidecars were served for blocks at ages 0.1, 5.7,
25.1 and 39.2 days (sidecar counts 4, 3, 5, 3). Probes at 62.7 and 86.2 days
returned HTTP 403 from the same endpoint (rate limiting; not conclusive about
retention). **[third-party reported — beacon config]** the protocol's p2p
retention constant is 4096 epochs ≈ 18.2 days.

**[bounded]** For the pre-Shasta eras (2024-08 → 2026-02), the blobs are far
outside any tested retention window: only the versioned hashes recorded on L1
remain. *Bound:* blob content is retrievable from the tested public endpoint for
at least 39 days; nothing in this data shows it is retrievable for the
2024–2025 eras.

### F10. The specification's own arithmetic claim about the modulus reduction

**[derived; inputs from EIP-4844's `BLS_MODULUS`]** DA-03(iii) states the
`% BLS_MODULUS` reduction "biases the distribution by at most
`BLS_MODULUS / 2^256 ≈ 2^-127`". With
`BLS_MODULUS = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001`
(the earlier `≈ 2^254.86` is this constant to five significant figures).
`log2(BLS_MODULUS) = 254.8570894130472`, so
`BLS_MODULUS / 2^256 = 0.4528450563462822 = 2^(254.8570894130472 - 256) =
2^-1.142910586952811 ≈ 2^-1.14`, not `2^-127`. The derivation written out is
`log2(BLS_MODULUS) - 256 = 254.8570894130472 - 256 = -1.143` (3 s.f.). The per-value bound is
`ceil(2^256/p)/2^256 ≈ 1/p + 2^-256`, so the union bound over ≤4095 roots
(≈ `2^-243`) is unchanged; the sentence is what is wrong. This is the
pre-identified item in S4 §7 and it is confirmed by arithmetic here, but the
reviewer still must recompute it (S4 R6).

*Correction (this report, F10): the earlier summary line read
`BLS_MODULUS / 2^256 ≈ 0.731 ≈ 2^-0.45` — it had taken the ratio as the
exponent. `0.731` is the value of `2^-0.45`, not of the ratio; the ratio is
`0.4528 = 2^-1.14`. The pre-registered review's own §7
([S4-blob-binding-review.md](../S4-blob-binding-review.md) §7) already states
`2^-1.14`, so this correction makes the report consistent with it. No
conclusion changes: the specification's `2^-127` sentence was wrong either
way, and the per-value bound, the union bound over ≤ 4095 roots and the
`2^-243` headline are unaffected.*

---

## 4. What public data CANNOT establish here

1. **The in-guest blob-evaluation cost (S4 §5 metrics; gate T5).** No cycle
   count, wall-clock or peak-memory figure exists in public data, and none can
   be derived from L1. A first-party number requires the `blob-eval` guest on
   RISC Zero v3.0.6 and SP1 6.8.1 with the pinned accelerators. *Nothing in this
   report shortens that work.* The only adjacent public fact is that the
   evaluation form can be implemented against the reference library (F4), which
   is a correctness check, not a cost measurement.
2. **Contract/guest challenge identity (gate T2).** The 10,000-journal
   differential test is a property of two implementations of `z_i`; public data
   contains neither. The R4-PB-05 divergence risk is untouched by this report.
3. **The rejection matrix and the convention tests (gate T1, RC-1…RC-9, V1–V4).**
   These require the harness and, for RC-4/RC-5/RC-9, the Etna contract's own
   call path. The `0x0A` precompile's behaviour is measurable (F4), the Etna
   contract's is not deployed.
4. **The independent cryptographic review (gates T3/T4, claims 1–5).** The
   joint-event fixed-point argument, the Fiat–Shamir transcript's completeness,
   the canonical-field-element rule, and the search for a cheaper attack are
   arguments about the proof statement. On-chain data can show what production
   does; it cannot show that the design's binding is sound. **This half of S4
   remains exactly as specified: a human cryptographer, a frozen bundle, and per
   claim findings with a stated attack model.**
5. **That production blobs carry valid KZG openings.** The public beacon data
   sampled here serves placeholder proofs (F4), so the opening half of the
   binding could not be confirmed for any block; and even if it were, that would
   verify EIP-4844's own Fiat–Shamir challenge, not the Etna transcript's `z_i`.
6. **What the pre-Shasta blobs contained.** Retention (F9) makes the bytes
   unavailable; the historical claim in F7 is about transaction *shape*, not
   content.
7. **The Etna `land` path's L1 execution gas, K, `MAX_BATCH_BLOCKS`, the data
   budget `b`, and proving throughput (S1/S3).** No Etna contract is deployed
   and no guest runs, so public data bounds none of these; F1–F3 and F6–F7 only
   supply the prices, blob counts and parameter set those measurements must use.

---

## 5. What this changes in the specification

Nothing here promotes a placeholder to a value. Each row names the rule or
parameter, what the finding does to it, and whether that is enough to fix it.

| Spec item | Finding | Sufficient to fix, or only to bound? |
|---|---|---|
| S4 Pins: "Blob limits 6/9 (EIP-7691)"; S3 §3.1 `n_blobs` sweep {1,2,3,6,9}, P2 "≤ 9"; `09-parameters.html` "R × blobs_per_block ≤ 9 hard ceiling, R ≤ 6 sustainable" | F6: the window is post-BPO2 — target 14 / max 21 per block, update fraction 11,684,671; Pectra's 6/9 was superseded on 2025-12-09 and 2026-01-07 | **The constants are fixed** *(PB-L-07: this row still told an editor to "fix the constants" and that "the sweep must be re-based"; the re-base has since been applied — the S4 pre-registration's pins now read target 14 / maximum 21, spec/04 L1-01 and spec/09 row 120 read 21 hard / 14 sustainable, and the S1 and S3 sweeps carry 14 and 21)*. The *batch-length* consequence (R, K, `MAX_BATCH_BLOCKS`) remains **only bounded** — it depends on S3's measured `land` gas and the atomicity gate; the per-transaction blob ceiling is 21, not 9 |
| S3 §3 blob base fee sweep ("minimum 1 wei/blob gas … p50, p90, p99, max, 10×max") and the `C_land` cost model | F3: the measured price over the window's proposal blocks is 1.67 million–675 million wei/blob gas, i.e. orders of magnitude above the EIP-4844 minimum | **Bound**: the sweeps must be instantiated from the measured series, but the *fee-coverage* conclusion (`REWARD_QUOTE` floor, whether revenue covers landing + proving) still needs S1's proving cost and S3's measured `land` gas |
| [DA-07](../spec/04-l1-integration.html#DA-07)(5), [DA-03](../spec/04-l1-integration.html#DA-03)(i) carried path (`blobhash(i) != 0`, ordered hashes recorded) | F1/F2/F5: exercised in production on 40,473 proposals; event hashes equal the transaction's versioned hashes on every sampled proposal | **Sufficient to confirm implementability of the carried check**; the referenced/publication-record path (DA-07/DA-08, D-11) has no production counterpart and stays open |
| [DA-03](../spec/04-l1-integration.html#DA-03)(ii), the on-chain `0x0A` opening check | F5: absent from the deployed contract; F4: the precompile itself behaves as specified on a real Taiko blob | **Bound only**: the precompile is understood, the design's check and its transcript binding are not exercised anywhere and remain for the reviewer |
| [PRF-07](../spec/05-proof-statement.html#PRF-07)(b), the binding between published bytes and the proven range | F4: commitment↔blob↔versioned-hash verified, but the openings served by the public endpoint are placeholders; F10: the `2^-127` sentence is wrong by ~126 bits | **Neither**: this is the cryptographic half. The review (S4 §3.5 claims 1–5) is still required, and the `2^-127` correction is a required review output (S4 §7) |
| [DA-07](../spec/04-l1-integration.html#DA-07)(1) "blobs are still retrievable"; `ARCHIVE_REQUIREMENT`; `PUB_RECORD_RETENTION` / `T_PROVE_DEADLINE` | F9: sidecars served up to 39.2 days from the tested endpoint; protocol p2p retention constant 4096 epochs ≈ 18.2 days; pre-Shasta blobs are gone | **Bound**: any retention window the design assumes must fit inside the measured retrieval window it is willing to pay for; the design's own archive mandate is what would extend it |
| [DA-03](../spec/04-l1-integration.html#DA-03)(0) "every published byte is inside the commitment, including the unused remainder" | F8: production pays for a full 131,072-byte blob per proposal while only ~2.3–6.4 KB is non-zero, and the commitment is over the whole blob | **Bound**: the commitment rule is consistent with production; the *data budget* consequence (S1's `b`, K) needs the measured payload sizes, which this report only bounds |
| [DA-03](../spec/04-l1-integration.html#DA-03)(iii) reduction-bias sentence | F10: `BLS_MODULUS/2^256 = 0.4528 ≈ 2^-1.14`, not `2^-127` | **Sufficient to fix the text** (pure arithmetic), subject to the reviewer's independent recomputation. *(Correction: this row earlier read `2^-0.45` — the ratio had been read as the exponent; the pre-registered review §7 states `2^-1.14`, and the conclusion is unchanged — see F10.)* |

---

## 6. Reproducing this report

1. Scripts and raw responses: `raw/s4-blob-binding/` — `logs/` (census),
   `sources/` (EIP and consensus-specs snapshots, c-kzg source), `blobs/`
   (per-blob verification records), and the JSON artifacts named beside each
   finding.
2. Exact commands in order: `raw/s4-blob-binding/COMMANDS.md`.
3. Known limits of the substitution, repeated for the reader: no hardware, no
   testnet, no independent cryptographer; the cryptographic review half of S4
   is untouched; the placeholders in §3 F4 are properties of the public data
   this environment serves, reported as observed.
