import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { defineConfig } from '@wagmi/cli'
import type { Abi, Address } from 'abitype'
import { existsSync, mkdirSync,readFileSync, writeFileSync } from 'fs'

import * as DevnetDeployment from '../taikoon/deployments/devnet.json'
import * as HoleskyDeployment from '../taikoon/deployments/holesky.json'
import * as LocalhostDeployment from '../taikoon/deployments/localhost.json'
import TaikoonToken from '../taikoon/out/TaikoonToken.sol/TaikoonToken.json'



function generateNetworkWhitelist(network: string){
    const tree = StandardMerkleTree.load(JSON.parse(
        readFileSync(
            `../taikoon/data/whitelist/${network}.json`,
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
    generateNetworkWhitelist("holesky");
    generateNetworkWhitelist('devnet')
}

generateWhitelistJson();

export default defineConfig({
    out: 'src/generated/abi/index.ts',
    contracts: [
        {
            name: 'TaikoonToken',
            address: {
                31337: LocalhostDeployment.TaikoonToken as Address,
                17000: HoleskyDeployment.TaikoonToken as Address,
                167001: DevnetDeployment.TaikoonToken as Address,
            },
            abi: TaikoonToken.abi as Abi,
        }
    ],
})
