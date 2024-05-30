import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { defineConfig } from '@wagmi/cli';
import type { Abi, Address } from 'abitype';
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'fs';

import * as LocalhostDeployment from '../nfts/deployments/taikoon/localhost.json';
import * as MainnetDeployment from '../nfts/deployments/taikoon/mainnet.json';
import TaikoonToken from '../nfts/out/TaikoonToken.sol/TaikoonToken.json';

function generateNetworkWhitelist(network: string) {
  const tree = StandardMerkleTree.load(
    JSON.parse(readFileSync(`../nfts/data/taikoon/whitelist/${network}.json`, 'utf8')),
  );

  writeFileSync(`./src/generated/whitelist/${network}.json`, JSON.stringify(tree.dump(), null, 2));

  console.log(`Whitelist merkle root for network ${network}: ${tree.root}`);
}
function generateWhitelistJson() {
  const whitelistDir = './src/generated/whitelist';
  if (!existsSync(whitelistDir)) {
    mkdirSync(whitelistDir, { recursive: true });
  }
  const whitelistFiles = readdirSync(whitelistDir);

  whitelistFiles.forEach((file) => {
    // Skip files that are not csv
    if (file.endsWith('.csv') === false) {
      return;
    }

    // extract filename without extension
    const network = file.split('.')[0];
    generateNetworkWhitelist(network);
  });
}

generateWhitelistJson();

export default defineConfig({
  out: 'src/generated/abi/index.ts',
  contracts: [
    {
      name: 'TaikoonToken',
      address: {
        31337: LocalhostDeployment.TaikoonToken as Address,
        //17000: HoleskyDeployment.TaikoonToken as Address,
        167000: MainnetDeployment.TaikoonToken as Address,
      },
      abi: TaikoonToken.abi as Abi,
    },
  ],
});
