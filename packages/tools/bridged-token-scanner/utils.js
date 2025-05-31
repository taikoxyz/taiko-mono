// utils.js
import { promises as fs } from "fs";
import { JsonRpcProvider } from "ethers";

/**
 * Finds the deployment block of a contract by checking when its code became non-empty.
 * Uses binary search between block 0 and latestBlock to locate the first block where code exists.
 * @param {ethers.providers.Provider} provider - An initialized ethers provider for the network.
 * @param {string} address - Contract address to check.
 * @param {number} latestBlock - The latest block number to consider (usually current head of chain).
 * @returns {Promise<number>} - The block number where the contract was deployed (or 0 if at genesis or not found).
 */
export async function findDeploymentBlock(provider, address, latestBlock) {
  let start = 0;
  let end = latestBlock;
  let deploymentBlock = 0;
  try {
    // Quick check: if code already exists at genesis (block 0), assume deployment at genesis.
    const codeAtGenesis = await provider.getCode(address, 0);
    if (codeAtGenesis && codeAtGenesis !== "0x") {
      return 0;
    }
    // Binary search for the first block with contract code
    while (start <= end) {
      const mid = Math.floor((start + end) / 2);
      const code = await provider.getCode(address, mid);
      if (code && code !== "0x") {
        // Found code at `mid`, contract exists here; record and search lower half
        deploymentBlock = mid;
        end = mid - 1;
      } else {
        // No code at `mid`, search higher half
        start = mid + 1;
      }
    }
  } catch (err) {
    console.error(`Error finding deployment block for ${address}:`, err);
    return 0;  // Fallback to 0 if any error occurs
  }
  return deploymentBlock;
}

/**
 * Save data as a JSON file.
 * @param {string} filename - The name of the file (e.g., "bridged_tokens.json").
 * @param {Object|Array} data - The data to write (will be JSON-stringified).
 */
export async function saveJSON(filename, data) {
  const jsonStr = JSON.stringify(data, null, 2);  // pretty-print with 2-space indentation
  try {
    await fs.writeFile(filename, jsonStr, 'utf-8');
    console.log(`✅ Successfully saved JSON data to ${filename}`);
  } catch (err) {
    console.error(`❌ Error writing JSON to ${filename}:`, err);
  }
}

/**
 * Save data as a CSV file.
 * @param {string} filename - The name of the CSV file (e.g., "bridged_tokens.csv").
 * @param {Array<Object>} rows - Array of objects representing rows of data.
 * @param {Array<string>} headers - Ordered list of headers/keys to include as columns.
 */
export async function saveCSV(filename, rows, headers) {
  try {
    // Construct CSV header line
    const headerLine = headers.join(',');
    // Construct each data line by mapping headers to row values
    const lines = rows.map(row => {
      return headers.map(field => {
        let value = row[field];
        // If the value contains a comma or newline, wrap it in quotes (basic CSV escaping)
        if (typeof value === 'string' && (value.includes(',') || value.includes('\n'))) {
          value = `"${value.replace(/"/g, '""')}"`;  // also double-up any quotes inside
        }
        return value !== undefined ? value : '';
      }).join(',');
    });
    // Combine header and lines
    const csvContent = [headerLine, ...lines].join('\n');
    await fs.writeFile(filename, csvContent, 'utf-8');
    console.log(`✅ Successfully saved CSV data to ${filename}`);
  } catch (err) {
    console.error(`❌ Error writing CSV to ${filename}:`, err);
  }
}
