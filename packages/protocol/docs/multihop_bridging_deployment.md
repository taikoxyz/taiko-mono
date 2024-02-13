# Multi-hop cross-chain bridging

This document briefly describes how multi-hop cross-chain bridging is done in Taiko.


## L1<->L2 data synchornization
We will use the following diagram to represent a blockchain's state. The bigger triangle is the world state, the smaller triangle is the storage tree of a special contract called the *Signal Service*, which must be deployed on both L1 and L2.

<img src="./multihop/state.png" height="280" style="padding:40px">

When a signal is sent by the Signal Service, a unique slot in the Signal Service's storage will be written with value `1`, as shown by the code below.

```solidity
function _sendSignal(address sender, bytes32 signal)
 	internal returns (bytes32 slot) 
{
    if (signal == 0) revert SS_INVALID_SIGNAL();
    slot = getSignalSlot(uint64(block.chainid), sender, signal);
    assembly {
        sstore(slot, 1)
    }
}

function getSignalSlot(
    uint64 chainId,
    address app,
    bytes32 signal
)
    public
    pure
    returns (bytes32)
{
    return keccak256(abi.encodePacked("SIGNAL", chainId, app, signal));
}
```

Merkle proofs can be used to verify that signals has been sent by specific senders if the signal service's state root is known on another chain. A full merkle proof consists of an *account proof* and a *storage proof*. Note that if the signal service's storage root (aka the *signal root*) is known on another chain, a storage proof is sufficient to verify the signal was indeed send on the source chain, a full merkle proof is not necessary.


<img src="./multihop/merkle_proof.png" height="280" style="padding:40px">



Taiko's core protocol code (TaikoL1.sol and TaikoL2.sol) automatically cross-synchronize or relay the state roots between L1 and L2.

When chainA's state root is relayed to chainB, a special signal is sent (written) in chainB's signal service. The signal is calculated such that chainA's block ID must be hashed in. Note that these special signals are always sent by the target chain's signal service, as shown in the diagram below.

<img src="./multihop/l1_l2_sync.png" height="400" style="padding:40px">

If you deploy more chains using Taiko protocol, you can have a chain of relayed state roots between these chains.


<img src="./multihop/three_chains.png"  style="padding-top:40px">

