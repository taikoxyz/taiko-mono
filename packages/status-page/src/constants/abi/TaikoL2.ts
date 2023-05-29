export default [
  {
    inputs: [
      {
        internalType: "uint64",
        name: "expected",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "actual",
        type: "uint64",
      },
    ],
    name: "L2_BASEFEE_MISMATCH",
    type: "error",
  },
  {
    inputs: [],
    name: "L2_INVALID_1559_PARAMS",
    type: "error",
  },
  {
    inputs: [],
    name: "L2_INVALID_CHAIN_ID",
    type: "error",
  },
  {
    inputs: [],
    name: "L2_INVALID_GOLDEN_TOUCH_K",
    type: "error",
  },
  {
    inputs: [],
    name: "L2_INVALID_SENDER",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "expected",
        type: "bytes32",
      },
      {
        internalType: "bytes32",
        name: "actual",
        type: "bytes32",
      },
    ],
    name: "L2_PUBLIC_INPUT_HASH_MISMATCH",
    type: "error",
  },
  {
    inputs: [],
    name: "L2_TOO_LATE",
    type: "error",
  },
  {
    inputs: [],
    name: "M1559_OUT_OF_STOCK",
    type: "error",
  },
  {
    inputs: [],
    name: "M1559_OUT_OF_STOCK",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint64",
        name: "expected",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "actual",
        type: "uint64",
      },
    ],
    name: "M1559_UNEXPECTED_CHANGE",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint64",
        name: "expected",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "actual",
        type: "uint64",
      },
    ],
    name: "M1559_UNEXPECTED_CHANGE",
    type: "error",
  },
  {
    inputs: [],
    name: "Overflow",
    type: "error",
  },
  {
    inputs: [],
    name: "RESOLVER_DENIED",
    type: "error",
  },
  {
    inputs: [],
    name: "RESOLVER_INVALID_ADDR",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "chainId",
        type: "uint256",
      },
      {
        internalType: "bytes32",
        name: "name",
        type: "bytes32",
      },
    ],
    name: "RESOLVER_ZERO_ADDR",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "addressManager",
        type: "address",
      },
    ],
    name: "AddressManagerChanged",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint64",
        name: "number",
        type: "uint64",
      },
      {
        indexed: false,
        internalType: "uint64",
        name: "basefee",
        type: "uint64",
      },
      {
        indexed: false,
        internalType: "uint64",
        name: "gaslimit",
        type: "uint64",
      },
      {
        indexed: false,
        internalType: "uint64",
        name: "timestamp",
        type: "uint64",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "parentHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "prevrandao",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "coinbase",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint32",
        name: "chainid",
        type: "uint32",
      },
    ],
    name: "Anchored",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "srcHeight",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "blockHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "signalRoot",
        type: "bytes32",
      },
    ],
    name: "CrossChainSynced",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint8",
        name: "version",
        type: "uint8",
      },
    ],
    name: "Initialized",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferred",
    type: "event",
  },
  {
    inputs: [],
    name: "GOLDEN_TOUCH_ADDRESS",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "GOLDEN_TOUCH_PRIVATEKEY",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "addressManager",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "l1Hash",
        type: "bytes32",
      },
      {
        internalType: "bytes32",
        name: "l1SignalRoot",
        type: "bytes32",
      },
      {
        internalType: "uint64",
        name: "l1Height",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "parentGasUsed",
        type: "uint64",
      },
    ],
    name: "anchor",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "gasExcess",
    outputs: [
      {
        internalType: "uint64",
        name: "",
        type: "uint64",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint32",
        name: "timeSinceParent",
        type: "uint32",
      },
      {
        internalType: "uint64",
        name: "gasLimit",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "parentGasUsed",
        type: "uint64",
      },
    ],
    name: "getBasefee",
    outputs: [
      {
        internalType: "uint256",
        name: "_basefee",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "number",
        type: "uint256",
      },
    ],
    name: "getBlockHash",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "number",
        type: "uint256",
      },
    ],
    name: "getCrossChainBlockHash",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "number",
        type: "uint256",
      },
    ],
    name: "getCrossChainSignalRoot",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getEIP1559Config",
    outputs: [
      {
        components: [
          {
            internalType: "uint128",
            name: "yscale",
            type: "uint128",
          },
          {
            internalType: "uint64",
            name: "xscale",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "gasIssuedPerSecond",
            type: "uint64",
          },
        ],
        internalType: "struct TaikoL2.EIP1559Config",
        name: "",
        type: "tuple",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_addressManager",
        type: "address",
      },
      {
        components: [
          {
            internalType: "uint64",
            name: "basefee",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "gasIssuedPerSecond",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "gasExcessMax",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "gasTarget",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "ratio2x1x",
            type: "uint64",
          },
        ],
        internalType: "struct TaikoL2.EIP1559Params",
        name: "_param1559",
        type: "tuple",
      },
    ],
    name: "init",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "latestSyncedL1Height",
    outputs: [
      {
        internalType: "uint64",
        name: "",
        type: "uint64",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "parentTimestamp",
    outputs: [
      {
        internalType: "uint64",
        name: "",
        type: "uint64",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "publicInputHash",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "renounceOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "chainId",
        type: "uint256",
      },
      {
        internalType: "bytes32",
        name: "name",
        type: "bytes32",
      },
      {
        internalType: "bool",
        name: "allowZeroAddress",
        type: "bool",
      },
    ],
    name: "resolve",
    outputs: [
      {
        internalType: "address payable",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "name",
        type: "bytes32",
      },
      {
        internalType: "bool",
        name: "allowZeroAddress",
        type: "bool",
      },
    ],
    name: "resolve",
    outputs: [
      {
        internalType: "address payable",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newAddressManager",
        type: "address",
      },
    ],
    name: "setAddressManager",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "digest",
        type: "bytes32",
      },
      {
        internalType: "uint8",
        name: "k",
        type: "uint8",
      },
    ],
    name: "signAnchor",
    outputs: [
      {
        internalType: "uint8",
        name: "v",
        type: "uint8",
      },
      {
        internalType: "uint256",
        name: "r",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "s",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];
