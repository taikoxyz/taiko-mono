export const MAX_CHECKPOINT_SEARCH_BLOCKS = 10000n;

export const anchorGetBlockStateAbi = [
  {
    type: 'function',
    name: 'getBlockState',
    inputs: [],
    outputs: [
      {
        type: 'tuple',
        components: [
          { name: 'anchorBlockNumber', type: 'uint48' },
          { name: 'ancestorsHash', type: 'bytes32' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'checkpointStore',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
  },
] as const;
