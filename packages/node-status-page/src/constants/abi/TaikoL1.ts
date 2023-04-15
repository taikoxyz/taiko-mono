export default [
  {
    inputs: [],
    name: "L1_0_FEE_BASE",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_0_FEE_BASE",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ALREADY_PROVEN",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ANCHOR_CALLDATA",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ANCHOR_DEST",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ANCHOR_GAS_LIMIT",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ANCHOR_RECEIPT_ADDR",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ANCHOR_RECEIPT_DATA",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ANCHOR_RECEIPT_LOGS",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ANCHOR_RECEIPT_PROOF",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ANCHOR_RECEIPT_STATUS",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ANCHOR_RECEIPT_TOPICS",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ANCHOR_SIG_R",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ANCHOR_SIG_S",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ANCHOR_TX_PROOF",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ANCHOR_TYPE",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_BLOCK_NUMBER",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_BLOCK_NUMBER",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_CANNOT_BE_FIRST_PROVER",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_COMMITTED",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_CONFLICT_PROOF",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_CONTRACT_NOT_ALLOWED",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_DUP_PROVERS",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_EXTRA_DATA",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_GAS_LIMIT",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ID",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ID",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_INPUT_SIZE",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_INVALID_CONFIG",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_INVALID_CONFIG",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_INVALID_PARAM",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_METADATA_FIELD",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_META_MISMATCH",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_NOT_COMMITTED",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_NOT_ORACLE_PROVER",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_PROOF_LENGTH",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_PROVER",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_SOLO_PROPOSER",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_TOO_MANY_BLOCKS",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_TX_LIST",
    type: "error",
  },
  {
    inputs: [],
    name: "L1_ZKP",
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
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "uint64",
        name: "commitSlot",
        type: "uint64",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "commitHash",
        type: "bytes32",
      },
    ],
    name: "BlockCommitted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
      {
        components: [
          {
            internalType: "uint256",
            name: "id",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "l1Height",
            type: "uint256",
          },
          {
            internalType: "bytes32",
            name: "l1Hash",
            type: "bytes32",
          },
          {
            internalType: "address",
            name: "beneficiary",
            type: "address",
          },
          {
            internalType: "bytes32",
            name: "txListHash",
            type: "bytes32",
          },
          {
            internalType: "bytes32",
            name: "mixHash",
            type: "bytes32",
          },
          {
            internalType: "bytes",
            name: "extraData",
            type: "bytes",
          },
          {
            internalType: "uint64",
            name: "gasLimit",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "timestamp",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "commitHeight",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "commitSlot",
            type: "uint64",
          },
        ],
        indexed: false,
        internalType: "struct TaikoData.BlockMetadata",
        name: "meta",
        type: "tuple",
      },
    ],
    name: "BlockProposed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "parentHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "blockHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "address",
        name: "prover",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint64",
        name: "provenAt",
        type: "uint64",
      },
    ],
    name: "BlockProven",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "blockHash",
        type: "bytes32",
      },
    ],
    name: "BlockVerified",
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
        name: "srcHash",
        type: "bytes32",
      },
    ],
    name: "HeaderSynced",
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
        internalType: "uint64",
        name: "commitSlot",
        type: "uint64",
      },
      {
        internalType: "bytes32",
        name: "commitHash",
        type: "bytes32",
      },
    ],
    name: "commitBlock",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "getBlockFee",
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
    name: "getConfig",
    outputs: [
      {
        components: [
          {
            internalType: "uint256",
            name: "chainId",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "maxNumBlocks",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "blockHashHistory",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "maxVerificationsPerTx",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "commitConfirmations",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "blockMaxGasLimit",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "maxTransactionsPerBlock",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "maxBytesPerTxList",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "minTxGasLimit",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "anchorTxGasLimit",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "slotSmoothingFactor",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "rewardBurnBips",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "proposerDepositPctg",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "feeBaseMAF",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "blockTimeMAF",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "proofTimeMAF",
            type: "uint256",
          },
          {
            internalType: "uint64",
            name: "rewardMultiplierPctg",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "feeGracePeriodPctg",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "feeMaxPeriodPctg",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "blockTimeCap",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "proofTimeCap",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "bootstrapDiscountHalvingPeriod",
            type: "uint64",
          },
          {
            internalType: "bool",
            name: "enableTokenomics",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "enablePublicInputsCheck",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "enableAnchorValidation",
            type: "bool",
          },
        ],
        internalType: "struct TaikoData.Config",
        name: "",
        type: "tuple",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "id",
        type: "uint256",
      },
      {
        internalType: "bytes32",
        name: "parentHash",
        type: "bytes32",
      },
    ],
    name: "getForkChoice",
    outputs: [
      {
        components: [
          {
            internalType: "bytes32",
            name: "blockHash",
            type: "bytes32",
          },
          {
            internalType: "address",
            name: "prover",
            type: "address",
          },
          {
            internalType: "uint64",
            name: "provenAt",
            type: "uint64",
          },
        ],
        internalType: "struct TaikoData.ForkChoice",
        name: "",
        type: "tuple",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getLatestSyncedHeader",
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
        internalType: "uint64",
        name: "provenAt",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "proposedAt",
        type: "uint64",
      },
    ],
    name: "getProofReward",
    outputs: [
      {
        internalType: "uint256",
        name: "reward",
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
        name: "id",
        type: "uint256",
      },
    ],
    name: "getProposedBlock",
    outputs: [
      {
        components: [
          {
            internalType: "bytes32",
            name: "metaHash",
            type: "bytes32",
          },
          {
            internalType: "uint256",
            name: "deposit",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "proposer",
            type: "address",
          },
          {
            internalType: "uint64",
            name: "proposedAt",
            type: "uint64",
          },
        ],
        internalType: "struct TaikoData.ProposedBlock",
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
        name: "addr",
        type: "address",
      },
    ],
    name: "getRewardBalance",
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
    name: "getStateVariables",
    outputs: [
      {
        components: [
          {
            internalType: "uint256",
            name: "feeBase",
            type: "uint256",
          },
          {
            internalType: "uint64",
            name: "genesisHeight",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "genesisTimestamp",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "nextBlockId",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "lastProposedAt",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "avgBlockTime",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "latestVerifiedHeight",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "latestVerifiedId",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "avgProofTime",
            type: "uint64",
          },
        ],
        internalType: "struct LibUtils.StateVariables",
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
        internalType: "uint256",
        name: "number",
        type: "uint256",
      },
    ],
    name: "getSyncedHeader",
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
        internalType: "address",
        name: "_addressManager",
        type: "address",
      },
      {
        internalType: "bytes32",
        name: "_genesisBlockHash",
        type: "bytes32",
      },
      {
        internalType: "uint256",
        name: "_feeBase",
        type: "uint256",
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
        name: "commitSlot",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "commitHeight",
        type: "uint256",
      },
      {
        internalType: "bytes32",
        name: "commitHash",
        type: "bytes32",
      },
    ],
    name: "isCommitValid",
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
        internalType: "bytes[]",
        name: "inputs",
        type: "bytes[]",
      },
    ],
    name: "proposeBlock",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "blockId",
        type: "uint256",
      },
      {
        internalType: "bytes[]",
        name: "inputs",
        type: "bytes[]",
      },
    ],
    name: "proveBlock",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "blockId",
        type: "uint256",
      },
      {
        internalType: "bytes[]",
        name: "inputs",
        type: "bytes[]",
      },
    ],
    name: "proveBlockInvalid",
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
        internalType: "uint256",
        name: "chainId",
        type: "uint256",
      },
      {
        internalType: "string",
        name: "name",
        type: "string",
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
        name: "hash",
        type: "bytes32",
      },
      {
        internalType: "uint8",
        name: "k",
        type: "uint8",
      },
    ],
    name: "signWithGoldenTouch",
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
    inputs: [],
    name: "state",
    outputs: [
      {
        internalType: "uint64",
        name: "genesisHeight",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "genesisTimestamp",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "__reservedA1",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "__reservedA2",
        type: "uint64",
      },
      {
        internalType: "uint256",
        name: "feeBase",
        type: "uint256",
      },
      {
        internalType: "uint64",
        name: "nextBlockId",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "lastProposedAt",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "avgBlockTime",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "__avgGasLimit",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "latestVerifiedHeight",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "latestVerifiedId",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "avgProofTime",
        type: "uint64",
      },
      {
        internalType: "uint64",
        name: "__reservedC1",
        type: "uint64",
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
  {
    inputs: [
      {
        internalType: "uint256",
        name: "maxBlocks",
        type: "uint256",
      },
    ],
    name: "verifyBlocks",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "withdrawBalance",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];
