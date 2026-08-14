# URC (Universal Registry Contract) — Research Report

Research subagent output for the Taiko protocol team. Working tree: '/Users/d/Projects/dantaik/taiko-mono' (branch 'kimi-k3-audit', HEAD '93060dda0', 2026-07-21). URC cloned to '/tmp/urc' (commit 132bc79, the exact commit the review cites). Current date: 2026-08-14.

---

## 0. Executive summary

**Facts (verified in-repo):**
- URC's `main` last commit is '132bc79 "Solady libs (#66)"' on **2025-07-07** — ~13.1 months before today, confirming the review's "frozen ~13 months" claim.
- README states outright: *"These standards are currently under review / feedback and are not audited"* and *"This project is not audited and is not ready for production use."*
- 'docs/overview.md' milestones show **"Audit 1 [X], Audit 2 [X], Audit 3 [ ]"** — a third audit is listed as incomplete, and no audit report files exist in-repo.
- There **is** an unmerged 'signing-domain' branch (a794ceb…, 21 commits ahead of main) that reworks the hardcoded domain separators into a configurable, Commit-Boost-compatible signing scheme — consistent with the review's "unmerged signing-domain branch" point.
- The registry is **immutable and governance-free by design** (config set only in the constructor, no owner, no upgrade proxy) — so any bug found post-deploy cannot be patched in place.
- **Taiko's current main branch no longer wires URC at all.** The permissionless (URC-based) preconf stack was moved to 'origin/permissionless-preconf' (commits 67625be60 "move permissionless preconf to its own branch (#21887)" and 37f8e270a "…(#21908)"). What remains on main is a **whitelist-based** 'PreconfWhitelist' with **no URC and no slashing**.

**Speculation (clearly flagged):** the impact analysis of ePBS/FOCIL/Orbit-SSF/ET/MaxEB in §5 is forward-looking analysis, not code fact; finalization dates are estimates from the prompt.

---

## 1. What is actually in the URC repository

URC is far smaller than the review's component list implies. **"Gateway", "forwarder", and "lookahead" are NOT in the URC repo.** They are off-chain / other-repo concepts (eth-fabric 'constraints-specs' "Constraints API", Commit-Boost sidecars, and Taiko's own LookaheadStore/gateway). The repo contains only:

'src/' (the "contract"):
| Component | Files | Role |
|---|---|---|
| **Registry** | 'src/Registry.sol', 'src/IRegistry.sol' | The core contract. Operators batch-register BLS keys + ETH collateral ('register()'), opt in/out of slasher protocols ('optInToSlasher'/'optOutOfSlasher'), and are slashed for fraud/equivocation/commitment-breaks ('slashRegistration', 'slashEquivocation', two 'slashCommitment' overloads). Key structs: 'Config', 'Operator', 'SignedRegistration', 'SlasherCommitment', 'RegistrationProof'. |
| **Slasher interface** | 'src/ISlasher.sol' | The 66-line interface every slasher must implement: 'Delegation' (proposer BLS key → delegate BLS key → ECDSA 'committer' → 'uint64 slot' → metadata), 'SignedDelegation', 'Commitment' ('commitmentType', 'payload', 'slasher'), 'SignedCommitment', and 'slash(...)'. |
| **BLS libs** | 'src/lib/BLS.sol' (481 lines), 'src/lib/BLSUtils.sol' (215) | Thin wrappers over the **EIP-2537 BLS12-381 precompiles** (hash-to-curve + pairing). 'BLS.sol' credits Paradigm's forge-alphanet; 'BLSUtils.sol' adds 'verify'/'compress'/negate helpers. |
| **Merkle lib** | 'src/lib/MerkleTree.sol' | Binary Merkle tree (solady 'MerkleTreeLib'/'MerkleProofLib') used to batch-register many BLS keys under one registration root, and 'hashToLeaves' (leaf = keccak256(abi.encode(SignedRegistration, owner))). |

'example/' (reference slashers, explicitly "not production-ready"):
- 'example/InclusionPreconfSlasher.sol' — 2-step stateful "inclusion preconf" slasher (challenge + fraud-proof window).
- 'example/StateLockSlasher.sol' — 1-step stateless "exclusion/state-lock" slasher.
- 'example/PreconfStructs.sol' — shared structs ('InclusionProof', 'TransactionCommitment', …) adapted from chainbound/bolt.
- 'example/lib/' — vendored RLP reader/writer, transaction decoder, and Merkle-Patricia trie ('MerkleTrie', 'SecureMerkleTrie').

'script/' (Foundry deploy/ops scripts) and 'config/registry.json' (deploy params, see §3). No gateway, no forwarder, no lookahead, no beacon-API client anywhere in the repo (grep for lookahead|validator|epoch|committee|beacon api returns only a test comment).

---

## 2. Consensus-layer dependencies (with code quotes)

### 2.1 BLS12-381 precompiles (EIP-2537, Pectra/Prague)
'foundry.toml' pins 'evm_version = "prague" # for testing bls precompiles'. 'src/lib/BLS.sol' declares the precompile addresses and calls them via staticcall:

    address internal constant BLS12_G1ADD = 0x000000000000000000000000000000000000000b;
    address internal constant BLS12_G1MSM = 0x000000000000000000000000000000000000000C;
    address internal constant BLS12_G2ADD = 0x000000000000000000000000000000000000000d;
    address internal constant BLS12_G2MSM = 0x000000000000000000000000000000000000000E;
    address internal constant BLS12_PAIRING_CHECK = 0x000000000000000000000000000000000000000F;
    address internal constant BLS12_MAP_FP_TO_G1 = 0x0000000000000000000000000000000000000010;
    address internal constant BLS12_MAP_FP2_TO_G2 = 0x0000000000000000000000000000000000000011;

plus the MODEXP precompile 'address(0x5)' in '_modfield'. **Dependency:** URC cannot run pre-Pectra; its BLS verification ('BLSUtils.verify' → 'BLS.Pairing') only works where EIP-2537 is live.

### 2.2 Beacon slot / epoch timing
'src/ISlasher.sol' commitments are bound to a beacon slot: 'uint64 slot;' in 'Delegation'. The example slashers hardcode consensus timing and genesis timestamps:

    uint256 public constant SLOT_TIME = 12;
    uint256 public ETH2_GENESIS_TIMESTAMP; // 1606824023 (mainnet), 1695902400 (Holesky), 1718967660 (Helder)
    function _getCurrentSlot() public view returns (uint256) { return _getSlotFromTimestamp(block.timestamp); } // (timestamp - genesis)/12

### 2.3 Beacon roots contract (EIP-4788)
'example/InclusionPreconfSlasher.sol' and 'example/StateLockSlasher.sol':

    address public constant BEACON_ROOTS_CONTRACT = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02;
    uint256 public constant EIP4788_WINDOW = 8191;
    (bool success, bytes memory data) = BEACON_ROOTS_CONTRACT.staticcall(abi.encode(_timestamp));

### 2.4 Reorg / finality assumptions
'example/InclusionPreconfSlasher.sol':

    uint256 public constant JUSTIFICATION_DELAY = 32;
    uint256 public constant BLOCKHASH_EVM_LOOKBACK = 256;
    if (targetSlot > _getCurrentSlot() - JUSTIFICATION_DELAY) {
        // We cannot open challenges for slots that are not finalized by Ethereum consensus yet.
        // This is admittedly a bit strict, since 32-slot deep reorgs are very unlikely.
        revert BlockIsNotFinalized();
    }
    bytes32 trustedPreviousBlockHash = blockhash(proof.inclusionBlockNumber - 1);

The inclusion proof trusts the EVM 'blockhash' opcode + a Merkle-Patricia proof against the execution block's 'txRoot' ('MerkleTrie.get(txLeaf, proof, targetBlockHeader.txRoot)'), i.e. it assumes **execution-block inclusion**, anchored to a single previous-block hash.

### 2.5 Proposer commitments / inclusion guarantees
The whole model is "proposer commitments": a validator's BLS key signs a 'Delegation', which authorizes an ECDSA 'committer' to sign a 'Commitment' binding an opaque payload to a slasher contract. Inclusion is enforced economically (slash), not by consensus (see §3).

### 2.6 What is NOT in URC
There is **no beacon validator-lookahead API dependency in URC itself**. The "lookahead" dependency lives in **Taiko's** contracts ('LookaheadStore'/'LookaheadSlasher'/'LibEIP4788' on 'origin/permissionless-preconf'), which verify the **beacon proposer lookahead** on-chain via SSZ Merkle proofs anchored to EIP-4788 roots — see §6. (Confirmed: grep lookahead|validator|epoch over '/tmp/urc' returns nothing in 'src/'.)

---

## 3. Enforcement model

**Who posts stake:** operators (validators/sequencers) call 'register(SignedRegistration[] regs, address owner)' sending ≥ 'minCollateralWei' (default **1 ETH**, 'config/registry.json'). Collateral is ETH, held by the immutable Registry.

**Who gets slashed, for which faults, and how it is proven on-chain:**

1. **Registration fraud** — 'slashRegistration(proof)': registration signatures are *optimistically* accepted (not BLS-verified at register time to save gas). A challenger submits a Merkle proof + executes the BLS verification; if the registered signature was invalid, the operator is slashed **minCollateralWei**: half burned, half paid to the challenger ('_rewardAndBurn(config.minCollateralWei / 2, msg.sender)').

2. **Equivocation** — 'slashEquivocation(proof, d1, d2)': two *different* 'SignedDelegation's by the same proposer key for the **same slot** → slash minCollateralWei (half burn / half reward).

3. **Commitment break** — 'slashCommitment(proof, delegation, commitment, evidence)': URC (a) verifies the delegation was BLS-signed by the registered key, (b) recovers the commitment's ECDSA signer and checks it equals 'delegation.committer', then (c) calls the slasher contract 'ISlasher(commitment.commitment.slasher).slash(...)' which examines the evidence and returns the slash amount; URC then **burns** that amount ('_burnETH'). There is a second overload ('slashCommitment(registrationRoot, commitment, evidence)') for the explicit 'optInToSlasher' flow.

**Opt-in model:** 'optInToSlasher(registrationRoot, slasher, committer)' binds an operator to a slasher + ECDSA committer; 'optOutOfSlasher' with an 'optInDelay'. This is the path Taiko uses (see §6).

**Windows (all uint32 seconds, from 'config/registry.json' → constructor):** 'fraudProofWindow=7200', 'unregistrationDelay=7200', 'slashWindow=7200', 'optInDelay=7200' (all ~2 hours; originally block numbers, changed to timestamps in 638dbcf "use timestamps (not block numbers) to mark windows (#62)"). The fraud-proof window means operators aren't liable until 2h after registration; a slash opens a 2h 'slashWindow' for further slashings before 'claimSlashedCollateral'.

**If the L1 proposer fails to include a preconf:** in URC's *reference* example ('InclusionPreconfSlasher'), the challenger posts a 1 ETH bond via 'createChallenge'; if nobody proves inclusion within the 24h 'CHALLENGE_WINDOW', 'URC.slashCommitment' slashes the operator and returns the challenger's bond. In *Taiko's* design (below), the L2 slasher detects 'MissedSubmission'/'MissingEOP' and routes back to L1 via the bridge to call 'URC.slashCommitment'.

**Reorg handling:** finality margin baked into example slashers ('JUSTIFICATION_DELAY=32' slots, 'blockhash' 256-block lookback); Taiko's 'LookaheadSlasher' anchors to a beacon root from ~1 epoch earlier.

**Trusted parties:** the Registry itself is **trustless/governance-free/immutable** (no owner, no pause, no upgrade — a stated design principle). Trust concentrates in the **slasher contracts** (which encode the specific commitment semantics and are effectively trusted by the operators who opt in), in the **off-chain gateway/builder** that constructs lookaheads and signs commitments, and — in Taiko's case — in **blacklist overseers** and the **whitelist** (see §6). Burn address is '0x0'.

---

## 4. Production-readiness (from the repo itself)

- **Activity:** 'git log' shows continuous development Dec 2024 → **2025-07-07**, then nothing. Branches: 'main', 'chore-docs', 'gas-tests', 'signing-domain' (unmerged), 'update-license'. **No git tags** ('git ls-remote --tags' empty).
- **README status:** "under review / feedback and are not audited"; disclaimer "not audited and is not ready for production use."
- **Open issues (gh, 4 total):** #19 "Delegation Message encoding" (help wanted), #6 "Finalize value for DOMAIN_SEPARATOR parameter", #5 "Finalize value for FRAUD_PROOF_WINDOW parameter", #4 "Finalize value for MIN_COLLATERAL parameter" — all from Nov–Dec 2024, i.e. **the core constants/signing-domain questions are still open.**
- **Audits:** milestone list "Audit 1 [X], Audit 2 [X], Audit 3 [ ]". No audit report files or auditor names in-repo; the README's "not audited" disclaimer conflicts with the checked-off milestones (likely stale). Could not locate the audit reports online (eth-fabric docs site restates only the design principles).
- **Deployment addresses:** none in-repo. 'config/registry.json' is parameters only; 'script/output/*.json' are empty templates; the one address in 'Commitment.json' is a checksummed test vanity address (0x…cf7ed3acca…), not a deployment.
- **Signing-domain risk:** 'src/Registry.sol:20-21' hardcodes 'REGISTRATION_DOMAIN_SEPARATOR = "0x00555243"' ("URC" LE) and 'DELEGATION_DOMAIN_SEPARATOR = "0x0044656c"' ("Del" LE). The unmerged 'signing-domain' branch makes these configurable ('config.signingDomain', 'config.chainId'), adds a 'MessageType' enum + 'nonce' + 'signingId', and switches to hashToG2 signing roots "compatible with commit-boost signing module" (commits 304e59f, 2a17ac7). Because the registry is immutable, getting this wrong at deploy time is unfixable — precisely the "unpatchable bug after immutable deploy" risk.
- **Other readiness flags in-repo:** 'example/README.md' "these are not production-ready implementations"; 'script/README.md' "THIS SCRIPT IS NOT MEANT FOR PRODUCTION"; test data pins old mainnet blocks ('header_20785011.json', ~late 2024).

**Bottom line:** the repo itself agrees with the review — URC is a **standard/draft + reference implementation**, not a production system.

---

## 5. Upcoming consensus changes vs. URC assumptions

| Change | Affected URC/Taiko component | How it breaks or alters the assumption |
|---|---|---|
| **ePBS / EIP-7732** (proposer/builder split) | Inclusion-preconf semantics ('InclusionPreconfSlasher', Taiko 'PreconfSlasherL1' faults); the "proposer controls inclusion" premise | Under ePBS the beacon **proposer** no longer selects transactions — the **builder** does. A validator's "I will include tx X" commitment becomes unfulfillable by the proposer alone. 'Delegation.slot'→proposer-key mapping still identifies *who is scheduled to propose*, but the *commitment content* (inclusion) shifts to builders/execution-ticket holders. Lookahead (proposer schedule) is unaffected; preconf *fulfillment* is. |
| **FOCIL / EIP-7805** (fork-choice-enforced inclusion lists) | Taiko 'PreconfSlasherL1.slash' fault classification ('MissedSubmission'/liveness vs 'MissingEOP'/safety, keyed on 'getBeaconBlockRootAt(preconfirmation.submissionWindowEnd) == 0') | FOCIL forces the proposer to include IL txs, so "the tx wasn't included" is no longer cleanly attributable to a broken promise, and "empty/missed slot" liveness logic must account for IL constraints. The binary liveness-vs-safety slash (0.5 vs 1 ETH) likely needs richer fault taxonomy. |
| **Orbit SSF** (single-slot finality) | Reorg/finality margins: URC example 'JUSTIFICATION_DELAY=32' ("32-slot deep reorgs"); epoch-based windows ('SECONDS_IN_EPOCH=384') | SSF makes finality ~1 slot, obsoleting the 2-epoch finality assumption (an *improvement*), but also reshapes slot/epoch timing (possibly different slot duration and no meaningful "epoch"), so hardcoded 'SLOT_TIME=12'/'SECONDS_IN_EPOCH'/'fraudProofWindow' epoch math would need rework. |
| **Execution tickets (ET)** | The core URC identity assumption: "registered BLS key = the (beacon) proposer who will include my tx"; Taiko 'LookaheadStore' beacon-proposer→operator mapping | ET moves execution rights from beacon proposers to separate ticket holders. The **beacon proposer lookahead** (which Taiko's lookahead is built on, 'LibEIP4788.verifyValidator' gindex 11 / proposer-lookahead) would no longer determine who can actually preconf/build. The registry's BLS-key→proposer mapping and the "slot" binding in 'Delegation' need to be re-targeted at ticket holders. |
| **EIP-7251 MaxEB** (max effective balance 32→2048 ETH) | Lookahead *construction*/indexing ('urcindexer-rs', Nethermind 'urc' crate) and validator-list proofs | No structural change to the beacon state SSZ layout used by 'LibEIP4788' (validator pubkey is still BLS12-381; proposer lookahead format unchanged), so proofs still verify. Impact is operational/economic: fewer, larger validators change proposer-schedule construction, collateral-adequacy assumptions, and the distribution of who is in the lookahead. |

**Speculative overall takeaway:** ePBS/ET are the existential changes — they split "who is scheduled to propose" (beacon, still readable via lookahead) from "who controls inclusion" (builder/ticket holder), which is exactly what URC's inclusion-preconf slashing assumes are the same actor. FOCIL/SSF are more about fault-classification and timing constants.

---

## 6. How Taiko wires URC in (and its current status)

### 6.1 The permissionless (URC-based) stack — on 'origin/permissionless-preconf'

URC is an **npm/forge dependency**, not vendored. 'packages/protocol/package.json:60' → '"urc": "github:eth-fabric/urc#main"', and 'pnpm-lock.yaml:313' resolves it to exactly 'https://codeload.github.com/eth-fabric/urc/tar.gz/132bc796a27721252984923a76760bed24643205' (the review's commit). 'foundry.toml:30' remaps '"@eth-fabric/urc/=node_modules/urc/src/"'.

**Contracts importing URC** (all under 'packages/protocol/contracts/layer1/preconf/'):
- 'iface/ILookaheadStore.sol' → '@eth-fabric/urc/ISlasher.sol'; 'LookaheadSlot' carries 'registrationRoot' (URC) + 'validatorLeafIndex'.
- 'iface/ILookaheadSlasher.sol' → 'IRegistry.sol', 'ISlasher.sol', '@solady/.../BLS.sol'; evidence structs embed 'IRegistry.SignedRegistration[]' and 'IRegistry.RegistrationProof'.
- 'iface/IPreconfSlasherL1.sol' → 'ISlasher.sol'.
- 'impl/LookaheadStore.sol' → 'IRegistry.sol', 'ISlasher.sol'; reads 'urc.getOperatorData', 'urc.getHistoricalCollateral', 'urc.getSlasherCommitment'; 'urc = IRegistry(_urc)'.
- 'impl/LookaheadSlasher.sol' → '@eth-fabric/urc/lib/MerkleTree.sol' + 'IRegistry'/'ISlasher'/BLS; verifies 'IRegistry(urc).verifyMerkleProof(registrationProof)' and 'IRegistry(urc).getOperatorData(...)'.
- 'impl/PreconfSlasherL1.sol' → 'IRegistry.sol', 'ISlasher.sol'; calls 'IRegistry(urc).slashCommitment(registrationRoot, signedCommitment, abi.encode(fault))' from 'onMessageInvocation'.
- 'impl/UnifiedSlasher.sol' → 'ISlasher.sol'; it is the **URC entrypoint** ('require(msg.sender == urc)') and delegatecalls to 'LookaheadSlasher' or 'PreconfSlasherL1' based on 'commitmentType'.
- 'libs/LibEIP4788.sol' → '@eth-fabric/urc/lib/BLSUtils.sol' + '@solady/.../BLS.sol'; 'libs/LibBLSSignature.sol' → local 'LibBLS12381.sol' (EIP-2537 pairing).

**Wiring into the rollup:** 'Inbox.propose' forwards '_lookahead' to an 'IProposerChecker'; when preconfirmation is enabled that checker is 'LookaheadStore', which derives the eligible proposer from the beacon proposer lookahead mapped to URC operators, and stores only a 'bytes26' lookahead hash. Slashing backstop: 'LookaheadSlasher' proves a beacon validator's BLS key is the scheduled proposer at a slot via **SSZ Merkle proofs** ('LibEIP4788.verifyValidator': validator in the validator list at gindex 11, beacon state root in the beacon block at gindex 3) anchored to **EIP-4788** beacon roots ('BEACON_BLOCK_ROOT_CONTRACT = 0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02'), and compares the "preconf lookahead" vs "beacon lookahead". Faults: 'MissedSubmission'/'MissingEOP' (liveness 0.5 ETH vs safety 1 ETH in 'getSlashAmount()').

**Supporting pieces:** 'packages/urcindexer-rs' (Rust service wrapping Nethermind's 'urc' crate; indexes 'OperatorRegistered'/'OperatorOptedIn' events into MySQL to build the URC lookahead set); 'test/layer1/preconf/mocks/MockURC.sol'; 'docs/preconfirmation_lookahead.md' (detailed design — itself documents a blacklist-eligibility bug §10.2 and the "fallback lookahead not slashable" trust assumption §10.3).

### 6.2 Current main branch — URC removed

On the checked-out 'kimi-k3-audit' branch (and 'main'): **zero '\bURC\b' matches** in Solidity source. The permissionless stack was moved to 'origin/permissionless-preconf' (#21887 protocol, #21908 client-rs). What remains:
- 'packages/protocol/contracts/layer1/preconf/impl/PreconfWhitelist.sol' (whitelist proposer selection using beacon-root randomness — 'getBeaconBlockRootAtOrAfter' with 'RANDOMNESS_DELAY = 2 epochs') and 'IPreconfWhitelist.sol'. Its 'checkProposer' explicitly notes: *"Slashing is not enabled for whitelisted preconfers, so we return 0"* ('PreconfWhitelist.sol:139').
- 'packages/urcindexer-rs/' is an **empty placeholder** (only '.DS_Store') on this branch.
- Stale compiled artifacts remain under 'packages/protocol/out/layer1/' ('LookaheadStore.sol', 'LookaheadSlasher.sol', 'ISlasher.sol', etc.), which still reference URC (grep shows 27 "urc"/6 "URC"/2 "IRegistry" hits in 'LookaheadSlasher.json').
- Rust bindings ('taiko-client-rs/crates/bindings/') still bind 'Inbox', 'Anchor', 'LookaheadStore', 'PreconfWhitelist' — the 'LookaheadStore' binding is stale relative to the moved source.

**Interpretation (fact + mild inference):** Taiko has already pivoted the *shipped* preconf path to a permissioned whitelist (no URC, no slashing), while keeping the URC-based permissionless design on a side branch — directionally consistent with the review's "URC not production-ready" conclusion.

---

## 7. Key facts vs. speculation

**Facts:** URC frozen since 2025-07-07; "not audited / not production-ready" per its own README; 3rd audit incomplete; 4 open parameter-finalization issues (Nov–Dec 2024); unmerged 'signing-domain' branch; immutable no-governance registry; hardcoded domain separators + 'evm_version=prague' BLS precompiles; EIP-4788 + beacon-slot/epoch + 32-slot-finality + blockhash assumptions; Taiko pins URC at exactly 132bc79 via npm and imports 'IRegistry'/'ISlasher'/'MerkleTree'/'BLSUtils' into 'LookaheadStore'/'LookaheadSlasher'/'PreconfSlasherL1'/'UnifiedSlasher'/'LibEIP4788' on 'origin/permissionless-preconf'; Taiko's main branch no longer uses URC.

**Speculation:** §5 impact analysis; the exact deployment status of URC on mainnet (not found in-repo); the identity/dates of "Audit 1/2"; ePBS/ET/FOCIL/SSF timelines.

**Primary references (URLs):** https://github.com/eth-fabric/urc · https://github.com/eth-fabric/urc/blob/main/docs/overview.md · https://eth-fabric.github.io/website/development/l1-components/urc · https://github.com/eth-fabric/awesome-based-preconfs · https://github.com/eth-fabric/constraints-specs/blob/main/specs/proposer.md · https://eips.ethereum.org/EIPS/eip-2537 · https://eips.ethereum.org/EIPS/eip-4788 · https://eips.ethereum.org/EIPS/eip-7732 · https://eips.ethereum.org/EIPS/eip-7805 · https://eips.ethereum.org/EIPS/eip-7251
