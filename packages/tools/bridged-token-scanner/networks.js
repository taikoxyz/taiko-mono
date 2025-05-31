// networks.js
/**
 * Network configuration for L1 and L2 (testnet and mainnet).
 * Contains RPC endpoints, chain IDs, human-readable names, and ERC20Vault contract addresses.
 */
export const networks = [
  {
    name: "L1 Testnet (Holesky)",
    chainId: 17000,
    rpcUrl: "https://l1rpc.hekla.taiko.xyz/",  // Holesky testnet RPC:contentReference[oaicite:7]{index=7}
    erc20VaultAddress: "0x2259662ed5dE0E09943Abe701bc5f5a108eABBAa",  // ERC20Vault on Holesky
    erc721VaultAddress: "0x046b82D9010b534c716742BE98ac3FEf3f2EC99f",  // ERC721Vault on Holesky
    erc1155VaultAddress: "0x9Ae5945Ab34f6182F75E16B73e037421F341fEe3",  // ERC1155Vault on Holesky
    fromBlock: 1528000   // can be set to deployment block for efficiency (0 means genesis/scan from start)
  },
  {
    name: "L2 Testnet (Taiko Hekla)",
    chainId: 167009,
    rpcUrl: "https://rpc.hekla.taiko.xyz",             // Taiko Hekla testnet RPC:contentReference[oaicite:8]{index=8}
    erc20VaultAddress: "0x1670090000000000000000000000000000000002",  // ERC20Vault on Hekla
    erc721VaultAddress: "0x1670090000000000000000000000000000000003",  // ERC721Vault on Hekla
    erc1155VaultAddress: "0x1670090000000000000000000000000000000004",  // ERC1155Vault on Hekla
    fromBlock: 0   // 0 if contract was deployed at genesis on L2
  },
  {
    name: "L1 Mainnet (Ethereum)",
    chainId: 1,
    rpcUrl: "https://l1rpc.mainnet.taiko.xyz/",                 // e.g., Infura/Alchemy URL or own node
    erc20VaultAddress: "0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab",  // ERC20Vault on Ethereum mainnet
    erc721VaultAddress: "0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa",  // ERC721Vault on Ethereum mainnet
    erc1155VaultAddress: "0xaf145913EA4a56BE22E120ED9C24589659881702",  // ERC1155Vault on Ethereum mainnet
    fromBlock: 19773000   // (Recommended to set this to the deployment block of vault on mainnet)
  },
  {
    name: "L2 Mainnet (Taiko Alethia)",
    chainId: 167000,
    rpcUrl: "https://rpc.mainnet.taiko.xyz",          // Taiko Alethia mainnet RPC:contentReference[oaicite:9]{index=9}
    erc20VaultAddress: "0x1670000000000000000000000000000000000002",  // ERC20Vault on Alethia:contentReference[oaicite:10]{index=10}
    erc721VaultAddress: "0x1670000000000000000000000000000000000003",  // ERC721Vault on Alethia:contentReference[oaicite:11]{index=11}
    erc1155VaultAddress: "0x1670000000000000000000000000000000000004",  // ERC1155Vault on Alethia:contentReference[oaicite:12]{index=12}
    fromBlock: 0   // (If deployed at genesis, keep 0; otherwise set deployment block)
  }
];
