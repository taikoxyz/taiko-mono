---
title: Why Taiko Alethia?
description: Core concept page for "Why Taiko Alethia?".
---

Ethereum's success as a decentralized execution layer has led to scalability challenges. Most rollups today attempt to address these challenges but introduce new centralization risks. The dominant rollup models rely on **centralized sequencers**, leading to:

- **Censorship risks**: The sequencer can refuse to include certain transactions.
- **MEV (Maximal Extractable Value) centralization**: A single entity controls transaction ordering.
- **Liveness failures**: If the sequencer goes offline, the entire rollup halts.
- **Trust assumptions**: Users must trust the sequencer to operate fairly.

Taiko Alethia eliminates these issues by embracing **Ethereum's native block production process**.

## Based Rollups: Aligning with Ethereum L1

Taiko Alethia is a **Based Rollup**, meaning it does not rely on a separate sequencer. Instead, Ethereum **L1 block proposers** also act as L2 sequencers. This ensures:

- **Censorship resistance**: If a transaction can be included in Ethereum L1, it can be included in Taiko L2.
- **Trust minimization**: No reliance on off-chain sequencer infrastructure.
- **Stronger economic alignment**: L1 proposers are naturally incentivized to include L2 transactions.

### Example: Why Based Sequencing Matters

Consider a scenario where a user submits a transaction on an Optimistic Rollup with a centralized sequencer:

1. The sequencer **reorders transactions** to maximize MEV.
2. The sequencer **delays inclusion** if it benefits another transaction.
3. The sequencer **outright censors** certain transactions.

In contrast, on Taiko Alethia:

1. The transaction enters Ethereum L1's mempool **without a centralized sequencer**.
2. Any Ethereum L1 validator can **naturally order the L2 block** in the next L1 slot.
3. There is **no additional censorship vector** apart from Ethereum itself.

## Multi-Proof Architecture: Enhancing Security

Most rollups adopt a **single-proof model**, such as validity proofs (ZK-SNARKs) or fraud proofs (Optimistic). However, a single proof system can introduce **systemic risks** if a cryptographic vulnerability is discovered.

Taiko Alethia mitigates this by implementing a **multi-proof model**:

- **Tier 1**: Trusted Execution Environments (SGX) for instant proofs.
- **Tier 2**: ZK proofs (Halo2, Risc0, SP1) for cryptographic security.
- **Tier 3**: Hybrid (SGX + ZK) for redundancy.
- **Tier 4**: Guardian proofs (multi-signature) as a last resort.

### Example: Why Multi-Proofs Matter

Imagine a ZK-rollup using only one proof system (e.g., Groth16). If an undiscovered vulnerability allows forging of valid proofs, an attacker could **steal user funds**, and the system would collapse.

With Taiko’s **multi-proof hierarchy**, even if one proof tier is compromised:

1. A **higher-tier proof** can be submitted to contest it.
2. The network can **fallback** to an alternative proof system.
3. The modular architecture allows **upgrading proofs** without forking.

## Contestability: The Self-Healing Mechanism

To maintain security, **all proofs in Taiko Alethia are contestable**. This means:

- If an incorrect proof is submitted, it can be **challenged** with a higher-tier proof.
- Contestation uses an **economic bonding system**, ensuring **malicious actors are penalized**.
- If a proof remains unchallenged, it **automatically gains finality**.

### Example: Contestation in Action

1. Bob submits an SGX proof claiming a state transition from `H1 → H2`.
2. Cindy contests it, posting a **bond** to dispute the proof.
3. David submits a ZK-proof proving the correct transition was `H1 → H3`.
4. Cindy **wins the dispute**, receiving a portion of Bob’s bond.

This ensures **fraudulent proofs are naturally eliminated**.

## Taiko vs. Traditional Rollups

| Feature                        | Traditional Rollups                  | Taiko Alethia                          |
| ------------------------------ | ------------------------------------ | -------------------------------------- |
| **Sequencing**                 | Centralized (single sequencer)       | Decentralized (L1 validators sequence) |
| **Proof System**               | Single proof type (ZK or Optimistic) | Multi-proof (ZK, TEE, Guardian)        |
| **Censorship Resistance**      | Operator can censor transactions     | No censorship beyond Ethereum itself   |
| **Smart Contract Equivalence** | Modified Ethereum (Geth changes)     | 100% Ethereum-equivalent               |
| **Security Model**             | Single proof, non-contestable        | Multi-proof, contestable               |

## Conclusion: Why Taiko Alethia?

1. **Ethereum-native sequencing**: No centralized sequencer, ensuring full decentralization.
2. **Multi-proof security**: More robust than single-proof rollups.
3. **Contestability**: Self-healing security without hard forks.
4. **Ethereum-equivalence**: No changes to the EVM, making migrations seamless.
5. **Economic alignment**: L1 block producers are incentivized to secure the rollup.

🚀 **Taiko Alethia is the rollup Ethereum deserves.**
