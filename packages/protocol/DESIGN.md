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
1. A prover selected address $a$ only which can transact the `proveBlock` transaction for this block, though anyone else can verify the ZKP's validity.

Therefore, we have:

$$ p_i^a = \mathbb{Z}(h\_{i-256}, ..., h\_{i-1}, h_i, T_i, X_i, a) $$

where $p_i^a$ is the ZKP for this block with $a$ as the prover address, and $\mathbb{Z}$ is the zkEVM proof generation function.

### Verification of ZKPs

Verification of ZKP on L1 through solidity contract requires the following inputs:

1. The latest 256 block hashes $h_{i-256}, ..., h_{i-1}$;
1. This block's hash $h_i$;
1. The keccak256 hash of $X_i$, e.g., $\mathbb{H}(X_i)$. When [Proto-Danksharding](https://www.eip4844.com/) is enabled, it will become $X_i$'s KZG commitment, and;
1. The current `msg.sender`, treated as the prover address $a$.

The following will be the verification function:

$$ \mathbb{V}\_K(h\_{i-256}, ..., h\_{i-1}, h_i, \mathbb{H}(X_i), a) $$

where

-   $\mathbb{V}$ is the ZKP verification function implemented in solidity
-   $K$ is zkEVM's verification key.

### About txList

We assume valid ZKPs (with different prover addresses) can be generated for a txList as long as the following function returns true:

```solidity
function isTxListValid(bytes calldata encodedTxList)
    internal
    pure
    returns (bool)
{
    try decodeTxList(encodedTxList) returns (TxList memory txList) {
        return
            txList.items.length <= MAX_TAIKO_BLOCK_NUM_TXS &&
            LibTxListDecoder.sumGasLimit(txList) <= MAX_TAIKO_BLOCK_GAS_LIMIT;
    } catch (bytes memory) {
        return false;
    }
}

function decodeTxList(bytes calldata encodedTxList)
    public
    pure
    returns (TxList memory txList)
{
    Lib_RLPReader.RLPItem[] memory txs = Lib_RLPReader.readList(encodedTxList);
    require(txs.length > 0, "empty txList");

    Tx[] memory _txList = new Tx[](txs.length);
    for (uint256 i = 0; i < txs.length; i++) {
        bytes memory txBytes = Lib_RLPReader.readBytes(txs[i]);
        (uint8 txType, uint256 gasLimit) = decodeTx(txBytes);
        _txList[i] = Tx(txType, gasLimit, txBytes);
    }
    txList = TxList(_txList);
}

```

The above code verifies a txList is valid if and only if:

1. The txList is well-formed RLP, with no additional trailing bytes;
2. The total number of transactions is no more than a given threshold;
3. The sum of all transaction gas limit is no more than a given threshold;
4. Each transaction is well-formed RLP, with no additional trailing bytes (rule#1 in Ethereum yellow paper);
5. Each transaction's signature is valid (rule#2 in Ethereum yellow paper), and;
6. Each transaction's the gas limit is no smaller than the intrinsic gas (rule#5 in Ethereum yellow paper).

Once the txList is validated, a L2 block can be generated, but the block may potential be empty. This is because some transactions in the txList may be _unqualified_.

A _qualified transaction_ satisfies the following conditions:

-   It's nonce is valid, e.g., equivalent to the sender account's current nonce (rule#3 in Ethereum yellow paper);
-   It's sender account has no contract code deployed and (rule#4 in Ethereum yellow paper), and;
-   It's sender account balance contains _at least_ the cost required in up-front payment (rule#6 in Ethereum yellow paper).

Because checking if a transaction is indeed qualified can only be done by the Taiko L2 node using its knowledge of the L2 world-state, the L1 rollup contract treats qualified and unqualified transactions equally. In the case of all transactions in the txList are unqualfied, the L2 node will yield a empty but valid block. zkEVM shall generate a valid proof regardless.

### Handing of Unqualified Transactions on L2

If a Taiko node proposes blocks, it will have to _execute_ unqualified transactions to produce trace logs for ZKP computation. Such execution will, however, not change any state variable or block header field values.

Non-proposing Taiko nodes may skip over all unqualified transactions and only run those qualified transactions.
