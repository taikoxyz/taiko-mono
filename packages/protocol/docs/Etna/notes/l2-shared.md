# Phase 1: L2 anchor and shared-contract evidence

Baseline: `961bbd8ff55a0f66f44ad04160eb51638d655b66`. Scope: source code at the supplied baseline; no contract deployment, live ownership, proxy implementation, or chain-state claims are made. Root and protocol `CLAUDE.md` were read. In this note **proven** means demonstrated by the cited source and ordinary EVM semantics; **assumed** means an external system condition; **open** means additional evidence is required. This is a description and constraint inventory, not an Etna design.

## 1. Anchor transaction and checkpoint flow

**Proven.** Current `Anchor` identifies itself as the Shasta anchoring contract. It has immutable `checkpointStore` and `l1ChainId`, validates the constructor chain IDs, and initializes an owner. Its entry point is `anchorV4(ICheckpointStore.Checkpoint calldata _checkpoint) external`, restricted to `GOLDEN_TOUCH_ADDRESS = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec`, with a non-reentrancy guard. The source advertises `ANCHOR_GAS_LIMIT = 1_000_000`, but the Solidity entry point does not itself compare transaction gas or transaction position. [packages/protocol/contracts/layer2/core/Anchor.sol:12–17,36–50,86–114,121–138]

**Proven.** For each call the contract compares the stored ancestor digest with the expected digest, then updates it. `_calcAncestorsHash` hashes an array containing 255 historical block hashes and the chain ID, replacing the parent entry to compute the next digest. A later call in the same block normally encounters a digest mismatch; the ancestor check also detects skipped progression. This is a contract-level consistency check, not authentication of the supplied L1 state root. It stores the L2 parent's block hash in `blockHashes`. [packages/protocol/contracts/layer2/core/Anchor.sol:129–137,173–185,194–228]

**Proven.** A checkpoint is written only if its `blockNumber` exceeds `_blockState.anchorBlockNumber`. A same-or-older number is ignored by `_validateBlock`; the function contains no comparison of its hash/root against an independently authenticated L1 header. For a newer checkpoint, the trusted `checkpointStore.saveCheckpoint` call and the `anchorBlockNumber` update happen atomically. Thus correct L1 values and first-transaction/gas rules are derivation/client/proof obligations, not guarantees furnished by this Solidity method alone. `Derivation.md` explicitly assigns L1 hash/root matching to the node/driver, and exact 1,000,000 anchor gas to node software. [packages/protocol/contracts/layer2/core/Anchor.sol:173–185; packages/protocol/docs/Derivation.md:226–240,319–345]

**Proven.** The documented derivation rejects non-monotonic, future, and excessively lagged anchors by replacing the source with the default manifest. Forced sources intentionally inherit the parent anchor. The L2 block header carries the proposal ID and fee-sharing metadata; state/transaction/receipt roots arise after execution. [packages/protocol/docs/Derivation.md:226–240,294–317]

**Proven.** L1 `Inbox.prove(bytes _data, bytes _proof)` builds its checkpoint from the commitment's end L2 block number, end L2 state root, and last transition block hash. It calls `SignalService.saveCheckpoint`, updates finalized state, emits `Proved`, and finally invokes `_proofVerifier.verifyProof`. Although verification occurs after writes in source order, a verifier revert rolls back the whole transaction, including checkpoint writes. “Saved checkpoint” means an Inbox-accepted validity transition; it is not an independent claim that the enclosing Ethereum block has achieved consensus finality. [packages/protocol/contracts/layer1/core/impl/Inbox.sol:321–398]

**Assumed.** Consensus and the proving system enforce correct derivation and the system-transaction rules, and Ethereum eventually finalizes a canonical history. This note does not establish those properties from the anchor alone.

## 2. Exact shared interface

**Proven.** Both directions use the same interface, defined at [packages/protocol/contracts/shared/signal/ICheckpointStore.sol:7–43]:

```solidity
struct Checkpoint {
    uint48 blockNumber;
    bytes32 blockHash;
    bytes32 stateRoot;
}
event CheckpointSaved(uint48 indexed blockNumber, bytes32 blockHash, bytes32 stateRoot);
function saveCheckpoint(Checkpoint calldata _checkpoint) external;
function getCheckpoint(uint48 _blockNumber) external view returns (Checkpoint memory);
```

**Proven.** `SignalService` stores `CheckpointRecord { bytes32 blockHash; bytes32 stateRoot; }` under `mapping(uint256 version => mapping(uint48 blockNumber => CheckpointRecord))`. `VERSION` is currently `1`. Only immutable `_authorizedSyncer` may call `saveCheckpoint`; the source identifies this as Inbox on L1 and Anchor on L2. Nonzero hash/root are checked, but no monotonicity or immutability-by-height check is present: the authorized syncer can overwrite a checkpoint at the same height. Checkpoint absence is detected by zero block hash. [packages/protocol/contracts/shared/signal/SignalService.sol:23–40,49–75,173–217]

| Destination contract | Authorized source of a checkpoint | What its checkpoint describes |
|---|---|---|
| L1 SignalService | L1 Inbox | End L2 block hash and state root accepted by Inbox proof verification |
| L2 SignalService | L2 Anchor | L1 block hash and state root supplied through the derived anchor transaction |

The first row is **proven** by `Inbox.sol:364–398`; the second by `Anchor.sol:173–185`; the intended authority wiring is **proven as source intent** at `SignalService.sol:35–40`, but actual deployment constructor values remain **open**.

**Proven.** The public message interface is [packages/protocol/contracts/shared/signal/ISignalService.sol:24–49,51–108]:

```solidity
struct HopProof {
    uint64 chainId;
    uint64 blockId;
    bytes32 rootHash;
    CacheOption cacheOption;
    bytes[] accountProof;
    bytes[] storageProof;
}
event SignalSent(address app, bytes32 signal, bytes32 slot, bytes32 value);
function sendSignal(bytes32 _signal) external returns (bytes32 slot_);
function proveSignalReceived(uint64 _chainId, address _app, bytes32 _signal,
    bytes calldata _proof) external returns (uint256 numCacheOps_);
function verifySignalReceived(uint64 _chainId, address _app, bytes32 _signal,
    bytes calldata _proof) external view;
function isSignalSent(address _app, bytes32 _signal) external view returns (bool);
function isSignalSent(bytes32 _signalSlot) external view returns (bool);
```

**Proven.** Sending a signal is permissionless, with the app fixed to `msg.sender`. The service writes `_signal` at `keccak256(abi.encodePacked("SIGNAL", uint64(block.chainid), app, signal))`. These deliberately hashed storage slots are part of the bridge's proof compatibility surface; keeping only ordinary Solidity layout slots is insufficient. [packages/protocol/contracts/shared/signal/SignalService.sol:106–109,155–170,220–250]

**Proven.** For a nonempty proof the implementation decodes `HopProof[]` but requires exactly one element, both account and storage proof arrays nonempty, and `blockId <= uint48.max`. It reads the checkpoint at that height, requires equality of `proof.rootHash` with the saved state root, and verifies the remote SignalService account and signal storage slot against that state root. `_remoteSignalService` is an implementation immutable. `proof.chainId` and the deprecated cache option do not drive current verification; the function argument `_chainId` determines the signal slot. Empty `_proof` succeeds only for an already cached received-signal slot under `VERSION`. A successful `proveSignalReceived` writes that cache and returns zero cache operations. [packages/protocol/contracts/shared/signal/SignalService.sol:39–40,113–127,253–296]

**Constraint, proven from those checks.** Etna must supply authenticated full EVM state roots, retain the remote SignalService account address and signal slot domain, and explicitly manage checkpoint/cache continuity. Publishing a receipts root, an unproven soft state root, a transaction root, or merely a block hash does not meet this interface. Existing trusted checkpoints and cached signals cannot be assumed safe after changing what a checkpoint means. A version bump invalidates both checkpoint and received-signal lookup namespaces by design. [packages/protocol/contracts/shared/signal/SignalService.sol:49–73,284–296]

## 3. Bridge/vault trust and asset flows

**Proven.** `Bridge.sendMessage` checks owners/recipient, destination chain support, fee/gas constraints, and `msg.value == value + fee`; it assigns an ID, source sender and chain, then signals `hashMessage(message)`. Hashing is `keccak256(abi.encode("TAIKO_MESSAGE", message))`. Destination support comes from a resolver entry for the remote Bridge. [packages/protocol/contracts/shared/bridge/Bridge.sol:217–254,513–524,535–538]

**Proven.** `processMessage` is normally permissionless, checks NEW status, verifies the source signal against the resolved source Bridge, invokes the destination, calculates the relayer reward/refund, and records DONE or RETRIABLE. A user choosing `gasLimit == 0` reserves processing to `destOwner`, an asset-owner choice rather than a global administrative role. The relayer proof-size limit is 200,000 bytes. Quota exhaustion can revert release; the quota manager is optional. [packages/protocol/contracts/shared/bridge/Bridge.sol:51–52,307–403,628–654]

**Proven.** Retry requires RETRIABLE status; final-attempt and zero-gas messages have owner constraints. When `recallEnabled`, a failed final retry or `failMessage` by the destination owner emits a failed-message signal. Source-chain recall verifies that failed signal and sends assets back to the source owner or calls the source vault's recall hook. `recallEnabled` is immutable, so source presence does not prove recall is enabled on any particular deployment. [packages/protocol/contracts/shared/bridge/Bridge.sol:112–114,151–175,260–300,406–465,544–545]

**Proven.** Vault receivers do not accept arbitrary callers. `BaseVault.checkProcessMessageContext` requires the local resolved Bridge, then requires the bridge context's original sender to equal the same vault name on the source chain. Thus two trust edges matter: root authenticity and resolver correctness. This contract-to-contract authorization is necessary to prevent forged mint/withdraw calls; it should not be confused with a human operator allowlist. [packages/protocol/contracts/shared/vault/BaseVault.sol:53–62; packages/protocol/contracts/shared/common/EssentialResolverContract.sol:61–90]

**Proven.** ERC20 send locks canonical tokens using the observed balance delta, or transfers and burns mapped bridged tokens. Receipt transfers canonical collateral if the canonical chain ID is local, otherwise finds/deploys a wrapper and mints. The received amount is quota-metered if a manager is configured; recall returns tokens without consuming quota. Wrapper deployment uses the resolver's bridged-token implementation and gives the wrapper the vault's owner. [packages/protocol/contracts/shared/vault/ERC20Vault.sol:438–485,507–534,580–648]

**Proven.** ERC721 and ERC1155 use the same lock-or-burn / release-or-mint pattern with their respective token IDs and amounts. Their canonical-to-bridged mappings are reused on subsequent receipts. First receipt can deploy a token wrapper proxy; that is separate from deploying a new Vault address. [packages/protocol/contracts/shared/vault/ERC721Vault.sol:94–107,170–188,197–257; packages/protocol/contracts/shared/vault/ERC1155Vault.sol:99–114,218–235,243–304]

**Proven.** An additional administrative asset surface exists in wrapper code: `BridgedERC20.mint` normally authorizes either the owner or immutable ERC20 Vault, and `BridgedERC20V2` inherits it. ERC20 transfers also honor the inherited pause flag. ERC721/1155 mint/burn are vault-only but likewise pause-gated. Removing proposer/prover whitelists alone therefore cannot establish “DAO governs only upgradeability” across the reused bridge system. [packages/protocol/contracts/shared/vault/BridgedERC20.sol:112–141,168–181; packages/protocol/contracts/shared/vault/BridgedERC20V2.sol:19; packages/protocol/contracts/shared/vault/BridgedERC721.sol:58–71,99–107; packages/protocol/contracts/shared/vault/BridgedERC1155.sol:70–96]

## 4. Storage, proxy, immutable and resolver inventory

**Proven source-layout inventory.** The generated layout files document existing inheritance slots and must be revalidated against the exact deployed implementation before an upgrade. Slot numbers below are not claims about live deployments.

| Contract | Existing persistent state to preserve | Evidence |
|---|---|---|
| All Essential-derived proxies | initialization slot 0; owner 51; pending owner 101; old resolver gap 151–200; deprecated reentry byte and paused byte 201; gap 202–250 | `contracts/shared/signal/SignalService_Layout.sol:10–20` and corresponding layout files |
| Anchor | `blockHashes` 251; Pacaya reserved slots 252–254; deprecated proposal ID 255; block state 256–257; gap begins 258 | `contracts/layer2/core/Anchor_Layout.sol:21–25` |
| SignalService | Pacaya reservations 251–252; versioned received-signal map 253; versioned checkpoint map 254; gap begins 255; separately hashed signal slots | `contracts/shared/signal/SignalService_Layout.sol:21–24`; `SignalService.sol:155–170,232–235` |
| Bridge | reserved byte area and nextMessageId 251; messageStatus 252; retained old context 253–254; reservations 255–256; gap begins 257 | `contracts/shared/bridge/Bridge_Layout.sol:21–27` |
| ERC20Vault | BaseVault gap 251–300; bridgedToCanonical 301; canonicalToBridged 302; btokenDenylist 303; lastMigrationStart 304; gap begins 305 | `contracts/shared/vault/ERC20Vault_Layout.sol:21–26` |
| ERC721Vault | BaseVault gap 251–300; maps 301/302; BaseNFTVault gap 303–350; derived gap 351–400 | `contracts/shared/vault/ERC721Vault_Layout.sol:21–25` |
| ERC1155Vault | same maps and base gaps; additional inherited gaps through slot 500 | `contracts/shared/vault/ERC1155Vault_Layout.sol:21–27` |

All paths abbreviated in this table begin `packages/protocol/`. The authoritative full inheritance and wrapper layouts remain the individual `*_Layout.sol` files; a future wrapper upgrade must preserve its ERC balances, allowances, nonces, metadata and migration state as well, not merely the Vault maps. For ERC20V2, permit nonce storage and inherited ERC20/EIP712 bases are visible at [packages/protocol/contracts/shared/vault/BridgedERC20V2.sol:19–28,39–67].

**Proven.** Essential contracts use UUPS and two-step Ownable; upgrade authorization is `onlyOwner`. Their reentrancy guard now uses transient storage; its old persistent byte remains reserved. The immutable resolver pointer is set in `EssentialResolverContract`'s constructor, so replacing a resolver requires either changing that referenced resolver's behavior or a new compatible implementation with new immutable wiring. [packages/protocol/contracts/shared/common/EssentialContract.sol:4–10,17–36,207–223; packages/protocol/contracts/shared/common/EssentialResolverContract.sol:47–50]

**Proven.** Bridge's implementation immutables are SignalService, optional QuotaManager, pauser and recallEnabled, plus inherited resolver. SignalService's are authorized syncer, remote SignalService and pauser. ERC20Vault's are quotaManager and inherited resolver. NFT Vaults use inherited resolver. Wrappers pin their respective Vault. These values are implementation bytecode, not ordinary proxy storage setters. [packages/protocol/contracts/shared/bridge/Bridge.sol:105–175; packages/protocol/contracts/shared/signal/SignalService.sol:35–43,81–92; packages/protocol/contracts/shared/vault/ERC20Vault.sol:37,186–188; packages/protocol/contracts/shared/vault/BaseVault.sol:38; packages/protocol/contracts/shared/vault/BridgedERC20.sol:25; packages/protocol/contracts/shared/vault/BridgedERC721.sol:21; packages/protocol/contracts/shared/vault/BridgedERC1155.sol:21]

**Proven.** ForkRouter delegates to one of two immutable implementations selected by `shouldRouteToOldFork(msg.sig)`, sharing the proxy storage; its comment requires routed implementations to reserve slots 0–150. It retains owner-gated UUPS upgrades. The tree contains `AnchorForkRouter_Layout.sol` and `SignalServiceForkRouter_Layout.sol` but no corresponding concrete `.sol` source under those names in the assigned directories; these layouts do not establish current routing behavior. [packages/protocol/contracts/shared/fork-router/ForkRouter.sol:11–66; packages/protocol/contracts/shared/fork-router/ForkRouter_Layout.sol:10–16; packages/protocol/contracts/layer2/core/AnchorForkRouter_Layout.sol:4–16; packages/protocol/contracts/shared/signal/SignalServiceForkRouter_Layout.sol:4–16]

### Exact frozen-directory inventory and adjacent dependencies

**Proven by source-tree enumeration at the baseline.** Inventory paths below are relative to `packages/protocol/contracts/shared/`; listing a file does not imply it needs an Etna change.

| Directory | Executable contracts and interfaces | Layout/document artifacts |
|---|---|---|
| `signal/` | `ICheckpointStore.sol`, `ISignalService.sol`, `SignalService.sol` | `SignalService_Layout.sol`, `SignalServiceForkRouter_Layout.sol` |
| `bridge/` | `Bridge.sol`, `IBridge.sol`, `IQuotaManager.sol`, `QuotaManager.sol` | `Bridge_Layout.sol`, `README.md` |
| `vault/` | `BaseVault.sol`, `BaseNFTVault.sol`, `ERC20Vault.sol`, `ERC721Vault.sol`, `ERC1155Vault.sol`, `BridgedERC20.sol`, `BridgedERC20V2.sol`, `BridgedERC721.sol`, `BridgedERC1155.sol`, `IBridgedERC20.sol`, `IBridgedERC721.sol`, `IBridgedERC1155.sol`, `IPermit2.sol`, `LibBridgedToken.sol` | `ERC20Vault_Layout.sol`, `ERC721Vault_Layout.sol`, `ERC1155Vault_Layout.sol`, `BridgedERC20_Layout.sol`, `BridgedERC20V2_Layout.sol`, `BridgedERC721_Layout.sol`, `BridgedERC1155_Layout.sol` |
| `fork-router/` | `ForkRouter.sol` | `ForkRouter_Layout.sol` |

Adjacent authority dependencies are `shared/common/{EssentialContract,EssentialResolverContract,DefaultResolver,ResolverBase,IResolver}.sol`, `shared/common/DefaultResolver_Layout.sol`, OpenZeppelin UUPS/ERC1967/Ownable bases and token bases, and each resolver's bridged-token implementation entries. Import/wiring evidence: `BaseVault.sol:4–9,38`; `EssentialContract.sol:4–10`; `EssentialResolverContract.sol:4–7,47–50`; `DefaultResolver.sol:4–14`; `ForkRouter.sol:4–7`; `ERC20Vault.sol:640–646`; `ERC721Vault.sol:249–255`; `ERC1155Vault.sol:295–301`. The quota manager is **inside** `shared/bridge/`, is non-upgradeable, and has owner configuration; the resolver is **outside** the frozen four directories and is upgradeable. [packages/protocol/contracts/shared/bridge/QuotaManager.sol:8–11,67–83; packages/protocol/contracts/shared/common/DefaultResolver.sol:12,37–48]

Additional **proven source-layout** rows, necessary if wrapper/admin utility behavior is changed:

| Contract | Preserved slots | Source (prefix `packages/protocol/contracts/shared/`) |
|---|---|---|
| DefaultResolver | addresses map 251, gap 252–300 | `common/DefaultResolver_Layout.sol:21–22` |
| BridgedERC20 | balances 251, allowances 252, totalSupply 253, name/symbol 254–255, gap 256–300, source token/decimals packed301, source chain302, migration address/direction packed303, gap304–350 | `vault/BridgedERC20_Layout.sol:21–32` |
| BridgedERC20V2 | all ERC20 rows above plus EIP712 fields351–354, gap355–402, permit nonces403, gap404–452 | `vault/BridgedERC20V2_Layout.sol:21–39` |
| BridgedERC721 | gap251–300, name/symbol301–302, owners303, balances304, token approvals305, operator approvals306, gap307–350, source token351, source chain352, gap353–400 | `vault/BridgedERC721_Layout.sol:21–31` |
| BridgedERC1155 | gap251–300, balances301, operator approvals302, URI303, gap304–350, source token351, source chain352, symbol/name353–354, gap355–400 | `vault/BridgedERC1155_Layout.sol:21–30` |

**Open constraint:** immutable wiring to a non-upgradeable QuotaManager can be changed by a new compatible Bridge/ERC20Vault implementation, but the existing QuotaManager itself cannot be treated as a storage-layout-compatible UUPS upgrade. A design must say whether it continues using that utility and how its owner powers satisfy R1. [packages/protocol/contracts/shared/bridge/QuotaManager.sol:8–11; packages/protocol/contracts/shared/bridge/Bridge.sol:105–106,163–175; packages/protocol/contracts/shared/vault/ERC20Vault.sol:37,186–188]

## 5. Administrative and operational gates relevant to R1

| Surface | Proven current gate / consequence | Source |
|---|---|---|
| UUPS upgrades | owner; permitted by the stated Etna governance requirement | `shared/common/EssentialContract.sol:207`; `shared/fork-router/ForkRouter.sol:66` |
| Generic pause/unpause | owner by default | `shared/common/EssentialContract.sol:149–165,209` |
| SignalService pause | owner OR immutable pauser; disables signal proof verification/cache calls; sending and checkpoint saving are not pause-gated | `shared/signal/SignalService.sol:106–142,174–184,200–201` |
| Bridge pause | owner OR immutable pauser; send, process, retry, recall/fail are pause-gated | `shared/bridge/Bridge.sol:225,268,312,414,453,555–556` |
| Bridge plain ETH funding | only immutable pauser | `shared/bridge/Bridge.sol:182–188` |
| Bridge recovery initializer | owner can force selected message statuses to DONE once at initialization version 3 | `shared/bridge/Bridge.sol:204–213` |
| Anchor treasury withdrawal | owner can transfer all token/ETH balance to specified recipient; comment identifies base-fee income | `layer2/core/Anchor.sol:140–155` |
| Resolver registrations | owner can remap `(chainId,name)` addresses; pause unsupported | `shared/common/DefaultResolver.sol:33–48,69` |
| ERC20 wrapper replacement | owner; validates token metadata/address and 90-day minimum migration spacing, updates mappings and denylist | `shared/vault/ERC20Vault.sol:29,200–252` |
| Vault pauses | inherited owner authorization; transfer/receipt/recall entrypoints require not paused | `shared/common/EssentialContract.sol:209`; `shared/vault/ERC20Vault.sol:438,475–477`; `shared/vault/ERC721Vault.sol:36–40,94,129–131`; `shared/vault/ERC1155Vault.sol:37–41,99,140–142` |
| QuotaManager configuration | owner updates quota and refill period; only Bridge/ERC20Vault consume quota; zero configured token quota means unlimited | `shared/bridge/QuotaManager.sol:20–30,67–97,107–124` |
| ERC20 wrapper mint | owner OR Vault; pause also gates mint, burn and transfer | `shared/vault/BridgedERC20.sol:112–141,168–181` |

Paths in this table begin `packages/protocol/contracts/`. **Open design obligation:** each administrative operation other than upgrades needs explicit removal, objective replacement, or a narrowly justified interpretation of R1. Setting pauser to zero alone leaves owner pausing intact. Renouncing ownership would remove the promised DAO upgrade authority and does not automatically remove immutable pauser power. Access controls on system-contract calls, user-owned messages and token approvals are different from human-role whitelists; those must remain secure rather than simply be made public.

## 6. Same-address migration constraints (R2)

These are deductions from the preceding source, not a selected Etna migration mechanism.

1. **Proven constraint:** keep the Bridge message hash format, sent-signal slot construction, messageStatus mapping, counters, vault custody, and canonical wrapper mappings coherent across the cutover. Losing status history enables duplicate processing; losing canonical maps can deploy a second wrapper for collateral already represented. Sources: `Bridge.sol:247–254,335–341,604–607`; `SignalService.sol:155–170,232–235`; `ERC20Vault.sol:624–648`; `ERC721Vault.sol:233–257`; `ERC1155Vault.sol:280–304`.
2. **Proven constraint:** a newly addressed L1 inbox needs a SignalService implementation wired to its new authorized-syncer address (or an explicitly redesigned compatible authorization mechanism). The existing immutable cannot be changed by a resolver registration. The same applies to an Anchor address change and the L2 SignalService. Sources: `SignalService.sol:35–43,86–92,174–175`; `Anchor.sol:46–50,98–108`.
3. **Proven constraint:** preserving SignalService proxy addresses preserves the `_remoteSignalService` account that existing proofs target, provided state layout and slot semantics remain compatible. Source: `SignalService.sol:289–296`. Merely copying the interface at a new address would fail this proof binding and violate R2.
4. **Proven constraint:** a VERSION bump changes checkpoint/cache visibility without deleting old data. Old in-flight messages need either retained trusted checkpoints, an explicit historical read path, or proof against a later trustworthy root of the same chain that still contains the original sent signal. Source: `SignalService.sol:49–73,124–125,179–180,211–217,265–296`. The last option depends on **assumed** continued state history and signal persistence; no arbitrary replay/import is justified.
5. **Proven constraint:** reused proxy upgrades can change implementation constants/immutables without shifting stored slots, but actual storage safety still requires exact old/new layout comparison, initializer-version checks, and cutover-state verification. Existing reserved Pacaya fields cannot casually be repurposed while an old router branch may still access them. Sources: `Anchor.sol:59–72`; `SignalService.sol:58–75`; `ForkRouter.sol:18–20,52–63`.
6. **Open:** enumerating live proxy addresses, active implementation versions, resolver maps, owners, wrapper implementations, pending ownership transfers, active paused flags, quota values, pending messages and old checkpoint namespaces requires authorized public deployment evidence at a pinned block. This note has not obtained it. Current source is not proof of live deployment state.

## 7. Historical versus current behavior

**Proven.** Current Anchor preserves Pacaya slots for publicInputHash/gas/lastSyncedBlock/timestamp/target/L1 chain fields but does not use that earlier gas-accounting layout as current logic; it now stores block-level anchor number and ancestor digest. `_lastProposalId` is explicitly deprecated. [packages/protocol/contracts/layer2/core/Anchor.sol:59–72]

**Proven.** Current SignalService reserves old Pacaya topBlockId/isAuthorized slots; its active authority is one immutable syncer, checkpoints and received caches are versioned, and its implementation accepts exactly one hop with both proof arrays. Interface comments still mention older `ChainDataSynced`, `topBlockId`, `getSyncedChainData`, caching options, and empty account proofs for signal roots. Those comments are not current executable behavior. [packages/protocol/contracts/shared/signal/SignalService.sol:35–40,49–73,271–296; packages/protocol/contracts/shared/signal/ISignalService.sol:15–22,24–48]

**Proven.** Bridge's context and Essential's reentrancy guard now use transient storage, retaining old persistent fields. Recovery initializers and quota/pauser/recall configuration exist in this baseline, so a historical generic description of an unconditional Bridge is incomplete. [packages/protocol/contracts/shared/bridge/Bridge.sol:100–135,196–213,610–668; packages/protocol/contracts/shared/common/EssentialContract.sol:17–36,211–223]

**Open.** The presence of stale fork-router layout artifacts and descriptive historical comments cannot identify which historical implementations remain deployed or routed. Any migration plan must distinguish source history from live state.

## 8. Withholding exposure

**Proven negative observation.** None of Anchor's checks above demonstrates that a preconfirmed block was previously gossiped. The checkpoint interface accepts a root/hash/height, not a broadcast receipt or availability certificate. SignalService verifies Merkle proofs of signals under trusted roots; it does not reconstruct withheld L2 execution data. [packages/protocol/contracts/layer2/core/Anchor.sol:124–138,173–185; packages/protocol/contracts/shared/signal/ICheckpointStore.sol:13–20; packages/protocol/contracts/shared/signal/SignalService.sol:253–296]

**Deduction, proven given the interface:** a private preconfirmed state must not be treated by clients as an L1 bridge claim solely because its execution is locally valid or a signature exists. L1 withdrawals require a root actually accepted by L1 SignalService, plus a signal proof. Data availability, canonical-prefix agreement, and the timing of revelation remain protocol/client responsibilities. A party withholding private blocks may delay users obtaining proofs even when state commitments eventually become public; Merkle verification alone does not cure this. [packages/protocol/contracts/shared/bridge/Bridge.sol:335–341,628–644; packages/protocol/contracts/shared/signal/SignalService.sol:271–296]

**Open for Etna threat model:** there is no objective on-chain “not gossiped” evidence in this interface. Any new availability duty must define what signed obligation, timeout, challenge, or authenticated publication makes a slash objective and distinguish actual withholding from network delay/censorship. This observation is a design obligation, not an assertion that a particular timeout protocol is safe.

## 9. Questions for synthesis

- **Open:** should R1 encompass protocol-owned bridged token wrappers and quota/resolver utilities? The literal “DAO governs only upgradeability” implies yes; do not hide their existing mint/pause/configuration powers outside the core role table.
- **Open:** what is the authenticated L1 header/root rule for preconfirmed L2 anchor transactions before an L1 landing exists? The current Solidity Anchor delegates this correctness to derivation/proving.
- **Open:** how will a migration preserve old sent signals, checkpoint trust, received caches, and replay protection while avoiding any unsound legacy root acceptance?
- **Open:** what exact proxy, wrapper and resolver implementations are live at the migration block? The source baseline alone cannot answer.
- **Open:** if a router remains in use, which selectors/conditions still route to old code, and can that old code still pause, mint, register, or recover state?

## Five synthesis constraints

1. **Authenticated full-state checkpoints:** Etna must feed the existing `Checkpoint(uint48,bytes32,bytes32)` interface in both directions, with root correctness established outside SignalService.
2. **R1 reaches shared administration:** pause, token remapping, owner mint, resolver/quota configuration and treasury recovery need explicit treatment beyond whitelist removal.
3. **Addresses and histories both matter:** keep proxy addresses and preserve messageStatus, sent signal slots, vault collateral and canonical wrapper maps.
4. **Implementation immutables are migration inputs:** authorized syncer, remote service, resolver, quota and pauser values cannot be fixed by ordinary storage setters.
5. **Local execution validity is weaker than canonicality/availability:** Anchor and SignalService provide no gossip evidence or preconf fork-choice guarantee.
