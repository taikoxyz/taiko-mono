## Anchor Transaction

The first transaction in every Taiko L2 block to perform data validation and enable L1-to-L2 communication.

## Bridge

The Taiko bridge allowing users to bridge Ether and custom ERC-20 tokens from and to Taiko.

## Commit Hash

The Keccak-256 hash of a proposed block’s beneficiary and transaction list.

## Cross-chain communication (messaging)

Bridging over messages using a pair of smart contracts that use state proofs to verify data across chains.

## Decentralization

The proposing and proving design where no single party is able to control all transaction ordering or is solely responsible for proving blocks. Being sufficiently decentralized implies that the protocol should keep working in a reliable manner in adversarial situations.

## Deterministic

The block execution is deterministic after the block is appended to the proposed block chain, all block properties are immutable and the post-block state can be calculated by anyone.

## EtherVault

A contract that holds some huge amount of ETHs on L2 and is able to authorize third party bridges to receive Ether from the EtherVault to execute deposit operations.

## Fork Choice

Because blocks can be proven in parallel, the Taiko smart contract can receive a proof for a block for which it doesn’t know the correct pre-state for. The smart contract thus accepts all valid proofs using different pre-states, once the smart contract know the correct pre-state as proofs for all parent blocks come in, the correct pre-state can be selected together with its corresponding post-state to advance the verified chain.

## Golden Touch Address

An address with a revealed private key to transact all [anchor transactions](#Anchor-Transaction).

## Incentive multipliers

Time sensitive multipliers that can decrease fees and increase rewards to incentivize proposals and proofs when there are unpredictable deterrents acting against the engagement of proposers or provers.

## Intrinsic Validity Function

A function that is run on each proposed block to determine if the block contains valid data. If the block doesn’t contain valid data the block will be seen as a block with an empty transaction list.

## Invalid Block

A block that fails to pass the [Intrinsic Validity Function](#Intrinsic-Validity-Function).

## Metadata (of the block)

A tuple of 9 items comprising: block id, beneficiary (20-byte address), gas limit, timestamp, mixHash value, extraData value, Keccak-256 hash, the enclosing L1 block’s parent block number, the enclosing L1 block’s parent block hash.

## Verified block (on-chain verified)

A block is on-chain verified when its proof is submitted and its parent block is verified.

## Parallel Proof

Blocks can be proven in parallel because all intermediate states between blocks are known and [deterministic](#Deterministic).

## Proposing a block

Any willing entity can propose new Taiko blocks using the [TaikoL1 contract](#TaikoL1-Contract). Blocks are appended to a list in the order they come in (which is dictated by Ethereum L1 validators/block builders). Once the block is in the list it is [verified](#Verified-block-(on-chain verified)) and nodes can apply its state to the latest L2 state. A proposed block in Taiko is the collection of information, [Metadata](#Metadata), and a list of transactions.

## RLP decodable

A standard for data transfer between nodes in a space-efficient manner.

## Signal Service

A smart contract that can be used to exchange [cross-chain messages](<#Cross-chain-communication-(messaging)>) between L1 ↔ L2 and L2 ↔ L2 that any dapp developer can use.

## Slot-availability multipliers

Multipliers dependent on the number of unverified blocks aimed at offering the lowest fees and rewards when there are only a few unverified blocks and a surplus of available slots, and, on the opposite, as the number of available slots decrease, competition for the remaining slots increase for proposers, which leads to higher fees.

## TaikoL1 Contract

The smart contract on Ethereum L1 used to [propose](#Proposing-a-block), prove, and [verify](#Verified-block-(on-chain verified)) L2 blocks.

## TaikoL2 Contract

The smart contract on Taiko L2 that facilitates (i) [anchoring](#Anchor-Transaction) (ii) proving that a [proposed block](#Proposing-a-block) is [invalid](#Invalid_Block).

## Timestamp (of the block)

The timestamp used in the block, set to the enclosing L1 timestamp. If there are multiple L2 blocks included in one L1 block, their timestamp will be the same.

## TokenVault

A special contract in the Genesis Block with 2 to the power of 128 Ether that allows users to [bridge](#Bridge) Ether from and to Taiko.

## Valid block

Block is suggested to be valid if it satisfies the following criteria: (i) the transaction list is [RLP decodable](#RLP-decodable) into a list of transactions (ii) the number of transactions in the block is no larger than the maximum number of transactions in a Taiko block minus the [Anchor Transaction](#Anchor-Transaction) (iii) the sum of all transactions’ gasLimit is no larger than a Taiko block’s max gas limit (besides the gas limit of Anchor Transaction (iv) the transaction list length is no more than a max bytes amount per transaction list. For the full rules list check [this github page](https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/contracts/libs/LibInvalidTxList.sol#L18-L32).
