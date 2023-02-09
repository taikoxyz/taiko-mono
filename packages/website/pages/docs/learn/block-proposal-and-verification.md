# Block proposal & verification

Taiko aims to build a secure, decentralized, and permissionless rollup on Ethereum. These requirements dictate the following properties:

1. All block data required to reconstruct the post-block state needs to be put on Ethereum so it is publicly available. If this would not be the case, Taiko would not only fail to be a rollup but would also fail to be fully decentralized. This data is required so that anyone can know the latest chain state and so that useful new blocks can be appended to the chain. For the decentralization of the proof generation Taiko requires an even stronger requirement: all block data needed to be able to re-execute all work in a block in a step-by-step fashion needs to be made public. This makes it possible for provers to generate a proof for a block using only publicly known data.
2. Creating and proposing blocks should be a fast and efficient process. Anyone should be able to add blocks to the chain on a level playing field, having access to the same chain data at all times. Proposers, of course, should be able to compete on e.g. transaction fees and [Maximal Extractable Value (MEV)](https://ethereum.org/en/developers/docs/mev/).

We achieve this by splitting the block submission process in two parts:

### Block proposal

When a block gets proposed the block data is published on Ethereum and the block is appended to the proposed blocks list stored in the [TaikoL1](/docs/reference/contract-documentation/L1/TaikoL1) contract. Once registered, the protocol ensures that _all_ block properties are immutable. This makes the block execution _deterministic_: the post-block state can now be calculated by anyone. As such, the block is immediately _verified_. This also ensures that no one knows more about the latest state than anyone else, as that would create an unfair advantage.

### Block verification

Because the block should already be verified once proposed, it should _not_ be possible for the prover to have any impact on how the block is executed and what the post-block state is. All relevant inputs for the proof generation are verified on L1 directly or indirectly to achieve deterministic block transitions. As all proposed blocks are deterministic, they can be proven in parallel, because all intermediate states between blocks are known and unique. Once a proof is submitted for the block and its parent block, we call the block _on-chain verified_.
