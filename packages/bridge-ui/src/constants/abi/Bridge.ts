export default [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "chainId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bool",
        name: "enabled",
        type: "bool",
      },
    ],
    name: "DestChainEnabled",
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
        internalType: "bytes32",
        name: "signal",
        type: "bytes32",
      },
      {
        components: [
          {
            internalType: "uint256",
            name: "id",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "sender",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "srcChainId",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "destChainId",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "owner",
            type: "address",
          },
          {
            internalType: "address",
            name: "to",
            type: "address",
          },
          {
            internalType: "address",
            name: "refundAddress",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "depositValue",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "callValue",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "processingFee",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "gasLimit",
            type: "uint256",
          },
          {
            internalType: "bytes",
            name: "data",
            type: "bytes",
          },
          {
            internalType: "string",
            name: "memo",
            type: "string",
          },
        ],
        indexed: false,
        internalType: "struct IBridge.Message",
        name: "message",
        type: "tuple",
      },
    ],
    name: "MessageSent",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "signal",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "enum LibBridgeStatus.MessageStatus",
        name: "status",
        type: "uint8",
      },
    ],
    name: "MessageStatusChanged",
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
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "signal",
        type: "bytes32",
      },
    ],
    name: "SignalSent",
    type: "event",
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
    inputs: [],
    name: "context",
    outputs: [
      {
        components: [
          {
            internalType: "bytes32",
            name: "signal",
            type: "bytes32",
          },
          {
            internalType: "address",
            name: "sender",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "srcChainId",
            type: "uint256",
          },
        ],
        internalType: "struct IBridge.Context",
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
        internalType: "bytes32",
        name: "signal",
        type: "bytes32",
      },
    ],
    name: "getMessageStatus",
    outputs: [
      {
        internalType: "enum LibBridgeStatus.MessageStatus",
        name: "",
        type: "uint8",
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
    ],
    name: "init",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_chainId",
        type: "uint256",
      },
    ],
    name: "isDestChainEnabled",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "signal",
        type: "bytes32",
      },
      {
        internalType: "uint256",
        name: "srcChainId",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "proof",
        type: "bytes",
      },
    ],
    name: "isMessageReceived",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "signal",
        type: "bytes32",
      },
    ],
    name: "isMessageSent",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "signal",
        type: "bytes32",
      },
      {
        internalType: "uint256",
        name: "srcChainId",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        internalType: "bytes",
        name: "proof",
        type: "bytes",
      },
    ],
    name: "isSignalReceived",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        internalType: "bytes32",
        name: "signal",
        type: "bytes32",
      },
    ],
    name: "isSignalSent",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
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
    inputs: [
      {
        components: [
          {
            internalType: "uint256",
            name: "id",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "sender",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "srcChainId",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "destChainId",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "owner",
            type: "address",
          },
          {
            internalType: "address",
            name: "to",
            type: "address",
          },
          {
            internalType: "address",
            name: "refundAddress",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "depositValue",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "callValue",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "processingFee",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "gasLimit",
            type: "uint256",
          },
          {
            internalType: "bytes",
            name: "data",
            type: "bytes",
          },
          {
            internalType: "string",
            name: "memo",
            type: "string",
          },
        ],
        internalType: "struct IBridge.Message",
        name: "message",
        type: "tuple",
      },
      {
        internalType: "bytes",
        name: "proof",
        type: "bytes",
      },
    ],
    name: "processMessage",
    outputs: [],
    stateMutability: "nonpayable",
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
        internalType: "string",
        name: "name",
        type: "string",
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
        internalType: "uint256",
        name: "chainId",
        type: "uint256",
      },
      {
        internalType: "string",
        name: "name",
        type: "string",
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
        components: [
          {
            internalType: "uint256",
            name: "id",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "sender",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "srcChainId",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "destChainId",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "owner",
            type: "address",
          },
          {
            internalType: "address",
            name: "to",
            type: "address",
          },
          {
            internalType: "address",
            name: "refundAddress",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "depositValue",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "callValue",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "processingFee",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "gasLimit",
            type: "uint256",
          },
          {
            internalType: "bytes",
            name: "data",
            type: "bytes",
          },
          {
            internalType: "string",
            name: "memo",
            type: "string",
          },
        ],
        internalType: "struct IBridge.Message",
        name: "message",
        type: "tuple",
      },
      {
        internalType: "bool",
        name: "isLastAttempt",
        type: "bool",
      },
    ],
    name: "retryMessage",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        components: [
          {
            internalType: "uint256",
            name: "id",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "sender",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "srcChainId",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "destChainId",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "owner",
            type: "address",
          },
          {
            internalType: "address",
            name: "to",
            type: "address",
          },
          {
            internalType: "address",
            name: "refundAddress",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "depositValue",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "callValue",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "processingFee",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "gasLimit",
            type: "uint256",
          },
          {
            internalType: "bytes",
            name: "data",
            type: "bytes",
          },
          {
            internalType: "string",
            name: "memo",
            type: "string",
          },
        ],
        internalType: "struct IBridge.Message",
        name: "message",
        type: "tuple",
      },
    ],
    name: "sendMessage",
    outputs: [
      {
        internalType: "bytes32",
        name: "signal",
        type: "bytes32",
      },
    ],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "signal",
        type: "bytes32",
      },
    ],
    name: "sendSignal",
    outputs: [],
    stateMutability: "nonpayable",
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
  {
    stateMutability: "payable",
    type: "receive",
  },
];
