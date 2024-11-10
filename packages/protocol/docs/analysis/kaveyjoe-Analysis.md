# Taiko Advanced Analysis Report

![Taik Profile ](https://github.com/kaveyjoe/Assests/blob/main/Taiko%20Profile.png)

## 1. Introduction

An Ethereum-equivalent ZK-Rollup allows for scaling Ethereum without sacrificing security or compatibility. Advancements in Zero-Knowledge Proof cryptography and its application towards proving Ethereum Virtual Machine (EVM) execution have led to a flourishing of ZK-EVMs, now with further design decisions to choose from. Taiko aims to be a decentralized ZK-Rollup, prioritizing Ethereum-equivalence. Supporting all existing Ethereum applications, tooling, and infrastructure is the primary goal and benefit of this path. Besides the maximally compatible ZK-EVM component, which proves the correctness of EVM computation on the rollup, Taiko must implement a layer-2 blockchain architecture to support it.

Taiko aims to be a fully Ethereum-equivalent ZK-Rollup. aim to scale Ethereum in a manner that emulates Ethereum itself at a technical level, and a principles level.

**Taiko consists of three main parts**:

- the ZK-EVM circuits (for proof generation)
- the L2 rollup node (for managing the rollup chain)
- the protocol on L1 (for connecting these two parts together for rollup protocol verification).
  Blocks in the Taiko L2 blockchain consist of collections of transactions that are executed sequentially. New blocks can be appended to the chain to update its state, which can be calculated by following the protocol rules for the execution of the transactions.

### 1.1 How Does Taiko Work?

Taiko operates by utilizing a Zero Knowledge Rollup (ZK-Rollup) mechanism, specifically designed to scale the Ethereum blockchain without compromising its foundational features of security, censorship resistance, and permissionless access. Here's a breakdown of how Taiko functions:

- Zero Knowledge Proofs (ZKPs): Taiko leverages ZKPs to validate transactions confidentially, reducing data processing on Ethereum's mainnet. This efficiency cuts costs and increases transaction speed.
- Integration with Ethereum L1: Unlike rollups that use a centralized sequencer, Taiko's transactions are sequenced by Ethereum's Layer 1 validators. This method, called based sequencing, ensures that Taiko inherits Ethereum's security and decentralization properties.
- Smart Contracts and Governance: Taiko operates through smart contracts on Ethereum, detailing its protocol. Governance, including protocol updates, is managed by the Taiko DAO, ensuring community-driven decisions.
- Open Source and Compatibility: As an open-source platform, Taiko allows developers to deploy dApps seamlessly, maintaining Ethereum's ease of use and accessibility.
- Decentralized Validation: Taiko supports a decentralized model for proposers and validators, enhancing network security and integrity. Ethereum L1 validators also play a pivotal role, emphasizing decentralization.
- Community-Driven Governance: The Taiko DAO, driven by TKO token holders, oversees significant protocol decisions. This governance model promotes inclusivity and community engagement.

In essence, Taiko's approach, built on zero knowledge proofs and closely integrated with Ethereum's infrastructure, offers a scalable and secure solution while adhering to Ethereum’s foundational values. Its commitment to open-source development and community governance aligns well with the ethos of the wider Ethereum community.

### 1.2 Mechanism of Taiko

Mechanism of action of Taiko
Taiko's operating mechanism is based on the cooperation of three main subjects:

Proposer: Responsible for creating blocks from user transactions at layer 2 and proposing to Ethereum.
Prover: Create zk-Snark proofs to check the validity of transactions from layer 2, blocks proposed by the Proposer.
Node runner: Executes transactions in the network. Both the proposer and the prover must run a node to fulfill a role in the network.
Taiko's transaction confirmation process takes place as follows:
Users make transactions on layer 2 Taiko.

Proposer creates block rollup, synthesizes transactions from users at layer 2 and proposes to Ethereum.
Prover creates valid proof, proving the correctness of the block just submitted.
The block will then mark complete on the chain. The block status changes from green to yellow after being validated.

## 2. Architecture and protocol overview

![protocol overview](https://github.com/kaveyjoe/Assests/blob/main/Taiko%20Overview.png)

- block execution is deterministic once the block is appended to the proposed block list in the TaikoL1 contract. Once registered, the protocol ensures that all block properties are immutable. This makes the block execution deterministic: the post-block state can now be calculated by anyone. As such, the block is immediately verified. This also ensures that no one knows more about the latest state than anyone else, which would create an unfair advantage.
- block metadata is validated when the block is proposed. The prover has no impact on how the block is executed and what the post-block state is;
- the proof can be generated after the block is checked for validity and its parent block’s state is known
- as all proposed blocks are deterministic, they can be proven in parallel, because all intermediate states between blocks are known and unique. Once a proof is submitted for the block and its parent block, we call the block on-chain verified.

**1 . Block proposal**

- Anyone can run a Taiko sequencer. It monitors the Taiko network mempool for signed and submitted txs.
- The sequencer determines the tx order in the block.
- When a block is built, the proposing sequencer submits a proposeBlock transaction (block = transaction list + metadata) directly to Ethereum through the TaikoL1 contract. There is no consensus among L2 nodes, but there is some networking between L2 nodes (syncing, sharing transactions, etc.) However, the order of Taiko blocks on Ethereum (L1) is determined by the Ethereum node.
- All Taiko nodes connect to Ethereum nodes and subscribe to Ethereum's block events. When a Taiko block proposal is confirmed, the block is appended to a queue on L1 in a TaikoL1 contract. Taiko nodes can then download these blocks and execute valid transactions in each block. Taiko nodes track which L2 blocks are verified by subscribing to another TaikoL1 event on Ethereum.

**2. Block validation**

- The block consists of a transaction list (txList) and metadata. The txList of an L2 block will eventually (when EIP-4844 is live) be part of a blob in the L1 Consensus Layer (CL).
- txList is not directly accessible to L1 contracts. Therefore, a ZKP shall prove that the chosen txList is a slice of the given blob data.
- Block validity criteria that all blocks need to respect: K_maxBobSize, K_BlockMaxTxs, K_BlockMaxGasLimit and config.anchorTxGasLimit
- Once the block is proposed, the Taiko client checks if the block is decoded into a list of transactions
- Taiko client validates each enclosed transaction and generates a tracelog for each transaction for the prover to use as witness data. If a tx is invalid, it will be dropped.
- The first transaction in the Taiko L2 block is always an anchoring transaction, which verifies the 256 hashes of the latest blocks, the L2 chain ID and the EIP-1559 base fee

**3. Block proving**

- Anyone can run a prover.
- Proof can be prepared if all valid txs have been executed; and the parent block’s state is known. The proof proves the change in the block state.
- The block can be verified once the parent block is verified; and there is a valid ZKP proving the transition from the parent state to the current block’s state.
- only the first proof will be accepted for any given block transition (fork choice).
- The address receiving the reward is coupled with the proof, preventing it from being stolen by other provers.

**Sequencer design (sequencers are called proposers in Taiko)**

- Based sequencing/L1-sequencing: as an Ethereum-equivalent rollup, Taiko can reuse Ethereum L1 validators to drive the sequencing of Taiko blocks, inheriting L1 liveness and decentralization. This is also called "based sequencing", or a "based rollup". More info on this: https://ethresear.ch/t/based-rollups-superpowers-from-l1-sequencing/15016
- Based sequencing inherits the decentralization of L1 and naturally reuses L1 searcher-builder-proposer infrastructure. L1 searchers and block builders are incentivised to extract rollup MEV by including rollup blocks within their L1 bundles and L1 blocks. This then incentivises L1 proposers to include rollup blocks on the L1.
  Details:

- L2 sequencers (proposers) deliver L2 blocks (as bundles) directly to L1 builders (they act like the searchers in the L1 PBS setup). Builders take L2 blocks as regular bundles (similarly as they get L1 bundles from searchers)
- L2 sequencers will earn some MEV (here MEV includes (i) L2 block fees and (ii) MEV from txs reorgs etc.) - this is their motivation to be proposers. In the same manner as on L1, in the chain of searcher >> builder >> proposer, the proposer gets most MEV but searchers still get some share to make profits. It works the same way for L2 sequencers.
- As mentioned anyone can propose a block anytime (there are no time slots on Taiko like on Ethereum the 12-second slots)
- L2 sequencers build blocks and they compete for the most lucrative txs. Multiple blocks are proposed in parallel based on the same L2 mempool. These blocks are sent to the L1 builders as bundles, and it may happen that some transactions are included in multiple bundles proposed by L2 sequencers.
- When the L1 builders choose which L2 block to accept – they run simulations to find the most profitable bundle. If some txs in the L2 block were already taken by another builder and proposed by the Ethereum validator (this means that block already reached finality), then they are not counted in the current bundle anymore but get excluded from it. However the other L2 blocks proposed should still be valuable enough to be selected and included by an L1 builder within negligible time.
- Theoretically it could happen that most of the txs in a proposed L2 block were already included by L1 builders through other L2 blocks, and thus it is not anymore profitable, but this is expected to be a very rare, marginal case.

**Fee structure**

L2 tx fee = L2 EIP-1559* base fee + L1 tx fee + prover fee + proposer fee*
![Fee structure](https://github.com/kaveyjoe/Assests/blob/main/L2TXFEE.png)

L2 EIP-1559 fee = L2 EIP-1559 tip (goes to the proposer) + L2 EIP-1559 base fee (goes to the Taiko DAO).

Once a proposer has collected enough transactions, most probably including and ordering them with the intent to generate a (maxim) profit, they create a block.

- Profit means that for the proposer, the sum of transaction fees (L2 tx fees) from the block is larger than L1 tx fee + prover fee + EIP-1559 base fee.

**Prover economics and prover mechanisms**

1 . First prover wins and gets rewarded only
One proof should be confirmed for one “window.” A “window” is a period of time in which multiple blocks are proposed. Any prover can submit a proof for any amount of blocks at any time.

- There is a target reward, x, that is paid to the prover if they confirm the proof exactly at the target window, t = n. If proven earlier, the reward is lower, if later, reward is higher.
- A target reward is defined based on the historical reward values and is adjusted after each window depending on the proof confirmation time

![Prover economics](https://github.com/kaveyjoe/Assests/blob/main/Prover%20Economics.png)

- Effects:
  - To be efficient within this design, a prover should be able to find an optimal trade-off point between (i) confirming the proof as late as possible (to get the higher reward) and (ii) confirming the proof earlier than all other provers.
  - to confirm the proof as early as possible is not an optimal strategy for the prover; confirming all proofs as fast as possible decreases the rewards making it unreasonable for provers (but beneficial for users).

2 . Staking-based prover design

one prover is pseudo-randomly chosen for each block from a pool which includes the top 32 provers, and assigns it to a proposed block. This designated prover must then submit a valid proof within a set time window for block verification. If the prover fails to submit the proof on time, the prover’s stake will be slashed. Prover exit is possible anytime, with a withdrawal time of one week.

- Prover weight W is calculated based on the stake A and expected reward per gas R. This weight reflects probability to be chosen.

![Staking-based prover design](https://github.com/kaveyjoe/Assests/blob/main/Staking%20Based%20Prover%20Design.png)

- The current fee per gas F is calculated based on historical values and is supplied by the core protocol.
- Three other parameters unique for each prover; claimed while joining the pool:

  1. Amount of Taiko’s TTKO tokens to stake A;
  2. The expected reward per gas, R, is limited to (75% – 125%) _ F range. If the R claimed by the prover is below or above this range, R will be automatically fixed at 75% _ F or 125% \* F, respectively;
  3. The compute capacity specified by the prover

  - If selected, the capacity reduces by one, and
  - when the capacity hits zero, the prover will no longer be selected.
  - When a block is proven (by them or any other prover), the capacity increases by one, up to the max capacity specified by the prover during staking.

- If fails to prove the block within a specific time window, the prover gets slashed;
- If the prover failed to prove the block or there is no available prover at the moment to be assigned, any prover can jump in and prove the block. Such a block is considered an “open block”;
- If the block was proven, the prover reward is R \* gasUsed.
- the oracle prover cannot prove/verify blocks directly and thus cannot change the chain state. Therefore, a regular prover will need to generate a ZKP to prove the overridden fork choice.

3. PBS-inspired proposing and proving design

There are two ways to assign a block to a prover:

- If you run a Taiko-node as a proposer or prover, your proposer will select your own local prover by default (left side of the below screenshot), and this prover has to provide a bond of 2.5 TKO as assurance for generating the proof
- proposers can also choose any prover from the open prover market. Proposers send a hash of the L2 block’s transaction list to an open market of provers, who offer a price that they’re willing to provide a bond of 2.5 TKO for (right side of the below screenshot); proposers pay their provers off-chain.

![PBS-inspired proposing](https://github.com/kaveyjoe/Assests/blob/main/PBS-inspired%20proposing.png)

When an agreement is reached concerning the proving fee for a specific block, the chosen proof service provider is then granting a cryptographic signature to the proposer which serves as a binding commitment to deliver the proof within the agreed-upon timeframe.

Provers within this off-chain proof market come in two primary forms: Externally Owned Accounts (EOA) and contracts, often referred to as Prover pools. The reward depends on the proof service provider and the agreement. For EOAs and Prover pools that implement the IERC1271 interface, the reward is disbursed in ETH. However, in cases where providers implement the IProver interface, the prover fee can be ETH, any other ERC20 tokens, or even NFTs, based on the negotiated terms.

![Bonded prover](https://github.com/kaveyjoe/Assests/blob/main/Bonded%20Prover.png)

In the event of a failure to deliver the proof within the given time, 1/4 of the bond provided, is directed to the actual prover, while the remaining 3/4 are permanently burnt. Conversely, successful and timely proof delivery ensures the return of these tokens to the Prover.

### How taiko L1 Works??

Taiko is a Layer 2 optimistic rollup solution for Ethereum that aims to provide fast and low-cost transactions while maintaining the security guarantees of the Ethereum network. The L1 part of Taiko plays a crucial role in managing the communication between Layer 2 and the Ethereum mainnet (Layer 1) and ensuring the validity of the L2 state.

**Here is an overview of how Taiko L1 works**:

- **Sequencer Selection**: The L1 Taiko contract selects a sequencer responsible for processing and ordering L2 transactions. The sequencer is chosen based on the highest total ETH staked, and the contract ensures that only one sequencer is active at any given time.
- **Transaction Relay**: When users submit transactions to Layer 2, they are first sent to the Taiko L1 contract. The L1 contract checks whether the sequencer has been properly initialized and then forwards the transaction to the sequencer.
- **L2 Block Creation**: The sequencer collects and orders transactions into L2 blocks, performs any necessary state updates, and then generates a merkle root.
- **Block Submission**: The sequencer then submits the L2 block to the L1 contract, along with the new merkle root and necessary metadata. The L1 contract checks whether the submitted block is valid and updates its records accordingly.
- **Dispute Resolution**: In case of a dispute about the validity of an L2 block, anyone can call the dispute function in the L1 contract. This initiates a challenge period, during which parties can submit evidence to either support or dispute the block's validity. If a dispute is successfully resolved, the L1 contract updates the state accordingly.

Overall, the L1 component of Taiko plays a crucial role in managing the L2 sequencer, facilitating communication and state transitions between L1 and L2, and ensuring the overall security of the system.

### How taiko L2 Works??

Taiko's Layer 2 (L2) is an optimistic rollup solution for Ethereum that aims to provide fast and low-cost transactions while maintaining the security guarantees of the Ethereum network. In a nutshell, the L2 solution bundles transactions into batches and processes them off-chain, only posting the bundles and any necessary proofs on-chain to maintain security and maintain a consistent state.

**Here's an overview of how Taiko's L2 works**:

- **Transaction Submission**: Users submit transactions to the sequencer, which collects and orders transactions into L2 blocks.
- **State Transition**: The sequencer performs any necessary state updates in accordance with the L2 transactions it receives and the current L2 state. The sequencer generates a merkle root to represent the updated L2 state and submits the block along with the merkle root and other metadata to the L1 contract.
- **State Validation**: The L1 contract validates the submitted L2 block by checking its merkle root against the previous L2 state and evaluating any necessary fraud proofs. If the L1 contract deems the L2 block valid, it updates its records to reflect the new L2 state.
- **Dispute Resolution**: In case of a dispute about the validity of an L2 block, anyone can submit a challenge within a certain time period, during which evidence can be submitted to either support or dispute the block's validity. If a dispute is successfully resolved, the L1 contract updates the state accordingly.
- **Withdrawals**: Users can withdraw their assets from the L2 contract to the L1 contract by submitting a withdraw request to the L2 contract and waiting for a predetermined challenge period to elapse. Once the challenge period has passed, the funds are transferred to the user's L1 address.

Overall, Taiko L2 offers a fast and cost-effective way to process transactions off-chain and only post the necessary information on-chain to maintain security and consistency. The L2 contract submits blocks to the L1 contract, and the L1 contract is responsible for validating the L2 blocks and maintaining the overall system security.

## 3. Scope Contracts

1 . contracts/common/

- [common/IAddressManager.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/IAddressManager.sol)
- [common/AddressManager.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/AddressManager.sol)
- [common/IAddressResolver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/IAddressResolver.sol)
- [common/AddressResolver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/AddressResolver.sol)
- [common/EssentialContract.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/EssentialContract.sol)

2 . contracts/libs/

- [libs/Lib4844.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/Lib4844.sol)
- [libs/LibAddress.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/LibAddress.sol)
- [libs/LibMath.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/LibMath.sol)
- [libs/LibTrieProof.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/LibTrieProof.sol)

3. contracts/L1/

- [L1/gov/TaikoGovernor.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/gov/TaikoGovernor.sol)
- [L1/gov/TaikoTimelockController.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/gov/TaikoTimelockController.sol)
- [L1/hooks/IHook.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/hooks/IHook.sol)
- [L1/hooks/AssignmentHook.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/hooks/AssignmentHook.sol)
- [L1/ITaikoL1.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/ITaikoL1.sol)
- [L1/libs/LibDepositing.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibDepositing.sol)
- [L1/libs/LibProposing.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProposing.sol)
- [L1/libs/LibProving.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProving.sol)
- [L1/libs/LibUtils.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibUtils.sol)
- [L1/libs/LibVerifying.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibVerifying.sol)
- [GuardianProver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/provers/GuardianProver.sol)
- [L1/provers/Guardians.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/provers/Guardians.sol)
- [L1/TaikoData.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoData.sol)
- [L1/TaikoErrors.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoErrors.sol)
- [L1/TaikoEvents.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoEvents.sol)
- [L1/TaikoL1.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoL1.sol)
- [L1/TaikoToken.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoToken.sol)
- [L1/tiers/ITierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/ITierProvider.sol)
- [L1/tiers/DevnetTierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/DevnetTierProvider.sol)
- [L1/tiers/MainnetTierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol)
- [L1/tiers/TestnetTierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/TestnetTierProvider.sol)

4. contracts/L2/

- [L2/CrossChainOwned.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/CrossChainOwned.sol)
- [L2/Lib1559Math.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/Lib1559Math.sol)
- [L2/TaikoL2.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/TaikoL2.sol)
- [L2/TaikoL2EIP1559Configurable.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol)

5. contracts/signal/

- [signal/ISignalService.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/signal/ISignalService.sol)
- [signal/LibSignals.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/signal/LibSignals.sol)
- [signal/SignalService.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/signal/SignalService.sol)

6. contracts/bridge/

- [bridge/IBridge.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/IBridge.sol)
- [bridge/Bridge.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol)

7. contracts/tokenvault/

- [tokenvault/adapters/USDCAdapter.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol)
- [tokenvault/BridgedERC20.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC20.sol)
- [tokenvault/BridgedERC20Base.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol)
- [tokenvault/BridgedERC721.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC721.sol)
- [tokenvault/BridgedERC1155.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC1155.sol)
- [tokenvault/BaseNFTVault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BaseNFTVault.sol)
- [tokenvault/BaseVault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BaseVault.sol)
- [tokenvault/ERC1155Vault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/ERC1155Vault.sol)
- [tokenvault/ERC20Vault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/ERC20Vault.sol)
- [tokenvault/ERC721Vault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/ERC721Vault.sol)
- [tokenvault/IBridgedERC20.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/IBridgedERC20.sol)
- [tokenvault/LibBridgedToken.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/LibBridgedToken.sol)

8. contracts/thirdparty/

- [thirdparty/nomad-xyz/ExcessivelySafeCall.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/nomad-xyz/ExcessivelySafeCall.sol)
- [thirdparty/optimism/Bytes.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/Bytes.sol)
- [thirdparty/optimism/rlp/RLPReader.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol)
- [thirdparty/optimism/rlp/RLPWriter.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol)
- [thirdparty/optimism/trie/MerkleTrie.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol)
- [thirdparty/optimism/trie/SecureMerkleTrie.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/trie/SecureMerkleTrie.sol)
- [thirdparty/solmate/LibFixedPointMath.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/solmate/LibFixedPointMath.sol)

9. contracts/verifiers/

- [verifiers/IVerifier.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/verifiers/IVerifier.sol)
- [verifiers/GuardianVerifier.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/verifiers/GuardianVerifier.sol)
- [verifiers/SgxVerifier.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/verifiers/SgxVerifier.sol)

10. contracts/team/

- [team/airdrop/ERC20Airdrop.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol)
- [team/airdrop/ERC20Airdrop2.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol)
- [team/airdrop/ERC721Airdrop.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol)
- [team/airdrop/MerkleClaimable.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol)
- [team/TimelockTokenPool.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/TimelockTokenPool.sol)

11. contracts/automata-attestation/

- [automata-attestation/AutomataDcapV3Attestation.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol)
- [automata-attestation/interfaces/IAttestation.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/interfaces/IAttestation.sol)
- [automata-attestation/interfaces/ISigVerifyLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/interfaces/ISigVerifyLib.sol)
- [automata-attestation/lib/EnclaveIdStruct.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/EnclaveIdStruct.sol)
- [automata-attestation/lib/interfaces/IPEMCertChainLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/interfaces/IPEMCertChainLib.sol)
- [automata-attestation/lib/PEMCertChainLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol)
- [automata-attestation/lib/QuoteV3Auth/V3Parser.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol)
- [automata-attestation/lib/QuoteV3Auth/V3Struct.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol)
- [automata-attestation/lib/TCBInfoStruct.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/TCBInfoStruct.sol)
- [automata-attestation/utils/Asn1Decode.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol)
- [automata-attestation/utils/BytesUtils.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol)
- [automata-attestation/utils/RsaVerify.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol)
- [automata-attestation/utils/SHA1.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/SHA1.sol)
- [automata-attestation/utils/SigVerifyLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol)
- [automata-attestation/utils/X509DateUtils.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol)

## 4. Codebase Analysis

### 4.1 Approach Taken reviewing the codebase

First, by examining the scope of the code, I determined my code review and analysis strategy.
https://code4rena.com/audits/2024-03-taiko#top
My approach to ensure a thorough and comprehensive audit would encompass several steps, combining theoretical understanding, practical testing, and security assessments. Here’s how I would proceed:

- \***\*Understanding the Taiko Protocol**: I familiarized myself with the Taiko protocol and its components, focusing on the Layer 2 (L2) aspects. L2 solutions provide enhanced scalability and privacy features to the Ethereum blockchain. The Taiko protocol combines several L2 techniques, such as optimistic and zero-knowledge rollups, and validity proof systems.

- **Exploring the Codebase**: I explored the Taiko smart contract codebase available on GitHub to understand the different components and contract interactions. The codebase mainly consists of the following categories:

  - Core: Core contracts related to the L2 infrastructure, such as TaikoL1, TaikoL2, L1ERC20Bridge, and others.
  - Verifiers: Contracts responsible for verifying the validity proofs, such as GuardianVerifier and SgxVerifier.
  - Tokens: Token-related contracts, including ERC-20 and ERC-721 bridges.
  - Third-party libraries/contracts: Libraries and third-party contracts from OpenZeppelin, Solmate, and others.
  - Airdrops, timelocks, and other team-related contracts: Contracts dealing with airdrops, token vesting, and other team-related applications.

- **Dependency Analysis**: I examined the external dependencies used in the contracts, such as OpenZeppelin and Solmate, ensuring they were up-to-date and compatible with the codebase.

- **Code Quality Review**: I checked the code for proper formatting, naming conventions, and overall readability. I also ensured that the code followed best practices for secure development, minimizing complexity where possible, and making contract interactions modular and clear.

- **Security Analysis**: I manually inspected the contracts and used automated tools to identify potential security issues, including:

  - Reentrancy
  - Integer overflows/underflows
  - Front-running opportunities
  - Race conditions
  - Denial-of-Service (DoS) attacks
  - Privilege escalation
  - Visibility issues

- **Testing**: I reviewed the test coverage and ensured that the tests were comprehensive, testing various scenarios, boundary cases, and potential attack vectors.

- **Audit Findings and Recommendations**: I reviewed audit reports related to the Taiko protocol to ensure that previously identified issues were addressed.

### 4.2 Contracts Overview

1 . [common/IAddressManager.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/IAddressManager.sol)
This is an interface defining common functions for managing addresses, such as adding or removing an address from a whitelist or blacklist.

2. [common/AddressManager.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/AddressManager.sol)
   This is an implementation of the IAddressManager interface. It manages a set of addresses and maintains separate whitelists and blacklists. The contract has internal functions for adding/removing addresses from both lists, as well as functions for getting the total number of addresses and checking membership on the lists.

3. [common/IAddressResolver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/IAddressResolver.sol)
   This is an interface for a contract that resolves addresses, essentially mapping deployment addresses (i.e., contract or token addresses) to other information that the protocol requires.

4. [common/AddressResolver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/AddressResolver.sol)
   This is an implementation of the IAddressResolver interface. It can resolve the addresses based on the name of the required contract. The contract maintains a mapping between the contract name and the actual deployment address, and exposes functions for adding, updating, and removing contract mappings, as well as resolving the contract address.

5. [common/EssentialContract.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/common/EssentialContract.sol)
   This is a base contract for other protocol contracts to inherit. It ensures that the implementing contract is initialized properly and provides access to essential protocol functionality. The contract defines an interface for a two-step setup process, which includes initialization (performed once at deployment) and activation (performed after deployment). Additionally, the contract includes functions for checking initialization and activation status, as well as a mechanism for upgrading the contract.

6. [libs/Lib4844.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/Lib4844.sol)
   This library provides helper functions for interacting with the 4844 network: an optimistic rollup network built on top of the Ethereum blockchain. The library includes methods for calculating the storage root, adding logger, and constructing and validating transaction proofs. These utility functions simplify 4844-related logic in the main Taiko protocol contracts, making it easier to perform tasks that involve the 4844 network, such as fetching and validating transaction proofs from the rollup network.

7. [libs/LibAddress.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/LibAddress.sol)
   This library provides functions for handling Ethereum addresses. It includes several helper functions to deal with ENS names, checking if an address is a contract, and performing common address operations like sending and approving tokens. This library helps keep address-related functions reusable, simplified, and consistent across the entire protocol.

8. [libs/LibMath.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/LibMath.sol)
   This library provides various mathematical operations, particularly related to fixed-point numbers and division. It includes functions for safe division, fractional multiplication, and other useful arithmetic operations that are required throughout the Taiko protocol.

9. [libs/LibTrieProof.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/libs/LibTrieProof.sol)
   This library is specifically designed for Merkle Trie proof functions, which are essential when working with Ethereum's state trie. This library provides functions to create and validate merkle paths as well as perform range proofs. The functions can be used to efficiently check the state root stored in 4844 blocks and entries in associated Merkle Tries.

10. [L1/gov/TaikoGovernor.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/gov/TaikoGovernor.sol)
    This contract is the governance contract for the Taiko protocol on L1. It allows for the creation and management of proposals, as well as the ability to queue and execute actions. It inherits from TaikoTimelockController.sol, which provides a timelock mechanism for actions being executed.

11. [L1/gov/TaikoTimelockController.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/gov/TaikoTimelockController.sol)
    This contract is responsible for implementing a timelock mechanism for the Taiko protocol on L1. It allows for actions to be queued and then executed after a specified delay. It also provides functionality for cancelling queued actions.

12. [L1/hooks/IHook.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/hooks/IHook.sol)
    This contract is an interface for hooks, which are contracts that can be called before or after certain actions in the Taiko protocol.

13. [L1/hooks/AssignmentHook.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/hooks/AssignmentHook.sol)
    This contract is an implementation of the IHook interface and is used to handle the assignment of roles and permissions in the Taiko protocol.

14. [L1/ITaikoL1.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/ITaikoL1.sol)
    This contract is an interface for the Taiko L1 contract, which is the main contract for the Taiko protocol on L1. It includes functionality for creating and managing proposals, as well as handling deposits and withdrawals.

15. [L1/libs/LibDepositing.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibDepositing.sol)
    This contract contains library functions for handling deposits in the Taiko protocol. It includes functions for calculating the correct deposit amount, as well as handling the actual deposit of funds.

16. [L1/libs/LibProposing.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProposing.sol)
    This contract contains library functions for handling proposals in the Taiko protocol. It includes functions for calculating the number of votes needed to pass a proposal, as well as functions for handling the execution of proposals.

17. [L1/libs/LibProving.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibProving.sol)
    This contract contains library functions for proof generation and verification in the Taiko protocol.

18. [L1/libs/LibUtils.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibUtils.sol)
    This contract contains library functions for various utility functions used throughout the Taiko protocol.

19. [L1/libs/LibVerifying.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/libs/LibVerifying.sol)
    This contract contains library functions for verifying signatures and messages in the Taiko protocol.

20. [GuardianProver.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/provers/GuardianProver.sol)
    This contract is responsible for generating proofs required for certain actions in the Taiko protocol. It uses the Guardians.sol contract to generate these proofs.

21. [L1/provers/Guardians.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/provers/Guardians.sol)
    This contract manages a list of guardians who are responsible for generating proofs required for certain actions in the Taiko protocol.

22. [L1/TaikoData.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoData.sol)
    This contract contains various data structures used throughout the Taiko protocol.

23. [L1/TaikoErrors.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoErrors.sol)
    This contract contains custom errors used throughout the Taiko protocol.

24. [L1/TaikoEvents.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoEvents.sol)
    This contract contains event definitions used throughout the Taiko protocol.

25. [L1/TaikoL1.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoL1.sol)
    This contract is the main contract for the Taiko protocol on L1 and is responsible for managing proposals, handling deposits and withdrawals, and interfacing with the TaikoTimelockController.sol contract.

26. [L1/TaikoToken.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/TaikoToken.sol)
    This contract is an ERC20 token used for voting in the Taiko protocol.

27. [L1/tiers/ITierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/ITierProvider.sol)
    This contract is an interface for tier providers, which are contracts that provide information about the current tier of a given address.

28. [L1/tiers/DevnetTierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/DevnetTierProvider.sol)
    This contract is an implementation of the ITierProvider interface for the devnet environment.

29. [L1/tiers/MainnetTierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/MainnetTierProvider.sol)
    This contract is an implementation of the ITierProvider interface for the mainnet environment.

30. [L1/tiers/TestnetTierProvider.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L1/tiers/TestnetTierProvider.sol)
    This contract is an implementation of the ITierProvider interface for the testnet environment.

31. [L2/CrossChainOwned.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/CrossChainOwned.sol)
    This contract is an implementation of the Owned pattern, where the contract owner can transfer ownership to another address. It also includes a function to force a contract upgrade by specifying the address of the new implementation.

32. [L2/Lib1559Math.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/Lib1559Math.sol)
    This library contains mathematical functions related to Ethereum's EIP-1559 upgrade. It includes functions to calculate the base fee, maximum base fee per gas, and gas tip cap.

33. [L2/TaikoL2.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/TaikoL2.sol)
    This contract is the main L2 contract responsible for handling transactions, storing the state root, and interacting with the L1 contract via the bridge. It includes functionalities for transaction submission, state transition, and state proof verification.

34. [L2/TaikoL2EIP1559Configurable.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/L2/TaikoL2EIP1559Configurable.sol)
    This contract is similar to TaikoL2 but is EIP-1559 compatible. It includes functions to set the base fee, gas tip cap, and other related parameters.

35. [signal/ISignalService.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/signal/ISignalService.sol)
    This is an interface contract for the SignalService. It provides function declarations for emitting and canceling signals.

36. [signal/LibSignals.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/signal/LibSignals.sol)
    This library contract contains functions for creating and managing signals. It includes functions for creating signals, canceling signals, and checking the status of signals.

37. [signal/SignalService.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/signal/SignalService.sol)
    This contract is the main SignalService implementation. It enables users to create and cancel signals, while also tracking the status and expiry of signals.

38. [bridge/IBridge.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/IBridge.sol)
    This is an interface contract for the Bridge. It contains function declarations for L1-L2 transaction handling and state syncing.

39. [bridge/Bridge.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/bridge/Bridge.sol)
    This contract is the main Bridge implementation. It facilitates the transfer of messages between L1 and L2, ensuring the atomicity and consistency of the state between the two layers. Additionally, it includes functionalities for handling cross-layer transactions, applying penalties for invalid transactions, and syncing L1 and L2 states.

40. [tokenvault/adapters/USDCAdapter.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/adapters/USDCAdapter.sol)
    This contract is an adapter for the USDC token. It inherits from IBridgedERC20, which is an interface for bridged ERC20 tokens. The contract includes two functions: name and symbol, which return the name and symbol of the USDC token.

41. [tokenvault/BridgedERC20.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC20.sol):
    This contract is an implementation of the IBridgedERC20 interface. It is a bridged version of the ERC20 standard that allows for transferring tokens between different blockchain networks. The contract includes functionality for transferring tokens, approving other contracts to transfer tokens, and getting the allowance that an owner has granted to a spender.

42. [tokenvault/BridgedERC20Base.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC20Base.sol)
    This contract is the base contract for BridgedERC20. It includes the basic functionality for bridged tokens, such as transferring tokens, approving other contracts to transfer tokens, and getting allowances.

43. [tokenvault/BridgedERC721.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC721.sol)
    This contract is an implementation of the ERC721 standard for non-fungible tokens (NFTs) that allows for transferring NFTs between different blockchain networks. The contract includes functionality for transferring NFTs, approving other contracts to transfer NFTs, and getting the approval status for a given NFT.

44. [tokenvault/BridgedERC1155.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BridgedERC1155.sol)
    This contract is an implementation of the ERC1155 standard for multi-token contracts that allows for transferring multiple tokens between different blockchain networks. The contract includes functionality for transferring tokens, approving other contracts to transfer tokens, and getting allowances for multiple tokens.

45. [tokenvault/BaseNFTVault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BaseNFTVault.sol)
    This contract is a base contract for NFT vaults. It includes basic functionality for NFT vaults, such as storing NFTs and transferring them out of the vault.

46. [tokenvault/BaseVault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/BaseVault.sol)
    This contract is a base contract for token vaults. It includes basic functionality for token vaults, such as storing tokens and transferring them out of the vault.

47. [tokenvault/ERC1155Vault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/ERC1155Vault.sol)
    This contract is a vault for ERC1155 tokens that allows for transferring multiple tokens between different blockchain networks. It inherits from BridgedERC1155, which implements the ERC1155 standard.

48. [tokenvault/ERC20Vault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/ERC20Vault.sol)
    This contract is a vault for ERC20 tokens that allows for transferring tokens between different blockchain networks. It inherits from BridgedERC20Base.

49. [tokenvault/ERC721Vault.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/ERC721Vault.sol)
    This contract is a vault for ERC721 tokens that allows for transferring NFTs between different blockchain networks. It inherits from BridgedERC721.

50. [tokenvault/IBridgedERC20.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/IBridgedERC20.sol)
    This contract is an interface for bridged ERC20 tokens. It includes the basic functionality for transferring tokens, approving other contracts to transfer tokens, and getting allowances.

51. [tokenvault/LibBridgedToken.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/tokenvault/LibBridgedToken.sol)
    This contract is a library for BridgedERC20, BridgedERC721, and BridgedERC1155. It includes common functionality for bridged tokens, such as managing metadata.

52. [thirdparty/nomad-xyz/ExcessivelySafeCall.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/nomad-xyz/ExcessivelySafeCall.sol)
    This contract is a simple library that provides a safe way to call external contracts without worrying about reentrancy attacks. It uses a pattern called the "Reentrancy Guard" to ensure that a contract can only be called once within a given execution context. This is useful for situations where a contract needs to make an external call that could potentially modify its state.

53. [thirdparty/optimism/Bytes.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/Bytes.sol)
    This contract is a simple library that provides a number of utility functions for working with byte arrays in Solidity. It includes functions for checking the length of a byte array, slicing a byte array, and concatenating multiple byte arrays together.

54. [thirdparty/optimism/rlp/RLPReader.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/rlp/RLPReader.sol)
    This contract is a library that provides functions for parsing Recursive Length Prefix (RLP) encoded data. RLP is a binary data format used in Ethereum to encode structured data. This library provides functions for decoding RLP-encoded data into Solidity data types, such as integers, byte arrays, and arrays of other data types.

55. [thirdparty/optimism/rlp/RLPWriter.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/rlp/RLPWriter.sol)
    This contract is a library that provides functions for encoding data into Recursive Length Prefix (RLP) format. It can be used to encode Solidity data types, such as integers, byte arrays, and arrays of other data types, into RLP format.

56. [thirdparty/optimism/trie/MerkleTrie.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/trie/MerkleTrie.sol)
    This contract is a library that provides an implementation of a Merkle tree. A Merkle tree is a binary tree data structure that allows for efficient and secure verification of large datasets. This library provides functions for creating a Merkle tree, adding data to the tree, and verifying the integrity of the tree.

57. [thirdparty/optimism/trie/SecureMerkleTrie.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/optimism/trie/SecureMerkleTrie.sol)
    This contract is a library that provides a secure implementation of a Merkle tree. It is similar to the MerkleTrie library, but includes additional security measures to prevent against attacks such as hash collisions.

58. [thirdparty/solmate/LibFixedPointMath.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/thirdparty/solmate/LibFixedPointMath.sol)
    This contract is a library that provides functions for performing arithmetic operations with fixed-point numbers. Fixed-point numbers are a way of representing decimal values in a binary format, and are commonly used in blockchain applications for representing values such as token balances. This library provides functions for adding, subtracting, multiplying, and dividing fixed-point numbers.

59. [verifiers/IVerifier.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/verifiers/IVerifier.sol)
    This contract is an interface for verifiers. It defines the functions that a verifier contract must implement.

60. [verifiers/GuardianVerifier.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/verifiers/GuardianVerifier.sol)
    This contract is a verifier that uses a "guardian" contract to verify the correctness of transactions. The guardian contract is responsible for checking the state of the Taiko protocol and ensuring that transactions are valid.

61. [verifiers/SgxVerifier.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/verifiers/SgxVerifier.sol)
    This contract is a verifier that uses Intel Software Guard Extensions (SGX) to verify the correctness of transactions. SGX is a hardware-based technology that allows for secure execution of code in an enclave environment. This verifier uses SGX to ensure that transactions are not tampered with.

62. [team/airdrop/ERC20Airdrop.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/ERC20Airdrop.sol)
    This contract is used for distributing a fixed number of tokens to a list of recipients. It is an implementation of the ERC20 token standard.

63. [team/airdrop/ERC20Airdrop2.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/ERC20Airdrop2.sol)
    This contract is similar to ERC20Airdrop, but allows for the possibility of distributing additional tokens in the future.

64. [team/airdrop/ERC721Airdrop.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/ERC721Airdrop.sol)
    This contract is used for distributing a fixed number of non-fungible tokens to a list of recipients. It is an implementation of the ERC721 token standard.

65. [team/airdrop/MerkleClaimable.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/airdrop/MerkleClaimable.sol)
    This contract is a library that provides functions for generating and verifying Merkle proofs. It can be used to allow users to claim tokens or other assets by proving that they are entitled to them.

66. [team/TimelockTokenPool.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/team/TimelockTokenPool.sol)
    This contract is used for holding a pool of tokens that are subject to a time lock. This can be useful for distributing tokens to a team or community over a period of time.

67. automata-attestation/AutomataDcapV3Attestation.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/AutomataDcapV3Attestation.sol)
    This contract is the main contract in the automata-attestation directory. It is responsible for verifying attestation Quote V3 from Intel SGX enclaves. The contract uses several libraries and interfaces to perform the verification, including IAttestation, ISigVerifyLib, IPEMCertChainLib, and QuoteV3Auth.

68. [automata-attestation/interfaces/IAttestation.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/interfaces/IAttestation.sol)
    This is an interface contract that defines the required functions for attestation. It includes functions for getting the quote from an enclave and verifying the quote.

69. [automata-attestation/interfaces/ISigVerifyLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/interfaces/ISigVerifyLib.sol)
    This is an interface contract that defines the required functions for signature verification. It includes functions for verifying ECDSA and RSA signatures.

70. [automata-attestation/lib/EnclaveIdStruct.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/EnclaveIdStruct.sol)
    This contract defines a struct for storing enclave ID information.

71. [automata-attestation/lib/interfaces/IPEMCertChainLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/interfaces/IPEMCertChainLib.sol)
    This is an interface contract that defines the required functions for working with a chain of Platform Error Management Certificates (PEMCertChain). It includes functions for getting the root certificate and verifying the chain.

72. [automata-attestation/lib/PEMCertChainLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/PEMCertChainLib.sol)
    This contract implements the IPEMCertChainLib interface and provides functionality for working with a chain of PEMCertificates.

73. [automata-attestation/lib/QuoteV3Auth/V3Parser.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Parser.sol)
    This contract is a library contract that provides functionality for parsing Quote V3 from Intel SGX enclaves.

74. [automata-attestation/lib/QuoteV3Auth/V3Struct.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/QuoteV3Auth/V3Struct.sol)
    This contract defines a struct for storing Quote V3 information.

75. [automata-attestation/lib/TCBInfoStruct.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/lib/TCBInfoStruct.sol)
    This contract defines a struct for storing Trusted Computing Base (TCB) information.

76. [automata-attestation/utils/Asn1Decode.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/Asn1Decode.sol)
    This contract is a library contract that provides functionality for decoding ASN.1 encoded data.

77. [automata-attestation/utils/BytesUtils.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/BytesUtils.sol)
    This contract is a library contract that provides functionality for working with bytes, including concatenating, slicing, and checking lengths.

78. [automata-attestation/utils/RsaVerify.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/RsaVerify.sol)
    This contract is a library contract that provides functionality for verifying RSA signatures.

79. [automata-attestation/utils/SHA1.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/SHA1.sol)This contract is a library contract that provides SHA-1 hashing functionality.

80. [automata-attestation/utils/SigVerifyLib.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/SigVerifyLib.sol)
    This contract is a library contract that provides signature verification functionality, including ECDSA and RSA.

81. [automata-attestation/utils/X509DateUtils.sol](https://github.com/code-423n4/2024-03-taiko/blob/main/packages/protocol/contracts/automata-attestation/utils/X509DateUtils.sol)
    This contract is a library contract that provides functionality for working with X.509 dates, including parsing and comparing.

### 4.3 Codebase Quality Analysis

| Aspect                  | Description                                                                                                                                                                                                                                                            |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Architecture and Design |                                                                                                                                                                                                                                                                        |
| Upgradeability          | The contracts/L1/gov/TaikoGovernor.sol and contracts/L1/gov/TaikoTimelockController.sol contracts have a version variable that allows for upgrades. The rest of the contracts do not have upgradeability features.                                                     |
| Modularity              | The codebase is divided into several directories, each containing related contracts. This modular structure helps to organize the code and makes it easier to navigate.                                                                                                |
| Testability             | The contracts/L1/TaikoData.sol contract provides a getTestData() function that returns test data for use in testing. This is a good practice for making code more testable.                                                                                            |
| Security                |                                                                                                                                                                                                                                                                        |
| Authorization           | The contracts/L1/gov/TaikoGovernor.sol contract uses role-based access control to restrict certain functions to specific addresses. This is a good practice for preventing unauthorized access.                                                                        |
| Input Validation        | The contracts/L1/libs/LibMath.sol contract provides functions for validating input values, such as isUint and isAddr. These functions should be used throughout the codebase to ensure that inputs are valid before being processed.                                   |
| Auditability            |                                                                                                                                                                                                                                                                        |
| Comments                | Comments are used throughout the codebase to explain the code and provide additional information. This is a good practice for making code more readable and understandable.                                                                                            |
| Naming Conventions      | Consistent naming conventions are used throughout the codebase. This helps to quickly identify and understand the code.                                                                                                                                                |
| Code Complexity         | The codebase has a mix of simple and complex functions. Simple functions are generally easier to understand and audit, while complex functions can be more difficult to follow.                                                                                        |
| Error Handling          | The contracts/L1/TaikoErrors.sol contract provides a standardized way of handling errors throughout the codebase. This is a good practice for ensuring that errors are handled consistently and that the code remains readable.                                        |
| Documentation           |                                                                                                                                                                                                                                                                        |
| Codebase Overview       | A high-level overview of the codebase would be helpful for quickly understanding the structure and organization of the code. This could include a diagram or chart showing the relationships between the different contracts and directories.                          |
| Contract Documentation  | Each contract should have detailed documentation that explains its purpose, functionality, and any relevant variables or functions. This documentation should be easily accessible from the code itself, either through comments or separate documentation files.      |
| Function Documentation  | Each function should have detailed documentation that explains its purpose, functionality, and any relevant input and output parameters. This documentation should be easily accessible from the code itself, either through comments or separate documentation files. |
| Global Variables        | Global variables that are used throughout the codebase should be documented in a central location. This helps to ensure that they are used consistently and that their purpose is clear.                                                                               |
| Security Best Practices | The codebase should follow well-established security best practices, such as using secure coding practices and performing regular security audits. This helps to ensure that the code remains secure and up-to-date with the latest threats and vulnerabilities.       |

## 4.5 Contracts Workflow

| Contracts                                                                                                                                                     | Category                            | Core Functionality                                    | Technical Details                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| IAddressResolver, AddressResolver                                                                                                                             | Common                              | Address resolution for L1 and L2 contracts            | Uses a trie data structure to efficiently store and retrieve addresses                           |
| IHook, AssignmentHook                                                                                                                                         | L1 Hooks                            | Allows L1 contracts to be notified of specific events | Provides a flexible system for triggering callbacks from L1 contracts                            |
| ITaikoL1                                                                                                                                                      | L1 Contracts                        | Main L1 contract that orchestrates L1 operations      | Contains logic for L1 deposits, proposals, proving, and verifying                                |
| LibDepositing, LibProposing, LibProving, LibUtils, LibVerifying                                                                                               | L1 Libraries                        | Various utility functions for L1 contracts            | Provides functionality for deposit calculations, proposing, proving, and verifying               |
| GuardianProver, Guardians                                                                                                                                     | L1 Provers                          | Manages secure enclaves for proof verification        | Provides an interface for secure enclave communication and verification                          |
| TaikoData, TaikoErrors, TaikoEvents, TaikoL1, TaikoToken                                                                                                      | L1 Contracts                        | Core L1 contracts for Taiko                           | Contains logic for L1 errors, events, and token management                                       |
| IBridge, Bridge                                                                                                                                               | Bridge                              | Manages L1 to L2 token transfers                      | Provides an interface for L1 to L2 token bridging                                                |
| IVerifier, GuardianVerifier, SgxVerifier                                                                                                                      | Verifiers                           | Verifies L2 state transitions                         | Provides an interface for verifying L2 state transitions using Secure Enclaves or SGX technology |
| CrossChainOwned                                                                                                                                               | L2 Contracts                        | Provides cross-chain ownership management             | Facilitates cross-chain contract interaction and ownership management                            |
| Lib1559Math, TaikoL2, TaikoL2EIP1559Configurable, TaikoL1, TaikoL2, TaikoEvents                                                                               | L2 Contracts                        | Core L2 contracts for Taiko                           | Contains logic for L2 token management, transactions, and events                                 |
| ISignalService, LibSignals, SignalService                                                                                                                     | Signal Service                      | Manages signal services for Taiko                     | Provides an interface for various signal services and library functions                          |
| USDCAdapter                                                                                                                                                   | Token Vaults                        | Manages the USDC token vault                          | Provides functionality for depositing and withdrawing USDC tokens                                |
| BridgedERC20, BridgedERC20Base, BridgedERC721, BridgedERC1155, BaseNFTVault, BaseVault, ERC1155Vault, ERC20Vault, ERC721Vault, IBridgedERC20, LibBridgedToken | Token Vaults                        | Various token vault and adapter contracts             | Provides functionality for depositing and withdrawing various ERC token standards                |
| ExcessivelySafeCall, Bytes, RLPReader, RLPWriter, MerkleTrie, SecureMerkleTrie, LibFixedPointMath                                                             | Third Party Contracts and Libraries | Various contracts and libraries from third parties    | Provides various functionality for third party contracts and libraries                           |
| IVerifier                                                                                                                                                     | Verifiers                           | Verifies L2 state transitions                         | Provides an interface for verifying L2 state transitions using Secure Enclaves or SGX technology |

## 5. Economic Model Analysis

| Variable Name     | Description                                               | Economic Impact                                                                                                                                                                                 |
| ----------------- | --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| depositFee        | Fee charged for depositing assets.                        | Determines the revenue generated by the protocol for handling deposits. High deposit fees encourage more protocol revenue but may discourage users from depositing.                             |
| withdrawalFee     | Fee charged for withdrawing assets.                       | Determines the revenue generated by the protocol for handling withdrawals. High withdrawal fees may discourage users from withdrawing.                                                          |
| crossChainFee     | Fee charged for cross-chain transactions.                 | Determines the revenue generated by the protocol for facilitating cross-chain transactions. High cross-chain fees may discourage users from using the cross-chain feature.                      |
| proposerFee       | Fee charged for proposing blocks.                         | Determines the revenue generated by the protocol for handling block proposals. High proposer fees may discourage users from proposing blocks.                                                   |
| guardianFee       | Fee charged for verifying blocks.                         | Determines the revenue generated by the protocol for handling block verifications. High guardian fees may discourage users from verifying blocks.                                               |
| L1GasPrice        | Gas price on the L1 chain.                                | Determines the cost of executing transactions and smart contracts on the L1 chain. High gas prices may discourage users from using the L1 chain.                                                |
| L2GasPrice        | Gas price on the L2 chain.                                | Determines the cost of executing transactions and smart contracts on the L2 chain. High gas prices may discourage users from using the L2 chain.                                                |
| rewardsPerBlock   | Rewards distributed per block.                            | Determines the incentives for users to participate in the protocol, such as proposing and verifying blocks. High rewards encourage more participation but may reduce overall revenue.           |
| tokenEmissionRate | Rate at which new tokens are generated.                   | Determines the inflation rate of the token and the dilution of existing token holders. High emission rates lead to rapid inflation and token dilution.                                          |
| minimumDeposit    | Minimum deposit amount.                                   | Determines the minimum amount required for users to participate in the protocol. Low minimum deposits encourage more participation, but may also reduce overall security.                       |
| maximumDeposit    | Maximum deposit amount.                                   | Determines the maximum amount that users can deposit in the protocol. High maximum deposits may increase overall security but may also pose a risk to the system if not properly managed.       |
| minimumWithdrawal | Minimum withdrawal amount.                                | Determines the minimum amount required for users to withdraw their assets. Low minimum withdrawals encourage more participation but may also increase transaction costs.                        |
| maximumWithdrawal | Maximum withdrawal amount.                                | Determines the maximum amount that users can withdraw from the protocol. High maximum withdrawals may increase overall security but may also pose a risk to the system if not properly managed. |
| tierProvider      | Contract responsible for providing tier information.      | Determines the economic incentives and penalties for different user tiers. Influences the overall security of the system.                                                                       |
| airdrop           | Contract responsible for distributing tokens as airdrops. | Determines the distribution of tokens to users and may impact the token's value.                                                                                                                |
| teamPool          | Contract responsible for managing the team's token pool.  | Determines the distribution and allocation of tokens to the team members and may impact the token's value.                                                                                      |
| verifier          | Contract responsible for verifying block attestations.    | Determines the security and integrity of the system. High-quality verifiers can increase overall system security.                                                                               |

## 6. Architecture Business Logic

| Component                | Functionality                                                                                             | Interactions                                                                                                                                                                  |
| ------------------------ | --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| L1 Contracts             | L1 bridge functionality, L1 token handling, L1 cross-chain messages, L1 data handling, and L1 governance. | L1 <-> L2 bridge contracts, L1 bridge helpers, L1 governance contracts, L1 token contracts, L1 ERC20 token wrappers, L1 ERC721 token wrappers, and L1 ERC1155 token wrappers. |
| L2 Contracts             | L2 bridge functionality, L2 token handling, L2 cross-chain messages, L2 data handling, and L2 verifiers.  | L1 <-> L2 bridge contracts, L2 cross-chain message queue, L2 ERC20 token wrappers, L2 ERC721 token wrappers, L2 ERC1155 token wrappers, and L2 verifier contracts.            |
| Bridge Contracts         | Bi-directional message passing, token transfers, and token wrappers between L1 and L2.                    | L1 <-> L2 bridge contracts, L1 token contracts, and L2 token contracts.                                                                                                       |
| Helper Contracts         | Assist L1 and L2 contracts with various tasks, such as deposits, withdrawals, and message handling.       | L1 <-> L2 bridge contracts, and L1 and L2 token contracts.                                                                                                                    |
| Governance Contracts     | Allow for managing parameters and upgrades for the Taiko protocol.                                        | L1 <-> L2 bridge contracts and helper contracts.                                                                                                                              |
| Token Contracts          | Native tokens for L1 and L2.                                                                              | L1 and L2 token contracts, L1 and L2 bridge contracts, and L1 and L2 ERC20, ERC721, and ERC1155 token wrappers.                                                               |
| Verifier Contracts       | Handle L1 and L2 verification tasks.                                                                      | Bridge contracts, L1 and L2 token contracts, and L1 and L2 ERC20, ERC721, and ERC1155 token wrappers.                                                                         |
| Token Vault Contracts    | Interact with L1 and L2 tokens for deposit/withdrawal, transfer, and cross-chain messages.                | Bridge contracts, L1 <-> L2 bridge contracts, and L1 and L2 token contracts.                                                                                                  |
| Signal Service Contracts | Process L1 and L2 contract signals.                                                                       | Bridge contracts, L1 token contracts, L2 token contracts, and governance contracts.                                                                                           |
| Third-Party Libraries    | Reusable libraries for various tasks, such as RLP encoding and decoding.                                  | Multiple contracts throughout the Taiko protocol.                                                                                                                             |

## 7. Representation of Risk Model

### 7.1 Centralization & Systematic Risks

- Centralized management of trusted parties, including Guardians, Verifiers, and Tier Providers.
- Guardians have significant control and potential influence over the system's consensus, introducing the risk of centralization. Guardians may collude, censor transactions, or manipulate the system for personal gain. A transparent and fair guardian selection process, as well as frequent evaluations and updates, can help mitigate these risks.
- Tier Providers are responsible for managing the transaction fees and auxiliary gas costs, which can lead to centralization risks if these providers collude, manipulate, or censor transactions. Transparency in their selection process and regular evaluations can help mitigate these risks.
- Taiko currently uses two verifier contracts - GuardianVerifier and SgxVerifier. However, any vulnerabilities found in these contracts may impact the entire system's security. Ensuring a robust and secure design and conducting regular audits can help minimize these risks.
- The bridge between the L1 and L2 chains is a single trust boundary and is responsible for securing and maintaining communication between the two chains. This centralized communication line can lead to single-point failures, censorship, or manipulation of transactions. Prioritizing bridge security, resilience, and regular audits can help reduce these risks.
- Bridge.sol contains critical functionality such as token deposits and withdrawals. Centralizing this functionality in a single contract can have systemic implications if vulnerabilities are found in this contract. Consider distributing this functionality across multiple contracts to reduce potential exposure and risk.
- BaseNFTVault.sol and its derived contracts manage NFT tokens, which can be centralized and expose the system to failures, censorship, or manipulation by a single or a group of vault owners. Implementing decentralized measures, such as vault rotation or owner switching, can help reduce these risks.
- Taiko relies on third-party libraries like OpenZeppelin, optimism, and solmate, introducing potential systemic risks. If vulnerabilities are discovered in these libraries, they can affect multiple contracts within the Taiko ecosystem. Ensuring timely updates and audits of these libraries can help minimize these risks.
- Centralized control over various token contracts can introduce systemic risks, especially if these tokens are fungible and widely adopted. Specifying clear guidelines for token implementations, audits, and periodic reviews can help maintain a robust and secure environment.
- TokenVault and Bridge handle critical aspects of token transfers, deposits, and withdrawals between L1 and L2 chains. Centralizing these functionalities may introduce vulnerabilities, manipulations, or failures. Decentralizing these contracts or distributing their responsibilities can help mitigate systemic risks.

### 7.2 Technical Risks

- The TaikoL1 contract's deposit function uses \_checkProofAndUpdateState function, which is vulnerable to denial-of-service attacks if the proof is invalid.
- The CrossChainOwned contract's execute function uses \_checkProofAndUpdateState, introducing the same risk as the TaikoL1 contract.
- The TaikoL2 contract's deposit function and TaikoL2EIP1559Configurable contract's deposit function use \_checkProofAndUpdateState, introducing the same risk as the TaikoL1 contract.
- The TaikoErrors contract's fail function uses revert, which consumes gas and introduces the possibility of transaction failure.
- The ApprovalHook contract's execute function uses \_checkProofAndUpdateState function, which, if the proof is invalid, can result in denial-of-service attacks.
- The AssignmentHook contract uses \_checkProofAndUpdateState function, introducing the same risk as in the ApprovalHook contract.
- The RoundEndHook contract uses \_checkProofAndUpdateState function, introducing the same risk as in the ApprovalHook contract.
- Some of the contracts make use of external libraries, such as solmate, optimism, and nomad-xyz. These libraries have not been audited and could contain vulnerabilities that could be exploited to compromise the system.
- The USDCAdapter contract uses transferFrom to move funds, but does not check the return value. This could allow malicious actors to execute a reentrancy attack.
- The GuardianProver contract uses the push opcode to execute a call to TaikoL1. However, there is no check to ensure that the call succeeded. This could allow malicious actors to execute a denial-of-service (DoS) attack.
- The BaseVault contract has a nonce variable that is used to ensure that funds can only be withdrawn by calling the correct function. However, this variable is not reset after withdrawal. This could allow malicious actors to repeatedly call the withdraw function and drain the vault of its funds.
- The SgxVerifier contract assumes that the hardware implementation of the remote attestation process cannot be tampered with. However, this assumption may not be valid and could allow malicious actors to submit false or malicious attestations that are accepted by the system.
- The DevnetTierProvider contract uses a fixed list of addresses to determine the validity of proofs. This could allow malicious actors to submit false or invalid proofs that are accepted by the system.

### 7.3 Weak Spots

- The TaikoL1, CrossChainOwned, TaikoL2, and TaikoL2EIP1559Configurable contracts do not properly validate input parameters, allowing for potential vulnerabilities.
- The TaikoData contract and various libraries contain complex logic, which may lead to potential security risks and vulnerabilities.
- Dependencies on third-party code, such as nomad-xyz/ExcessivelySafeCall, optimism/Bytes, optimism/rlp/RLPReader.sol, optimism/rlp/RLPWriter.sol, optimism/trie/MerkleTrie.sol, optimism/trie/SecureMerkleTrie.sol, and solmate/LibFixedPointMath.sol, introduce potential security risks, as their behavior is influenced by their implementers.
- The TaikoL1, CrossChainOwned, TaikoL2, and TaikoL2EIP1559Configurable contracts implement complex logic in \_checkProofAndUpdateState functions, introducing potential vulnerabilities and security risks.
- The TaikoL1 contract's deposit function does not properly check the input proof length, introducing potential vulnerabilities.
- The TaikoL2EIP1559Configurable contract does not validate input parameters, introducing potential security risks.
- The USDCAdapter contract has a typo in its implementation storage variable, which may lead to errors and potential security risks.
- The BridgedERC20Base contract relies on count and length to iterate over mappings, which may lead to incorrect results or potential security risks.

## 7.4 Economic Risks

- The TaikoEvents contract contains an Exit event that can be triggered when a contract errors out. However, the documentation does not make it clear how this event could be used or what its implications are. If this event is used to exit a contract prematurely, it could result in a loss of funds for users.
- The TaikoL2EIP1559Configurable contract has a gasPriceLimit function that can be used to set the maximum gas price for transactions. However, this function does not check that the new gas price is higher than the current price. This could allow malicious actors to set the gas price to a very low value, effectively allowing them to execute transactions at a much lower cost than other users.
- The TaikoL2 contract has a migrate function that can be used to migrate funds from one contract to another. However, this function does not check that the destination contract is valid. This could allow malicious actors to migrate funds to a malicious contract, resulting in a loss of funds for users.
- The TaikoL1 contract has a init function that can be used to initialize the contract. However, this function does not check that the contract has sufficient funds to execute its operations. This could allow malicious actors to execute a denial-of-service (DoS) attack by repeatedly calling the init function with low-cost transactions that consume all of the contract's gas.
- The TaikoL1 contract also has a execute function that can be used to execute arbitrary commands on the contract. This function does not check that the contract has sufficient funds to execute the command, nor does it check that the command is valid. This could allow malicious actors to execute arbitrary code on the contract, potentially resulting in a loss of funds for users.

## 8. Architecture Recommendations

- Diversify the set of trusted parties that are responsible for performing critical tasks such as proving and verifying proofs.
- Use a more robust mechanism for error handling, such as reverting the contract or logging an error message, instead of relying on hardcoded error messages.
- Implement proper input validation and error handling in all contract functions to prevent reentrancy, denial-of-service (DoS), and other attacks.
- Use a more robust mechanism for storing and retrieving attestation data, such as a public blockchain, to ensure that data is tamper-evident and auditable.
- Consider implementing multi-party computation techniques, such as threshold signing, to decentralize the responsibility for executing critical tasks.
- Perform thorough security testing and auditing of all contracts and external libraries to identify and fix any vulnerabilities.
- Implement rate-limiting and gas limits on critical functions to prevent abuse and denial-of-service (DoS) attacks.
- Implement proper input validation and error handling in all contract functions to prevent reentrancy, denial-of-service (DoS), and other attacks.
- Consider implementing a more robust mechanism for handling contract errors, such as reverting the contract or logging an error message, instead of relying on a single Exit event.
- Consider implementing a more robust mechanism for configuring gas limits on transactions, such as using a separate contract or smart contract wallet.
- Implement proper input validation and error handling in all contract functions to prevent reentrancy, denial-of-service (DoS), and other attacks.
- Implement proper input validation and error handling in all contract functions to prevent reentrancy, denial-of-service (DoS), and other attacks.
- Consider implementing a more robust mechanism for handling contract errors, such as reverting the contract or logging an error message, instead of relying on a single Exit event.
- Consider implementing a more robust mechanism for handling contract errors, such as reverting the contract or logging an error message, instead of relying on a single Exit event.

## 9. Learning And Insights

- **Understanding of cross-chain bridges**: Taiko codebase deals with bridges for transferring assets between different blockchain networks, which is a complex and interesting problem. Reviewing this codebase helped me to understand the challenges involved in building cross-chain bridges and the different approaches used to solve them.
- **Better understanding of L2 scaling solutions**: Taiko codebase is built on top of L2 scaling solutions such as Optimism and ZK-Rollups. Reviewing this codebase helped me to understand how these L2 solutions work and how they can be used to build scalable blockchain applications.
- **Understanding of cryptography and security**: Taiko codebase involves cryptographic protocols such as ECDSA signatures and elliptic curve cryptography. Reviewing this codebase helped me to understand the importance of security in blockchain development and the different techniques used to ensure the security of the system.
- **Code organization and readability**: Taiko codebase is well-organized and easy to read, with consistent naming conventions and well-documented code. Reviewing this codebase helped me to understand the importance of code organization and readability in blockchain development.
- **Modularity and reusability**: Taiko codebase makes extensive use of libraries and interfaces, which helps to promote code modularity and reusability. Reviewing this codebase helped me to understand the importance of designing code for reuse and how to build reusable components in blockchain development.
- **Learning from experienced developers**: Taiko codebase is developed by experienced developers who have a deep understanding of blockchain technology and smart contract development. Reviewing this codebase helped me to learn from their experience and expertise.

## 10. Conclusion

I reviewed the Taiko codebase and identified several strengths, weaknesses, opportunities, and threats (SWOT analysis) for the project. I found that the codebase is well-structured, well-documented, and follows best practices for blockchain development. The team has taken a security-focused approach to development, with a strong emphasis on formal verification and testing.

However, there are some areas for improvement, including the need for additional input validation, error handling, and gas optimization techniques. Additionally, there are some potential risks associated with the use of L2 scaling solutions and cross-chain bridges, including the need for adequate security measures to prevent attacks and ensure data consistency and integrity.

To address these challenges, I recommend that the Taiko team continue to prioritize security and best practices throughout the development process. This includes implementing additional input validation, error handling, and gas optimization techniques, as well as conducting ongoing security testing and auditing. Additionally, the team should consider implementing multi-party computation techniques, such as threshold signing, to decentralize the responsibility for critical tasks and improve the system's overall resilience.

Overall, the Taiko codebase is a solid foundation for building a scalable and secure L2 scaling solution. With continued attention to detail and commitment to best practices, the Taiko project is well-positioned for long-term success.

## 11. Message For Taiko Team

Congratulations to the Taiko team on a successful audit! It's clear that a lot of work and dedication has gone into building this project, and the attention to detail and thoughtfulness that went into the code and documentation is commendable.

The codebase is well-structured and organized, and it's clear that the team has a deep understanding of blockchain technology and smart contract development. The use of libraries and interfaces to promote modularity and reusability is particularly impressive, as is the attention paid to security and cryptography.

As a warden in the Code4rena community, I'm always impressed when I see a project that takes security seriously, and the Taiko team's approach to security is commendable. The team's commitment to testing and formal verification is a clear sign that they take security seriously, and I believe this will help to build trust and confidence in the Taiko project.

Overall, I'm excited to see where the Taiko project will go, and I'm confident that the team's dedication and expertise will help to ensure its success. Keep up the great work, and thank you for the opportunity to review your code!

## 12. Time Spent

| Task                      | Time Spent (hours) |
| ------------------------- | ------------------ |
| Analysis of documentation | 20                 |
| Review of Taiko codebase  | 40                 |
| Preparation of report     | 10                 |
| Total time spent          | 70                 |

## 13. References

- https://github.com/code-423n4/2024-03-taiko
- https://docs.taiko.xyz/start-here/getting-started
- https://taiko.mirror.xyz/oRy3ZZ_4-6IEQcuLCMMlxvdH6E-T3_H7UwYVzGDsgf4
- https://www.datawallet.com/crypto/what-is-taiko
- https://medium.com/@mustafa.hourani/interview-with-taiko-a-leading-type-1-zkevm-ddf71eb4eabe
- https://taiko.mirror.xyz/y_47kIOL5kavvBmG0zVujD2TRztMZt-xgM5d4oqp4_Y?ref=bankless.ghost.io

### Time spent:

70 hours
