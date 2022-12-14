export default [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "height",
        type: "uint256",
      },
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
];
