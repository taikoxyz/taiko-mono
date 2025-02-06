---
title: Contestable Rollups
description: Core concept page for "Contestable Rollups".
---

Taiko Alethia employs a **Based Contestable Rollup (BCR)** architecture, combining **based sequencing** with **multi-proof validation** to ensure a high degree of security and decentralization. Unlike centralized rollups that can tolerate certain risks due to their controlled environments, Taiko is fully permissionless. This necessitates a robust **multi-proof contestation mechanism** to prevent malicious behavior and ensure finality.

In a BCR, every proof submitted undergoes a challenge period where any participant can contest it. This ensures the validity of state transitions while allowing the system to dynamically adjust based on security and cost considerations.

## Hierarchy of Proofs in Taiko Alethia

Taiko Alethia supports a multi-tiered proof system:

1. **Tier 1 - TEE (Trusted Execution Environment) Proofs:**

   - SGX-based proofs provide a low-cost and efficient proving mechanism.
   - These are fast but have trust assumptions related to Intel SGX.

<br/>

2. **Tier 2 - Zero-Knowledge (ZK) Proofs:**

   - Ensures correctness without requiring any trust assumptions.
   - More expensive computationally but cryptographically secure.

<br/>

3. **Tier 3 - Hybrid (TEE + ZK) Proofs:**

   - A combination of TEE and ZK, increasing robustness.
   - Allows parallel proving while maintaining security.

<br/>

4. **Tier 4 - Guardian Minority:**

   - A small set of guardian provers for backup security.
   - Used in edge cases where TEE/ZK are disputed.

<br/>

5. **Tier 5 - Guardian Majority:**
   - A larger multi-sig proving mechanism used as the final fallback.
   - Meant to be phased out as the system becomes more decentralized.

<br/>

![Proof Tiers](~/assets/content/docs/core-concepts/proof-tiers.png)

## Proof Contests and Escalation

Each proof submission in Taiko goes through a **contestable validation process**, ensuring high security while remaining cost-efficient.

### Scenario:

1. A proposer (Alice) submits a new block.
2. A tier-1 prover (Bob) submits a proof **(H1 → H2)** with a validity bond.
3. A cooldown period starts, allowing anyone to contest the proof.
4. A contester (Cindy) challenges Bob’s proof, claiming the correct transition should be **H1 → H3**.
5. The system awaits a higher-tier proof to resolve the dispute.
6. Two possible outcomes:

   - If a tier-2 prover (David) confirms Bob’s proof was correct, Bob is rewarded, Cindy loses her contestation bond.
   - If David proves Cindy was correct (H1 → H3), Cindy gets rewarded, and Bob loses his bond.

![BCR Workflow](~/assets/content/docs/core-concepts/contestable.png)

## Contestation Bond Economics

Contesting a proof requires putting up a **contest bond**, ensuring economic security. The outcomes are:

- If the contester wins:

  - The contester receives the contestation bond back and 1/4 of the original prover's bond.
  - The new prover receives 1/4 of the original prover’s validity bond as a proving fee.
  - 1/2 of the original prover’s bond is sent to the DAO treasury.

<br/>

- If the original prover wins:
  - The original prover gets back the validity bond and 1/4 of the contest bond as a reward.
  - The new prover earns 1/4 of the contest bond.
  - 1/2 of the contest bond goes to the DAO treasury.

## Advantages of Based Contestable Rollups

1. **Permissionless and Decentralized:**

   - No centralized sequencer, relying on Ethereum validators for sequencing.
   - Anyone can prove or contest a block.

<br/>

2. **Multi-Proof Security Model:**

   - Enables dynamic configuration of proving systems.
   - Different proof tiers balance security and efficiency.

<br/>

3. **Economic Security with Bonds:**

   - Contestation requires financial commitments, discouraging spam disputes.
   - Ensures incentives for provers and contesters.

<br/>

4. **Future-Proofing with Dynamic Proofing System:**
   - Allows gradual migration from TEE-based proofs to fully ZK-based proofs.
   - Adapts to evolving cryptographic advancements.

## Learn More

For a deep dive into the BCR model, read our blog post:
[Based Contestable Rollup (BCR): A configurable, multi-proof rollup design](https://taiko.mirror.xyz/Z4I5ZhreGkyfdaL5I9P0Rj0DNX4zaWFmcws-0CVMJ2A).
