import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { defineConfig } from '@wagmi/cli'
import type { Abi, Address } from 'abitype'
import { existsSync, mkdirSync,readFileSync, writeFileSync } from 'fs'

import * as DevnetDeployment from '../nfts/deployments/snaefell/devnet.json'
import * as LocalhostDeployment from '../nfts/deployments/snaefell/localhost.json'
import SnaefellToken from '../nfts/out/SnaefellToken.sol/SnaefellToken.json'



function generateNetworkWhitelist(network: string){
    const tree = StandardMerkleTree.load(JSON.parse(
        readFileSync(
            `../nfts/data/snaefell/whitelist/${network}.json`,
             'utf8')
    ))

    writeFileSync(`./src/generated/whitelist/${network}.json`,
    JSON.stringify(tree.dump(), null, 2))

    console.log(`Whitelist merkle root for network ${network}: ${tree.root}`)

}
function generateWhitelistJson() {

    const whitelistDir = "./src/generated/whitelist";
    if (!existsSync(whitelistDir)) {
        mkdirSync(whitelistDir, { recursive: true });
    }

    generateNetworkWhitelist("hardhat");
    generateNetworkWhitelist('devnet')
}

generateWhitelistJson();

export default defineConfig({
    out: 'src/generated/abi/index.ts',
    contracts: [
        {
            name: 'SnaefellToken',
            address: {
                31337: LocalhostDeployment.SnaefellToken as Address,
                167001: DevnetDeployment.SnaefellToken as Address,
            },
            abi: SnaefellToken.abi as Abi,
        }
    ],
})
