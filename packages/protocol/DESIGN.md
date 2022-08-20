# DESIGN

## Assumptions of zkEVM Proofs

What a ZKP can and cannot prove is critical to a zkRollup's protocol design. Different assumptions allow different designs. As a matter of fact, our current protocol design is fundamentally different from the one we had in Q2 2022, simply because we now adopt a new set of ZKP assumptions outlined in this section.


### Computation of ZKPs

In this and the next section, when we mention ZKP, we always refer to the aggregated proof for verification on L1.

To compute a ZKP for a L2 block $B_i$, the following data will be used as inputs:

1. The parent block hash $h_{i-1}$
1. This block's hash $h_i$
1. a RPL-encoded list of L2 transactions $X_i$. It is the data rolled up from L2 to L1 and what makes a rollup a rollup. In our code, we refer it as the `txList`.

> Question(brecht): do we need $X_i$ or only its hash in ZKP computaton?

4. The trace logs $T_i$ produced by running all transactions in $X_i$ by a Taiko L2 node. Not that the trace logs also include information related to *unqualified L2 transactions* which we will talk about later.
5. A prover selected address $a$ only which can transact the `proveBlock` transaction for this block, though anyone else can verifiy the ZKP's validity.

Therefore, we have:

$$ p_i^a =  \mathbb{Z}(h_{i-1}, h_i, X_i, T_i, a)      $$

where $p_i^a$ is the ZKP for this block with $a$ as the prover address, and  $\mathbb{Z}$ is the zkEVM proof generation function.

### Verification of ZKPs
Verification of ZKP on L1 through solidity contract requires the following inputs:

1. The parent block hash $h_{i-1}$
1. This block's hash $h_i$
1. The keccak256 hash of $X_i$, or $\mathbb{H}(X_i)$. When proto-danksharding is enabled, it will become $X_i$'s KZG commitment.
1. The current `msg.sender`, treated as the prover address $a$.

The following will be the verification function:

$$  \mathbb{V}(K, h_{i-1}, h_i, \mathbb{H}(\mathbb{H}(X_i), a)) $$

where
- $\mathbb{V}$ is the ZKP verification function implemented in solidity
- $K$ is zkEVM's verification key.
- $\mathbb{H}(\mathbb{H}(X_i), a)$ is considered the *public input*.
> Question(brecht): is the above statement correct at all?
