# Published-public-PoP Registry lifecycle

H01 executes the actual pinned `EtnaStakingRegistry` through a fresh ERC1967
proxy at the published registration domain. It imports only the Foundry `Vm`
interface, the actual Registry/interface and the actual ERC1967 proxy. It does
not inherit the existing Registry8, identity or recovery replay bases. Those
older executions used test-key setup and retain their original attribution.

## Public input and setup boundary

`registry_public/registration.json` is the exact allowlisted public extract:

| Input                     | Pin                                                                |
| ------------------------- | ------------------------------------------------------------------ |
| Contract commit           | `89f419915de4b73bb57c53bf970f6dea9e8e8c8c`                         |
| Published source          | `testdata/etna_vectors/vectors.json`                               |
| Published source Git blob | `e069e2930143cbaf126d46532a96179764ec0ab6`                         |
| Published source SHA256   | `85d9df59bbc1709950be8cd8b248a3871523229afabd3d4e65b8027d6e4529de` |
| Exact extract SHA256      | `e441ece5cd83e70c2008da00b144f3411a1009dda3e18ce8cda9a4bebb208cdf` |
| Domain                    | chain `1`, Registry `0x2222222222222222222222222222222222222222`   |

The public source was extracted separately from that pinned public blob. The
extract contains exactly twelve `register_digests` rows and six public points.
The only per-registration fields are `name`, `key`, `owner`, `digest`, `pop_sig`,
`l1_chain_id`, `registry`, `domain_separator`; the only per-point fields are
`name`, `public_key`, `ck_addr`, `ck_prefix`, `ck_x`, `ck_y`, `entry_key`. Top-level
fields contain schema, provenance, deployment and those two arrays. No private
material is present or consumed. The two owner-cohort tests execute all twelve
published proofs on separate fresh deployments, including the leading-zero X
point. Each setup checks all twelve actual `registerDigest(owner)` values before
registration; each actual registration repeats its exact digest check. Public
point compression, published key address and lifetime identity are also checked.

The only storage seeded with a cheatcode is the ERC1967 implementation pointer;
proxy runtime code is placed at the public domain address. Actual constructor
validation and actual `init(admin)` run. No Registry business storage, stake,
checkpoint, held slot or history is seeded. Literal public callers represent
owners, admin, public actor, sink and payee; they are impersonation premises.
No private-key generation, address derivation from private keys, signature
creation, RPC, environment reads or FFI executes.

`PublicReplayToken` is a minimal exact-transfer token with no callbacks or fees.
Both public owners start with 100 units and approve 100. `PublicReplayInbox`
always reports initialized and unlocked; its selected committee snapshot is an
explicit mock input. This does not authenticate or prove a real Inbox landing,
DAO authorization, token deployment, deployment history or governance decision.
Block 10 starts at timestamp 1000; scheduled later blocks advance timestamp by
12 seconds per block. Forfeiture at block 15 uses its inclusive deadline 1060.
Parameters are minStake 4, activationDelay 2, exitDelay 2, withdrawalDelay 2,
forfeitBps 5000 (or 10000 in the separate full-forfeit test), bounty 0, L2 id 167.

## Literal execution ledgers

All registrations below occur at block 10, stake 4, activeFrom 12, no-exit
sentinel `2^48-1`. The published PoP signs ownership/domain, so this legal amount
needs no new signature. Every listed successful state-changing action checks its
complete event stream, including token transfers, emitter, all topics and data.

| Exact test suffix after `test_public_`    | Required progress                                                                                                                                                    |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `allPublishedOwnerAAPoPs()`               | Six real AA registrations in block 10; one coalesced checkpoint; topUp 4 at 12; public activation at 14; closed block-10 checkpoint retained                         |
| `allPublishedOwnerBBPoPs()`               | Same chronology using all six BB proofs on fresh state                                                                                                               |
| `repeatedActivationAndClosedHistory()`    | topUp 4 at 12, activation at 13 refuses, public activation at 14; topUp 4 at 15, public activation at 17; final effective 12 / pending 0; checkpoints 10,14,17       |
| `pendingLiabilityConfirmationAndPayout()` | The liability ledger below, through payout and permanent-key checks                                                                                                  |
| `fullForfeitPublicZeroWithdrawal()`       | Separate 10000bps configuration; forfeit all 4 at 15; first confirmation 16; public withdrawal at 18 emits recipient zero / amount zero, with no zero token transfer |

| Liability action / block                    | Effective | Pending / ready | Custody | Sink | Payee | First confirmation |
| ------------------------------------------- | --------: | --------------: | ------: | ---: | ----: | -----------------: |
| register / 10                               |         4 |           0 / 0 |       4 |    0 |     0 |                  0 |
| topUp 12 / 12                               |         4 |         12 / 14 |      16 |    0 |     0 |                  0 |
| maturity, deliberately no activation / 14   |         4 |         12 / 14 |      16 |    0 |     0 |                  0 |
| forfeit 5000bps / 15                        |         0 |          8 / 14 |       8 |    8 |     0 |                  0 |
| snapshot 14, confirmation refuses / 16      |         0 |          8 / 14 |       8 |    8 |     0 |                  0 |
| snapshot 15, first public confirmation / 16 |         0 |          8 / 14 |       8 |    8 |     0 |                 16 |
| repeat confirmation / 17                    |         0 |          8 / 14 |       8 |    8 |     0 |                 16 |
| owner early withdrawal refuses / 17         |         0 |          8 / 14 |       8 |    8 |     0 |                 16 |
| stranger positive withdrawal refuses / 18   |         0 |          8 / 14 |       8 |    8 |     0 |                 16 |
| owner withdrawal / 18                       |         0 |           0 / 0 |       0 |    8 |     8 |                  0 |

The 16-unit balance loses the literal 8-unit penalty, effective 4 first and then
pending 4. Raw custody must back the independently expected remaining liability.
Owner cash, allowance, sink and payee must conserve deposits. Repeated
confirmation requires complete raw no-op equality and zero logs, beyond just
checking the first-confirmation field. Maturity alone and top-ups leave entry
roots and all historical checkpoints unchanged. Withdrawal clears the held slot,
owner, confirmation and top-up fields, while the issued bond retains its key,
activation, exit, permanent key index and forfeiture flag. A second withdrawal
and re-registration of the same public key must refuse.

Additional negative controls use a valid public AA PoP with the wrong owner,
just-before-ready activation, an insufficient snapshot, early withdrawal,
zero-effective top-up, a stranger claiming positive principal, a withdrawn bond
and an already-used key. They require exact revert bytes, no logs and identical
complete selected raw state before and after failure.

## Independent observation

The expected ledger is built from literal public fields and the scheduled legal
actions. No Registry getter, production leaf helper, production tree update or
mutated write helper computes an expected value. The independent leaf is the
canonical seven-word ABI encoding of `ETNA_REG_ENTRY_V1`, slot, prefix, X,
effective stake, active block and exit block. A small full binary reduction pads
the occupied prefix with zero leaves to its next power of two. An empty used
slot hashes its all-zero entry, rather than becoming an unused zero leaf.

Observers check raw namespace slots and packed array/mapping words directly via
`Vm.load`, alongside supplementary getter agreement. They check held bond/slot
mirrors, issued/key/owner identity, first confirmation, pending amounts/readiness
and lifetime forfeiture. Expected checkpoint records are frozen at each legal
write and all closed rows are rechecked after later actions; same-block writes
replace only that block's expected final row. Comparing only current root with
current checkpoint would miss a consistent bad write, so both are separately
compared against independent literal roots.

The before/after digest covers ordinary slots 0..250, the implementation pointer,
all eight Registry namespace headers, eight checkpoint records, six entry/bond
records, their owner/confirmation/top-up/key/slot/forfeiture mappings, every one
of the 8192 admission-index cells, all tree nodes of the padded eight-leaf prefix,
all six actor token balances/Registry allowances, token transfer counter and Inbox
snapshot. This is complete for the selected bounded histories and their legal
write footprint; it is not an enumeration of arbitrary EVM storage. All revert
bytes and logs are also checked. No business state is written by the observer.

Only these expensive raw digest sweeps pause gas metering, resuming before each
actual public call and afterward. All 8192 index cells remain checked. This lane
makes no Registry gas, EVM budget, capacity or performance claim; its Forge gas
numbers include fixture/observer overhead and are not meaningful measurements.

## Execution and limits

Use the existing `sensitivity/run.py` supervisor/classifier and
`conformance/run_isolated.py`, an external runtime manifest and exact full
identities for only `EtnaRegistryPublicReplayTest`. Run offline with FFI disabled,
empty scripts, read-only source/dependency/test mounts, no network or host home
or Git metadata, and only the existing physical Foundry build cache writable
under its canonical `.formal-cache.lock`. No dependency installation, duplicate
build cache or old Forge obligation is needed.

The authored diagnostic actual-source fault omits only pending-principal
deduction in `forfeit`. Original and same-copy restored source must pass all
five exact identities; the private mutant must fail only
`test_public_pendingLiabilityConfirmationAndPayout()` with
`public ledger: pending principal`. A wrong failure, setup failure, resource
limit or parse error is INCONCLUSIVE. The evidence records the original
564-entry source verification, before/after test/tool/dependency hashes,
private mutation hashes, actual restored execution and unchanged source inputs.
Independent review and an independently chosen behavioral challenge remain
separate gates. Fault injection is sensitivity evidence, not a protocol defect.

Six public points cannot establish 4096-slot displacement, full-capacity
admission/gas feasibility, vote signing, double-sign admission, authentic
committee selection, real proving, token callbacks, concurrent transactions or
live chain behavior. Existing older Forge evidence remains historical test-key
execution. This new lane does not relabel or weaken it.

The strongest remaining false-green hypothesis is a shared misunderstanding of
canonical encoding or the declared deployment/Inbox premises. Independent raw
packing/root review and an independently chosen checkpoint or confirmation fault
challenge that hypothesis; they do not establish all Registry behavior. Newly
exercised progress is real repeated activation, pending-inclusive forfeiture,
first-confirmation preservation and exact-delay payout/public-zero withdrawal.
An absence of protocol findings is limited to these selected legal histories.
