# Security Review: taiko-mono

## Scope

Scoped Daybreak/Codex Security audit opened on the verifier directory and focused on the two SGX verifier contracts requested by the user: `SgxVerifier.sol` and `SecureSgxVerifier.sol`. Other verifier files, interfaces, tests, composition contracts, and deployment scripts were read only as supporting context.

- Scan mode: scoped_path
- Target kind: git_worktree
- Target ID: target_sha256_acbdca0571e0319261aecb7d1e1b0bfd4dd74b719090d04205112a39b0b0e738
- Revision: ce262b3d1b4449dc43d6ed6f498b1f9a4a7851ba
- Snapshot digest: codex-security-snapshot/v1:sha256:30c4e3877ceaf8a33db3e798121f272767aa41b71054e32ba1649b52258da06b
- Inventory strategy: custom
- Included paths: packages/protocol/contracts/layer1/verifiers
- Excluded paths: none
- Runtime or test status: After installing declared protocol dependencies with CI=1, targeted Foundry verifier tests passed: 122 tests for SgxVerifier.t.sol and 154 tests for all layer1 verifier tests.
- Artifacts reviewed: packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol, packages/protocol/contracts/layer1/verifiers/SecureSgxVerifier.sol, packages/protocol/contracts/layer1/verifiers/IDcapAttestation.sol, packages/protocol/contracts/layer1/verifiers/LibPublicInput.sol, packages/protocol/test/layer1/verifiers/SgxVerifier.t.sol, packages/protocol/contracts/layer1/mainnet/MainnetVerifier.sol, packages/protocol/contracts/layer1/verifiers/compose/ComposeVerifier.sol
- Scan context: The repository-level threat model was generated during the scan and copied to artifacts/01_context/threat_model.md.

Limitations and exclusions:
- The bundled scan worklist helper did not include .sol files, so the two user-requested Solidity files were used as the authoritative custom worklist.
- Deployment-script issues were treated as supporting context and not promoted unless rooted in the two target contracts.
- Excluded packages/protocol/contracts/layer1/verifiers/\*.sol except SgxVerifier.sol and SecureSgxVerifier.sol: The Daybreak workspace scope was the verifier directory, but the user explicitly requested only SgxVerifier.sol and SecureSgxVerifier.sol; other verifier contracts were supporting context only.
- Excluded packages/protocol/script/\*\*: Deployment scripts were supporting context only, except for the out-of-scope observation preserved in coverage.

### Scan Summary

| Field | Value |
| --- | --- |
| Reportable findings | 1 |
| Severity mix | medium: 1 |
| Confidence mix | high: 1 |
| Coverage | complete |
| Validation mode | Static code trace with existing Foundry test validation for adjacent controls. |

Canonical artifacts: `scan-manifest.json`, `findings.json`, and `coverage.json`. This report is a deterministic projection of those files.

## Threat Model

Taiko is an Ethereum based rollup whose protocol safety depends on correct proof verification and strict verifier configuration. SGX verifier false positives can weaken state-transition integrity; stale or untrusted enclave identities are security-critical.

### Assets

- canonical rollup state
- accepted transition hashes
- SGX verifier instance identity
- MRENCLAVE/MRSIGNER and attribute policy configuration
- bridge escrowed value

### Trust Boundaries

- untrusted proof submitters to on-chain verifier contracts
- trusted owner/registrar/governance configuration to public proof verification
- off-chain SGX attestation infrastructure to on-chain instance registration

### Attacker Capabilities

- submit proof calldata
- submit SGX quotes when registration is permissionless or registrar-authorized
- control a prover host or compromised SGX instance under realistic incident-response assumptions

### Security Objectives

- reject invalid or stale SGX proof signers
- bind SGX quotes to authenticated enclave report bytes
- enforce revocation and expiry policies consistently at proof time
- preserve domain separation across chain, verifier, signer, and commitment hash

### Assumptions

- Ethereum consensus and EVM semantics hold
- owner and registrar are trusted but operational mistakes are possible
- external Automata attestation contracts behave according to their interface
- production deployments use secure verifier composition

## Findings

| Finding | Severity | Confidence |
| --- | --- | --- |
| [Removing an enclave policy does not revoke existing SGX instances](#finding-1) | medium | high |

### Confidence Scale

| Label | Meaning |
| --- | --- |
| high | Direct evidence supports the finding with no material unresolved blocker. |
| medium | Evidence supports a plausible issue, but material runtime or reachability proof remains. |
| low | Evidence is incomplete and the item is retained only for explicit follow-up. |

<a id="finding-1"></a>

### [1] Removing an enclave policy does not revoke existing SGX instances

| Field | Value |
| --- | --- |
| Severity | medium |
| Confidence | high |
| Confidence rationale | Direct source trace confirms the registration-time-only policy check and timestamp-only proof check; targeted verifier tests pass and cover the adjacent controls. |
| Category | Revocation bypass / stale trust |
| CWE | CWE-284 Improper Access Control, CWE-693 Protection Mechanism Failure |
| Affected lines | packages/protocol/contracts/layer1/verifiers/SecureSgxVerifier.sol:113-118, packages/protocol/contracts/layer1/verifiers/SecureSgxVerifier.sol:138-149, packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol:24-27, packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol:414-419, packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol:173-183 |

#### Summary

Removing an MRENCLAVE attribute policy blocks future registration, but stored instances keep verifying proofs because instance records contain only the signer address and timestamp and `verifyProof` never rechecks current enclave policy.

#### Root Cause

The violated invariant is that removing an enclave policy should stop that MRENCLAVE from contributing trusted SGX proofs. The implementation only deletes the registration-time policy and does not record MRENCLAVE on stored instances, so proof verification cannot reject stale instances for a removed policy.

**Policy removal deletes only the attribute policy** — `packages/protocol/contracts/layer1/verifiers/SecureSgxVerifier.sol:113-118`

`removeEnclaveAttributePolicy` removes future registration policy but does not touch stored instance ids.

```solidity
function removeEnclaveAttributePolicy(bytes32 _mrEnclave) external onlyOwnerOr(registrar) {
    require(
        enclaveAttributePolicy[_mrEnclave].mask != bytes16(0), SGX_ATTRIBUTE_POLICY_NOT_SET()
    );
    delete enclaveAttributePolicy[_mrEnclave];
    emit EnclaveAttributePolicyRemoved(_mrEnclave);
}
```

**Attribute policy is enforced only during registration** — `packages/protocol/contracts/layer1/verifiers/SecureSgxVerifier.sol:138-149`

The hook rejects unpinned or mismatched enclaves only when `registerInstance` calls it.

```solidity
function _validateEnclaveAttributes(bytes32 _mrEnclave, bytes16 _attributes)
    internal
    view
    override
{
    AttributePolicy memory policy = enclaveAttributePolicy[_mrEnclave];
    require(policy.mask != bytes16(0), SGX_ATTRIBUTE_POLICY_NOT_SET());
    require(_attributes & policy.mask == policy.expected, SGX_ATTRIBUTE_MISMATCH());
}
```

**Stored instances omit MRENCLAVE and policy generation** — `packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol:24-27`

Once registration succeeds, the contract keeps only the signer address and validity timestamp.

```solidity
struct Instance {
    address addr;
    uint64 validSince;
}
```

**Proof verification checks only address and timestamp** — `packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol:414-419`

`verifyProof` relies on this check and does not consult the current MRENCLAVE policy.

```solidity
function _isInstanceValid(uint256 id, address instance) private view returns (bool) {
    require(instance != address(0), SGX_INVALID_INSTANCE());
    require(instance == instances[id].addr, SGX_INVALID_INSTANCE());
    return instances[id].validSince <= block.timestamp
        && block.timestamp <= instances[id].validSince + INSTANCE_EXPIRY;
}
```

#### Validation

The source trace confirms that policy removal has no effect on already stored instances. Tests passing for adjacent controls increase confidence that this is a specific revocation gap rather than a broader verifier failure.

Validation method: static code trace plus existing Foundry verifier tests

**Policy removal deletes only the attribute policy** — `packages/protocol/contracts/layer1/verifiers/SecureSgxVerifier.sol:113-118`

`removeEnclaveAttributePolicy` removes future registration policy but does not touch stored instance ids.

```solidity
function removeEnclaveAttributePolicy(bytes32 _mrEnclave) external onlyOwnerOr(registrar) {
    require(
        enclaveAttributePolicy[_mrEnclave].mask != bytes16(0), SGX_ATTRIBUTE_POLICY_NOT_SET()
    );
    delete enclaveAttributePolicy[_mrEnclave];
    emit EnclaveAttributePolicyRemoved(_mrEnclave);
}
```

**Attribute policy is enforced only during registration** — `packages/protocol/contracts/layer1/verifiers/SecureSgxVerifier.sol:138-149`

The hook rejects unpinned or mismatched enclaves only when `registerInstance` calls it.

```solidity
function _validateEnclaveAttributes(bytes32 _mrEnclave, bytes16 _attributes)
    internal
    view
    override
{
    AttributePolicy memory policy = enclaveAttributePolicy[_mrEnclave];
    require(policy.mask != bytes16(0), SGX_ATTRIBUTE_POLICY_NOT_SET());
    require(_attributes & policy.mask == policy.expected, SGX_ATTRIBUTE_MISMATCH());
}
```

**Stored instances omit MRENCLAVE and policy generation** — `packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol:24-27`

Once registration succeeds, the contract keeps only the signer address and validity timestamp.

```solidity
struct Instance {
    address addr;
    uint64 validSince;
}
```

**Proof verification checks only address and timestamp** — `packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol:414-419`

`verifyProof` relies on this check and does not consult the current MRENCLAVE policy.

```solidity
function _isInstanceValid(uint256 id, address instance) private view returns (bool) {
    require(instance != address(0), SGX_INVALID_INSTANCE());
    require(instance == instances[id].addr, SGX_INVALID_INSTANCE());
    return instances[id].validSince <= block.timestamp
        && block.timestamp <= instances[id].validSince + INSTANCE_EXPIRY;
}
```

**Instance deletion is separate and owner-only** — `packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol:173-183`

Manual revocation exists, but it is not coupled to policy removal and the registrar cannot call it.

```solidity
function deleteInstances(uint256[] calldata _ids) external onlyOwner {
    uint256 size = _ids.length;
    for (uint256 i; i < size; ++i) {
        uint256 idx = _ids[i];
        require(instances[idx].addr != address(0), SGX_INVALID_INSTANCE());
        emit InstanceDeleted(idx, instances[idx].addr);
        delete instances[idx];
    }
}
```

#### Dataflow

authorized policy removal -\> deleted attribute policy -\> stored instance remains -\> `verifyProof` checks id/address/timestamp -\> stale SGX signature is accepted

- **Source:** owner or registrar removes an enclave policy while a matching instance already exists or is pending

- **Sink:** `SgxVerifier.verifyProof` through `_isInstanceValid`

- **Outcome:** a removed enclave measurement can continue contributing SGX proof signatures until expiry

**Policy removal deletes only the attribute policy** — `packages/protocol/contracts/layer1/verifiers/SecureSgxVerifier.sol:113-118`

`removeEnclaveAttributePolicy` removes future registration policy but does not touch stored instance ids.

```solidity
function removeEnclaveAttributePolicy(bytes32 _mrEnclave) external onlyOwnerOr(registrar) {
    require(
        enclaveAttributePolicy[_mrEnclave].mask != bytes16(0), SGX_ATTRIBUTE_POLICY_NOT_SET()
    );
    delete enclaveAttributePolicy[_mrEnclave];
    emit EnclaveAttributePolicyRemoved(_mrEnclave);
}
```

**Stored instances omit MRENCLAVE and policy generation** — `packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol:24-27`

Once registration succeeds, the contract keeps only the signer address and validity timestamp.

```solidity
struct Instance {
    address addr;
    uint64 validSince;
}
```

**Proof verification checks only address and timestamp** — `packages/protocol/contracts/layer1/verifiers/SgxVerifier.sol:414-419`

`verifyProof` relies on this check and does not consult the current MRENCLAVE policy.

```solidity
function _isInstanceValid(uint256 id, address instance) private view returns (bool) {
    require(instance != address(0), SGX_INVALID_INSTANCE());
    require(instance == instances[id].addr, SGX_INVALID_INSTANCE());
    return instances[id].validSince <= block.timestamp
        && block.timestamp <= instances[id].validSince + INSTANCE_EXPIRY;
}
```

**Production composition still requires another proof leg** — `packages/protocol/contracts/layer1/mainnet/MainnetVerifier.sol:31-50`

A stale SGX proof is a serious trust-boundary regression, but this composition requirement limits immediate chain-safety impact.

```solidity
if (_verifiers.length != 2) return false;

if (_verifiers[0] == sgxGethVerifier) {
    return _verifiers[1] == sgxRethVerifier || _verifiers[1] == risc0RethVerifier
        || _verifiers[1] == sp1RethVerifier;
}

if (_verifiers[0] == sgxRethVerifier) {
    return _verifiers[1] == sgxGethVerifier || _verifiers[1] == risc0RethVerifier
        || _verifiers[1] == sp1RethVerifier;
}
```

#### Reachability

The attacker needs control of a registered instance key for the removed MRENCLAVE. This is plausible during enclave compromise response, but mainnet-style verification still requires another accepted proof leg.

- **Attacker:** SGX prover or host controlling a registered instance key

- **Entry point:** `verifyProof` proof submission through the protocol verifier composition

- **Outcome:** stale SGX trust remains active after policy removal

#### Severity

**Medium** — The issue weakens a protocol verifier revocation control and can preserve a removed enclave measurement for up to `INSTANCE_EXPIRY`, but exploitation requires an already registered compromised instance and mainnet-style composition still requires a second proof leg.

Severity would increase if SGX alone can satisfy a production proof path or if an attacker can practically pair the stale SGX proof with another accepted proof. It would decrease if repository-backed automation atomically deletes all instance ids for a removed MRENCLAVE.

#### Remediation

Store the attested MRENCLAVE or a policy generation with each instance and make `verifyProof` reject instances whose current MRENCLAVE policy is unset or changed. Alternatively, make policy removal atomically revoke all instance ids for that MRENCLAVE, and give the registrar a bounded revocation path for those ids if it is expected to fail-close compromised enclaves.

Tests:
- Add a test that registers a non-owner `SecureSgxVerifier` instance, removes its MRENCLAVE policy before the validity delay elapses, warps past the delay, and asserts `verifyProof` reverts.
- Add a test that an already valid instance reverts after its MRENCLAVE policy is removed unless explicitly reauthorized.
- Add a test that registrar-triggered policy removal also closes any registrar-intended revocation path.

Preventive controls:
- Keep revocation controls coupled to the runtime proof-acceptance check, not only to future registration.
- Emit enough indexed data during registration to support complete MRENCLAVE-to-instance revocation audits.
- Document whether policy removal is intended to affect existing instances; enforce the documented invariant in tests.

## Reviewed Surfaces

| Surface | Risk Area | Outcome | Notes |
| --- | --- | --- | --- |
| SGX quote registration and attestation binding | Invalid or attacker-spliced quote accepted | Rejected | Rejected after reviewing quote length, Output header, verified-body binding, TCB policy, and tests for malformed quotes. Evidence: artifacts/03_coverage/repository_coverage_ledger.md, artifacts/02_discovery/work_ledger.jsonl |
| SGX forbidden attributes and enclave identity | Debug/provisioning enclave admitted | Rejected | Rejected because DEBUG/provisioning attributes, local MRENCLAVE/MRSIGNER allowlist, and strict attribute pins are enforced and tested. Evidence: artifacts/03_coverage/repository_coverage_ledger.md, artifacts/02_discovery/work_ledger.jsonl |
| Instance registration, expiry, and proof verification | Replay or stale instance accepted outside intended lifetime | Rejected | Rejected for the normal lifetime/replay path because domain separation, id/address checks, and expiry are enforced and tested. Evidence: artifacts/03_coverage/repository_coverage_ledger.md, artifacts/02_discovery/work_ledger.jsonl |
| Enclave attribute policy removal | Removed MRENCLAVE instances continue verifying proofs | Reported | Reported as CAND-SGX-POLICY-REMOVAL-NONREVOCATION. Evidence: artifacts/05_findings/CAND-SGX-POLICY-REMOVAL-NONREVOCATION/candidate_ledger.jsonl, artifacts/05_findings/CAND-SGX-POLICY-REMOVAL-NONREVOCATION/validation_report.md, artifacts/05_findings/CAND-SGX-POLICY-REMOVAL-NONREVOCATION/attack_path_analysis_report.md |
| Hoodi deployment verifier selection | Public testnet deploys lenient verifier | Rejected | Rejected for this scan as out of scope; root control is a deployment script outside the two requested contract files. Evidence: artifacts/05_findings/CS-SGX-HOODI-INSECURE-TCB/candidate_ledger.jsonl, artifacts/05_findings/CS-SGX-HOODI-INSECURE-TCB/validation_report.md, artifacts/05_findings/CS-SGX-HOODI-INSECURE-TCB/attack_path_analysis_report.md |
