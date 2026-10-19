# ETNA_CUT schema v1 (Task 6 frozen sampled-runtime interface)

The tester-owned `EtnaInboxCutsConformance.t.sol` adds the separate
`test_land_ContiguousCuts` entry point. It leaves the 65 `LAND_OBSERVATION` rows and
strict existing identity gates unchanged. Stage it as
`test/layer1/etna/EtnaInboxCutsConformance.t.sol` in the authenticated paired protocol.

The fixed six ordered per-block inclusion counts are `[1,0,1,1,0,1]`. Four entries
are admitted through actual `saveForcedInclusion`, paying its actual current fee
immediately before each admission. The resulting four stored uint64 gwei fees are
emitted as `feesGwei`, decimal strings. A snapshot after admission preserves the same
proxy, registry, queue, fees and balance for every plan. No production storage is
seeded for this test. Terminal block hash is `bytes32(0x1000 + height)` and state
root is `bytes32(0x2000 + height)`; all plans land height 6. Every cut lands with
`l2RewardRecipient = 0xfeed` and `baseFeeAmount = sum of h gwei` over its blocks.

Exactly four JSON records are printed, each prefixed `ETNA_CUT `:

- `cut-6`: cuts `[6]`.
- `cut-1-6`: cuts `[1,6]`.
- `cut-2-4-6`: cuts `[2,4,6]`.
- `cut-every`: cuts `[1,2,3,4,5,6]`.

Fields: `schemaVersion:1`, unique `id`, `steps:[1,0,1,1,0,1]`, `cuts`,
`initialHead:0`, `finalHead:4`, `initialHeight:0`, `finalHeight:6`, `feesGwei`
(exact four decimal strings), `paidWei` (decimal string), `intervals` (one object
per cut, in order): `{before,after,paidWei,lastHeight}`. Empty intervals remain
present, have zero payment and no actual value CALL/consumption event. Nonempty
intervals exactly partition `[0,4)` once. Additional evidence fields may include
actual final checkpoint/hash/root, proxy and registry identity.

The harness asserts actual Inbox and concrete SignalService checkpoints, the exact
consumption event interval/amount/recipient, actual successful value CALL target
and amount from the call journal, and the absence of payment/consumption for empty
intervals. It compares final head, terminal checkpoint and total executed transfers
across all four plans. Each landing must emit exactly one `BatchRewardRecorded` whose id,
recipient and fields match its receipt; the observed amounts total 21 gwei in every plan,
receipt ids are distinct, and every earlier receipt slot is intact after the last cut. Reward
fields are harness assertions only; they are not part of the `ETNA_CUT` record. Recorded logs concern successful calls in this test; committed
log interpretation still uses the EVM journal law, not an independent receipt API.
The controlled accepting void verifier is not evidence of guest soundness.

This finite runtime sampling is separate from the Lean theorem over arbitrary finite
valid cuts. The existing actual 36-preimage/65-row differential remains the statement
encoding leg; this test does not replace or weaken it.
