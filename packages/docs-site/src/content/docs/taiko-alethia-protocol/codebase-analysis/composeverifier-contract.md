---
title: ComposeVerifier
description: Taiko Alethia protocol page for "ComposeVerifier.sol".
---

[ComposeVerifier](https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v2.3.0/packages/protocol/contracts/layer1/verifiers/compose/ComposeVerifier.sol) is a smart contract that designates which subsidiary proof verifier contracts are active in the protocol. It is used in conjunction with **SgxVerifier.sol, SP1Verifier.sol and Risc0Verifier.sol** to verify proofs for every batch on chain.

---

## Features

- **Proof Verification** - This contract is an abstract verifier that composes multiple sub-verifiers to validate proofs. It ensures that a set of sub-proofs are verified by their respective verifiers before considering the overall proof as valid.

---

## Contract Methods

### `verifyProof`

Verifies an SGX proof for a **single block state transition**.

| Input Parameter  | Type      | Description                    |
| ---------------- | --------- | ------------------------------ |
| `_ctxs`          | `bytes32` | Contexts of the proof.         |
| `_proof`         | `bytes`   | All bytes of all subproofs.    |

**Mechanism**:

- Decodes the `_proof` bytes into `SubProofs` and verifies them with their respective `Verifier` contract.

---

### `areVerifiersSufficient`

| Input Parameter | Type        | Description                  |
| --------------- | ----------- | ---------------------------- |
| `_verifiers`    | `address[]` | Array of verifier addresses. |

**Mechanism**:

- Returns `true` or `false` depending on if the array of submitted verifiers are sufficient depending on which are enabled in the protocol.
