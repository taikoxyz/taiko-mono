export default [
  {
    inputs: [],
    name: 'CHANGE_TOO_FREQUENT',
    type: 'error',
  },
  {
    inputs: [],
    name: 'INVALID_PARAMS',
    type: 'error',
  },
  {
    inputs: [],
    name: 'NO_MATURE_EXIT',
    type: 'error',
  },
  {
    inputs: [],
    name: 'PROVER_NOT_GOOD_ENOUGH',
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
    inputs: [],
    name: 'UNAUTHORIZED',
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
        internalType: 'address',
        name: 'addr',
        type: 'address',
      },
      {
        indexed: false,
        internalType: 'uint64',
        name: 'amount',
        type: 'uint64',
      },
    ],
    name: 'Exited',
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
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'address',
        name: 'addr',
        type: 'address',
      },
      {
        indexed: false,
        internalType: 'uint64',
        name: 'amount',
        type: 'uint64',
      },
    ],
    name: 'Slashed',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'address',
        name: 'addr',
        type: 'address',
      },
      {
        indexed: false,
        internalType: 'uint64',
        name: 'amount',
        type: 'uint64',
      },
      {
        indexed: false,
        internalType: 'uint32',
        name: 'rewardPerGas',
        type: 'uint32',
      },
      {
        indexed: false,
        internalType: 'uint32',
        name: 'currentCapacity',
        type: 'uint32',
      },
    ],
    name: 'Staked',
    type: 'event',
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: 'address',
        name: 'addr',
        type: 'address',
      },
      {
        indexed: false,
        internalType: 'uint64',
        name: 'amount',
        type: 'uint64',
      },
    ],
    name: 'Withdrawn',
    type: 'event',
  },
  {
    inputs: [],
    name: 'EXIT_PERIOD',
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
    name: 'MAX_NUM_PROVERS',
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
    inputs: [],
    name: 'MIN_CAPACITY',
    outputs: [
      {
        internalType: 'uint32',
        name: '',
        type: 'uint32',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'MIN_CHANGE_DELAY',
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
    inputs: [],
    name: 'MIN_STAKE_PER_CAPACITY',
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
    name: 'SLASH_MULTIPLIER',
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
    name: 'SLASH_POINTS',
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
        internalType: 'uint64',
        name: 'blockId',
        type: 'uint64',
      },
      {
        internalType: 'uint32',
        name: 'feePerGas',
        type: 'uint32',
      },
    ],
    name: 'assignProver',
    outputs: [
      {
        internalType: 'address',
        name: 'prover',
        type: 'address',
      },
      {
        internalType: 'uint32',
        name: 'rewardPerGas',
        type: 'uint32',
      },
    ],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'exit',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getCapacity',
    outputs: [
      {
        internalType: 'uint256',
        name: 'capacity',
        type: 'uint256',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint32',
        name: 'feePerGas',
        type: 'uint32',
      },
    ],
    name: 'getProverWeights',
    outputs: [
      {
        internalType: 'uint256[32]',
        name: 'weights',
        type: 'uint256[32]',
      },
      {
        internalType: 'uint32[32]',
        name: 'erpg',
        type: 'uint32[32]',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getProvers',
    outputs: [
      {
        components: [
          {
            internalType: 'uint64',
            name: 'stakedAmount',
            type: 'uint64',
          },
          {
            internalType: 'uint32',
            name: 'rewardPerGas',
            type: 'uint32',
          },
          {
            internalType: 'uint32',
            name: 'currentCapacity',
            type: 'uint32',
          },
        ],
        internalType: 'struct ProverPool.Prover[]',
        name: '_provers',
        type: 'tuple[]',
      },
      {
        internalType: 'address[]',
        name: '_stakers',
        type: 'address[]',
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
    name: 'getStaker',
    outputs: [
      {
        components: [
          {
            internalType: 'uint64',
            name: 'exitRequestedAt',
            type: 'uint64',
          },
          {
            internalType: 'uint64',
            name: 'exitAmount',
            type: 'uint64',
          },
          {
            internalType: 'uint32',
            name: 'maxCapacity',
            type: 'uint32',
          },
          {
            internalType: 'uint32',
            name: 'proverId',
            type: 'uint32',
          },
        ],
        internalType: 'struct ProverPool.Staker',
        name: 'staker',
        type: 'tuple',
      },
      {
        components: [
          {
            internalType: 'uint64',
            name: 'stakedAmount',
            type: 'uint64',
          },
          {
            internalType: 'uint32',
            name: 'rewardPerGas',
            type: 'uint32',
          },
          {
            internalType: 'uint32',
            name: 'currentCapacity',
            type: 'uint32',
          },
        ],
        internalType: 'struct ProverPool.Prover',
        name: 'prover',
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
        name: '_addressManager',
        type: 'address',
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
        internalType: 'uint256',
        name: 'id',
        type: 'uint256',
      },
    ],
    name: 'proverIdToAddress',
    outputs: [
      {
        internalType: 'address',
        name: 'prover',
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
        name: '',
        type: 'uint256',
      },
    ],
    name: 'provers',
    outputs: [
      {
        internalType: 'uint64',
        name: 'stakedAmount',
        type: 'uint64',
      },
      {
        internalType: 'uint32',
        name: 'rewardPerGas',
        type: 'uint32',
      },
      {
        internalType: 'uint32',
        name: 'currentCapacity',
        type: 'uint32',
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
    name: 'releaseProver',
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
    inputs: [
      {
        internalType: 'address',
        name: 'addr',
        type: 'address',
      },
      {
        internalType: 'uint64',
        name: 'proofReward',
        type: 'uint64',
      },
    ],
    name: 'slashProver',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint64',
        name: 'amount',
        type: 'uint64',
      },
      {
        internalType: 'uint32',
        name: 'rewardPerGas',
        type: 'uint32',
      },
      {
        internalType: 'uint32',
        name: 'maxCapacity',
        type: 'uint32',
      },
    ],
    name: 'stake',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'address',
        name: 'staker',
        type: 'address',
      },
    ],
    name: 'stakers',
    outputs: [
      {
        internalType: 'uint64',
        name: 'exitRequestedAt',
        type: 'uint64',
      },
      {
        internalType: 'uint64',
        name: 'exitAmount',
        type: 'uint64',
      },
      {
        internalType: 'uint32',
        name: 'maxCapacity',
        type: 'uint32',
      },
      {
        internalType: 'uint32',
        name: 'proverId',
        type: 'uint32',
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
    inputs: [],
    name: 'withdraw',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
];
