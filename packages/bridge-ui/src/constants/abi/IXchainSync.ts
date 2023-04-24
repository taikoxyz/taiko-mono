export default [
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
    name: 'XchainSynced',
    type: 'event',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'number',
        type: 'uint256',
      },
    ],
    name: 'getXchainBlockHash',
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
        name: 'number',
        type: 'uint256',
      },
    ],
    name: 'getXchainSignalRoot',
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
];
