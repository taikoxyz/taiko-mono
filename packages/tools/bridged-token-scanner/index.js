// index.js
import { JsonRpcProvider, ethers } from "ethers";
import { networks } from "./networks.js";
import { findDeploymentBlock, saveJSON, saveCSV } from "./utils.js";
import path from "path";
import fs from "fs/promises";

// Define the ABI for each vault type's BridgedTokenDeployed event
const BRIDGED_TOKEN_DEPLOYED_ABIS = {
  ERC20: [
    "event BridgedTokenDeployed(uint256 indexed srcChainId, address indexed ctoken, address indexed btoken, string ctokenSymbol, string ctokenName, uint8 ctokenDecimal)"
  ],
  ERC721: [
    "event BridgedTokenDeployed(uint64 indexed chainId, address indexed ctoken, address indexed btoken, string ctokenSymbol, string ctokenName)"
  ],
  ERC1155: [
    "event BridgedTokenDeployed(uint64 indexed chainId, address indexed ctoken, address indexed btoken, string ctokenSymbol, string ctokenName)"
  ]
};

async function getLastScannedBlock(dataDir, networkName, vaultName) {
  const safeName = networkName.replace(/[^a-zA-Z0-9-_]/g, "_");
  const dir = path.join(dataDir, safeName, `BridgedTokenDeployed_${vaultName}`);
  try {
    const files = await fs.readdir(dir);
    const chunkFiles = files.filter(f => f.startsWith("chunk_") && f.endsWith(".json"));
    const lastBlocks = chunkFiles.map(f => {
      const match = f.match(/^chunk_(\d+)_\d+_BridgedTokenDeployed\.json$/);
      return match ? parseInt(match[1]) : null;
    }).filter(Boolean);
    return lastBlocks.length > 0 ? Math.max(...lastBlocks) + 1 : null;
  } catch {
    return null;
  }
}

async function withRetry(fn, retries = 3, delayMs = 1000) {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      if (attempt === retries) throw err;
      console.warn(`⚠️ Retry ${attempt + 1}/${retries} after error: ${err.message}`);
      await new Promise(res => setTimeout(res, delayMs));
    }
  }
}

(async () => {
  const allEvents = [];

  for (const net of networks) {
    const { name, chainId, rpcUrl, erc20VaultAddress, erc721VaultAddress, erc1155VaultAddress } = net;
    let { fromBlock } = net;
    const toBlock = net.toBlock || "latest";

    console.log(`\n=== Connecting to ${name} (ChainID ${chainId}) ===`);
    const provider = new JsonRpcProvider(rpcUrl, chainId);

    const eventsByType = {
      BridgedTokenDeployed: []
    };

    try {
      const latestBlock = await provider.getBlockNumber();
      console.log(`Connected to ${name}. Latest block: ${latestBlock}`);

      if (fromBlock === 0 || fromBlock == null) {
        console.log(`Finding deployment block for vaults on ${name}...`);
        const deploymentBlock = await findDeploymentBlock(provider, erc20VaultAddress, latestBlock);
        fromBlock = deploymentBlock > 0 ? deploymentBlock : 0;
        console.log(`> Using start block: ${fromBlock}`);
      }

      const vaultContracts = [
        { name: "ERC20", address: erc20VaultAddress },
        { name: "ERC721", address: erc721VaultAddress },
        { name: "ERC1155", address: erc1155VaultAddress }
      ];

      const outputDir = "data";
      await fs.mkdir(outputDir, { recursive: true });

      // Determine resume block
      let startBlock = fromBlock;
      for (const vault of vaultContracts) {
        const last = await getLastScannedBlock(outputDir, name, vault.name);
        if (last !== null && last > startBlock) {
          startBlock = last;
        }
      }

      const chunkSize = 10000;
      let endBlock = toBlock === "latest" ? latestBlock : Number(toBlock);

      const csvHeaders = [
        "network", "chainId", "blockNumber", "txHash", "vaultType", "event",
        "srcChainId", "canonicalToken", "bridgedToken", "symbol", "name", "decimals"
      ];

      while (startBlock <= endBlock) {
        const chunkEnd = Math.min(startBlock + chunkSize - 1, endBlock);
        console.log(`- Fetching events in blocks [${startBlock}, ${chunkEnd}]`);

        for (const vault of vaultContracts) {
          const abi = BRIDGED_TOKEN_DEPLOYED_ABIS[vault.name];
          const contract = new ethers.Contract(vault.address, abi, provider);
          const events = await withRetry(() =>
            contract.queryFilter(contract.filters.BridgedTokenDeployed(), startBlock, chunkEnd)
          );

          const chunkRecords = events.map((evt) => {
            const { args, blockNumber, transactionHash } = evt;
            return {
              network: name,
              chainId,
              blockNumber,
              txHash: transactionHash,
              vaultType: vault.name,
              event: "BridgedTokenDeployed",
              srcChainId: (args.srcChainId || args.chainId).toString(),
              canonicalToken: args.ctoken,
              bridgedToken: args.btoken,
              symbol: args.ctokenSymbol,
              name: args.ctokenName,
              decimals: args.ctokenDecimal !== undefined ? args.ctokenDecimal.toString() : ""
            };
          });

          eventsByType.BridgedTokenDeployed.push(...chunkRecords);
          allEvents.push(...chunkRecords);

          const chunkLabel = `${startBlock}_${chunkEnd}`;
          const safeName = name.replace(/[^a-zA-Z0-9-_]/g, "_");
          const chunkDir = path.join(outputDir, safeName, `BridgedTokenDeployed_${vault.name}`);
          await fs.mkdir(chunkDir, { recursive: true });

          const jsonFile = path.join(chunkDir, `chunk_${chunkLabel}_BridgedTokenDeployed.json`);
          const csvFile = path.join(chunkDir, `chunk_${chunkLabel}_BridgedTokenDeployed.csv`);
          await fs.writeFile(jsonFile, JSON.stringify(chunkRecords, null, 2), "utf8");
          await saveCSV(csvFile, chunkRecords, csvHeaders);

          if (chunkRecords.length > 0) {
            console.log(`> Found ${chunkRecords.length} BridgedTokenDeployed events in chunk for ${vault.name}.`);
          }
        }

        startBlock = chunkEnd + 1;
      }

    } catch (err) {
      console.error(`Error processing network ${name} (Chain ${chainId}):`, err);
      continue;
    }
  }
})();
