// combine-bridged-events.js
import fs from "fs/promises";
import path from "path";
import { ethers } from "ethers";
import { saveCSV } from "./utils.js";
import { networks } from "./networks.js";

const dataDir = "data";
const outputDir = "combined";
const vaultTypes = ["ERC20", "ERC721", "ERC1155"];

const csvHeaders = [
  "network",
  "chainId",
  "blockNumber",
  "txHash",
  "vaultType",
  "event",
  "srcChainId",
  "canonicalToken",
  "bridgedToken",
  "symbol",
  "name",
  "decimals",
  "contractOwner",
];

const OWNABLE_ABI = ["function owner() view returns (address)"];

async function fetchOwner(provider, address) {
  try {
    const contract = new ethers.Contract(address, OWNABLE_ABI, provider);
    return await contract.owner();
  } catch (err) {
    console.warn(`⚠️ Failed to fetch owner for ${address}: ${err.message}`);
    return "";
  }
}

async function collectChunkFilesByVault(rootDir) {
  const fileMap = {}; // key: `${network}:::${vaultType}`

  const networkDirs = await fs.readdir(rootDir);
  for (const networkDir of networkDirs) {
    const vaultDirs = await fs.readdir(path.join(rootDir, networkDir));
    for (const vaultDir of vaultDirs) {
      for (const vaultType of vaultTypes) {
        if (vaultDir === `BridgedTokenDeployed_${vaultType}`) {
          const fullDir = path.join(rootDir, networkDir, vaultDir);
          try {
            const files = await fs.readdir(fullDir);
            const chunkFiles = files.filter(
              (f) => f.startsWith("chunk_") && f.endsWith(".json"),
            );
            const key = `${networkDir}:::${vaultType}`;
            fileMap[key] = chunkFiles.map((f) => path.join(fullDir, f));
          } catch (err) {
            console.warn(
              `⚠️ Failed to read directory ${fullDir}: ${err.message}`,
            );
          }
        }
      }
    }
  }

  return fileMap;
}

(async () => {
  const fileMap = await collectChunkFilesByVault(dataDir);
  await fs.mkdir(outputDir, { recursive: true });

  for (const [key, files] of Object.entries(fileMap)) {
    const [network, vaultType] = key.split(":::");
    const matchedNet = networks.find(
      (n) => n.name.replaceAll(" ", "_") === network,
    );
    if (!matchedNet?.rpcUrl) {
      console.error(`❌ Missing RPC URL for network: ${network}`);
      continue;
    }

    const provider = new ethers.JsonRpcProvider(matchedNet.rpcUrl);
    const merged = [];

    for (const file of files) {
      try {
        const content = await fs.readFile(file, "utf8");
        const records = JSON.parse(content);
        merged.push(...records);
      } catch (err) {
        console.error(`❌ Failed to load ${file}: ${err.message}`);
      }
    }

    // Deduplicate by txHash + logIndex (canonical EVM event key)
    const unique = new Map();
    for (const r of merged) {
      if (!r.txHash || r.logIndex == null) {
        console.warn("⚠️ Skipping malformed record", r);
        continue;
      }
      const key = `${r.txHash}-${r.logIndex}`;
      if (unique.has(key)) {
        console.warn(`⚠️ Duplicate detected: ${key}`);
        continue;
      }
      unique.set(key, r);
    }

    const deduped = Array.from(unique.values());

    // Fetch owners for unique bridgedToken addresses
    const ownerCache = {};
    const uniqueAddresses = [
      ...new Set(deduped.map((e) => e.bridgedToken).filter(Boolean)),
    ];
    for (const addr of uniqueAddresses) {
      ownerCache[addr] = await fetchOwner(provider, addr);
    }

    // Attach contractOwner
    for (const record of deduped) {
      record.contractOwner = ownerCache[record.bridgedToken] || "";
    }

    const filenameBase = `${network}_${vaultType}_BridgedTokenDeployed`;
    const jsonFile = path.join(outputDir, `${filenameBase}.json`);
    const csvFile = path.join(outputDir, `${filenameBase}.csv`);

    await fs.writeFile(jsonFile, JSON.stringify(deduped, null, 2), "utf8");
    await saveCSV(csvFile, deduped, csvHeaders);

    console.log(
      `✅ Combined ${files.length} chunks into ${deduped.length} records for ${network} ${vaultType}`,
    );
  }
})();
