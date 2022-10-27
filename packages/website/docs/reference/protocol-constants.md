| Name                           | Value | Description                                                                                                                |
| ------------------------------ | ----- | -------------------------------------------------------------------------------------------------------------------------- |
| $K_{ChainID}$                  | 167   | Taiko's chain ID.                                                                                                          |
| $K_{MaxProposedBlocks}$        | 2048  | The maximum number of proposed blocks.                                                                                     |
| $K_{MaxFinalizationsPerTx}$    | 5     | The number of proven blocks that can be finalized when a new block is proposed or a block is proven.                       |
| $K_{CommitDelayConfirmations}$ | 4     | The number of confirmations to wait for before a block can be proposed after its commit-hash has been written on Ethereum. |
| $K_{MaxProofsPerForkChoice}$   | 5     | The maximum number of proofs per fork choice.                                                                              |
| $K_{BlockMaxGasLimit}$         | TBD   | A Taiko block’s max gas limit besides $K_{AnchorTxGasLimit}$.                                                              |
| $K_{BlockMaxTxs}$              | TBD   | The maximum number of transactions in a Taiko block besides the anchor transaction.                                        |
| $K_{BlockDeadEndHash}$         | 0x1   | A special value to mark blocks proven invalid.                                                                             |
| $K_{TxListMaxBytes}$           | TBD   | A txList’s maximum number of bytes                                                                                         |
| $K_{TxMinGasLimit}$            | TBD   | A transaction’s minimum gas limit.                                                                                         |
| $K_{AnchorTxGasLimit}$         | TBD   | Anchor transaction’s fixed gas limit.                                                                                      |

| Name                          | Value                                                              |
| ----------------------------- | ------------------------------------------------------------------ |
| $K_{AnchorTxSelector}$        | 0xa0ca2d08                                                         |
| $K_{GoldenTouchAddress}$      | 0x0000777735367b36bC9B61C50022d9D0700dB4Ec                         |
| $K_{GoldenTouchPrivateKey}$   | 0x92954368afd3caa1f3ce3ead0069c1af414054aefe1ef9aeacc1bf426222ce38 |
| $K_{InvalidateBlockLogTopic}$ | 0x64b299ff9f8ba674288abb53380419048a4271dda03b837ecba6b40e6ddea4a2 |
| $K_{EmptyOmersHash}$          | 0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347 |
