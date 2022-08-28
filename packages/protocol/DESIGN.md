# DESIGN

## Anchor Transaction

TODO

## Assumptions of zkEVM Proofs

What a ZKP can and cannot prove is critical to a zkRollup's protocol design. Different assumptions allow for different designs. As a matter of fact, our current protocol design is fundamentally different from the one we had in Q2 2022, simply because we adopted a new set of ZKP assumptions that will be outlined in this section.

### ZKP Computation

In the following sections, when we mention ZKP we are always referring to the aggregated proof for verification on L1.

To compute a ZKP for a L2 block at height $i$, the following data will be used as inputs:

1. This block's header $H_i$;
1. A prover-selected address $a$ only which can transact the `proveBlock` transaction for this block using _this_ to-be generated ZKP, though anyone else can verify the ZKP's validity;
1. A RLP-encoded list of L2 transactions $X_i$. It is the data rolled up from L2 to L1 and what makes a rollup. We also refer it as the _txList_;
1. A RLP-encoded transaction $z_i$, referred as _the anchor transaction_ prepared by the prover. $z_i$ is the last tx in the block, and;
1. The trace logs $T_i$ produced by running all transactions in $X_i$ by a Taiko L2 node. Note that the trace logs also include data related to _unqualified L2 transactions_ which we will talk about later

Hence we have:

$$ p_i^a = \mathbb{Z} (H_i, a, X_i, z_i, T_i) $$

where

-   $\mathbb{Z}$ is the zkEVM proof generation function.
-   $p_i^a$ is the ZKP for this block with $a$ as the prover address, and;

### ZKP Verification

Verification of a ZKP on L1 through solidity contract requires the following inputs:

1. $p_i^a$ is the ZKP with $a$ as the prover address;
1. The fee receipient address $a$;
1. This block's hash $h_i = \mathbb{H}(H_i)$;
1. The keccak256 hash of $X_i$, e.g., $\mathbb{H}(X_i)$ (or $X_i$'s KZG commitment after [EIP4844](https://www.eip4844.com/));
1. The keccak256 hash of $z_i$, e.g., $\mathbb{H}(z_i)$ (or $z_i$'s KZG commitment after [EIP4844](https://www.eip4844.com/)), and;

Hence we have:

$$ \mathbb{V}\_K(p_i^a, h_i, a, \mathbb{H}(X_i), \mathbb{H}(z_i)) $$

where

-   $K$ is zkEVM's verification key;
-   $\mathbb{V}$ is the ZKP verification function implemented in solidity.

### Validating txLists and Transactions

A _txList_ is valid if and only if:

1. The txList's lenght is no more than `TAIKO_BLOCK_MAX_TXLIST_BYTES`;
2. The txList is well-formed RLP, with no additional trailing bytes;
3. The total number of transactions is no more than `TAIKO_BLOCK_MAX_TXS` and;
4. The sum of all transaction gas limit is no more than `TAIKO_BLOCK_MAX_GAS_LIMIT`.

A transaction is valid if and only if:

1. The transaction is well-formed RLP, with no additional trailing bytes (rule#1 in Ethereum yellow paper);
2. The transaction's signature is valid (rule#2 in Ethereum yellow paper), and;
3. The transaction's the gas limit is no smaller than the intrinsic gas `TAIKO_TX_MIN_GAS_LIMIT`(rule#5 in Ethereum yellow paper).

A transaction is qualified if and only if:

4. The transaction is valid;
5. The transaction's nonce is valid, e.g., equivalent to the sender account's current nonce (rule#3 in Ethereum yellow paper);
6. The transaction's sender account has no contract code deployed (rule#4 in Ethereum yellow paper) and;
7. The transaction's sender account balance contains _at least_ the cost required in up-front payment (rule#6 in Ethereum yellow paper).

### Design Options

We have two options for validating txList:

-   Option 1:
    -   If the txList is invalid or at least one of its transactions is invalid/unqualified, no L2 block will be produced;
    -   Otherwise, a L2 block with all transactions will be produced.
-   Option 2:
    -   If the txList is invalid or at least one of its transactions is invalid, no L2 block will be produced;
    -   Otherwise, a L2 block with qualified transactions will be produced(all valid but unquanlifed transactions dropped). The worst-case scenario is that an empty block is produced.

We choose option 2 to maximize the change that a transaction makes into the L2 chain.

### False Proving a txList

If a txList is invalid, the prover knows the reason. The prover now can create a temporary L2 block that includes a `verifyTxListInvalid` transaction with the txList and the reason as the transaction inputs. The `verifyTxListInvalid` transaction, once verifies the txList is invalid, will store `true` to a specific storage slot that the txList's hash maps to. The prover will then be able to generate a normal ZKP to prove this temporary block is valid, then provide a merkle proof to verify the value of the specific storage slot is `true`. This will indirectly prove the txList is invalid, thus its corresponding proposed L2 block is invalid.

Note that the temporary L2 block that include the `verifyTxListInvalid` is NOT the block in question that will be proven to be invalid, the temporary block is not part of the L2 chain and will be throw away.

The tempoary block can use any recent L2 block as its parent, beause the `verifyTxListInvalid` transacton is a _pure_ solidity function that works the same way regardless of the current L2's actual world state.

### Verification of L2 Global Variable Value

We further assume **zkEVM can verify global-variable opcodes' return values if these values are stored in the Patricia Trie or are part of the block header.** Therefore, we need special verificaton of the following global variables per L2 block by checking their values are either constant or match the values stored in the Patricia Trie inside the parent block's Anchor Transaction.

-   `block.chainid`
-   `block.baseFee`
-   `block.hash`
