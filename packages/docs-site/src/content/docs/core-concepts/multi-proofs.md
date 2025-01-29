---
title: Multi-proofs
description: Core concept page for "Multi-proofs".
---

Taiko Alethia supports **multi-proofs**, leveraging a combination of **zkVMs, Trusted Execution Environments (TEEs) using SGX, and Guardian proofs**. This multi-proof approach enhances security and robustness by reducing reliance on a single proving system.

For a deeper dive, explore:

- **zkVMs in Taiko** [Blog Post](https://taiko.mirror.xyz/e_5GeGGFJIrOxqvXOfzY6HmWcRjCjRyG0NQF1zbNpNQ)
- **Raiko Architecture** [Twitter Thread](https://x.com/taikoxyz/status/1791201812768600209)

---

## Proving Taiko Alethia Blocks

---

### **Why is proving required?**

Proving blocks ensures that the **state transitions within the rollup are valid**, providing certainty to **bridges and other dependent systems** that L2 transactions were executed correctly.

### **Prover Participation**

- Anyone can **permissionlessly** run a node and prove blocks.
- Provers examine proposed blocks on the **TaikoL1 contract**, generate proofs, and submit them.
- The **first prover** with a valid proof of the correct state transition receives the **proof reward**.
- Rewards can be in **ETH, ERC20 tokens, or even NFTs**, depending on the implementation.

---

## Verified Blocks and Parallel Proving

---

### **Block States**

A block in Taiko Alethia progresses through three key states:

1. **Proposed** (Initial state, pending proof submission)
2. **Proved** (At least one valid proof exists)
3. **Verified** (Proof is confirmed along with parent blocks)

### **Parallel Proof Generation**

- Blocks are proved **independently** in parallel.
- For a block to be **verified**, its **parent block must also be verified**.
- Taiko Alethia verifies **blocks in batches** instead of sequentially.
- **A verified block may have `verifiedTransitionId == 0` due to batch verification.**

#### **Illustrative Stages**

**Proposed Blocks:**
![Proposed](~/assets/content/docs/taiko-alethia-protocol/proposed.png)

**Proved Blocks:**
![Proved](~/assets/content/docs/taiko-alethia-protocol/proved.png)

**Verified Blocks:**
![Verified](~/assets/content/docs/taiko-alethia-protocol/verified.png)

---

## Off-Chain Prover Market (PBS-style)

Generating and verifying proofs on **Ethereum L1** incurs **significant computation costs**. To optimize efficiency, Taiko Alethia introduces an **off-chain prover marketplace** inspired by **Proposer-Builder Separation (PBS)**.

### **Key Challenges in Pricing Proofs**

1. Ethereum **gas costs** for proof verification are unpredictable.
2. Proof generation costs **do not directly correlate** with gas fees.
3. Hardware and software **optimizations continuously reduce costs**.
4. Proof generation **cost depends on the required proof latency**.

### **How the Prover Market Works**

- **Proposers seek proof service providers** through an off-chain marketplace.
- **Provers bid** by offering to generate proofs for a negotiated fee.
- Once an agreement is reached, the prover **signs a cryptographic commitment**.
- The proposer submits this proof on-chain.
- **If the proof is not provided within the agreed timeframe, penalties apply**.

### **Prover Types**

- **EOA Provers:** Individual accounts that submit proofs.
- **Prover Pools (Smart Contracts):** Contract-based provers implementing:
  - `IProver` interface (Taiko-defined)
  - `IERC1271` interface (for signature verification)

### **Prover Incentives**

- Provers must deposit **TAIKO tokens as collateral per block**.
- **Failure to deliver a proof** within the agreed time results in:
  - **1/4 of the deposit going to the next prover**.
  - **3/4 of the deposit permanently burned**.
- Successful proof submission **returns the deposit**.

---

## Multi-Proofs: Enhancing Security & Redundancy

Taiko Alethia embraces **multi-proof verification** to minimize the risks of **single-point cryptographic failures**.

### **Why Multi-Proof?**

- **Cryptographic implementations are complex and evolving.**
- **Bugs in a single proof system could compromise security.**
- **Combining multiple proof systems enhances security through redundancy.**

### **Taiko Alethia’s Multi-Proof Pipeline**

- Converts **execution layer instructions** into **arithmetizations**.
- Supports multiple **cryptographic backends**:
  - **SuperNova**
  - **Halo2**
  - **eSTARK**
- **Does not rely on a single proving protocol.**

### **SGX: Trusted Execution Environments (TEEs)**

- **Intel SGX** is used as an alternative proof mechanism.
- **SGX runs a light execution client** that verifies state transitions.
- **SGX signs execution results using an ECDSA signature**, which is validated on-chain.

### **More Resources on Multi-Proof Security**

- **Taiko Alethia Multi-Proof Discussion** [Twitter Thread](https://x.com/taikoxyz/status/1745546868028068273)

---

## Video Explanation

<iframe
src="https://www.youtube.com/embed/9LT6B1pgkI8?si=KFQxakvFTNdXwwvJ"
title="YouTube video player"
frameborder="0"
allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
allowFullScreen
></iframe>

---
