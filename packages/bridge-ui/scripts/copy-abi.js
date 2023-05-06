import fs from 'fs-extra';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const protocolAbiPath = path.resolve(__dirname, '../../protocol/abi');
const abiOutputPath = path.resolve(__dirname, '../src/constants/abi');

const jsonFilesMap = {
  BRIDGE: '/contracts/bridge/Bridge.sol/Bridge.json',
  ERC20: '/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json',
  TOKEN_VAULT: '/contracts/bridge/TokenVault.sol/TokenVault.json',
  CROSS_CHAIN_SYNC:
    '/contracts/common/ICrossChainSync.sol/ICrossChainSync.json',
  FREE_MINT_ERC20: '/contracts/test/erc20/FreeMintERC20.sol/FreeMintERC20.json',
};

// Copy all ABI files to the output directory
function copyAbis() {
  Object.entries(jsonFilesMap).forEach(([, jsonPath]) => {
    try {
      const jsonStr = fs.readFileSync(protocolAbiPath + jsonPath, {
        encoding: 'utf8',
      });

      const filename = path.basename(jsonPath);

      fs.writeFileSync(`${abiOutputPath}/${filename}`, jsonStr, 'utf8');
    } catch (e) {
      if (e.code === 'ENOENT') {
        console.error(`File not found: ${e.path}`);
      } else {
        console.error('Something really bad happened 😱', e);
      }
    }
  });
}

// Generate index.ts file with exporting abi files
function generateIndexFile() {
  const indexFile = Object.entries(jsonFilesMap)
    .map(([name, jsonPath]) => {
      const filename = path.basename(jsonPath);
      return `export { default as ${name}_ABI } from './${filename}';`;
    })
    .join('\n');

  fs.writeFileSync(`${abiOutputPath}/index.ts`, indexFile, 'utf8');
}

// Remove all files within the directory but not the directory itself
fs.emptyDirSync(abiOutputPath);

copyAbis();

generateIndexFile();
