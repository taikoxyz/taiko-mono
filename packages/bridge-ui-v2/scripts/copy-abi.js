import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const artifactsPath = path.resolve(__dirname, '../../protocol/artifacts')
const abiOutputPath = path.resolve(__dirname, '../src/abi')

const jsonFilesMap = {
  Bridge: '/contracts/bridge/IBridge.sol/IBridge.json',
  ERC20: '/@openzeppelin/contracts/token/ERC20/IERC20.sol/IERC20.json',
  TokenVault: '/contracts/bridge/TokenVault.sol/TokenVault.json',
  CrossChainSync: '/contracts/common/ICrossChainSync.sol/ICrossChainSync.json',
}

Object.entries(jsonFilesMap).map(([name, jsonPath]) => {
  try {
    const jsonStr = fs.readFileSync(artifactsPath + jsonPath, { encoding: 'utf8' })

    const json = JSON.parse(jsonStr)
    const { abi } = json

    fs.writeFileSync(`${abiOutputPath}/${name}.json`, JSON.stringify(abi), 'utf8')
  } catch (e) {
    if (e.code === 'ENOENT') {
      console.log(`File not found: ${e.path}`)
    }
  }
})
