import { ethers } from "ethers"
import { Result } from "./interface"
const path = require("path")
const ARTIFACTS_PATH = path.join(__dirname, "../../artifacts/contracts")
const {
    computeStorageSlots,
    getStorageLayout,
} = require("@defi-wonderland/smock/dist/src/utils")

export const PREMINT_ADDRESS_BALANCE = ethers.BigNumber.from(1024000)

export async function deployERC20(
    config: any,
    result: Result
): Promise<Result> {
    const { contractOwner, chainId, premintEthAccounts } = config

    const alloc: any = {}
    const storageLayouts: any = {}

    const artifact = require(path.join(
        ARTIFACTS_PATH,
        "./test/TestERC20.sol/TestERC20.json"
    ))

    const address = ethers.utils.getCreate2Address(
        contractOwner,
        ethers.utils.keccak256(
            ethers.utils.toUtf8Bytes(`${chainId}${artifact.contractName}`)
        ),
        ethers.utils.keccak256(ethers.utils.toUtf8Bytes(artifact.bytecode))
    )

    const variables = {
        _name: "predeployERC20",
        _symbol: "PRE",
        _totalSupply: PREMINT_ADDRESS_BALANCE.mul(premintEthAccounts.length),
        _balances: {} as any,
    }

    for (const account of premintEthAccounts) {
        variables._balances[Object.keys(account)[0]] = PREMINT_ADDRESS_BALANCE
    }

    alloc[address] = {
        contractName: artifact.contractName,
        storage: {},
        code: artifact.deployedBytecode,
        balance: "0x0",
    }

    storageLayouts[artifact.contractName] = await getStorageLayout(
        artifact.contractName
    )

    for (const slot of computeStorageSlots(
        storageLayouts[artifact.contractName],
        variables
    )) {
        alloc[address].storage[slot.key] = slot.val
    }

    result.alloc = Object.assign(result.alloc, alloc)
    result.storageLayouts = Object.assign(result.storageLayouts, storageLayouts)

    return result
}
