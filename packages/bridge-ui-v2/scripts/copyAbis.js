#!/usr/bin/env node

const pathToProtocolArtifacts = '../../protocol/artifacts/'
const copyToPath = '../src/abis/'

const abiJsonFiles = [
  'contracts/Bridge.sol/Bridge.json',
  'contracts/TokenVault.sol/TokenVault.json',
  'contracts/common/IHeaderSync.sol/IHeaderSync.json',
  '@openzeppelin/contracts/token/ERC20/IERC20.sol/.json',
]
