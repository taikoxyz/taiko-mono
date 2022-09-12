This document outlines the design for Taiko, a zkEVM-based general-purpose zkRollup layer 2 for Ethereum.

## Design Goals

- Simplicity — the design shall impose as few responsibilities as possible on the network’s sequencers/validators so that they only have to perform a minimal set of actions to keep the network up and running.
- Ethereum equivalence — the ultimate goal is to allow DApps developed for Ethereum L1 to be migrated to Taiko without a single line of code change. Taiko shall express Ether exactly the same way as on L1, which means Ether is Taiko’s native currency, not an ERC20 token.
- Cost efficiency —  Taiko’s footprint on L1 shall be minimized to the extreme to reduce cost.
- Fully decentralized — Taiko shall be permissionless and decentralized from day one.

## Terminology

- L1: the Ethereum network.
- L2: layer-2 in general, but sometimes also called Taiko.
- Block: an L2 block. When we need to mention L1 Block, we’ll call it out explicitly as L1 _block_ or _Ethereum block_.
- L1 Rollup: a set of smart contracts on L1 that handles block submissions.
- L2 Rollup: a set of smart contracts on L2 that prepares a block, which includes authorizing L1 validators and handling cross-chain signals.
- L2 Sequencer: a L2 block miner who decides which transactions to include in the block and when/how to transact the L2 rollup contract’s `prepareBlock` transaction.
- L1 Validator: the address to interact with L1 Rollup. A block’s validator address must be authorized by the L2 sequencer first within the `prepareBlock` transaction.
- Signal: 32-byte data on the source chain to represent a message to be sent to the destination chain. The interpretation of the data is up to DApps thus agnostic to the system.
- Signal Root: the Merkel root of all the signals contained in a block’s outbox. Signal roots, not signals, are made available on the destination layer for DApps to verify the inclusion of their signals using Merkel proofs.
- Outbox: the data structure that contains signals. Each L2 block has two outboxes, one on L1 and one on Taiko.
- Inbox: The data structure that marks all received signal roots. There are two inboxes, one on L1 and one on Taiko.

## Assumptions

We use AppliedZKP’s zkEVM as a core component in our rollup. We assume that:

- zkEVM is fully compatible with the current Ethereum client implementation, except that the block reward will be changed to zero Ether.
- The signatures of L2 transactions are not part of data availability (DA, DA data), therefore, the L2 transactions are not available in their entirety to parties other than the block’s sequencer and validator.

## Chain Selection and PoS

Our PoS design is highly inspired by the [NXT](https://nxtdocs.jelurida.com/Nxt_Whitepaper) project.

Chain selection in Taiko differs from Ethereum in that proposed blocks are submitted to L1 Rollup on Ethereum to verify their validity instead of being broadcast to a peer-to-peer network for consensus. Pending transactions in Taiko do propagate through the network for potential inclusion by future blocks.

A Taiko block may have the following status on L1:

- Pending - the block is temporarily accepted by L1 but it has not been proven with a valid ZKP yet.
- Proven - the block is proven with a valid ZKP but may still be dropped if one of its ancestors is invalidated.
- Finalized - the block is proven and all its ancestors are also proven. Once a block is finalized, it is part of the canonical chain forever unless L1 • re-organizes out the finalization transaction. L2’s genesis block is immediately finalized, without a ZKP.

On L1, we use a ring buffer to keep track of the latest finalized block and up to $N$ pending blocks, therefore, the ring buffer has $N+1$ slots, and the block at height $H$ will be put in slot $H \% (N+1)$. We also allow the first $M (0 < M \eqslantless N)$ pending blocks to be proven in an arbitrary order.

In the example below, the ring buffer is configured with $N = 100$ and $M=3$. The genesis block (block #0) is finalized, block 1 to 5 have been proposed and only block 2 is proven. Block 1 and 3 can be proven as they are in the proving zone but block 4 and 5 cannot.

![block selection.png](/b/DESIGN%20564281f59d274c258b7e9f871e817528/block_selection.png)

The benefit of using a ring buffer is that L1 storage slots will be reused after $N+1$ blocks are proposed so storage writes will be less expensive.

In the following paragraphs, we flatten the ring buffer and always show the latest finalized block as the first element in the block list. The above block states can then be illustrated as:

![block selection.png](/b/DESIGN%20564281f59d274c258b7e9f871e817528/block_selection%201.png)

If block 3 is proven and block 1 is proven later, then block 1, 2, 3 will all get finalized and the block states will change the following:

![block selection.png](/b/DESIGN%20564281f59d274c258b7e9f871e817528/block_selection%202.png)

Such a block finalization design has the following implications:

- The transactions that prove Block 2 and 3 are cheaper as they do not handle block finalization-related state updates which are expensive. The transaction that proves block 1 is more expensive as it has to finalize not only block 1, but also all the consecutive proven blocks after block 1 up to $M$ blocks, in this example, block 2 and 3. This implication will encourage validators to prove their own blocks as soon as possible after they enter the proving zone to reduce their L1 cost.
- Block finalization may advance the latest finalized block by more than one, given that $M$ is greater than 1. This translates directly to a faster block finalization speed and thus higher L2 throughput. But $M$ cannot be too large, otherwise, the finalization transaction may require more gas than the L1 block gas limit.

### Block Expiry

Provable pending blocks will expire if they haven’t been proven within their corresponding expiry windows. We define block $i$’s expiry window as $w^i = max(t_p^i + T_p, t_f + T_f)$ where $t_p^i$ is the time this block is proposed, $t_f$ is the time the latest finalized block was finalized, $T_p$ is a constant value based on the average time required for ZKP computation, and $T_f$ is set to be 10 minutes for now.

Expired blocks are still valid until they are reported —the network allows any address to report expired blocks. Once an expired block is reported it will be removed together with all blocks that follow it, regardless of whether those following blocks are proven. This means the validators of all subsequent blocks lost their transaction fees. To punish the validator of the expired block, a certain percentage of its staking will be slashed.

If an expired block is proven before being reported, its status changes to proven or finalized, and any reporting transactions will fail. Note that pending blocks outside of the proving zone never expire.

### Block Replacing

A block is invalid if its data has no integrity. Invalid blocks can be identified by the Taiko node software by replaying the enclosed transactions on top of its parent’s world state and comparing the post-block state root. When an invalid block is identified, the L2 client will drop the block immediately and treat its valid parent as the latest known block. If the client has PoS mining enabled, it will produce a new (potentially empty) block to replace the invalid block with `replaceBlock` transaction on L1.

The diagram below shows that block 4’ has replaced block 4. Similar to expired block reporting logic, when a block is replaced, all its subsequent blocks are dropped as well. In the example below, block 5 will be deleted.

![block selection.png](/b/DESIGN%20564281f59d274c258b7e9f871e817528/block_selection%203.png)

To prevent a valid block to be replaced, we require the replacing block to stake an additional amount of tokens called _Replacing Stake_. If the replaced block receives a valid ZKP before its proving timeout, the replacing block’s replacing stake will be slashed, and the replaced block validator earns the same block reward, but on L1.

The replaced block’s proving timeout is defined as $t_p^i + T_p$, no matter it’s inside or outside of the proving zone.

On the other hand, if the replaced block doesn’t receive a valid ZKP within the proving timeout, the replacing block’s validator can claim back his replacing stake and earn a replacing reward, which is higher than a regular block reward to incentive network validators for invalid block removal.

A replacing block can also be replaced by yet another block, but not by blocks that have been previously replaced. In other words, circular block replacement is prohibited.

### Proposing Delay

Blocks can be proposed by validators who staked any non-zero amount of protocol tokens with a **_minimal_ _proposing delay_ (MPD)**. The first one who successfully proposed a block for height $i$ will be the pending block at height $i$. Once there is a pending block at certain height $i$, other block proposals at the same height will fail.

MPD will be calculated as follows (the same 1559 style math, but reversed):

$F^0 = \hat{T}$

$D_j^i={F^{i-1}{\\(h_j^i\\)^{1\over M}}/(w_j^i b_j^i)}$

$F^i = F^{i-1}{\frac{K\hat{T}}{(K-1)\hat{T} + T^{i}}}$

where:

- $\bar{T}$ is the target block-time, a constant.
- $F$ is the _adjustment factor_ that tracks recent block-time changes, defaults to $1$ at time zero, and is updated after each block.
- $D_j^i$ is the minimal proposal delay for validator $j$ at block $i$.
- $T^i$ is the actual block time at block $i$, therefore $T^i \eqslantgtr \min\{D_j^i\}$.
- $h_j^i$ is a deterministically random number called the _hit_ for validator $j$ at block $i$, $0 \eqslantless h_j^i \eqslantless 1$. We currently use the `keccak256` hash of 1) the validator’s address, 2) the parent block’s hash and 3) the parent block’s proposing timestamp as the hit.
- $w_j^i$ is the staking wait for validator $j$ at block $i$, such that $0 < \sum_i{w_j^i} \eqslantless 1$.
- $b_j^i$ is the weight of the candidate block from validator $j$ at block $i$, $0 < b_j^i < 1$. This weight is the total gas used in the current implementation, but it can be a combination of the number of transactions enclosed, and the calldata size.
- $M$ is a configurable constant to determine the weight of hits, $M \eqslantgtr 1$ . Bigger values translate to less randomness, In our simulation, we use 4.
- $K$ is a configurable constant to determine how responsive $F$ will be, $K > 1$.

We performed many simulations; all of them show that the average block time converges at our target block time $\hat{T}$ regardless of how staking weights and block weights vary or distribute.

![Simulation results](/b/DESIGN%20564281f59d274c258b7e9f871e817528/output.png)

Simulation results

The math has two obvious implications:

- a validator’s average MPD becomes smaller when its stake gets bigger.
- a validator’s MPD is smaller when the block to propose has a bigger weight.

### Block Timestamp

In any L1 block, all enclosed transactions share the same `block.timestamp` value. It seems all transactions occur within a single point in time. This view implies no one can propose more than one L2 block inside one L1 block, as there is a nonzero **MPD** for each L2 block.

![L1 block has zero time-span](/b/DESIGN%20564281f59d274c258b7e9f871e817528/block_selection%204.png)

L1 block has zero time-span

Therefore, we adopt another view of the L1 block timestamp. We interpret `block.timestamp` as the **start time** of an L1 block, and its end time is defined as `block.timestamp + 12 seconds`, as an L1 block time will be [12 seconds](https://github.com/ethereum/consensus-specs/blob/v0.11.1/specs/phase0/beacon-chain.md#time-parameters) (`SECONDS_PER_SLOT`) in Eth2 after the Merge.

Note that this 12-second doesn’t have to be accurate. We always require an L2 block’s `proposedAt` value to be greater than its parent’s `proposedAt`.

![L1 block has non-zero time-span](/b/DESIGN%20564281f59d274c258b7e9f871e817528/block_selection%205.png)

L1 block has non-zero time-span

Then it becomes possible for validators to propose more than one L2 block inside an L1 block as long as those blocks’ `proposedAt` timestamps are no smaller than `block.timestamp` and no larger than `block.timestamp + 12 seconds`.

### Block Rewards

Block rewards are TAI tokens mint in each L2 block. An exception is for replaced but proven blocks, their rewards are mint on L1 because their state changes are discarded. The amount of block reward will automatically be halved for every 4 years.

A fixed amount of TAI tokens will also be minted and sent to the DAO’s address for 4 years to ensure the DAO has sufficient funds to support continuous protocol upgrades and ecosystem development.

## Cross-Chain Data Synchronization

### Block Hash Availability

Each L2 block shall bring the latest known L1 block’s number and hash to L2 and make them available for L2 DApps. The L1 block’s number must not be smaller than the one brought to L2 by the parent L2 block.

The latest finalized L2 block's block hash, block number, and state root are brought to L1 and made available for L1 DApps.

Applications on both chains can use the latest block hash of the other chain and use Trie proof to verify the other chain’s world state.\*\*\*\*

### Signals and Signal Roots

We also introduce a cross-chain communication sub-protocol for DApps to send signals to the other layer. DApps on the destination layer can use Merkel proofs to verify the inclusion of the signals on the source chain.

A signal is a 32-byte application-agnostic data. On the source chain, the signal is hashed with its sender address and is put into the outbox associated with the L2 block next to the one to be proposed — meaning the next block’s outbox is closed. Note that for each L2 block, there are two outboxes, one on L2 and the other one on L1. Each outbox has a fixed capacity (1024 signals by default). Once the outbox is full, the signal service becomes unavailable before a block is proposed.

When an L2 block is proposed, signals in its outboxes are merkelized into two 32-byte signal roots (they are actually Merkel tree roots), and only these two signal roots will be written to the destination chain’s inbox. Signals and signal roots are permanently persisted and will never be deleted or modified unless Ethereum is reorganized.

The diagram below shows that after block 5 is proposed, DApps can only send signals to block 7’s outbox and the sequencers are busy with proposing block 6.

![block selection.png](/b/DESIGN%20564281f59d274c258b7e9f871e817528/block_selection%206.png)

> If we allow signals to be sent to block 6’s L2 outbox, then block 6’s `prepareBlock` transaction may proceed `sendSignal` transactions, which ends up with an incorrect L2 outbox signal root, thus a serious security bug.

The signal-based cross-chain communication sub-protocol guarantees that all received signals will be sent cross-chain eventually. Therefore, for expired blocks and replaced blocks, their signals will always remain in the box.

In the example below, while block 6 is being proposed, DApps can only write signals to block 7’s outbox. But since block 7’s outbox is full, the signal service is unavailable.

![block selection.png](/b/DESIGN%20564281f59d274c258b7e9f871e817528/block_selection%207.png)

Now if block 4 is replaced (sequencers will be busy with proposing block 5), DApps can access block 6’s outbox again but can only consume the remaining capacity, not overriding existing signals.

![block selection.png](/b/DESIGN%20564281f59d274c258b7e9f871e817528/block_selection%208.png)

### Signal Fees

Since each outbox has a limited capacity, a fee will be charged per signal to prevent spamming. Each block's outbox has a different signal fee, which is calculated based on 1) the current block’s signal fee and 2) the number of signals in the outbox using the same EIP-1558-style math - the targeted number of cross-chain signals per outbox is set to half of the max capacity. Note that once a fee is set for an outbox, it will not change again, even in the case the corresponding block is expired or replaced.

Signal fees are paid in Ether on both L1 and L2. Signal fees received on L1 will be immediately forwarded to a DAO vault; while signal fees received on L2 are rewarded to the sequencer.

### Sync Hash

In order to support the aforementioned cross-chain data synchronization for each block, the block’s sequencer must write certain data to the L2 world state, including 1) the latest known L1 block number, 2) the latest known L1 block’s hash,3) the validator address that is authorized to transact the `proposeBlock` transaction on L2, and 4) the L1 and L2 signal roots. It’s likely that more data may also be added to this list.

The L1 rollup contract can verify that the correct data are written correctly to the L2 world state, but it will require the `proposeBlock` transaction to provide all the values and their corresponding L2 Trie proofs. We simplify the verification by hashing all these values into a bytes32 called _sync hash._ On L1 we only need to verify the sync hash is written to the L2 world state, therefore, one single Trie proof suffices.

## Bridges

Bridges are designed to facilitate cross-chain contract invocations including Ether transfers. But Bridge is not part of the core rollup protocol, therefore, multiple bridges including third-party bridges can be deployed on Taiko.

The default Bridge-enabled invocations are captured by the `Message` struct defined below where `sender` represent the address that invokes the sendMessage transaction, `owner` represent the owner of the message on the destination chain that can perform certain actions, `to` is the target address on which the invocation will occur, and `data` is the transaction calldata payload (empty `data` means Ether transfer to the `to` address).

```solidity
struct Message {
    uint256 nonce;
    address sender;
    bytes32 fromCodeHash;
    uint256 srcChainId;
    uint256 destChainId;
    address owner;
    address to;
    address refundAddress;
    uint256 depositValue;
    uint256 callValue;
    uint256 maxProcessingFee;
    uint256 gasLimit;
    uint256 gasPrice;
    bytes   data;
}
```

The internal transaction represented by `data` can get access to a `Context` object by calling `Bridge(bridgeAddress).context()`. This function returns an object defines as follows:

```solidity
struct Context {
    uint256 srcChainId;
    uint256 destChainId;
    address xchainSender;
}
```

### Fees and Required Ether

On the source chain, the message sender must send enough sender to cover 1) signal sending fee, 2) cross-chain deposit, 3) contract invocation Ether call value and gas cost, and 4) message processing fee on the destination chain. Therefore, the total ether required is:

```solidity
sService.signalFee() +
message.maxProcessingFee +
message.gasPrice * message.gasLimit +
message.depositValue +
message.callValue;
```

Any extra Ether will be refunded to the caller of the `sendMessage` function or a designated address.

Note that if `message.gastLimt` is set to be zero, then only the message’s owner address can invoke the message call.

### Message Processing

On the destination layer, arbitrary addresses are allowed to process a message by interacting with the Bridge contract as long as:

- the message has a valid inclusion proof;
- the message has not been processed yet.

Message processors cannot charge more than `message.maxProcessingFee` ether as the processing fee. If `message.maxProcessingFee` is set to zero, the message can still be processed by arbitrary addresses without fee payments, as long as the processors are willing to pay the gas cost.

### Message Invocation

Message invocation is part of message processing unless `message.gasLimit` is zero. Up to `message.gasPrice * message.gasLimit` more fee will be charged. If the invocation is successful, the message will be marked as _done_; otherwise, all remaining fees will be refunded and the message will become _retriable_. Retriable messages can only be re-invoked by their owners, and while messages are retried, custom gas limit and gas price can be provided.

## Summary

Taiko’s design is still preliminary and we are still trying to identify potential security and performance-related issues. The solidity L1/L2 rollup contracts will be open-sourced soon for the community to review. We will welcome and appreciate constructive feedback.
