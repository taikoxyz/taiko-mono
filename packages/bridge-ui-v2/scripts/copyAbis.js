#!/usr/bin/env node

const fs = require('fs')
const path = require('path')

const artifactsPath = path.resolve(__dirname, '../../protocol/artifacts')
const abiPath = path.resolve(__dirname, '../abi')

const jsonFilesMap = {
  Bridge: '/contracts/bridge/IBridge.sol/IBridge.json',
  ERC20: '/@penzeppelin/contracts/token/IERC20.sol/IERC20.json',
  TokenVault: '/contracts/bridge/TokenVault.sol/TokenVault.json',
  XchainSync: '/contracts/common/IXchainSync.sol/IXchainSync.json',
}

Object.entries(jsonFilesMap).map(([name, jsonPath]) => {
  const json = require(artifactsPath + jsonPath)
  const abi = JSON.stringify(json.abi)
  fs.writeFileSync(path.resolve(__dirname, `${abiPath}/${name}.json`), abi, 'utf8')
})
