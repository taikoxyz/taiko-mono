export default [
  {
    inputs: [],
    name: 'L1_ALREADY_PROVEN',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_ALREADY_PROVEN',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_BATCH_NOT_AUCTIONABLE',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_BLOCK_ID',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_BLOCK_ID',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_BLOCK_ID',
    type: 'error',
  },
  {
    inputs: [
      {
        internalType: 'bytes32',
        name: 'expected',
        type: 'bytes32',
      },
      {
        internalType: 'bytes32',
        name: 'actual',
        type: 'bytes32',
      },
    ],
    name: 'L1_EVIDENCE_MISMATCH',
    type: 'error',
  },
  {
    inputs: [
      {
        internalType: 'bytes32',
        name: 'expected',
        type: 'bytes32',
      },
      {
        internalType: 'bytes32',
        name: 'actual',
        type: 'bytes32',
      },
    ],
    name: 'L1_EVIDENCE_MISMATCH',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_FORK_CHOICE_NOT_FOUND',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_FORK_CHOICE_NOT_FOUND',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INSUFFICIENT_TOKEN',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INSUFFICIENT_TOKEN',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INSUFFICIENT_TOKEN',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INVALID_BID',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INVALID_CONFIG',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INVALID_CONFIG',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INVALID_ETH_DEPOSIT',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INVALID_ETH_DEPOSIT',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INVALID_EVIDENCE',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INVALID_EVIDENCE',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INVALID_METADATA',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INVALID_METADATA',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INVALID_PARAM',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INVALID_PROOF',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_INVALID_PROOF',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_NOT_BETTER_BID',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_NOT_PROVEABLE',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_NOT_PROVEABLE',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_NOT_SPECIAL_PROVER',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_SAME_PROOF',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_SAME_PROOF',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_TOO_MANY_BLOCKS',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_TOO_MANY_BLOCKS',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_TOO_MANY_OPEN_BLOCKS',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_TOO_MANY_OPEN_BLOCKS',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_TX_LIST',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_TX_LIST',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_TX_LIST_HASH',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_TX_LIST_HASH',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_TX_LIST_NOT_EXIST',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_TX_LIST_NOT_EXIST',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_TX_LIST_RANGE',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_TX_LIST_RANGE',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_UNAUTHORIZED',
    type: 'error',
  },
  {
    inputs: [],
    name: 'L1_UNAUTHORIZED',
    type: 'error',
  },
  {
    inputs: [],
    name: 'RESOLVER_DENIED',
    type: 'error',
  },
  {
    inputs: [],
    name: 'RESOLVER_INVALID_ADDR',
    type: 'error',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'chainId',
        type: 'uint256',
      },
      {
        internalType: 'bytes32',
        name: 'name',
        type: 'bytes32',
      },
    ],
    name: 'RESOLVER_ZERO_ADDR',
    type: 'error',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: 'address',
        name: 'addressManager',
        type: 'address',
      },
    ],
    name: 'AddressManagerChanged',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'uint256',
        name: 'blockId',
        type: 'uint256',
      },
      {
        indexed: true,
        internalType: 'address',
        name: 'assignedProver',
        type: 'address',
      },
      {
        indexed: false,
        internalType: 'uint32',
        name: 'rewardPerGas',
        type: 'uint32',
      },
      {
        indexed: false,
        internalType: 'uint64',
        name: 'feePerGas',
        type: 'uint64',
      },
      {
        components: [
          {
            internalType: 'uint64',
            name: 'id',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'timestamp',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'l1Height',
            type: 'uint64',
          },
          {
            internalType: 'bytes32',
            name: 'l1Hash',
            type: 'bytes32',
          },
          {
            internalType: 'bytes32',
            name: 'mixHash',
            type: 'bytes32',
          },
          {
            internalType: 'bytes32',
            name: 'txListHash',
            type: 'bytes32',
          },
          {
            internalType: 'uint24',
            name: 'txListByteStart',
            type: 'uint24',
          },
          {
            internalType: 'uint24',
            name: 'txListByteEnd',
            type: 'uint24',
          },
          {
            internalType: 'uint32',
            name: 'gasLimit',
            type: 'uint32',
          },
          {
            internalType: 'address',
            name: 'beneficiary',
            type: 'address',
          },
          {
            internalType: 'address',
            name: 'treasury',
            type: 'address',
          },
          {
            components: [
              {
                internalType: 'address',
                name: 'recipient',
                type: 'address',
              },
              {
                internalType: 'uint96',
                name: 'amount',
                type: 'uint96',
              },
              {
                internalType: 'uint64',
                name: 'id',
                type: 'uint64',
              },
            ],
            internalType: 'struct TaikoData.EthDeposit[]',
            name: 'depositsProcessed',
            type: 'tuple[]',
          },
        ],
        indexed: false,
        internalType: 'struct TaikoData.BlockMetadata',
        name: 'meta',
        type: 'tuple',
      },
    ],
    name: 'BlockProposed',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'uint256',
        name: 'blockId',
        type: 'uint256',
      },
      {
        indexed: true,
        internalType: 'address',
        name: 'assignedProver',
        type: 'address',
      },
      {
        indexed: false,
        internalType: 'uint32',
        name: 'rewardPerGas',
        type: 'uint32',
      },
      {
        indexed: false,
        internalType: 'uint64',
        name: 'feePerGas',
        type: 'uint64',
      },
      {
        components: [
          {
            internalType: 'uint64',
            name: 'id',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'timestamp',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'l1Height',
            type: 'uint64',
          },
          {
            internalType: 'bytes32',
            name: 'l1Hash',
            type: 'bytes32',
          },
          {
            internalType: 'bytes32',
            name: 'mixHash',
            type: 'bytes32',
          },
          {
            internalType: 'bytes32',
            name: 'txListHash',
            type: 'bytes32',
          },
          {
            internalType: 'uint24',
            name: 'txListByteStart',
            type: 'uint24',
          },
          {
            internalType: 'uint24',
            name: 'txListByteEnd',
            type: 'uint24',
          },
          {
            internalType: 'uint32',
            name: 'gasLimit',
            type: 'uint32',
          },
          {
            internalType: 'address',
            name: 'beneficiary',
            type: 'address',
          },
          {
            internalType: 'address',
            name: 'treasury',
            type: 'address',
          },
          {
            components: [
              {
                internalType: 'address',
                name: 'recipient',
                type: 'address',
              },
              {
                internalType: 'uint96',
                name: 'amount',
                type: 'uint96',
              },
              {
                internalType: 'uint64',
                name: 'id',
                type: 'uint64',
              },
            ],
            internalType: 'struct TaikoData.EthDeposit[]',
            name: 'depositsProcessed',
            type: 'tuple[]',
          },
        ],
        indexed: false,
        internalType: 'struct TaikoData.BlockMetadata',
        name: 'meta',
        type: 'tuple',
      },
    ],
    name: 'BlockProposed',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'uint256',
        name: 'blockId',
        type: 'uint256',
      },
      {
        indexed: false,
        internalType: 'bytes32',
        name: 'parentHash',
        type: 'bytes32',
      },
      {
        indexed: false,
        internalType: 'bytes32',
        name: 'blockHash',
        type: 'bytes32',
      },
      {
        indexed: false,
        internalType: 'bytes32',
        name: 'signalRoot',
        type: 'bytes32',
      },
      {
        indexed: false,
        internalType: 'address',
        name: 'prover',
        type: 'address',
      },
      {
        indexed: false,
        internalType: 'uint32',
        name: 'parentGasUsed',
        type: 'uint32',
      },
    ],
    name: 'BlockProven',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'uint256',
        name: 'blockId',
        type: 'uint256',
      },
      {
        indexed: false,
        internalType: 'bytes32',
        name: 'parentHash',
        type: 'bytes32',
      },
      {
        indexed: false,
        internalType: 'bytes32',
        name: 'blockHash',
        type: 'bytes32',
      },
      {
        indexed: false,
        internalType: 'bytes32',
        name: 'signalRoot',
        type: 'bytes32',
      },
      {
        indexed: false,
        internalType: 'address',
        name: 'prover',
        type: 'address',
      },
      {
        indexed: false,
        internalType: 'uint32',
        name: 'parentGasUsed',
        type: 'uint32',
      },
    ],
    name: 'BlockProven',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'uint256',
        name: 'blockId',
        type: 'uint256',
      },
      {
        indexed: false,
        internalType: 'bytes32',
        name: 'blockHash',
        type: 'bytes32',
      },
      {
        indexed: false,
        internalType: 'address',
        name: 'prover',
        type: 'address',
      },
      {
        indexed: false,
        internalType: 'uint64',
        name: 'blockFee',
        type: 'uint64',
      },
      {
        indexed: false,
        internalType: 'uint64',
        name: 'proofReward',
        type: 'uint64',
      },
    ],
    name: 'BlockVerified',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'uint256',
        name: 'blockId',
        type: 'uint256',
      },
      {
        indexed: false,
        internalType: 'bytes32',
        name: 'blockHash',
        type: 'bytes32',
      },
      {
        indexed: false,
        internalType: 'address',
        name: 'prover',
        type: 'address',
      },
      {
        indexed: false,
        internalType: 'uint64',
        name: 'blockFee',
        type: 'uint64',
      },
      {
        indexed: false,
        internalType: 'uint64',
        name: 'proofReward',
        type: 'uint64',
      },
    ],
    name: 'BlockVerified',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'uint256',
        name: 'srcHeight',
        type: 'uint256',
      },
      {
        indexed: false,
        internalType: 'bytes32',
        name: 'blockHash',
        type: 'bytes32',
      },
      {
        indexed: false,
        internalType: 'bytes32',
        name: 'signalRoot',
        type: 'bytes32',
      },
    ],
    name: 'CrossChainSynced',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'uint256',
        name: 'srcHeight',
        type: 'uint256',
      },
      {
        indexed: false,
        internalType: 'bytes32',
        name: 'blockHash',
        type: 'bytes32',
      },
      {
        indexed: false,
        internalType: 'bytes32',
        name: 'signalRoot',
        type: 'bytes32',
      },
    ],
    name: 'CrossChainSynced',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        components: [
          {
            internalType: 'address',
            name: 'recipient',
            type: 'address',
          },
          {
            internalType: 'uint96',
            name: 'amount',
            type: 'uint96',
          },
          {
            internalType: 'uint64',
            name: 'id',
            type: 'uint64',
          },
        ],
        indexed: false,
        internalType: 'struct TaikoData.EthDeposit',
        name: 'deposit',
        type: 'tuple',
      },
    ],
    name: 'EthDeposited',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        components: [
          {
            internalType: 'address',
            name: 'recipient',
            type: 'address',
          },
          {
            internalType: 'uint96',
            name: 'amount',
            type: 'uint96',
          },
          {
            internalType: 'uint64',
            name: 'id',
            type: 'uint64',
          },
        ],
        indexed: false,
        internalType: 'struct TaikoData.EthDeposit',
        name: 'deposit',
        type: 'tuple',
      },
    ],
    name: 'EthDeposited',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: 'uint8',
        name: 'version',
        type: 'uint8',
      },
    ],
    name: 'Initialized',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'address',
        name: 'previousOwner',
        type: 'address',
      },
      {
        indexed: true,
        internalType: 'address',
        name: 'newOwner',
        type: 'address',
      },
    ],
    name: 'OwnershipTransferred',
    type: 'event',
  },
  {
    inputs: [],
    name: 'addressManager',
    outputs: [
      {
        internalType: 'address',
        name: '',
        type: 'address',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'amount',
        type: 'uint256',
      },
    ],
    name: 'canDepositEthToL2',
    outputs: [
      {
        internalType: 'bool',
        name: '',
        type: 'bool',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'address',
        name: 'recipient',
        type: 'address',
      },
    ],
    name: 'depositEtherToL2',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'amount',
        type: 'uint256',
      },
    ],
    name: 'depositTaikoToken',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'blockId',
        type: 'uint256',
      },
    ],
    name: 'getBlock',
    outputs: [
      {
        internalType: 'bytes32',
        name: '_metaHash',
        type: 'bytes32',
      },
      {
        internalType: 'uint32',
        name: '_gasLimit',
        type: 'uint32',
      },
      {
        internalType: 'uint24',
        name: '_nextForkChoiceId',
        type: 'uint24',
      },
      {
        internalType: 'uint24',
        name: '_verifiedForkChoiceId',
        type: 'uint24',
      },
      {
        internalType: 'bool',
        name: '_proverReleased',
        type: 'bool',
      },
      {
        internalType: 'address',
        name: '_proposer',
        type: 'address',
      },
      {
        internalType: 'uint32',
        name: '_feePerGas',
        type: 'uint32',
      },
      {
        internalType: 'uint64',
        name: '_proposedAt',
        type: 'uint64',
      },
      {
        internalType: 'address',
        name: '_assignedProver',
        type: 'address',
      },
      {
        internalType: 'uint32',
        name: '_rewardPerGas',
        type: 'uint32',
      },
      {
        internalType: 'uint64',
        name: '_proofWindow',
        type: 'uint64',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint32',
        name: 'gasLimit',
        type: 'uint32',
      },
    ],
    name: 'getBlockFee',
    outputs: [
      {
        internalType: 'uint64',
        name: '',
        type: 'uint64',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getConfig',
    outputs: [
      {
        components: [
          {
            internalType: 'uint256',
            name: 'chainId',
            type: 'uint256',
          },
          {
            internalType: 'bool',
            name: 'relaySignalRoot',
            type: 'bool',
          },
          {
            internalType: 'uint256',
            name: 'blockMaxProposals',
            type: 'uint256',
          },
          {
            internalType: 'uint256',
            name: 'blockRingBufferSize',
            type: 'uint256',
          },
          {
            internalType: 'uint256',
            name: 'blockMaxVerificationsPerTx',
            type: 'uint256',
          },
          {
            internalType: 'uint32',
            name: 'blockMaxGasLimit',
            type: 'uint32',
          },
          {
            internalType: 'uint32',
            name: 'blockFeeBaseGas',
            type: 'uint32',
          },
          {
            internalType: 'uint64',
            name: 'blockMaxTransactions',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'blockMaxTxListBytes',
            type: 'uint64',
          },
          {
            internalType: 'uint256',
            name: 'blockTxListExpiry',
            type: 'uint256',
          },
          {
            internalType: 'uint256',
            name: 'proofRegularCooldown',
            type: 'uint256',
          },
          {
            internalType: 'uint256',
            name: 'proofOracleCooldown',
            type: 'uint256',
          },
          {
            internalType: 'uint16',
            name: 'proofMinWindow',
            type: 'uint16',
          },
          {
            internalType: 'uint16',
            name: 'proofMaxWindow',
            type: 'uint16',
          },
          {
            internalType: 'uint256',
            name: 'ethDepositRingBufferSize',
            type: 'uint256',
          },
          {
            internalType: 'uint64',
            name: 'ethDepositMinCountPerBlock',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'ethDepositMaxCountPerBlock',
            type: 'uint64',
          },
          {
            internalType: 'uint96',
            name: 'ethDepositMinAmount',
            type: 'uint96',
          },
          {
            internalType: 'uint96',
            name: 'ethDepositMaxAmount',
            type: 'uint96',
          },
          {
            internalType: 'uint256',
            name: 'ethDepositGas',
            type: 'uint256',
          },
          {
            internalType: 'uint256',
            name: 'ethDepositMaxFee',
            type: 'uint256',
          },
          {
            internalType: 'uint8',
            name: 'rewardOpenMultipler',
            type: 'uint8',
          },
          {
            internalType: 'uint256',
            name: 'rewardOpenMaxCount',
            type: 'uint256',
          },
        ],
        internalType: 'struct TaikoData.Config',
        name: '',
        type: 'tuple',
      },
    ],
    stateMutability: 'pure',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'blockId',
        type: 'uint256',
      },
    ],
    name: 'getCrossChainBlockHash',
    outputs: [
      {
        internalType: 'bytes32',
        name: '',
        type: 'bytes32',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'blockId',
        type: 'uint256',
      },
    ],
    name: 'getCrossChainSignalRoot',
    outputs: [
      {
        internalType: 'bytes32',
        name: '',
        type: 'bytes32',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'blockId',
        type: 'uint256',
      },
      {
        internalType: 'bytes32',
        name: 'parentHash',
        type: 'bytes32',
      },
      {
        internalType: 'uint32',
        name: 'parentGasUsed',
        type: 'uint32',
      },
    ],
    name: 'getForkChoice',
    outputs: [
      {
        components: [
          {
            internalType: 'bytes32',
            name: 'key',
            type: 'bytes32',
          },
          {
            internalType: 'bytes32',
            name: 'blockHash',
            type: 'bytes32',
          },
          {
            internalType: 'bytes32',
            name: 'signalRoot',
            type: 'bytes32',
          },
          {
            internalType: 'address',
            name: 'prover',
            type: 'address',
          },
          {
            internalType: 'uint64',
            name: 'provenAt',
            type: 'uint64',
          },
          {
            internalType: 'uint32',
            name: 'gasUsed',
            type: 'uint32',
          },
        ],
        internalType: 'struct TaikoData.ForkChoice',
        name: '',
        type: 'tuple',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getStateVariables',
    outputs: [
      {
        components: [
          {
            internalType: 'uint32',
            name: 'feePerGas',
            type: 'uint32',
          },
          {
            internalType: 'uint64',
            name: 'genesisHeight',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'genesisTimestamp',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'numBlocks',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'lastVerifiedBlockId',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'nextEthDepositToProcess',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'numEthDeposits',
            type: 'uint64',
          },
        ],
        internalType: 'struct TaikoData.StateVariables',
        name: '',
        type: 'tuple',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'address',
        name: 'addr',
        type: 'address',
      },
    ],
    name: 'getTaikoTokenBalance',
    outputs: [
      {
        internalType: 'uint256',
        name: '',
        type: 'uint256',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint16',
        name: 'id',
        type: 'uint16',
      },
    ],
    name: 'getVerifierName',
    outputs: [
      {
        internalType: 'bytes32',
        name: '',
        type: 'bytes32',
      },
    ],
    stateMutability: 'pure',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'address',
        name: '_addressManager',
        type: 'address',
      },
      {
        internalType: 'bytes32',
        name: '_genesisBlockHash',
        type: 'bytes32',
      },
      {
        internalType: 'uint32',
        name: '_initFeePerGas',
        type: 'uint32',
      },
      {
        internalType: 'uint16',
        name: '_initAvgProofDelay',
        type: 'uint16',
      },
    ],
    name: 'init',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'owner',
    outputs: [
      {
        internalType: 'address',
        name: '',
        type: 'address',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'bytes',
        name: 'input',
        type: 'bytes',
      },
      {
        internalType: 'bytes',
        name: 'txList',
        type: 'bytes',
      },
    ],
    name: 'proposeBlock',
    outputs: [
      {
        components: [
          {
            internalType: 'uint64',
            name: 'id',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'timestamp',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'l1Height',
            type: 'uint64',
          },
          {
            internalType: 'bytes32',
            name: 'l1Hash',
            type: 'bytes32',
          },
          {
            internalType: 'bytes32',
            name: 'mixHash',
            type: 'bytes32',
          },
          {
            internalType: 'bytes32',
            name: 'txListHash',
            type: 'bytes32',
          },
          {
            internalType: 'uint24',
            name: 'txListByteStart',
            type: 'uint24',
          },
          {
            internalType: 'uint24',
            name: 'txListByteEnd',
            type: 'uint24',
          },
          {
            internalType: 'uint32',
            name: 'gasLimit',
            type: 'uint32',
          },
          {
            internalType: 'address',
            name: 'beneficiary',
            type: 'address',
          },
          {
            internalType: 'address',
            name: 'treasury',
            type: 'address',
          },
          {
            components: [
              {
                internalType: 'address',
                name: 'recipient',
                type: 'address',
              },
              {
                internalType: 'uint96',
                name: 'amount',
                type: 'uint96',
              },
              {
                internalType: 'uint64',
                name: 'id',
                type: 'uint64',
              },
            ],
            internalType: 'struct TaikoData.EthDeposit[]',
            name: 'depositsProcessed',
            type: 'tuple[]',
          },
        ],
        internalType: 'struct TaikoData.BlockMetadata',
        name: 'meta',
        type: 'tuple',
      },
    ],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'blockId',
        type: 'uint256',
      },
      {
        internalType: 'bytes',
        name: 'input',
        type: 'bytes',
      },
    ],
    name: 'proveBlock',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'renounceOwnership',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'chainId',
        type: 'uint256',
      },
      {
        internalType: 'bytes32',
        name: 'name',
        type: 'bytes32',
      },
      {
        internalType: 'bool',
        name: 'allowZeroAddress',
        type: 'bool',
      },
    ],
    name: 'resolve',
    outputs: [
      {
        internalType: 'address payable',
        name: '',
        type: 'address',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'bytes32',
        name: 'name',
        type: 'bytes32',
      },
      {
        internalType: 'bool',
        name: 'allowZeroAddress',
        type: 'bool',
      },
    ],
    name: 'resolve',
    outputs: [
      {
        internalType: 'address payable',
        name: '',
        type: 'address',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'address',
        name: 'newAddressManager',
        type: 'address',
      },
    ],
    name: 'setAddressManager',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'state',
    outputs: [
      {
        internalType: 'uint64',
        name: 'genesisHeight',
        type: 'uint64',
      },
      {
        internalType: 'uint64',
        name: 'genesisTimestamp',
        type: 'uint64',
      },
      {
        internalType: 'uint64',
        name: '__reserved70',
        type: 'uint64',
      },
      {
        internalType: 'uint64',
        name: '__reserved71',
        type: 'uint64',
      },
      {
        internalType: 'uint64',
        name: 'numOpenBlocks',
        type: 'uint64',
      },
      {
        internalType: 'uint64',
        name: 'numEthDeposits',
        type: 'uint64',
      },
      {
        internalType: 'uint64',
        name: 'numBlocks',
        type: 'uint64',
      },
      {
        internalType: 'uint64',
        name: 'nextEthDepositToProcess',
        type: 'uint64',
      },
      {
        internalType: 'uint64',
        name: 'lastVerifiedAt',
        type: 'uint64',
      },
      {
        internalType: 'uint64',
        name: 'lastVerifiedBlockId',
        type: 'uint64',
      },
      {
        internalType: 'uint64',
        name: '__reserved90',
        type: 'uint64',
      },
      {
        internalType: 'uint32',
        name: 'feePerGas',
        type: 'uint32',
      },
      {
        internalType: 'uint16',
        name: 'avgProofDelay',
        type: 'uint16',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'address',
        name: 'newOwner',
        type: 'address',
      },
    ],
    name: 'transferOwnership',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'maxBlocks',
        type: 'uint256',
      },
    ],
    name: 'verifyBlocks',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'amount',
        type: 'uint256',
      },
    ],
    name: 'withdrawTaikoToken',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    stateMutability: 'payable',
    type: 'receive',
  },
];
