export const SafeProxyFactoryABI = [
  {
    type: 'function',
    name: 'createProxyWithNonce',
    inputs: [
      { name: '_singleton', type: 'address' },
      { name: 'initializer', type: 'bytes' },
      { name: 'saltNonce', type: 'uint256' },
    ],
    outputs: [{ name: 'proxy', type: 'address' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'event',
    name: 'ProxyCreation',
    inputs: [
      { name: 'proxy', type: 'address', indexed: true },
      { name: 'singleton', type: 'address', indexed: false },
    ],
  },
] as const;

export const SafeProxyFactoryFullABI = [
  ...SafeProxyFactoryABI,
  {
    type: 'function',
    name: 'proxyCreationCode',
    inputs: [],
    outputs: [{ name: '', type: 'bytes' }],
    stateMutability: 'view',
  },
] as const;

export const SafeABI = [
  {
    type: 'function',
    name: 'setup',
    inputs: [
      { name: '_owners', type: 'address[]' },
      { name: '_threshold', type: 'uint256' },
      { name: 'to', type: 'address' },
      { name: 'data', type: 'bytes' },
      { name: 'fallbackHandler', type: 'address' },
      { name: 'paymentToken', type: 'address' },
      { name: 'payment', type: 'uint256' },
      { name: 'paymentReceiver', type: 'address' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'execTransaction',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'value', type: 'uint256' },
      { name: 'data', type: 'bytes' },
      { name: 'operation', type: 'uint8' },
      { name: 'safeTxGas', type: 'uint256' },
      { name: 'baseGas', type: 'uint256' },
      { name: 'gasPrice', type: 'uint256' },
      { name: 'gasToken', type: 'address' },
      { name: 'refundReceiver', type: 'address' },
      { name: 'signatures', type: 'bytes' },
    ],
    outputs: [{ name: 'success', type: 'bool' }],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'nonce',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getOwners',
    inputs: [],
    outputs: [{ name: '', type: 'address[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getTransactionHash',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'value', type: 'uint256' },
      { name: 'data', type: 'bytes' },
      { name: 'operation', type: 'uint8' },
      { name: 'safeTxGas', type: 'uint256' },
      { name: 'baseGas', type: 'uint256' },
      { name: 'gasPrice', type: 'uint256' },
      { name: 'gasToken', type: 'address' },
      { name: 'refundReceiver', type: 'address' },
      { name: '_nonce', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'SafeSetup',
    inputs: [
      { name: 'initiator', type: 'address', indexed: true },
      { name: 'owners', type: 'address[]', indexed: false },
      { name: 'threshold', type: 'uint256', indexed: false },
      { name: 'initializer', type: 'address', indexed: false },
      { name: 'fallbackHandler', type: 'address', indexed: false },
    ],
  },
] as const;

export const MultiSendABI = [
  {
    type: 'function',
    name: 'multiSend',
    inputs: [{ name: 'transactions', type: 'bytes' }],
    outputs: [],
    stateMutability: 'payable',
  },
] as const;

export const CrossChainSwapVaultL1ABI = [
  {
    type: 'function',
    name: 'swapETHForToken',
    inputs: [
      { name: '_minTokenOut', type: 'uint256' },
      { name: '_recipient', type: 'address' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'swapTokenForETH',
    inputs: [
      { name: '_tokenAmount', type: 'uint256' },
      { name: '_minETHOut', type: 'uint256' },
      { name: '_recipient', type: 'address' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'bridgeTokenToL2',
    inputs: [
      { name: '_amount', type: 'uint256' },
      { name: '_recipient', type: 'address' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'addLiquidityToL2',
    inputs: [
      { name: '_tokenAmount', type: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'removeLiquidityFromL2',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'swapToken',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
  },
] as const;

export const SimpleDEXABI = [
  {
    type: 'function',
    name: 'getReserves',
    inputs: [],
    outputs: [
      { name: 'ethReserve_', type: 'uint256' },
      { name: 'tokenReserve_', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getAmountOut',
    inputs: [
      { name: '_amountIn', type: 'uint256' },
      { name: '_reserveIn', type: 'uint256' },
      { name: '_reserveOut', type: 'uint256' },
    ],
    outputs: [{ name: 'amountOut_', type: 'uint256' }],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    name: 'reserveETH',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'reserveToken',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getLiquidity',
    inputs: [{ name: '_provider', type: 'address' }],
    outputs: [
      { name: 'ethAmount_', type: 'uint256' },
      { name: 'tokenAmount_', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
] as const;

export const BridgeABI = [
  {
    type: 'function',
    name: 'sendMessage',
    inputs: [
      {
        name: '_message',
        type: 'tuple',
        components: [
          { name: 'id', type: 'uint64' },
          { name: 'fee', type: 'uint64' },
          { name: 'gasLimit', type: 'uint32' },
          { name: 'from', type: 'address' },
          { name: 'srcChainId', type: 'uint64' },
          { name: 'srcOwner', type: 'address' },
          { name: 'destChainId', type: 'uint64' },
          { name: 'destOwner', type: 'address' },
          { name: 'to', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'data', type: 'bytes' },
        ],
      },
    ],
    outputs: [
      { name: 'msgHash_', type: 'bytes32' },
      {
        name: 'message_',
        type: 'tuple',
        components: [
          { name: 'id', type: 'uint64' },
          { name: 'fee', type: 'uint64' },
          { name: 'gasLimit', type: 'uint32' },
          { name: 'from', type: 'address' },
          { name: 'srcChainId', type: 'uint64' },
          { name: 'srcOwner', type: 'address' },
          { name: 'destChainId', type: 'uint64' },
          { name: 'destOwner', type: 'address' },
          { name: 'to', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'data', type: 'bytes' },
        ],
      },
    ],
    stateMutability: 'payable',
  },
] as const;

export const ERC20ABI = [
  {
    type: 'function',
    name: 'balanceOf',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'approve',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'allowance',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'transfer',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'nonpayable',
  },
] as const;
