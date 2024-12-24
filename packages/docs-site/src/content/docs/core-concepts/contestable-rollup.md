---
title: Contestable rollups
description: Core concept page for "Contestable rollups".
---

## Based Contestable Rollup

In based rollups, block building is permissionless. But permissionless block building comes at a cost, in the form of permissionless attacks to the chain if there is a vulnerability in the Taiko codebase. Centralized rollups can tolerate these risks due to their centralized nature, but Taiko cannot as fully decentralized design. Therefore, Taiko needs a robust multi-proof structure to prevent malicious behaviours.

Taiko is configured as a based contestable rollup (BCR). This means that there is a hierarchy of proofs in Taiko and it's permissionless to contest all tiers of proofs. Currently Taiko has SGX as a TEE proof, RiscO(RiscZero) and SP1(Succinct) as ZK proofs, Guardian (multi-sig) proof which is owned by Taiko Labs. Guardian proof is not contestable and we plan to phase out after the next protocol hard fork.

![Proof Tiers](~/assets/content/docs/core-concepts/proof-tiers.png)

**Scenario:**

The process begins when a proposer submits a new block, followed by a tier-1 (SGX) prover who submits a proof with a TAIKO bond. During the 4 hour cooldown period, anyone can contest this proof by posting their own bond, as demonstrated by Cindy.

The system then supports two possible scenarios: If a higher-tier proof confirms the original proof was correct, the original prover receives back their bond plus a reward, while the contester loses their bond. Conversely, if the higher-tier proof shows the original was wrong, the contester receives back their bond plus a reward, and the original prover loses their stake.

If the contester wins: The contester receives their contestation bond back plus 1/4 of the original prover's validity bond. The new prover receives 1/4 of the original prover's validity bond as a proving fee. The remaining 1/2 goes to the DAO treasury.

If the original prover wins: The original prover reclaims their validity bond and receives 1/4 of the contestation bond as a reward. The new prover (who may be the original prover) earns 1/4 of the contestation bond. The remaining 1/2 goes to the DAO treasury.

![BCR Workflow](~/assets/content/docs/core-concepts/contestable.png)


Check out our blog post on the [Based Contestable Rollup (BCR): A configurable, multi-proof rollup design](https://taiko.mirror.xyz/Z4I5ZhreGkyfdaL5I9P0Rj0DNX4zaWFmcws-0CVMJ2A).
