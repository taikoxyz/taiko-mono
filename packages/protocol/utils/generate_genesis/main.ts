import { Config } from "./interface"
const fs = require("fs")
const path = require("path")
const { ethers } = require("ethers")
const { deployV1TaikoL2 } = require("./v1TaikoL2")
const { deployERC20 } = require("./erc20")

async function main() {
    if (process.argv.length < 3) {
        throw new Error("missing config json")
    }

    const config: Config = require(path.isAbsolute(process.argv[2])
        ? process.argv[2]
        : path.join(process.cwd(), process.argv[2]))

    const contractOwner = config.contractOwner
    const ethDepositor = config.ethDepositor
    const chainId = config.chainId
    const premintEthAccounts = config.premintEthAccounts
    const predeployERC20 = config.predeployERC20

    if (
        !ethers.utils.isAddress(contractOwner) ||
        !ethers.utils.isAddress(ethDepositor) ||
        !Number.isInteger(chainId) ||
        !Array.isArray(premintEthAccounts) ||
        !premintEthAccounts.every((premintEthAccount) => {
            return (
                Object.keys(premintEthAccount).length === 1 &&
                ethers.utils.isAddress(Object.keys(premintEthAccount)[0]) &&
                Number.isInteger(Object.values(premintEthAccount)[0])
            )
        }) ||
        typeof predeployERC20 !== "boolean"
    ) {
        throw new Error(
            `invalid input: ${JSON.stringify({
                contractOwner,
                chainId,
                premintEthAccounts,
            })}`
        )
    }

    console.log("config: %o", config)

    console.log("start deploy V1TaikoL2 contract")

    let result = await deployV1TaikoL2(config, {
        alloc: {},
        storageLayouts: {},
    }).catch(console.error)

    if (config.predeployERC20) {
        console.log("start deploy an ERC-20 token")

        result = await deployERC20(config, result)
    }

    const allocSavedPath = path.join(
        __dirname,
        "../../deployments/genesis_alloc.json"
    )

    fs.writeFileSync(allocSavedPath, JSON.stringify(result.alloc, null, 2))

    const layoutSavedPath = path.join(
        __dirname,
        "../../deployments/genesis_storage_layout.json"
    )

    fs.writeFileSync(
        layoutSavedPath,
        JSON.stringify(result.storageLayouts, null, 2)
    )

    console.log("done")
    console.log(`alloc JSON saved to ${allocSavedPath}`)
    console.log(`layout JSON saved to ${layoutSavedPath}`)
}

main().catch(console.error)
