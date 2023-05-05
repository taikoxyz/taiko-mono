import fs from 'fs-extra';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const protocolAbiPath = path.resolve(__dirname, '../../protocol/abi');
const abiOutputPath = path.resolve(__dirname, '../src/constants/abi');

const jsonFilesMap = {
  Bridge: '/contracts/bridge/Bridge.sol/Bridge.json',
  ERC20: '/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json',
  TokenVault: '/contracts/bridge/TokenVault.sol/TokenVault.json',
  CrossChainSync: '/contracts/common/ICrossChainSync.sol/ICrossChainSync.json',
  FreeMintERC20: '/contracts/test/erc20/FreeMintERC20.sol/FreeMintERC20.json',
};

// Remove all files within the directory but not the directory itself
fs.emptyDirSync(abiOutputPath);

Object.entries(jsonFilesMap).forEach(([name, jsonPath]) => {
  try {
    const jsonStr = fs.readFileSync(protocolAbiPath + jsonPath, {
      encoding: 'utf8',
    });

    fs.writeFileSync(`${abiOutputPath}/${name}.json`, jsonStr, 'utf8');
  } catch (e) {
    if (e.code === 'ENOENT') {
      console.error(`File not found: ${e.path}`);
    } else {
      console.error('Something really bad happened 😱', e);
    }
  }
});
