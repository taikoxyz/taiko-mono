# Security Review: protocol

## Scope

Standard Codex Security scan of `/Users/d/Projects/taiko/taiko-mono/packages/protocol/contracts` at git revision `32abaf7465dbaef7b006c1da65966efdb533c7e3`. The scan reviewed Solidity runtime contracts for L1 rollup finalization, bridge/vaults, signal service, governance helpers, verifier and SGX attestation logic, preconfirmation/slashing components, L2 anchoring, and shared libraries.

- Scan mode: scoped_path
- Target kind: git_revision
- Target ID: target_sha256_07fd50dfd6c8cd73853de8659de19a6d4299e98e7583c9814ea1597be2eaa788
- Revision: 32abaf7465dbaef7b006c1da65966efdb533c7e3
- Inventory strategy: scoped_path
- Included paths: contracts
- Excluded paths: none
- Runtime or test status: Ran focused Foundry validation for forced-inclusion skipping and Anchor checkpoint persistence; other findings were validated by static source/control-flow review plus deployment/configuration evidence where available.
- Artifacts reviewed: artifacts/01_context/threat_model.md, artifacts/02_discovery/work_ledger.jsonl, artifacts/02_discovery/raw_candidates.jsonl, artifacts/03_coverage/repository_coverage_ledger.md, artifacts/04_reconciliation/dedupe_report.md, artifacts/05_findings/validation_summary.md, artifacts/05_findings/attack_path_analysis_report.md, artifacts/05_findings/final_reportable_findings.json
- Scan context: Threat model was generated during the scan from the scoped protocol contracts. User did not provide additional context beyond requesting a Codex Security scan on the repository.

Limitations and exclusions:
- The requested scope was `contracts`; tests, scripts, docs, audits, and other packages were used only as supporting evidence.
- No full end-to-end invalid rollup state proof, malicious SSZ vector, or URC collateral-loss transaction was generated.
- Deployment-specific severity for verifier composition, governance consumers, and Anchor derivation controls requires follow-up against live deployed addresses and operational configuration.
- Excluded test/: Outside requested scan scope; focused Foundry tests were used only as validation evidence.
- Excluded script/: Outside requested scan scope; deployment scripts were consulted only as supporting configuration evidence.
- Excluded docs/, audits/, packages outside packages/protocol/contracts: Outside requested path scope for this standard scan.

### Scan Summary

| Field | Value |
| --- | --- |
| Reportable findings | 9 |
| Severity mix | high: 5, medium: 4 |
| Confidence mix | high: 6, medium: 3 |
| Coverage | complete |
| Validation mode | Manual standard scan with deterministic file worklist, candidate deduplication, focused tests for two findings, and attack-path severity calibration. |

Canonical artifacts: `scan-manifest.json`, `findings.json`, and `coverage.json`. This report is a deterministic projection of those files.

## Threat Model

The scoped protocol package protects bridge/vault assets, L1 proposal and finalization state, L2 anchoring state, cross-chain signal truth, verifier trust configuration, governance and upgrade authority, preconfirmation operator state, and resolver-controlled role bindings. The primary adversaries are permissionless users, proposers, provers, preconfirmation actors, relayers, malicious token contracts, and lower-privileged operators attempting to abuse proofs, queues, signatures, checkpoint data, or role boundaries.

### Assets

- Locked and minted bridge/vault assets across ERC20, ERC721, ERC1155, and ETH paths.
- L1 rollup proposal, proof, finalization, checkpoint, bond, and forced-inclusion state.
- Verifier trust anchors including SGX/DCAP instances, ZK verifier addresses, trusted images/program keys, and composed verifier thresholds.
- L2 Anchor checkpoint state and SignalService checkpoint/message proof truth.
- Preconfirmation operator whitelist, lookahead data, URC slashing decisions, and collateral.
- Governance token voting supply, owner/UUPS authority, resolver mappings, and fork-router behavior.

### Trust Boundaries

- Permissionless external callers into bridge, vault, Inbox propose/prove, forced inclusion, token, and Anchor flows.
- Adversarial proposers/provers/preconfirmation participants versus rollup finality and slashing controls.
- Cross-chain proof and SignalService boundaries between source-chain truth and destination-chain execution.
- Verifier and SGX attestation boundary between proof bytes/quotes and accepted finalization proofs.
- Privileged owner, resolver, pauser, ejecter, prover-manager, verifier-configuration, and upgrade roles.
- Off-chain deployment, derivation, and prover controls that influence on-chain configuration and Anchor transaction correctness.

### Attacker Capabilities

- Submit arbitrary calldata, proofs, blob references, forced-inclusion requests, bridge messages, token callbacks, and slashing evidence to public entrypoints.
- Act as or compromise lower-privileged protocol roles such as proposer, prover, preconfirmation operator, ejecter, relayer, or token holder.
- Provide SGX quote material or ZK proof wrapper inputs where verifier contracts expose registration or proof verification paths.
- Use public protocol key material such as the golden-touch signer where the contract relies only on sender identity.

### Security Objectives

- Reject invalid rollup state transitions and forged proof or attestation material before finalization.
- Preserve forced-inclusion and permissionless proving liveness when configured as recovery or censorship-resistance mechanisms.
- Prevent forged cross-chain signals, unauthorized vault mint/burn/release, and unsafe checkpoint trust.
- Ensure preconfirmation slashing evidence is cryptographically bound to the correct beacon and lookahead state.
- Maintain least-privilege role separation for governance, whitelist, resolver, and upgrade operations.

### Assumptions

- L1 consensus and EVM semantics are trusted.
- Owners and governance are trusted not to act maliciously, but mistakes and lower-privileged role compromise are in scope for severity calibration.
- External verifier contracts, SGX hardware, and deployment parameters are trusted only to the extent they are correctly configured and bound by in-scope contracts.
- Off-chain derivation and prover pipelines can reduce severity but do not replace missing contract-layer checks unless the scan can verify that every consumer waits for those controls.

## Findings

| Finding | Severity | Confidence |
| --- | --- | --- |
| [Missing-operator slashing checks operator eligibility at a stale timestamp](#finding-1) | high | high |
| [Forced inclusions can be paid for but never consumed by proposals](#finding-2) | high | high |
| [Disabled SGX enclave-identity checks let arbitrary enclaves become proof signers](#finding-3) | high | high |
| [Beacon proposer-lookahead root is not anchored before slashing evidence is accepted](#finding-4) | high | high |
| [Lookahead slashing can classify an already assigned earlier slot as missing](#finding-5) | high | high |
| [Ejecter role can promote arbitrary preconfirmation proposers](#finding-6) | medium | medium |
| [Public golden-touch signer can write Anchor checkpoints at the contract layer](#finding-7) | medium | medium |
| [Signature delegation bypasses TaikoToken non-voting account guard and lowers voting supply](#finding-8) | medium | medium |
| [Permissionless proving fallback is unreachable while any prover remains whitelisted](#finding-9) | medium | high |

### Confidence Scale

| Label | Meaning |
| --- | --- |
| high | Direct evidence supports the finding with no material unresolved blocker. |
| medium | Evidence supports a plausible issue, but material runtime or reachability proof remains. |
| low | Evidence is incomplete and the item is retained only for explicit follow-up. |

<a id="finding-1"></a>

### [1] Missing-operator slashing checks operator eligibility at a stale timestamp

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | The timestamp convention mismatch is explicit in source, and the slashing sink is direct; only a full historical-state PoC is missing. |
| Category | Preconfirmation slashing / stale eligibility |
| CWE | CWE-345: Insufficient Verification of Data Authenticity |
| Affected lines | contracts/layer1/preconf/impl/LookaheadSlasher.sol:241-247, contracts/layer1/preconf/impl/LookaheadStore.sol:341-356, contracts/layer1/preconf/impl/LookaheadSlasher.sol:34-44, contracts/layer1/preconf/impl/LookaheadSlasher.sol:81-86 |

#### Summary

`_validateMissingOperatorEvidence` computes `previousEpochTimestamp - 2 * SECONDS_IN_SLOT` and passes it to `LookaheadStore.isLookaheadOperatorValid`, but the store treats its input as the reference timestamp directly. The comment says it is using the same reference timestamp, yet the values use different conventions and can validate stale operator state.

#### Root Cause

The invariant is that missing-operator evidence should verify the operator at the same historical reference used by lookahead posting and slashing rules. The slasher passes a pre-adjusted slot timestamp to a store function that expects the actual reference timestamp, causing stale eligibility validation.

**Slasher subtracts two slots before store call** — `contracts/layer1/preconf/impl/LookaheadSlasher.sol:238-247`

The slasher passes a timestamp before the previous epoch boundary into `isLookaheadOperatorValid`.

```solidity
        IRegistry(urc).verifyMerkleProof(registrationProof);

        // This is the same reference timestamp that is used in the lookahead store
        uint256 referenceTimestamp =
            _previousEpochTimestamp - 2 * LibPreconfConstants.SECONDS_IN_SLOT;

        // Verify that this operator was valid at the reference timestamp.
        // This reverts if the operator is not valid at the reference timestamp.
        ILookaheadStore(lookaheadStore)
            .isLookaheadOperatorValid(referenceTimestamp, registrationProof.registrationRoot);
```

**Store treats input as direct reference timestamp** — `contracts/layer1/preconf/impl/LookaheadStore.sol:341-356`

`isLookaheadOperatorValid` uses its `_epochTimestamp` argument directly as the validation reference.

```solidity
    function isLookaheadOperatorValid(
        uint256 _epochTimestamp,
        bytes32 _registrationRoot
    )
        external
        view
        returns (bool)
    {
        uint256 referenceTimestamp = _epochTimestamp;

        _validateLookaheadOperator(
            referenceTimestamp,
            _registrationRoot,
            getLookaheadStoreConfig().minCollateralForPreconfing,
            preconfSlasher
        );
```

#### Validation

Validated by comparing `LookaheadSlasher` and `LookaheadStore` source. The slasher comment claims the timestamp matches the store, but the store uses the supplied argument directly for `_validateLookaheadOperator`.

Validation method: Static cross-contract trace

**Slasher subtracts two slots before store call** — `contracts/layer1/preconf/impl/LookaheadSlasher.sol:238-247`

The slasher passes a timestamp before the previous epoch boundary into `isLookaheadOperatorValid`.

```solidity
        IRegistry(urc).verifyMerkleProof(registrationProof);

        // This is the same reference timestamp that is used in the lookahead store
        uint256 referenceTimestamp =
            _previousEpochTimestamp - 2 * LibPreconfConstants.SECONDS_IN_SLOT;

        // Verify that this operator was valid at the reference timestamp.
        // This reverts if the operator is not valid at the reference timestamp.
        ILookaheadStore(lookaheadStore)
            .isLookaheadOperatorValid(referenceTimestamp, registrationProof.registrationRoot);
```

**Store treats input as direct reference timestamp** — `contracts/layer1/preconf/impl/LookaheadStore.sol:341-356`

`isLookaheadOperatorValid` uses its `_epochTimestamp` argument directly as the validation reference.

```solidity
    function isLookaheadOperatorValid(
        uint256 _epochTimestamp,
        bytes32 _registrationRoot
    )
        external
        view
        returns (bool)
    {
        uint256 referenceTimestamp = _epochTimestamp;

        _validateLookaheadOperator(
            referenceTimestamp,
            _registrationRoot,
            getLookaheadStoreConfig().minCollateralForPreconfing,
            preconfSlasher
        );
```

Evidence:
- `_validateMissingOperatorEvidence` subtracts two slots from `previousEpochTimestamp`.
- `isLookaheadOperatorValid` does not apply the same epoch convention; it forwards the supplied argument as `referenceTimestamp`.

Counterevidence and remaining uncertainty:
- No full historical URC state PoC was run.
- Exploitability requires operator registration/collateral state to differ across the stale and intended reference windows.

#### Dataflow

Missing-operator evidence validates a beacon validator and registration proof, computes a stale reference timestamp, and asks the store whether the registration root was valid at that stale time. If it succeeds, `slash` returns `slashAmount`.

- **Source:** Slashing evidence containing operator registration proof and registration root

- **Sink:** URC slashing amount returned after stale registration validation

- **Outcome:** An operator can be considered valid or invalid using the wrong historical window, enabling false missing-operator slashing.

Transformations:
- Slasher derives `previousEpochTimestamp` from slot evidence.
- Slasher subtracts slots before the store call.
- Store interprets the value as the direct validation reference.

**Slasher subtracts two slots before store call** — `contracts/layer1/preconf/impl/LookaheadSlasher.sol:238-247`

The slasher passes a timestamp before the previous epoch boundary into `isLookaheadOperatorValid`.

```solidity
        IRegistry(urc).verifyMerkleProof(registrationProof);

        // This is the same reference timestamp that is used in the lookahead store
        uint256 referenceTimestamp =
            _previousEpochTimestamp - 2 * LibPreconfConstants.SECONDS_IN_SLOT;

        // Verify that this operator was valid at the reference timestamp.
        // This reverts if the operator is not valid at the reference timestamp.
        ILookaheadStore(lookaheadStore)
            .isLookaheadOperatorValid(referenceTimestamp, registrationProof.registrationRoot);
```

**Store treats input as direct reference timestamp** — `contracts/layer1/preconf/impl/LookaheadStore.sol:341-356`

`isLookaheadOperatorValid` uses its `_epochTimestamp` argument directly as the validation reference.

```solidity
    function isLookaheadOperatorValid(
        uint256 _epochTimestamp,
        bytes32 _registrationRoot
    )
        external
        view
        returns (bool)
    {
        uint256 referenceTimestamp = _epochTimestamp;

        _validateLookaheadOperator(
            referenceTimestamp,
            _registrationRoot,
            getLookaheadStoreConfig().minCollateralForPreconfing,
            preconfSlasher
        );
```

**Missing-operator branch reaches slash amount** — `contracts/layer1/preconf/impl/LookaheadSlasher.sol:78-86`

After missing-operator validation succeeds, `slash` returns the configured amount.

```solidity
        } else {
            // This condition is executed when the problematic slot has no assigned operator i.e
            // when it is an advanced proposal slot, or when the lookahead is empty.
            _validateMissingOperatorEvidence(
                previousEpochTimestamp, beaconLookaheadValPubKey, evidenceInvalidOrMissingOperator
            );
        }

        return slashAmount;
```

#### Reachability

The path is reachable through URC slashing evidence. An attacker needs a registration-root proof that passes under the stale reference and a state transition that would fail under the intended reference.

- **Attacker:** URC challenger or slashing-evidence submitter

- **Entry point:** URC call into `LookaheadSlasher.slash`

- **Outcome:** False or stale slashing decision for preconfirmation operators.

Preconditions:
- Operator registration or collateral validity changes between the stale and intended reference windows.
- Registration proof and beacon-validator proof otherwise pass.
- URC invokes the configured slasher.

#### Severity

**High** — A stale eligibility check can make missing-operator evidence pass for historical registration state and cause unjust slashing. Exploitability depends on operator state changing across the stale and intended reference windows.

Severity would increase with a concrete historical state transition that produces collateral loss; it would decrease if URC registration roots are immutable across the affected windows or upstream evidence prevents stale roots.

#### Remediation

Use a single documented timestamp convention across slasher and store. Pass the expected epoch timestamp into `isLookaheadOperatorValid`, or rename/split the store API so callers cannot pass already-adjusted reference timestamps accidentally.

Tests:
- Add tests around epoch boundaries where a registration root is valid at the stale timestamp but invalid at the intended reference.
- Add invariant tests comparing slasher-computed references to store expectations.

Preventive controls:
- Replace ambiguous `_epochTimestamp` parameters with domain-specific types or helper functions.
- Document and assert reference timestamp derivation in both lookahead posting and slashing paths.

<a id="finding-2"></a>

### [2] Forced inclusions can be paid for but never consumed by proposals

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | Direct source review and a focused Foundry test confirm due forced inclusions can be skipped while the queue head does not advance. |
| Category | Forced inclusion censorship / liveness |
| CWE | CWE-841: Improper Enforcement of Behavioral Workflow |
| Affected lines | contracts/layer1/core/impl/Inbox.sol:748-749, contracts/layer1/core/impl/Inbox.sol:427-433, contracts/layer1/core/impl/Inbox.sol:591-592, contracts/layer1/core/impl/Inbox.sol:647-657, contracts/layer1/core/impl/Inbox.sol:681-683 |

#### Summary

Users can pay `saveForcedInclusion` to enqueue a forced inclusion, but `propose` rejects every nonzero `numForcedInclusions`. The dequeue helper receives zero, returns without advancing the head, and normal proposals can continue without consuming due forced inclusions.

#### Root Cause

The invariant is that paid forced-inclusion entries should eventually be consumed once due. The implementation still accepts payment and queue writes but disables both the nonzero proposal request path and the due-entry enforcement path.

**Paid forced inclusion enqueue** — `contracts/layer1/core/impl/Inbox.sol:423-433`

The public entrypoint stores a paid forced inclusion request.

```solidity
    /// @inheritdoc IForcedInclusionStore
    /// @dev This function will revert if called before the first non-activation proposal is
    /// submitted to make sure blocks have been produced already and the derivation can use the
    /// parent's block timestamp.
    function saveForcedInclusion(LibBlobs.BlobReference memory _blobReference) external payable {
        bytes32 proposalHash = _proposalHashes[1];
        require(proposalHash != bytes32(0), IncorrectProposalCount());

        uint256 refund = _forcedInclusionStorage.saveForcedInclusion(
            _forcedInclusionFeeInGwei, _forcedInclusionFeeDoubleThreshold, _blobReference
        );
```

**Proposals require zero forced inclusions** — `contracts/layer1/core/impl/Inbox.sol:746-750`

`_validateProposeInput` rejects any nonzero requested forced-inclusion count.

```solidity
    /// @dev Validates propose function inputs.
    /// @param _input The ProposeInput to validate
    function _validateProposeInput(ProposeInput memory _input) private view {
        require(_input.numForcedInclusions == 0);
        require(_input.deadline == 0 || block.timestamp <= _input.deadline, DeadlineExceeded());
```

**Zero processing leaves queue head unchanged** — `contracts/layer1/core/impl/Inbox.sol:647-657`

The due-scan check is disabled and zero requested inclusions means zero processing.

```solidity
            // Temporarily do not force proposers to process due forced inclusions.
            // The previous due scan and `UnprocessedForcedInclusionIsDue` check are disabled.

            uint256 toProcess = _numForcedInclusionsRequested.min(available)
                .min(MAX_FORCED_INCLUSIONS_PER_PROPOSAL);

            result_.sources = new DerivationSource[](toProcess + 1);

            (, head) = _dequeueAndProcessForcedInclusions(
                $, _feeRecipient, result_.sources, head, toProcess
            );
```

#### Validation

Validated with source review and `forge test --match-test test_propose_allowsSkippingDueForcedInclusion -vv`, which passed and demonstrated that a proposal can skip due forced inclusions.

Validation method: Focused Foundry test plus static trace

**Paid forced inclusion enqueue** — `contracts/layer1/core/impl/Inbox.sol:423-433`

The public entrypoint stores a paid forced inclusion request.

```solidity
    /// @inheritdoc IForcedInclusionStore
    /// @dev This function will revert if called before the first non-activation proposal is
    /// submitted to make sure blocks have been produced already and the derivation can use the
    /// parent's block timestamp.
    function saveForcedInclusion(LibBlobs.BlobReference memory _blobReference) external payable {
        bytes32 proposalHash = _proposalHashes[1];
        require(proposalHash != bytes32(0), IncorrectProposalCount());

        uint256 refund = _forcedInclusionStorage.saveForcedInclusion(
            _forcedInclusionFeeInGwei, _forcedInclusionFeeDoubleThreshold, _blobReference
        );
```

**Proposals require zero forced inclusions** — `contracts/layer1/core/impl/Inbox.sol:746-750`

`_validateProposeInput` rejects any nonzero requested forced-inclusion count.

```solidity
    /// @dev Validates propose function inputs.
    /// @param _input The ProposeInput to validate
    function _validateProposeInput(ProposeInput memory _input) private view {
        require(_input.numForcedInclusions == 0);
        require(_input.deadline == 0 || block.timestamp <= _input.deadline, DeadlineExceeded());
```

**Zero processing returns current head** — `contracts/layer1/core/impl/Inbox.sol:680-683`

The dequeue helper explicitly returns the old head when `_toProcess` is zero.

```solidity
        unchecked {
            if (_toProcess == 0) {
                return (type(uint48).max, _head);
            }
```

Evidence:
- Focused Foundry test passed: `test/layer1/core/inbox/InboxPropose.t.sol:InboxProposeTest.test_propose_allowsSkippingDueForcedInclusion`.
- The public enqueue path remains payable while `propose` requires zero forced inclusions.

Counterevidence and remaining uncertainty:
- Economic loss depends on actual usage and fee amounts.
- The code comments say due-scan enforcement is temporarily disabled, which may be intentional but still leaves the paid queue path exposed.

#### Dataflow

A user enqueues and pays for a forced inclusion. Later, a proposer submits a normal proposal with zero requested inclusions because any nonzero value reverts. `_consumeForcedInclusions` receives zero, processes no entries, and the head remains unchanged.

- **Source:** User-paid queue entry created by `saveForcedInclusion`

- **Sink:** Queue head in `_forcedInclusionStorage` remains unchanged while proposals continue

- **Outcome:** Forced inclusions can be censored indefinitely and paid entries remain stuck.

Transformations:
- `_validateProposeInput` narrows the request count to only zero.
- `_consumeForcedInclusions` computes `toProcess` from the requested count and available entries.
- The dequeue helper exits early for zero.

**Proposals require zero forced inclusions** — `contracts/layer1/core/impl/Inbox.sol:746-750`

`_validateProposeInput` rejects any nonzero requested forced-inclusion count.

```solidity
    /// @dev Validates propose function inputs.
    /// @param _input The ProposeInput to validate
    function _validateProposeInput(ProposeInput memory _input) private view {
        require(_input.numForcedInclusions == 0);
        require(_input.deadline == 0 || block.timestamp <= _input.deadline, DeadlineExceeded());
```

**Consume call receives requested count** — `contracts/layer1/core/impl/Inbox.sol:591-592`

Proposal construction passes the user-supplied count into the forced-inclusion consumer.

```solidity
            ConsumptionResult memory result =
                _consumeForcedInclusions(msg.sender, _input.numForcedInclusions);
```

**Zero processing returns current head** — `contracts/layer1/core/impl/Inbox.sol:680-683`

The dequeue helper explicitly returns the old head when `_toProcess` is zero.

```solidity
        unchecked {
            if (_toProcess == 0) {
                return (type(uint48).max, _head);
            }
```

#### Reachability

The enqueue path is public and payable after activation. Any proposer can continue submitting normal proposals, and no special role is required to trigger the skip behavior.

- **Attacker:** Any proposer, or the protocol itself under normal proposal flow after a user enqueues a forced inclusion

- **Entry point:** `Inbox.saveForcedInclusion` followed by `Inbox.propose`

- **Outcome:** Users lose the guaranteed inclusion mechanism and may have fees locked in unprocessed queue entries.

Preconditions:
- Inbox is activated past the first non-activation proposal.
- A user submits a forced inclusion and pays the required fee.
- Proposals continue with `numForcedInclusions == 0`.

#### Severity

**High** — This breaks the forced-inclusion censorship-resistance path and can indefinitely leave paid inclusion requests unprocessed while the rollup continues accepting normal proposals.

Severity would increase with active production use of paid forced inclusions and no alternate enforced inclusion path; it would decrease if forced inclusions are intentionally disabled and deposits are blocked or refundable.

#### Remediation

Either fully disable forced inclusions by reverting/refunding `saveForcedInclusion`, or restore proposal consumption by allowing bounded nonzero `numForcedInclusions` and re-enabling due-entry enforcement. Ensure due forced inclusions must be consumed before normal-only proposal progress.

Tests:
- Keep the existing skip test as a regression test that must fail under the fixed implementation.
- Add tests for due forced-inclusion consumption, head advancement, fee distribution, and rejection when a proposer under-consumes due entries.

Preventive controls:
- Add monitoring for forced-inclusion head/tail age and stuck paid queue entries.
- Document temporary feature disablement with runtime guards that block user payment paths.

<a id="finding-3"></a>

### [3] Disabled SGX enclave-identity checks let arbitrary enclaves become proof signers

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | Source review shows the MR allowlists are gated by a disabled flag while registration consumes `reportData` as the signer; deployment evidence reviewed did not show the flag being enabled. |
| Category | Verifier trust / SGX attestation bypass |
| CWE | CWE-345: Insufficient Verification of Data Authenticity |
| Affected lines | contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:407-414, contracts/layer1/verifiers/SgxVerifier.sol:138-146, contracts/layer1/verifiers/SgxVerifier.sol:160-163, contracts/layer1/verifiers/SgxVerifier.sol:181-186, contracts/layer1/core/impl/Inbox.sol:390-394 |

#### Summary

`SgxVerifier.registerInstance` accepts permissionless SGX instance registration, but the DCAP verifier only checks `MRENCLAVE` and `MRSIGNER` when `checkLocalEnclaveReport` is enabled. With the registrar set to zero, an SGX-capable attacker can place their signer in `reportData`, register it as an instance, and then satisfy SGX proof-signature checks for rollup commitments.

#### Root Cause

The security invariant is that only approved application enclave identities should become proof-signing instances. The implementation stores MR allowlists but makes their enforcement optional and leaves the permissionless registration path able to register the report-data signer after quote validity alone.

**MR allowlist is conditional** — `contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:405-415`

The application enclave identity check is present but skipped whenever `checkLocalEnclaveReport` is false.

```solidity
        // Step 2: Verify application enclave report MRENCLAVE and MRSIGNER
        {
            if (checkLocalEnclaveReport) {
                // 4k gas
                bool mrEnclaveIsTrusted = trustedUserMrEnclave[v3quote.localEnclaveReport.mrEnclave];
                bool mrSignerIsTrusted = trustedUserMrSigner[v3quote.localEnclaveReport.mrSigner];

                if (!mrEnclaveIsTrusted || !mrSignerIsTrusted) {
                    return (false, retData);
                }
            }
```

**Permissionless SGX registration** — `contracts/layer1/verifiers/SgxVerifier.sol:138-146`

Registration is open when `registrar` is zero and trusts the external attestation result.

```solidity
    function registerInstance(V3Struct.ParsedV3QuoteStruct calldata _attestation)
        external
        returns (uint256)
    {
        require(registrar == address(0) || msg.sender == registrar, SGX_NOT_REGISTRAR());

        (bool verified, bytes memory retData) =
            IAttestation(automataDcapAttestation).verifyParsedQuote(_attestation);
        require(verified, SGX_INVALID_ATTESTATION());
```

**Signer comes from reportData** — `contracts/layer1/verifiers/SgxVerifier.sol:160-163`

The registered instance address is derived directly from the quote local report data.

```solidity
        address[] memory addresses = new address[](1);
        addresses[0] = address(bytes20(_attestation.localEnclaveReport.reportData));

        return _addInstances(addresses, false)[0];
```

#### Validation

Validated by direct source tracing from `registerInstance` through Automata attestation to instance storage and proof signature verification. Supporting deployment review found SGX verifier construction with registrar zero and MR allowlist configuration without corresponding evidence that `checkLocalEnclaveReport` is turned on.

Validation method: Static trace plus deployment/configuration review

**MR allowlist is conditional** — `contracts/layer1/automata-attestation/AutomataDcapV3Attestation.sol:405-415`

The application enclave identity check is present but skipped whenever `checkLocalEnclaveReport` is false.

```solidity
        // Step 2: Verify application enclave report MRENCLAVE and MRSIGNER
        {
            if (checkLocalEnclaveReport) {
                // 4k gas
                bool mrEnclaveIsTrusted = trustedUserMrEnclave[v3quote.localEnclaveReport.mrEnclave];
                bool mrSignerIsTrusted = trustedUserMrSigner[v3quote.localEnclaveReport.mrSigner];

                if (!mrEnclaveIsTrusted || !mrSignerIsTrusted) {
                    return (false, retData);
                }
            }
```

**Signer comes from reportData** — `contracts/layer1/verifiers/SgxVerifier.sol:160-163`

The registered instance address is derived directly from the quote local report data.

```solidity
        address[] memory addresses = new address[](1);
        addresses[0] = address(bytes20(_attestation.localEnclaveReport.reportData));

        return _addInstances(addresses, false)[0];
```

**Registered instance signs proofs** — `contracts/layer1/verifiers/SgxVerifier.sol:177-186`

Proof validation accepts signatures from registered instances over the commitment hash.

```solidity
        uint32 id = uint32(bytes4(_proof[:4]));
        address instance = address(bytes20(_proof[4:24]));
        require(_isInstanceValid(id, instance), SGX_INVALID_INSTANCE());

        bytes32 signatureHash = LibPublicInput.hashPublicInputs(
            _aggregatedProvingHash, address(this), instance, taikoChainId
        );

        // Verify the signature was created by the registered instance
        bytes memory signature = _proof[24:];
```

Evidence:
- `verifyParsedQuote` can return true without MR signer/enclave checks when the flag is false.
- `SgxVerifier` maps `localEnclaveReport.reportData` into the registered proof signer.
- `verifyProof` accepts signatures from registered instances over the rollup commitment hash.

Counterevidence and remaining uncertainty:
- Requires a valid DCAP quote from attacker-controlled SGX hardware or equivalent quote-producing access.
- Composed verifier policy may require an independent proof branch, so finality impact depends on active deployment wiring.

#### Dataflow

Attacker-controlled SGX quote data reaches `SgxVerifier.registerInstance`, Automata validates the quote while skipping local enclave identity, `reportData` becomes the registered signer, and `verifyProof` later accepts that signer for commitment hashes passed by `Inbox.prove`.

- **Source:** `localEnclaveReport.reportData` and enclave identity fields in the submitted SGX quote

- **Sink:** `SgxVerifier.verifyProof` signature acceptance and `Inbox.prove` finalization proof verification

- **Outcome:** An arbitrary enclave signer can become an accepted SGX proof instance for affected verifier branches.

Transformations:
- `verifyParsedQuote` validates quote and TCB data but skips MR allowlists when `checkLocalEnclaveReport` is false.
- `registerInstance` casts the first 20 bytes of `reportData` into an address and stores it as an instance.

**Permissionless SGX registration** — `contracts/layer1/verifiers/SgxVerifier.sol:138-146`

Registration is open when `registrar` is zero and trusts the external attestation result.

```solidity
    function registerInstance(V3Struct.ParsedV3QuoteStruct calldata _attestation)
        external
        returns (uint256)
    {
        require(registrar == address(0) || msg.sender == registrar, SGX_NOT_REGISTRAR());

        (bool verified, bytes memory retData) =
            IAttestation(automataDcapAttestation).verifyParsedQuote(_attestation);
        require(verified, SGX_INVALID_ATTESTATION());
```

**Signer comes from reportData** — `contracts/layer1/verifiers/SgxVerifier.sol:160-163`

The registered instance address is derived directly from the quote local report data.

```solidity
        address[] memory addresses = new address[](1);
        addresses[0] = address(bytes20(_attestation.localEnclaveReport.reportData));

        return _addInstances(addresses, false)[0];
```

**Registered instance signs proofs** — `contracts/layer1/verifiers/SgxVerifier.sol:177-186`

Proof validation accepts signatures from registered instances over the commitment hash.

```solidity
        uint32 id = uint32(bytes4(_proof[:4]));
        address instance = address(bytes20(_proof[4:24]));
        require(_isInstanceValid(id, instance), SGX_INVALID_INSTANCE());

        bytes32 signatureHash = LibPublicInput.hashPublicInputs(
            _aggregatedProvingHash, address(this), instance, taikoChainId
        );

        // Verify the signature was created by the registered instance
        bytes memory signature = _proof[24:];
```

#### Reachability

Any caller can reach `registerInstance` when `registrar == address(0)`. An attacker still needs SGX quote material and the target deployment must rely on the affected SGX verifier branch for proof composition.

- **Attacker:** External SGX-capable caller without owner or registrar privileges when registrar is zero

- **Entry point:** `SgxVerifier.registerInstance`

- **Outcome:** Verifier trust is bypassed for the SGX branch, enabling invalid or unauthorized proof signatures under affected composition.

Preconditions:
- The deployed attestation verifier has `checkLocalEnclaveReport` disabled.
- `SgxVerifier.registrar` is zero or otherwise permits attacker registration.
- The final proof composition accepts the affected SGX verifier branch.

#### Severity

**High** — The affected path can weaken the verifier trust boundary that protects L1 finalization. Mainnet composition requires multiple proofs, which bounds the issue below critical unless both required SGX branches or an equivalent composition accept attacker-registered instances.

Severity would increase if deployed verifier composition accepts two affected SGX verifier branches without an independent ZK proof, and would decrease if deployed attestation contracts enable `checkLocalEnclaveReport` before permissionless registration.

#### Remediation

Make local enclave identity enforcement mandatory for production registration, or require `checkLocalEnclaveReport` to be true before `SgxVerifier.registerInstance` accepts permissionless instances. Also bind the expected MR signer/enclave values directly in the verifier or registration call path and fail closed if the allowlists are empty.

Tests:
- Add a test where a quote from an untrusted MR signer/enclave is rejected even when all other quote checks pass.
- Add a deployment invariant test that production SGX verifier registration cannot proceed unless local enclave report checks are enabled and allowlists are populated.

Preventive controls:
- Emit and monitor events for local enclave report toggle changes.
- Add deployment scripts that assert registrar and Automata local-enclave settings before publishing verifier addresses.

<a id="finding-4"></a>

### [4] Beacon proposer-lookahead root is not anchored before slashing evidence is accepted

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | The proof field exists, the validator-index proof is checked under caller-supplied root, and no code references the root proof; the missing binding is direct source evidence. |
| Category | Beacon proof binding / false slashing |
| CWE | CWE-345: Insufficient Verification of Data Authenticity |
| Affected lines | contracts/layer1/preconf/libs/LibEIP4788.sol:92-99, contracts/layer1/preconf/libs/LibEIP4788.sol:28-31, contracts/layer1/preconf/libs/LibEIP4788.sol:102-110, contracts/layer1/preconf/impl/LookaheadSlasher.sol:34-44, contracts/layer1/preconf/impl/LookaheadSlasher.sol:81-86 |

#### Summary

`LibEIP4788.InclusionProof` carries `proposerLookaheadRootProof`, but `verifyValidator` never verifies `proposerLookaheadRoot` against `beaconStateRoot`. It verifies `validatorIndexProof` under the caller-supplied proposer-lookahead root, so slashing evidence can forge the proposer assignment while still anchoring the validator list and beacon state.

#### Root Cause

The invariant is that every proof branch used to establish beacon proposer assignment must be anchored to the same beacon state root. The implementation verifies the validator list and beacon state branches but omits the `proposerLookaheadRootProof` branch that would bind the proposer-lookahead root.

**Proposer lookahead root proof exists** — `contracts/layer1/preconf/libs/LibEIP4788.sol:24-35`

The struct includes a proof that should bind proposer-lookahead root into beacon state.

```solidity
        // Index of the validator in the beacon state proposer lookahead
        uint256 proposerLookaheadIndex;
        // Proof of inclusion of validator index in the proposer lookahead
        bytes32[] validatorIndexProof;
        // Root of the proposer lookahead in the beacon state
        bytes32 proposerLookaheadRoot;
        // Proof of inclusion of the root of proposer lookahead in the beacon state
        bytes32[] proposerLookaheadRootProof;
        // Root of the beacon state
        bytes32 beaconStateRoot;
        // Proof of inclusion of beacon state in the beacon block
        bytes32[] beaconStateRootProof;
```

**Validator index proof uses supplied root** — `contracts/layer1/preconf/libs/LibEIP4788.sol:87-100`

The validator index is proven only against `_inclusionProof.proposerLookaheadRoot`.

```solidity
        // Verify: Validator index is a part of the proposer lookahead at the expected index
        require(
            _inclusionProof.proposerLookaheadIndex == _expectedProposerLookaheadIndex,
            InvalidProposerLookaheadIndex()
        );
        require(
            LibBeaconMerkleUtils.verifyProof(
                _inclusionProof.validatorIndexProof,
                _inclusionProof.proposerLookaheadRoot,
                LibBeaconMerkleUtils.toLittleEndian(_inclusionProof.validatorIndex),
                _inclusionProof.proposerLookaheadIndex
            ),
            ValidatorIndexProofVerificationFailed()
        );
```

**Beacon state root is separately anchored** — `contracts/layer1/preconf/libs/LibEIP4788.sol:102-110`

The beacon state root is anchored to the block root, but proposer-lookahead root is not proven into that state.

```solidity
        // Verify: Beacon state is a part of the beacon block
        require(
            LibBeaconMerkleUtils.verifyProof(
                _inclusionProof.beaconStateRootProof,
                _beaconBlockRoot,
                _inclusionProof.beaconStateRoot,
                3
            ),
            BeaconStateProofVerificationFailed()
```

#### Validation

Validated by source review and repository search. `proposerLookaheadRootProof` appears in the proof struct but is not consumed by `verifyValidator` or any other in-scope verifier path.

Validation method: Static proof-binding review

**Proposer lookahead root proof exists** — `contracts/layer1/preconf/libs/LibEIP4788.sol:24-35`

The struct includes a proof that should bind proposer-lookahead root into beacon state.

```solidity
        // Index of the validator in the beacon state proposer lookahead
        uint256 proposerLookaheadIndex;
        // Proof of inclusion of validator index in the proposer lookahead
        bytes32[] validatorIndexProof;
        // Root of the proposer lookahead in the beacon state
        bytes32 proposerLookaheadRoot;
        // Proof of inclusion of the root of proposer lookahead in the beacon state
        bytes32[] proposerLookaheadRootProof;
        // Root of the beacon state
        bytes32 beaconStateRoot;
        // Proof of inclusion of beacon state in the beacon block
        bytes32[] beaconStateRootProof;
```

**Validator index proof uses supplied root** — `contracts/layer1/preconf/libs/LibEIP4788.sol:87-100`

The validator index is proven only against `_inclusionProof.proposerLookaheadRoot`.

```solidity
        // Verify: Validator index is a part of the proposer lookahead at the expected index
        require(
            _inclusionProof.proposerLookaheadIndex == _expectedProposerLookaheadIndex,
            InvalidProposerLookaheadIndex()
        );
        require(
            LibBeaconMerkleUtils.verifyProof(
                _inclusionProof.validatorIndexProof,
                _inclusionProof.proposerLookaheadRoot,
                LibBeaconMerkleUtils.toLittleEndian(_inclusionProof.validatorIndex),
                _inclusionProof.proposerLookaheadIndex
            ),
            ValidatorIndexProofVerificationFailed()
        );
```

**Beacon state root is separately anchored** — `contracts/layer1/preconf/libs/LibEIP4788.sol:102-110`

The beacon state root is anchored to the block root, but proposer-lookahead root is not proven into that state.

```solidity
        // Verify: Beacon state is a part of the beacon block
        require(
            LibBeaconMerkleUtils.verifyProof(
                _inclusionProof.beaconStateRootProof,
                _beaconBlockRoot,
                _inclusionProof.beaconStateRoot,
                3
            ),
            BeaconStateProofVerificationFailed()
```

Evidence:
- `validatorIndexProof` is checked against the supplied `proposerLookaheadRoot`.
- `beaconStateRootProof` is checked, but no check connects `proposerLookaheadRoot` to `beaconStateRoot`.
- The variable-depth Merkle helper issue was considered supporting context and subsumed by this missing binding.

Counterevidence and remaining uncertainty:
- No concrete malicious SSZ proof vector was generated.
- The validator-list branch is anchored correctly, so the issue is specific to proposer assignment binding.

#### Dataflow

Slashing evidence supplies a beacon validator proof. `verifyValidator` proves the validator index under a caller-controlled proposer-lookahead root, then proves the beacon state root to the block root without ever proving the proposer-lookahead root into that state. `LookaheadSlasher` can then accept the forged assignment.

- **Source:** Caller-controlled `proposerLookaheadRoot` and `validatorIndexProof` in slashing evidence

- **Sink:** `LookaheadSlasher.slash` returning `slashAmount` for forged beacon proposer assignment

- **Outcome:** False slashing evidence can be accepted because proposer assignment is not cryptographically bound to the beacon state.

Transformations:
- Verifier checks the expected proposer-lookahead index.
- Verifier validates the validator index under the supplied root.
- Verifier anchors only `beaconStateRoot`, leaving proposer-lookahead root unanchored.

**Validator index proof uses supplied root** — `contracts/layer1/preconf/libs/LibEIP4788.sol:87-100`

The validator index is proven only against `_inclusionProof.proposerLookaheadRoot`.

```solidity
        // Verify: Validator index is a part of the proposer lookahead at the expected index
        require(
            _inclusionProof.proposerLookaheadIndex == _expectedProposerLookaheadIndex,
            InvalidProposerLookaheadIndex()
        );
        require(
            LibBeaconMerkleUtils.verifyProof(
                _inclusionProof.validatorIndexProof,
                _inclusionProof.proposerLookaheadRoot,
                LibBeaconMerkleUtils.toLittleEndian(_inclusionProof.validatorIndex),
                _inclusionProof.proposerLookaheadIndex
            ),
            ValidatorIndexProofVerificationFailed()
        );
```

**Beacon state root is separately anchored** — `contracts/layer1/preconf/libs/LibEIP4788.sol:102-110`

The beacon state root is anchored to the block root, but proposer-lookahead root is not proven into that state.

```solidity
        // Verify: Beacon state is a part of the beacon block
        require(
            LibBeaconMerkleUtils.verifyProof(
                _inclusionProof.beaconStateRootProof,
                _beaconBlockRoot,
                _inclusionProof.beaconStateRoot,
                3
            ),
            BeaconStateProofVerificationFailed()
```

#### Reachability

The path is reachable through URC slashing evidence processed by `LookaheadSlasher`. An attacker needs to craft internally consistent proof material under the chosen proposer-lookahead root.

- **Attacker:** URC challenger or slashing-evidence submitter

- **Entry point:** `LookaheadSlasher.slash` via `LibEIP4788.verifyValidator`

- **Outcome:** Forged beacon proposer assignment can drive false invalid/missing-operator slashing.

Preconditions:
- URC invokes the slasher with attacker-supplied evidence.
- Evidence includes valid branches for the anchored validator list and beacon state.
- Chosen proposer-lookahead root makes the validator-index proof pass.

#### Severity

**High** — The missing beacon root binding can make false proposer evidence pass and reach the URC slashing sink. This can cause unjust collateral slashing; no full SSZ proof vector was generated, but the absent check is explicit.

Severity would increase with a concrete malicious SSZ proof vector against deployed parameters; it would decrease if upstream evidence generation independently binds `proposerLookaheadRoot` to the same beacon state root before this library is called.

#### Remediation

Verify `proposerLookaheadRootProof` against `beaconStateRoot` at the correct SSZ generalized index before using `proposerLookaheadRoot` for `validatorIndexProof`. Reject evidence if the proof is absent, has the wrong depth, or does not bind to the same beacon state root.

Tests:
- Add a negative test where `validatorIndexProof` passes under a forged proposer-lookahead root but `proposerLookaheadRootProof` does not bind to the beacon state.
- Add a positive test with a valid full proof tuple for the expected beacon fork.

Preventive controls:
- Centralize beacon proof generalized indices as named constants and test them against canonical SSZ vectors.
- Require every field named `*RootProof` in evidence structs to be consumed or explicitly documented as unused.

<a id="finding-5"></a>

### [5] Lookahead slashing can classify an already assigned earlier slot as missing

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | The comparison error and slashing sink are explicit in source; no full URC integration PoC was needed to establish the broken control. |
| Category | Preconfirmation slashing / false evidence |
| CWE | CWE-345: Insufficient Verification of Data Authenticity |
| Affected lines | contracts/layer1/preconf/impl/LookaheadSlasher.sol:130-131, contracts/layer1/preconf/impl/LookaheadSlasher.sol:34-44, contracts/layer1/preconf/impl/LookaheadSlasher.sol:71-86 |

#### Summary

`_validateLookaheadEvidence` lets evidence choose a later `lookaheadSlotsIndex` for an earlier slot timestamp because it only enforces `slotTimestamp <= selected.timestamp` and epoch lower bound. `slash` then treats mismatched timestamps as missing-operator evidence and can return `slashAmount` for a slot that was actually assigned earlier in the same lookahead.

#### Root Cause

The invariant is that slashing evidence must bind the slot timestamp to the exact lookahead entry that covers that slot. The implementation validates only an upper bound for the selected entry, so a later assigned slot can be used to classify an earlier assigned slot as missing.

**Lookahead index only has upper-bound timestamp check** — `contracts/layer1/preconf/impl/LookaheadSlasher.sol:125-131`

The selected lookahead slot only needs a timestamp at or after the evidence slot, so a later index can cover an earlier assigned slot.

```solidity
        if (_lookaheadSlots.length != 0) {
            lookaheadSlot_ = _lookaheadSlots[evidenceLookahead.lookaheadSlotsIndex];

            // Verify that `slotTimestamp_` is within the range of the timestamp contained in the
            // provided lookahead slot entry.
            if (slotTimestamp_ > lookaheadSlot_.timestamp || slotTimestamp_ < epochTimestamp) {
                revert InvalidLookaheadSlotsIndex();
```

**Mismatched timestamp enters missing-operator branch** — `contracts/layer1/preconf/impl/LookaheadSlasher.sol:71-86`

If selected lookahead slot timestamp does not equal the evidence slot timestamp, the function validates missing-operator evidence and returns `slashAmount`.

```solidity
        if (lookaheadSlots.length != 0 && lookaheadSlot.timestamp == slotTimestamp) {
            // This condition is executed when the problematic slot is a dedicated slot of an
            // operator, but is assigned to the wrong operator i.e the beacon validator is
            // not registered to the operator in the URC.
            _validateInvalidOperatorEvidence(
                lookaheadSlot, beaconLookaheadValPubKey, evidenceInvalidOrMissingOperator
            );
        } else {
            // This condition is executed when the problematic slot has no assigned operator i.e
            // when it is an advanced proposal slot, or when the lookahead is empty.
            _validateMissingOperatorEvidence(
                previousEpochTimestamp, beaconLookaheadValPubKey, evidenceInvalidOrMissingOperator
            );
        }

        return slashAmount;
```

#### Validation

Validated by source review of `_validateLookaheadEvidence` and `slash`. `LookaheadStore` enforces increasing timestamps, which means the missing lower-bound check is necessary and the later-index attack is structurally possible.

Validation method: Static trace of evidence validation and slashing return

**Lookahead index only has upper-bound timestamp check** — `contracts/layer1/preconf/impl/LookaheadSlasher.sol:125-131`

The selected lookahead slot only needs a timestamp at or after the evidence slot, so a later index can cover an earlier assigned slot.

```solidity
        if (_lookaheadSlots.length != 0) {
            lookaheadSlot_ = _lookaheadSlots[evidenceLookahead.lookaheadSlotsIndex];

            // Verify that `slotTimestamp_` is within the range of the timestamp contained in the
            // provided lookahead slot entry.
            if (slotTimestamp_ > lookaheadSlot_.timestamp || slotTimestamp_ < epochTimestamp) {
                revert InvalidLookaheadSlotsIndex();
```

**Mismatched timestamp enters missing-operator branch** — `contracts/layer1/preconf/impl/LookaheadSlasher.sol:71-86`

If selected lookahead slot timestamp does not equal the evidence slot timestamp, the function validates missing-operator evidence and returns `slashAmount`.

```solidity
        if (lookaheadSlots.length != 0 && lookaheadSlot.timestamp == slotTimestamp) {
            // This condition is executed when the problematic slot is a dedicated slot of an
            // operator, but is assigned to the wrong operator i.e the beacon validator is
            // not registered to the operator in the URC.
            _validateInvalidOperatorEvidence(
                lookaheadSlot, beaconLookaheadValPubKey, evidenceInvalidOrMissingOperator
            );
        } else {
            // This condition is executed when the problematic slot has no assigned operator i.e
            // when it is an advanced proposal slot, or when the lookahead is empty.
            _validateMissingOperatorEvidence(
                previousEpochTimestamp, beaconLookaheadValPubKey, evidenceInvalidOrMissingOperator
            );
        }

        return slashAmount;
```

Evidence:
- `lookaheadSlot_` is selected directly by attacker-provided `lookaheadSlotsIndex`.
- The check rejects only timestamps above the selected slot or below epoch start.
- `slash` routes timestamp mismatch to missing-operator validation and returns `slashAmount`.

Counterevidence and remaining uncertainty:
- No full URC transaction-level PoC was executed.
- Remaining evidence pieces still need to pass beacon-validator and registration checks.

#### Dataflow

Evidence supplies a slot timestamp for an earlier assigned slot and a later `lookaheadSlotsIndex`. The validation accepts the tuple because the earlier timestamp is below the later entry. `slash` then sees timestamp mismatch and processes missing-operator evidence.

- **Source:** Attacker-controlled `EvidenceLookahead.slotTimestamp` and `lookaheadSlotsIndex` inside URC slashing evidence

- **Sink:** `slashAmount` returned to URC from `LookaheadSlasher.slash`

- **Outcome:** An honest operator or lookahead poster can be slashed for a slot that was not missing.

Transformations:
- Evidence index selects a later lookahead slot.
- Validation checks only selected timestamp upper bound and epoch lower bound.
- Timestamp mismatch drives the missing-operator branch.

**Lookahead index only has upper-bound timestamp check** — `contracts/layer1/preconf/impl/LookaheadSlasher.sol:125-131`

The selected lookahead slot only needs a timestamp at or after the evidence slot, so a later index can cover an earlier assigned slot.

```solidity
        if (_lookaheadSlots.length != 0) {
            lookaheadSlot_ = _lookaheadSlots[evidenceLookahead.lookaheadSlotsIndex];

            // Verify that `slotTimestamp_` is within the range of the timestamp contained in the
            // provided lookahead slot entry.
            if (slotTimestamp_ > lookaheadSlot_.timestamp || slotTimestamp_ < epochTimestamp) {
                revert InvalidLookaheadSlotsIndex();
```

**Mismatched timestamp enters missing-operator branch** — `contracts/layer1/preconf/impl/LookaheadSlasher.sol:71-86`

If selected lookahead slot timestamp does not equal the evidence slot timestamp, the function validates missing-operator evidence and returns `slashAmount`.

```solidity
        if (lookaheadSlots.length != 0 && lookaheadSlot.timestamp == slotTimestamp) {
            // This condition is executed when the problematic slot is a dedicated slot of an
            // operator, but is assigned to the wrong operator i.e the beacon validator is
            // not registered to the operator in the URC.
            _validateInvalidOperatorEvidence(
                lookaheadSlot, beaconLookaheadValPubKey, evidenceInvalidOrMissingOperator
            );
        } else {
            // This condition is executed when the problematic slot has no assigned operator i.e
            // when it is an advanced proposal slot, or when the lookahead is empty.
            _validateMissingOperatorEvidence(
                previousEpochTimestamp, beaconLookaheadValPubKey, evidenceInvalidOrMissingOperator
            );
        }

        return slashAmount;
```

#### Reachability

The entrypoint is restricted to the URC contract, but adversarial slashing evidence is the expected input to the URC slasher callback. An attacker who can submit accepted evidence can trigger the bad branch.

- **Attacker:** URC challenger or slashing-evidence submitter

- **Entry point:** URC call into `LookaheadSlasher.slash`

- **Outcome:** False slashing of preconfirmation collateral.

Preconditions:
- Lookahead contains at least two ordered slots in the same epoch.
- Evidence can satisfy the other beacon-validator and registration checks.
- URC invokes the configured slasher with the crafted evidence.

#### Severity

**High** — A false slashing proof can burn or transfer meaningful operator collateral through the URC slashing path, and the attacker-controlled index/timestamp mismatch is directly accepted by source logic.

Severity would increase with demonstrated full URC collateral loss on deployed state; it would decrease if upstream URC or evidence construction prevents mismatched lookahead index and slot timestamp tuples.

#### Remediation

Validate that `slotTimestamp` lies in the interval belonging to the selected lookahead index: greater than the previous lookahead slot timestamp or epoch start, and less than or equal to the selected timestamp. Reject mismatched assigned slots before entering the missing-operator branch.

Tests:
- Add tests with two lookahead slots where evidence for the first slot uses the second index and must revert.
- Add boundary tests for index zero and adjacent slot windows.

Preventive controls:
- Encode lookahead evidence with explicit previous/next slot bounds or derive the index from the timestamp rather than trusting it from evidence.
- Add property tests over ordered lookahead arrays and slot timestamps.

<a id="finding-6"></a>

### [6] Ejecter role can promote arbitrary preconfirmation proposers

| Field | Value |
| --- | --- |
| Severity | medium |
| Confidence | medium |
| Confidence rationale | The authorization edge is clear in source, but final severity depends on operational role policy that is not fully documented in code. |
| Category | Role overreach / preconfirmation authorization |
| CWE | CWE-266: Incorrect Privilege Assignment |
| Affected lines | contracts/layer1/preconf/impl/PreconfWhitelist.sol:94-95, contracts/layer1/preconf/impl/PreconfWhitelist.sol:207-211, contracts/layer1/preconf/impl/PreconfWhitelist.sol:136-138 |

#### Summary

`PreconfWhitelist.addOperator` is guarded by `onlyOwnerOrEjecter`, the same role used for removals. Any configured ejecter can add an arbitrary proposer/sequencer pair, which later becomes selectable by `checkProposer` after the operator-change delay.

#### Root Cause

The invariant is that lower-trust ejection authority should not also grant admission authority unless explicitly intended. The implementation uses one modifier for both adding and removing operators, allowing ejecters to promote new proposers.

**Ejecter can add operators** — `contracts/layer1/preconf/impl/PreconfWhitelist.sol:92-100`

`addOperator` and `removeOperator` share `onlyOwnerOrEjecter` even though one grants new operator power.

```solidity
    /// @inheritdoc IPreconfWhitelist
    /// @dev The operator only becomes active after `OPERATOR_CHANGE_DELAY` epochs.
    function addOperator(address _proposer, address _sequencer) external onlyOwnerOrEjecter {
        _addOperator(_proposer, _sequencer);
    }

    /// @inheritdoc IPreconfWhitelist
    /// @dev IMPORTANT: The operator is removed immediately
    function removeOperator(uint256 _operatorIndex) external onlyOwnerOrEjecter {
```

**Operator is persisted** — `contracts/layer1/preconf/impl/PreconfWhitelist.sol:203-211`

`_addOperator` writes the proposer into operator state after nonzero checks.

```solidity
    /// @dev Adds an operator to the whitelist.
    /// NOTE: The operator only becomes active after `OPERATOR_CHANGE_DELAY` epochs.
    /// @param _proposer The proposer address of the operator to add.
    /// @param _sequencer The sequencer address of the operator to add.
    function _addOperator(address _proposer, address _sequencer) internal {
        require(_proposer != address(0), InvalidOperatorAddress());
        require(_sequencer != address(0), InvalidOperatorAddress());

        OperatorInfo storage info = operators[_proposer];
```

#### Validation

Validated by source review of add/remove authorization, operator persistence, and proposer checking. The main uncertainty is role policy rather than code reachability.

Validation method: Static authorization review

**Ejecter can add operators** — `contracts/layer1/preconf/impl/PreconfWhitelist.sol:92-100`

`addOperator` and `removeOperator` share `onlyOwnerOrEjecter` even though one grants new operator power.

```solidity
    /// @inheritdoc IPreconfWhitelist
    /// @dev The operator only becomes active after `OPERATOR_CHANGE_DELAY` epochs.
    function addOperator(address _proposer, address _sequencer) external onlyOwnerOrEjecter {
        _addOperator(_proposer, _sequencer);
    }

    /// @inheritdoc IPreconfWhitelist
    /// @dev IMPORTANT: The operator is removed immediately
    function removeOperator(uint256 _operatorIndex) external onlyOwnerOrEjecter {
```

**Stored operator is accepted as proposer** — `contracts/layer1/preconf/impl/PreconfWhitelist.sol:126-140`

`checkProposer` accepts the active operator returned for the epoch.

```solidity
    /// @inheritdoc IProposerChecker
    function checkProposer(
        address _proposer,
        bytes calldata
    )
        external
        view
        override(IProposerChecker)
        returns (uint48 endOfSubmissionWindowTimestamp_)
    {
        address operator = _getOperatorForEpoch(epochStartTimestamp(0));
        require(operator != address(0), InvalidProposer());
        require(operator == _proposer, InvalidProposer());
        // Slashing is not enabled for whitelisted preconfers, so we return 0
        endOfSubmissionWindowTimestamp_ = 0;
```

Evidence:
- `addOperator` is callable by owner or ejecter.
- `_addOperator` records the proposer/sequencer pair.
- `checkProposer` accepts the active stored operator.

Counterevidence and remaining uncertainty:
- If ejecters are intentionally full operator managers, this is not a privilege escalation.
- Owner or ejector manager must first grant ejecter status.

#### Dataflow

A configured ejecter calls `addOperator`, `_addOperator` stores the proposer, the activation delay passes, and `checkProposer` can accept that proposer for block proposals.

- **Source:** Ejecter-controlled `_proposer` and `_sequencer` arguments

- **Sink:** `checkProposer` accepting the stored proposer as current operator

- **Outcome:** Ejecter role can admit arbitrary preconfirmation proposers.

Transformations:
- `onlyOwnerOrEjecter` authorizes both admission and removal.
- `_addOperator` schedules the operator for later activation.

**Ejecter can add operators** — `contracts/layer1/preconf/impl/PreconfWhitelist.sol:92-100`

`addOperator` and `removeOperator` share `onlyOwnerOrEjecter` even though one grants new operator power.

```solidity
    /// @inheritdoc IPreconfWhitelist
    /// @dev The operator only becomes active after `OPERATOR_CHANGE_DELAY` epochs.
    function addOperator(address _proposer, address _sequencer) external onlyOwnerOrEjecter {
        _addOperator(_proposer, _sequencer);
    }

    /// @inheritdoc IPreconfWhitelist
    /// @dev IMPORTANT: The operator is removed immediately
    function removeOperator(uint256 _operatorIndex) external onlyOwnerOrEjecter {
```

**Stored operator is accepted as proposer** — `contracts/layer1/preconf/impl/PreconfWhitelist.sol:126-140`

`checkProposer` accepts the active operator returned for the epoch.

```solidity
    /// @inheritdoc IProposerChecker
    function checkProposer(
        address _proposer,
        bytes calldata
    )
        external
        view
        override(IProposerChecker)
        returns (uint48 endOfSubmissionWindowTimestamp_)
    {
        address operator = _getOperatorForEpoch(epochStartTimestamp(0));
        require(operator != address(0), InvalidProposer());
        require(operator == _proposer, InvalidProposer());
        // Slashing is not enabled for whitelisted preconfers, so we return 0
        endOfSubmissionWindowTimestamp_ = 0;
```

#### Reachability

Only addresses already granted ejecter privileges can trigger the path. The resulting proposer becomes active after `OPERATOR_CHANGE_DELAY`, limiting immediacy but not the privilege expansion.

- **Attacker:** Compromised or lower-trust ejecter address

- **Entry point:** `PreconfWhitelist.addOperator`

- **Outcome:** Unauthorized or unintended proposer admission into the preconfirmation whitelist.

Preconditions:
- Ejecter role is granted to the attacker or compromised address.
- Operator-change delay elapses.
- Preconf whitelist is used as the active proposer checker.

#### Severity

**Medium** — This is a role-overreach issue if ejecters are intended to remove bad operators rather than admit new ones. Impact is bounded by privileged ejecter assignment and activation delay, and it becomes policy-compatible if ejecters are intentionally full operator managers.

Severity would increase if ejecter keys are broadly delegated or operationally lower-trust than owner keys; it would decrease if documentation and governance policy define ejecters as operator-admission managers.

#### Remediation

Split admission and removal roles. Restrict `addOperator` to owner or a dedicated operator-manager role, leaving ejecters limited to removal/ejection if that is the intended policy.

Tests:
- Add tests proving ejecters can remove but cannot add operators unless explicitly granted an admission role.
- Add a role-policy test that `checkProposer` does not accept operators added by unauthorized roles.

Preventive controls:
- Document the operational trust level of ejecters.
- Emit distinct events and monitoring alerts for operator admission by non-owner roles.

<a id="finding-7"></a>

### [7] Public golden-touch signer can write Anchor checkpoints at the contract layer

| Field | Value |
| --- | --- |
| Severity | medium |
| Confidence | medium |
| Confidence rationale | Focused Foundry testing confirms the contract-layer write path, but final asset/security impact depends on off-chain derivation and proof rejection behavior. |
| Category | L2 anchoring / checkpoint trust |
| CWE | CWE-345: Insufficient Verification of Data Authenticity |
| Affected lines | contracts/layer2/core/Anchor.sol:87-88, contracts/layer2/core/Anchor.sol:37, contracts/layer2/core/Anchor.sol:124-130, contracts/layer2/core/Anchor.sol:181-184 |

#### Summary

`Anchor.anchorV4` authorizes only `GOLDEN_TOUCH_ADDRESS`, but the corresponding golden-touch private key is public protocol material. At the contract layer, any holder of that key can submit a fresher checkpoint and `checkpointStore.saveCheckpoint` persists it without verifying the checkpoint root or block hash against L1.

#### Root Cause

The invariant is that checkpoint data accepted by the L2 Anchor should be bound to authentic L1 data or to an authority that is not publicly forgeable. The implementation relies on `msg.sender == GOLDEN_TOUCH_ADDRESS`, while that signer is public by design and checkpoint contents are not verified in the contract.

**Golden-touch address constant** — `contracts/layer2/core/Anchor.sol:36-37`

The single authorized sender is a hard-coded address.

```solidity
    /// @notice Golden touch address is the only address that can do the anchor transaction.
    address public constant GOLDEN_TOUCH_ADDRESS = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;
```

**Only sender check** — `contracts/layer2/core/Anchor.sol:86-88`

The modifier checks only `msg.sender` against the golden-touch address.

```solidity
    modifier onlyValidSender() {
        require(msg.sender == GOLDEN_TOUCH_ADDRESS, InvalidSender());
        _;
```

**Checkpoint persistence sink** — `contracts/layer2/core/Anchor.sol:181-184`

A fresher checkpoint is saved without contract-layer verification against L1 roots.

```solidity
        // Anchor checkpoint data if a fresher L1 block is provided
        if (_checkpoint.blockNumber > _blockState.anchorBlockNumber) {
            checkpointStore.saveCheckpoint(_checkpoint);
            _blockState.anchorBlockNumber = _checkpoint.blockNumber;
```

#### Validation

Validated by focused Foundry test `forge test --match-contract AnchorTest --match-test test_anchorV4_savesCheckpointAndUpdatesState -vv`, which passed. The golden-touch private key was also checked locally to derive `0x0000777735367b36bC9B61C50022d9D0700dB4Ec`.

Validation method: Focused Foundry test plus key/address derivation

**Only sender check** — `contracts/layer2/core/Anchor.sol:86-88`

The modifier checks only `msg.sender` against the golden-touch address.

```solidity
    modifier onlyValidSender() {
        require(msg.sender == GOLDEN_TOUCH_ADDRESS, InvalidSender());
        _;
```

**Checkpoint persistence sink** — `contracts/layer2/core/Anchor.sol:181-184`

A fresher checkpoint is saved without contract-layer verification against L1 roots.

```solidity
        // Anchor checkpoint data if a fresher L1 block is provided
        if (_checkpoint.blockNumber > _blockState.anchorBlockNumber) {
            checkpointStore.saveCheckpoint(_checkpoint);
            _blockState.anchorBlockNumber = _checkpoint.blockNumber;
```

Evidence:
- Focused Anchor test passed and showed `anchorV4` saves fresher checkpoints.
- Local key derivation matched the hard-coded golden-touch address.
- `_validateBlock` saves the checkpoint when block number increases.

Counterevidence and remaining uncertainty:
- Taiko docs and prover/client paths expect the canonical anchor transaction to be first and correctly parameterized.
- Final L1 proof acceptance should reject bad anchor transactions, but that control is outside the Anchor contract.

#### Dataflow

An attacker signs an L2 transaction from the public golden-touch key, calls `anchorV4` with a fresher checkpoint, passes the sender and ancestors-hash checks, and writes the checkpoint into `checkpointStore`.

- **Source:** Caller-supplied `ICheckpointStore.Checkpoint` in a transaction from the golden-touch address

- **Sink:** `checkpointStore.saveCheckpoint(_checkpoint)`

- **Outcome:** L2 checkpoint state can be updated at the contract layer with attacker-chosen fresher checkpoint data.

Transformations:
- Sender check validates only the golden-touch address.
- Ancestors hash is updated independently from checkpoint authenticity.
- Fresher block numbers are persisted without L1 root verification.

**Golden-touch address constant** — `contracts/layer2/core/Anchor.sol:36-37`

The single authorized sender is a hard-coded address.

```solidity
    /// @notice Golden touch address is the only address that can do the anchor transaction.
    address public constant GOLDEN_TOUCH_ADDRESS = 0x0000777735367b36bC9B61C50022d9D0700dB4Ec;
```

**Only sender check** — `contracts/layer2/core/Anchor.sol:86-88`

The modifier checks only `msg.sender` against the golden-touch address.

```solidity
    modifier onlyValidSender() {
        require(msg.sender == GOLDEN_TOUCH_ADDRESS, InvalidSender());
        _;
```

**Checkpoint persistence sink** — `contracts/layer2/core/Anchor.sol:181-184`

A fresher checkpoint is saved without contract-layer verification against L1 roots.

```solidity
        // Anchor checkpoint data if a fresher L1 block is provided
        if (_checkpoint.blockNumber > _blockState.anchorBlockNumber) {
            checkpointStore.saveCheckpoint(_checkpoint);
            _blockState.anchorBlockNumber = _checkpoint.blockNumber;
```

#### Reachability

Anyone with the public golden-touch private key can produce the required sender. Impact is constrained by off-chain derivation/prover rules and by consumers that wait for final L1 proofs.

- **Attacker:** External caller using the public golden-touch private key

- **Entry point:** `Anchor.anchorV4`

- **Outcome:** Attacker-chosen checkpoint can exist in L2 contract state before higher-level controls reject the block.

Preconditions:
- The golden-touch private key remains public and accepted for anchor transactions.
- Attacker can submit an L2 transaction from that address.
- Consumer reads or trusts the checkpoint before derivation/proof rejection, or finality controls fail to reject it.

#### Severity

**Medium** — The contract-layer checkpoint authority is publicly reproducible, but documentation and prover/client flows should reject bad anchor transactions before final L1 proof acceptance. The finding remains medium because unsafe L2 state or downstream consumers may rely on the checkpoint before those off-chain/proof controls reject it.

Severity would increase if forged checkpoints can survive derivation/proving and be accepted by L1 bridge or signal consumers; it would decrease if all consumers treat Anchor checkpoints as unsafe until independently proven by L1 finality.

#### Remediation

Bind checkpoints to verifiable L1 data in the contract, or ensure the contract writes only data supplied by a non-public system authority. If the public golden-touch model is required, make Anchor state explicitly unsafe until independently verified and prevent bridge/signal consumers from relying on unfinalized checkpoints.

Tests:
- Add a negative test where an attacker-signed golden-touch transaction with incorrect checkpoint data is rejected by contract-level validation or by an enforced consumer guard.
- Add an integration test covering derivation/prover rejection before any bridge or signal consumer can use the forged checkpoint.

Preventive controls:
- Document Anchor checkpoint trust boundaries in contract comments and consumer APIs.
- Monitor unexpected golden-touch transactions and checkpoint jumps.

<a id="finding-8"></a>

### [8] Signature delegation bypasses TaikoToken non-voting account guard and lowers voting supply

| Field | Value |
| --- | --- |
| Severity | medium |
| Confidence | medium |
| Confidence rationale | The local token override and supply calculation are clear, but the inherited OpenZeppelin `delegateBySig` implementation and active governance consumers were not fully resolved inside the scoped contracts tree. |
| Category | Governance voting-supply manipulation |
| CWE | CWE-284: Improper Access Control |
| Affected lines | contracts/layer1/mainnet/TaikoToken.sol:46-52, contracts/layer1/mainnet/TaikoToken.sol:73-80 |

#### Summary

`TaikoToken.delegate(address)` blocks delegation to or from fixed non-voting accounts, but the inherited `delegateBySig` path is not overridden. A holder can delegate by signature to a non-voting account, then `getPastTotalSupply` subtracts that account’s raw delegated votes, lowering voting supply used by quorum consumers.

#### Root Cause

The invariant is that non-voting accounts cannot receive third-party voting power. The contract enforces that invariant only in `delegate(address)` while inherited signature delegation can update vote checkpoints without this override.

**Direct delegation guard** — `contracts/layer1/mainnet/TaikoToken.sol:46-52`

The local override rejects direct delegation to or from non-voting accounts.

```solidity
    function delegate(address _account) public override {
        // Ensure non-voting accounts cannot delegate or being delegated to.
        address[] memory accounts = getNonVotingAccounts();
        for (uint256 i; i < accounts.length; ++i) {
            require(_account != accounts[i] && msg.sender != accounts[i], TT_NON_VOTING_ACCOUNT());
        }
        super.delegate(_account);
```

**Voting supply subtracts raw delegated votes** — `contracts/layer1/mainnet/TaikoToken.sol:71-80`

`getPastTotalSupply` subtracts `super.getPastVotes` for non-voting accounts, including votes delegated to those accounts.

```solidity
    /// @notice This override modifies the return value to reflect the past total supply eligible
    /// for voting.
    function getPastTotalSupply(uint256 _timepoint) public view override returns (uint256) {
        uint256 nonVotingSupply;
        address[] memory accounts = getNonVotingAccounts();
        for (uint256 i; i < accounts.length; ++i) {
            // Must use `super.getPastVotes` instead of `this.getPastVotes`
            nonVotingSupply += super.getPastVotes(accounts[i], _timepoint);
        }
        return super.getPastTotalSupply(_timepoint) - nonVotingSupply;
```

#### Validation

Validated by local source review of the direct delegate guard and total-supply calculation. Standard ERC20Votes exposes `delegateBySig`, but no local override was found in `TaikoToken`.

Validation method: Static trace against inherited token behavior

**Direct delegation guard** — `contracts/layer1/mainnet/TaikoToken.sol:46-52`

The local override rejects direct delegation to or from non-voting accounts.

```solidity
    function delegate(address _account) public override {
        // Ensure non-voting accounts cannot delegate or being delegated to.
        address[] memory accounts = getNonVotingAccounts();
        for (uint256 i; i < accounts.length; ++i) {
            require(_account != accounts[i] && msg.sender != accounts[i], TT_NON_VOTING_ACCOUNT());
        }
        super.delegate(_account);
```

**Voting supply subtracts raw delegated votes** — `contracts/layer1/mainnet/TaikoToken.sol:71-80`

`getPastTotalSupply` subtracts `super.getPastVotes` for non-voting accounts, including votes delegated to those accounts.

```solidity
    /// @notice This override modifies the return value to reflect the past total supply eligible
    /// for voting.
    function getPastTotalSupply(uint256 _timepoint) public view override returns (uint256) {
        uint256 nonVotingSupply;
        address[] memory accounts = getNonVotingAccounts();
        for (uint256 i; i < accounts.length; ++i) {
            // Must use `super.getPastVotes` instead of `this.getPastVotes`
            nonVotingSupply += super.getPastVotes(accounts[i], _timepoint);
        }
        return super.getPastTotalSupply(_timepoint) - nonVotingSupply;
```

Evidence:
- `delegate(address)` rejects non-voting targets.
- `getPastTotalSupply` subtracts raw votes recorded for non-voting accounts.
- No local `delegateBySig` override was found in `TaikoToken.sol`.

Counterevidence and remaining uncertainty:
- The scoped repository scan did not identify an active in-scope Governor consumer.
- Exact exploit impact depends on the external governance/quorum configuration.

#### Dataflow

A holder signs a `delegateBySig` delegation to a non-voting account. The inherited path updates vote checkpoints. Later, `getPastTotalSupply` subtracts the non-voting account’s `super.getPastVotes`, reducing reported voting supply.

- **Source:** Holder signature authorizing delegation to a fixed non-voting account

- **Sink:** `getPastTotalSupply` result consumed by quorum or governance logic

- **Outcome:** Voting supply can be lowered, potentially reducing quorum thresholds.

Transformations:
- Signature delegation bypasses the local `delegate(address)` guard.
- The supply override subtracts the recipient account’s raw checkpointed votes.

**Voting supply subtracts raw delegated votes** — `contracts/layer1/mainnet/TaikoToken.sol:71-80`

`getPastTotalSupply` subtracts `super.getPastVotes` for non-voting accounts, including votes delegated to those accounts.

```solidity
    /// @notice This override modifies the return value to reflect the past total supply eligible
    /// for voting.
    function getPastTotalSupply(uint256 _timepoint) public view override returns (uint256) {
        uint256 nonVotingSupply;
        address[] memory accounts = getNonVotingAccounts();
        for (uint256 i; i < accounts.length; ++i) {
            // Must use `super.getPastVotes` instead of `this.getPastVotes`
            nonVotingSupply += super.getPastVotes(accounts[i], _timepoint);
        }
        return super.getPastTotalSupply(_timepoint) - nonVotingSupply;
```

#### Reachability

Any token holder can use inherited signature delegation if available, but meaningful impact requires a governance consumer that uses this token oracle for quorum or supply.

- **Attacker:** Any token holder able to sign delegation messages

- **Entry point:** Inherited `ERC20VotesUpgradeable.delegateBySig`

- **Outcome:** Governance supply accounting can be distorted for consumers of `getPastTotalSupply`.

Preconditions:
- Inherited `delegateBySig` is exposed in the deployed token.
- A holder delegates voting power to a listed non-voting account.
- A governance consumer relies on `getPastTotalSupply`.

#### Severity

**Medium** — The token-level voting oracle can be manipulated by any holder willing to delegate votes, but the scan did not find an in-scope Governor consumer, so deployed governance impact remains a consumer-dependent proof gap.

Severity would increase if production quorum or governance contracts consume `TaikoToken.getPastTotalSupply`; it would decrease if no governance consumer uses this token supply or if inherited signature delegation is disabled elsewhere.

#### Remediation

Override `delegateBySig` or the internal delegation hook used by both direct and signature delegation so the non-voting-account invariant is enforced for every delegation path. Consider subtracting only the accounts’ own balances or preventing third-party votes from being checkpointed to excluded accounts.

Tests:
- Add tests showing direct and signature delegation to non-voting accounts both revert.
- Add a supply accounting test where a third party attempts to delegate to a non-voting account and total supply remains unchanged.

Preventive controls:
- Audit all inherited token entrypoints when adding policy checks to only one public wrapper.
- Document governance consumers of `getPastTotalSupply` and test quorum assumptions against delegation edge cases.

<a id="finding-9"></a>

### [9] Permissionless proving fallback is unreachable while any prover remains whitelisted

| Field | Value |
| --- | --- |
| Severity | medium |
| Confidence | high |
| Confidence rationale | The control flow is direct: `_checkProver` reverts before any age-based proof verifier policy can execute. |
| Category | Rollup liveness / prover whitelist |
| CWE | CWE-841: Improper Enforcement of Behavioral Workflow |
| Affected lines | contracts/layer1/core/impl/Inbox.sol:756-763, contracts/layer1/core/impl/Inbox.sol:317-333, contracts/layer1/core/impl/Inbox.sol:390-394 |

#### Summary

`Inbox.prove` computes proposal age but calls `_checkProver` before verifier age handling. When `proverCount` is nonzero, any non-whitelisted prover reverts immediately, so the configured `permissionlessProvingDelay` cannot let outsiders prove stale proposals while even one whitelisted prover remains configured.

#### Root Cause

The security invariant is that stale proposals should become provable by permissionless actors after the configured delay. The implementation orders whitelist authorization before the age-based verifier path, making the fallback unreachable until the whitelist is empty.

**Proposal age then whitelist gate** — `contracts/layer1/core/impl/Inbox.sol:317-333`

The proof path computes age and then immediately checks caller whitelist status.

```solidity
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        unchecked {

            CoreState memory state = _coreState;
            ProveInput memory input = LibCodec.decodeProveInput(_data);

            // -------------------------------------------------------------------------------
            // 1. Validate batch bounds and calculate offset of the first unfinalized proposal
            // -------------------------------------------------------------------------------
            Commitment memory commitment = input.commitment;

            // `offset` is the index of the next-to-finalize proposal in the transitions array.
            (uint256 numProposals, uint256 lastProposalId, uint48 offset) =
                _validateCommitment(state, commitment);

            uint256 proposalAge = block.timestamp - commitment.transitions[offset].timestamp;
            bool isWhitelistEnabled = _checkProver(msg.sender);
```

**Non-whitelisted prover is rejected while count is nonzero** — `contracts/layer1/core/impl/Inbox.sol:756-763`

A non-whitelisted caller cannot progress if any prover remains in the whitelist.

```solidity
    function _checkProver(address _addr) private view returns (bool whitelistEnabled_) {
        if (address(_proverWhitelist) == address(0)) return false;

        (bool isWhitelisted, uint256 proverCount) = _proverWhitelist.isProverWhitelisted(_addr);
        if (proverCount == 0) return false;

        require(isWhitelisted, ProverNotWhitelisted());
        return true;
```

**Age reaches verifier only after whitelist acceptance** — `contracts/layer1/core/impl/Inbox.sol:388-394`

The age value is only passed to the proof verifier after the caller has survived `_checkProver`.

```solidity
            // For multi-proposal batches (more than 1 unfinalized proposal), pass 0 to verifier.
            // Single-proposal proofs pass actual age for age-based verification logic.
            _proofVerifier.verifyProof(
                numProposals - offset == 1 ? proposalAge : 0,
                LibHashOptimized.hashCommitment(commitment),
                _proof
            );
```

#### Validation

Validated by source control-flow review and config review showing `permissionlessProvingDelay` is accepted and exposed, but not consulted before `_checkProver` rejects non-whitelisted callers.

Validation method: Static trace

**Non-whitelisted prover is rejected while count is nonzero** — `contracts/layer1/core/impl/Inbox.sol:756-763`

A non-whitelisted caller cannot progress if any prover remains in the whitelist.

```solidity
    function _checkProver(address _addr) private view returns (bool whitelistEnabled_) {
        if (address(_proverWhitelist) == address(0)) return false;

        (bool isWhitelisted, uint256 proverCount) = _proverWhitelist.isProverWhitelisted(_addr);
        if (proverCount == 0) return false;

        require(isWhitelisted, ProverNotWhitelisted());
        return true;
```

Evidence:
- `_checkProver` returns false only when the whitelist contract is absent or `proverCount` is zero.
- When `proverCount` is nonzero, `require(isWhitelisted)` executes before verifier proof validation.

Counterevidence and remaining uncertainty:
- No focused Foundry test was added for this exact branch.
- If operators intentionally require manual whitelist removal before permissionless proving, the behavior is a policy mismatch rather than an implementation defect.

#### Dataflow

A non-whitelisted prover submits a valid proof for an old proposal, `Inbox.prove` computes age, `_checkProver` rejects because the whitelist still contains at least one address, and the proof verifier never receives the age that could trigger fallback logic.

- **Source:** `msg.sender` on `Inbox.prove` and the configured prover whitelist count

- **Sink:** `ProverNotWhitelisted` revert before verifier proof handling

- **Outcome:** Finality remains dependent on whitelisted provers or privileged whitelist updates despite configured permissionless delay.

Transformations:
- `isProverWhitelisted` returns both caller status and `proverCount`.
- `_checkProver` treats any nonzero count as a hard whitelist mode.

**Proposal age then whitelist gate** — `contracts/layer1/core/impl/Inbox.sol:317-333`

The proof path computes age and then immediately checks caller whitelist status.

```solidity
    function prove(bytes calldata _data, bytes calldata _proof) external nonReentrant {
        unchecked {

            CoreState memory state = _coreState;
            ProveInput memory input = LibCodec.decodeProveInput(_data);

            // -------------------------------------------------------------------------------
            // 1. Validate batch bounds and calculate offset of the first unfinalized proposal
            // -------------------------------------------------------------------------------
            Commitment memory commitment = input.commitment;

            // `offset` is the index of the next-to-finalize proposal in the transitions array.
            (uint256 numProposals, uint256 lastProposalId, uint48 offset) =
                _validateCommitment(state, commitment);

            uint256 proposalAge = block.timestamp - commitment.transitions[offset].timestamp;
            bool isWhitelistEnabled = _checkProver(msg.sender);
```

**Non-whitelisted prover is rejected while count is nonzero** — `contracts/layer1/core/impl/Inbox.sol:756-763`

A non-whitelisted caller cannot progress if any prover remains in the whitelist.

```solidity
    function _checkProver(address _addr) private view returns (bool whitelistEnabled_) {
        if (address(_proverWhitelist) == address(0)) return false;

        (bool isWhitelisted, uint256 proverCount) = _proverWhitelist.isProverWhitelisted(_addr);
        if (proverCount == 0) return false;

        require(isWhitelisted, ProverNotWhitelisted());
        return true;
```

#### Reachability

Any non-whitelisted prover can trigger the rejected path by attempting to prove, but the harmful outcome requires stale unproven proposals and whitelisted provers that are offline, censoring, or unable to prove.

- **Attacker:** External non-whitelisted prover or censoring whitelisted prover set

- **Entry point:** `Inbox.prove`

- **Outcome:** Permissionless fallback does not restore liveness while a stale whitelist entry remains.

Preconditions:
- At least one prover remains in the whitelist.
- A proposal is older than the intended permissionless proving delay.
- Whitelisted provers do not provide a proof.

#### Severity

**Medium** — The issue can prolong finality or censorship if whitelisted provers are unavailable or colluding, but owner/prover-manager action can remove provers and the path does not by itself accept invalid state.

Severity would increase if deployed operations rely on permissionless fallback for recovery and lack a fast prover-removal path; it would decrease if the fallback is intentionally disabled whenever a whitelist exists.

#### Remediation

Move the permissionless-delay decision before the hard whitelist rejection, or have `_checkProver` accept non-whitelisted callers once the relevant proposal age exceeds `_permissionlessProvingDelay`. Add explicit comments/tests if whitelist-empty is the only intended fallback.

Tests:
- Add a test proving that a non-whitelisted prover can prove after `permissionlessProvingDelay` when `proverCount > 0`.
- Add a complementary test that non-whitelisted provers remain rejected before the delay.

Preventive controls:
- Monitor proposal age when whitelist mode is enabled.
- Add configuration documentation stating whether nonempty whitelist intentionally disables permissionless fallback.

## Reviewed Surfaces

| Surface | Risk Area | Outcome | Notes |
| --- | --- | --- | --- |
| SGX attestation and proof signer registration | Verifier trust and rollup finalization | Reported | Reported FINDING-001. Duplicate candidate variants CS-PROTO-002-001 and CS-PROTO-017-001 were suppressed under the same disabled local-enclave identity control. Evidence: artifacts/05_findings/CS-PROTO-001-001/candidate_ledger.jsonl, artifacts/05_findings/CS-PROTO-001-001/validation_report.md, artifacts/05_findings/CS-PROTO-001-001/attack_path_analysis_report.md |
| Inbox proving whitelist and fallback timing | Rollup finality liveness | Reported | Reported FINDING-002. The fallback delay is configured but non-whitelisted provers cannot reach the age-based verifier path while any whitelist entry exists. Evidence: artifacts/05_findings/CS-PROTO-005-001/candidate_ledger.jsonl, artifacts/05_findings/CS-PROTO-005-001/validation_report.md, artifacts/05_findings/CS-PROTO-005-001/attack_path_analysis_report.md |
| Forced inclusion enqueue and proposal consumption | Censorship resistance and paid queue liveness | Reported | Reported FINDING-003. Duplicate liveness candidate CS-PROTO-006-001 was suppressed under the same disabled consumption path. Focused Foundry evidence was saved. Evidence: artifacts/05_findings/CS-PROTO-005-002/candidate_ledger.jsonl, artifacts/05_findings/CS-PROTO-005-002/validation_report.md, artifacts/05_findings/CS-PROTO-005-002/attack_path_analysis_report.md, artifacts/05_findings/CS-PROTO-005-002/validation_artifacts/forge_forced_inclusion.txt |
| TaikoToken voting and non-voting delegation controls | Governance supply accounting | Reported | Reported FINDING-004. No in-scope Governor consumer was found, so deployed impact remains a follow-up question. Evidence: artifacts/05_findings/CS-PROTO-011-001/candidate_ledger.jsonl, artifacts/05_findings/CS-PROTO-011-001/validation_report.md, artifacts/05_findings/CS-PROTO-011-001/attack_path_analysis_report.md |
| Lookahead slashing slot-index validation | Preconfirmation false slashing | Reported | Reported FINDING-005 for the missing lower-bound check between evidence slot timestamp and selected lookahead index. Evidence: artifacts/05_findings/CS-PROTO-013-001/candidate_ledger.jsonl, artifacts/05_findings/CS-PROTO-013-001/validation_report.md, artifacts/05_findings/CS-PROTO-013-001/attack_path_analysis_report.md |
| Lookahead missing-operator eligibility timestamp | Preconfirmation false slashing | Reported | Reported FINDING-006 for stale operator eligibility validation between LookaheadSlasher and LookaheadStore. Evidence: artifacts/05_findings/CS-PROTO-013-002/candidate_ledger.jsonl, artifacts/05_findings/CS-PROTO-013-002/validation_report.md, artifacts/05_findings/CS-PROTO-013-002/attack_path_analysis_report.md |
| Preconfirmation whitelist add/remove authorization | Role separation and proposer authorization | Reported | Reported FINDING-007 with medium confidence because final impact depends on intended ejecter role policy. Evidence: artifacts/05_findings/CS-PROTO-014-001/candidate_ledger.jsonl, artifacts/05_findings/CS-PROTO-014-001/validation_report.md, artifacts/05_findings/CS-PROTO-014-001/attack_path_analysis_report.md |
| Beacon proposer-lookahead proof binding | Beacon proof validation and preconfirmation slashing | Reported | Reported FINDING-008. The variable-depth Merkle proof candidate CS-PROTO-014-002 was suppressed as supporting context under the unanchored proposer-lookahead root. Evidence: artifacts/05_findings/CS-PROTO-015-001/candidate_ledger.jsonl, artifacts/05_findings/CS-PROTO-015-001/validation_report.md, artifacts/05_findings/CS-PROTO-015-001/attack_path_analysis_report.md, artifacts/05_findings/CS-PROTO-014-002/validation_report.md |
| L2 Anchor golden-touch checkpoint writes | L2 checkpoint trust and signal roots | Reported | Reported FINDING-010. Focused Foundry evidence and golden-touch key derivation support the contract-layer write path, while final L1 impact remains bounded by off-chain derivation/prover controls. Evidence: artifacts/05_findings/CS-PROTO-018-001/candidate_ledger.jsonl, artifacts/05_findings/CS-PROTO-018-001/validation_report.md, artifacts/05_findings/CS-PROTO-018-001/attack_path_analysis_report.md, artifacts/05_findings/CS-PROTO-018-001/validation_artifacts/forge_anchor.txt |
| RISC0 and SP1 verifier wrapper remote verifier addresses | ZK verifier deployment trust | Rejected | CS-PROTO-016-001 and CS-PROTO-016-002 were intentionally not reported after attack-path analysis. Exploitability requires a trusted deployment or operator to configure a no-code or wrong-code verifier address, and no evidence showed current deployments use a bad address. Evidence: artifacts/05_findings/CS-PROTO-016-001/validation_report.md, artifacts/05_findings/CS-PROTO-016-001/attack_path_analysis_report.md, artifacts/05_findings/CS-PROTO-016-002/validation_report.md, artifacts/05_findings/CS-PROTO-016-002/attack_path_analysis_report.md |
| Bridge and SignalService message/proof handling | Cross-chain message integrity and checkpoint proof consumption | No issue found | Reviewed bridge lifecycle, message status transitions, SignalService proof cache/checkpoint paths, and trie proof helpers. No standalone bridge or signal-service finding survived in the scoped scan. Evidence: artifacts/03_coverage/repository_coverage_ledger.md, artifacts/02_discovery/work_ledger.jsonl |
| ERC20, ERC721, ERC1155 vaults and bridged token implementations | Asset custody, mint/burn authorization, token callbacks, quota/migration | No issue found | Reviewed shared vaults, mainnet wrappers, bridged token contracts, and NFT base vault validation. No custody, unauthorized mint/burn, replay, or callback issue survived review. Evidence: artifacts/03_coverage/repository_coverage_ledger.md, artifacts/02_discovery/work_ledger.jsonl |
| Resolvers, controllers, fork routers, and EssentialContract authorization | Upgrade, ownership, resolver, and delegatecall authorization | No issue found | Reviewed controller execution, resolver base behavior, fork-router target selection, and UUPS/owner authorization in scoped contracts. No unauthorized upgrade or resolver-bypass issue survived review. Evidence: artifacts/03_coverage/repository_coverage_ledger.md, artifacts/02_discovery/work_ledger.jsonl |
| Generated layout files, interfaces, and pure utility libraries | Upgrade layout metadata and non-executable support code | No issue found | Layout and interface-only files were checked for executable controls and treated as supporting context. Pure helpers such as math, bytes, names, network, address, and trie proof utilities did not produce standalone findings. Evidence: artifacts/03_coverage/repository_coverage_ledger.md |
| Devnet, Hoodi, and non-mainnet wrappers/constants | Environment-specific verifier and address configuration | No issue found | Reviewed devnet verifier/inbox wrappers, Hoodi address constants, and insecure SGX verifier context. No production-impacting issue survived beyond the reported verifier-attestation configuration risks. Evidence: artifacts/03_coverage/repository_coverage_ledger.md, artifacts/02_discovery/work_ledger.jsonl |

## Open Questions And Follow Up

- Confirm deployed SGX/Automata verifier settings for revision 32abaf7465dbaef7b006c1da65966efdb533c7e3.
  - Follow-up prompt: Using deployed mainnet and Hoodi addresses for taiko-mono revision 32abaf7465dbaef7b006c1da65966efdb533c7e3, verify whether AutomataDcapV3Attestation.checkLocalEnclaveReport is enabled and whether both SGX verifier branches can register instances permissionlessly.
- Confirm governance consumers of TaikoToken voting supply.
  - Follow-up prompt: Review production governance/quorum contracts that consume packages/protocol/contracts/layer1/mainnet/TaikoToken.sol at revision 32abaf7465dbaef7b006c1da65966efdb533c7e3 and determine whether inherited delegateBySig can lower quorum supply through non-voting accounts.
- Run an end-to-end derivation/prover check for attacker-signed Anchor checkpoints.
  - Follow-up prompt: Starting from contracts/layer2/core/Anchor.sol at revision 32abaf7465dbaef7b006c1da65966efdb533c7e3, build an integration test showing whether a golden-touch-signed wrong checkpoint is rejected before any bridge or SignalService consumer can rely on it.
