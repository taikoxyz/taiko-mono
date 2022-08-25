# DESIGN

## Assumptions of zkEVM Proofs

What a ZKP can and cannot prove is critical to a zkRollup's protocol design. Different assumptions allow for different designs. As a matter of fact, our current protocol design is fundamentally different from the one we had in Q2 2022, simply because we adopted a new set of ZKP assumptions that will be outlined in this section.

### Computation of ZKPs

In the following sections, when we mention ZKP we are always referring to the aggregated proof for verification on L1.

To compute a ZKP for a L2 block at height $i$, the following data will be used as inputs:

1. The latest 256 block hashes $h_{i-256}, ..., h_{i-1}$;
1. This block's hash $h_i$;
1. a RPL-encoded list of L2 transactions $X_i$. It is the data rolled up from L2 to L1 and what makes a rollup. We also refer it as the _txList_.
1. The trace logs $T_i$ produced by running all transactions in $X_i$ by a Taiko L2 node. Note that the trace logs also include information related to _unqualified L2 transactions_ which we will talk about later, and;
1. A prover-selected address $a$ only which can transact the `proveBlock` transaction for this block using _this_ to-be generated ZKP, though anyone else can verify the ZKP's validity.


Hence we have:

$$ p_i^a = \mathbb{Z} (h_{i-256}, ..., h_{i-1}, h_i, T_i, X_i, a) $$

where
- $p_i^a$ is the ZKP for this block with $a$ as the prover address, and;
- $\mathbb{Z}$ is the zkEVM proof generation function.



### Verification of ZKPs

Verification of a ZKP on L1 through solidity contract requires the following inputs:

1. The latest 256 block hashes $h_{i-256}, ..., h_{i-1}$;
1. This block's hash $h_i$;
1. The keccak256 hash of $X_i$, e.g., $\mathbb{H}(X_i)$. When [Proto-Danksharding](https://www.eip4844.com/) is enabled, it will become $X_i$'s KZG commitment, and;
1. The current `msg.sender`, treated as the prover address $a$.

Hence we have:

$$ \mathbb{V}\_K(h\_{i-256}, ..., h\_{i-1}, h_i, \mathbb{H}(X_i), a) $$

where

-   $\mathbb{V}$ is the ZKP verification function implemented in solidity
-   $K$ is zkEVM's verification key.

### Validating txLists and Transactions

A _txList_ is valid if and only if:

1. The txList is well-formed RLP, with no additional trailing bytes;
2. The total number of transactions is no more than a given threshold;
3. The sum of all transaction gas limit is no more than a given threshold;

A transaction is _valid_ if and only if:
1. The transaction is well-formed RLP, with no additional trailing bytes (rule#1 in Ethereum yellow paper);
2. The transaction's signature is valid (rule#2 in Ethereum yellow paper), and;
3. The transaction's the gas limit is no smaller than the intrinsic gas (rule#5 in Ethereum yellow paper).

A transaction is _qualified_ if and only if:

4. The transaction is valid;
5. The transaction's nonce is valid, e.g., equivalent to the sender account's current nonce (rule#3 in Ethereum yellow paper);
6. The transaction's sender account has no contract code deployed (rule#4 in Ethereum yellow paper) and;
7. The transaction's sender account balance contains _at least_ the cost required in up-front payment (rule#6 in Ethereum yellow paper).

### Design Options

We have two options for validating txList:

- Option 1: requiring the txList is valid, and all transactions in a txList must be qualified; otherwise, the txList produces an empty block.
- Option 2: requiring the txList is valid, and all transactions in a txList must be valid. Qualfied transactions will make into the L2 block; and unqualfied transactions are dropped. The txList produces an empty block on if there is zero qualfied transactions.

Option 1 has the drawback that one unqualiifed transaction will disqualfied the entire block, therefore, we choose option 2 to maximize the number of transactions that will become part of L2 blocks.
