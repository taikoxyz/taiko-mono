import { Config } from "./interface";
const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");
const { deployTaikoL2 } = require("./taikoL2");
const { deployERC20 } = require("./erc20");

// Generate a L2 genesis JSON based on the given configurations.
// ref: https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
async function main() {
    if (process.argv.length < 3) {
        throw new Error("missing config json");
    }

    const config: Config = require(
        path.isAbsolute(process.argv[2])
            ? process.argv[2]
            : path.join(process.cwd(), process.argv[2]),
    );

    const ownerTimelockController = config.ownerTimelockController;
    const ownerSecurityCouncil = config.ownerSecurityCouncil;
    const chainId = config.chainId;
    const seedAccounts = config.seedAccounts;
    const predeployERC20 = config.predeployERC20;

    if (
        !ethers.utils.isAddress(ownerTimelockController) ||
        !ethers.utils.isAddress(ownerSecurityCouncil) ||
        !Number.isInteger(chainId) ||
        !Array.isArray(seedAccounts) ||
        !seedAccounts.every((seedAccount) => {
            return (
                Object.keys(seedAccount).length === 1 &&
                ethers.utils.isAddress(Object.keys(seedAccount)[0]) &&
                Number.isInteger(Object.values(seedAccount)[0])
            );
        }) ||
        typeof predeployERC20 !== "boolean"
    ) {
        throw new Error(
            `invalid input: ${JSON.stringify({
                ownerTimelockController,
                ownerSecurityCouncil,
                chainId,
                seedAccounts,
            })}`,
        );
    }

    console.log("config: %o", config);

    console.log("start deploy TaikoL2 contract");

    let result = await deployTaikoL2(config, {
        alloc: {},
        storageLayouts: {},
    });

    if (config.predeployERC20) {
        console.log("start deploy an ERC-20 token");

        result = await deployERC20(config, result);
    }

    const allocSavedPath = path.join(
        __dirname,
        "../../deployments/genesis_alloc.json",
    );

    fs.writeFileSync(allocSavedPath, JSON.stringify(result.alloc, null, 2));

    const layoutSavedPath = path.join(
        __dirname,
        "../../deployments/genesis_storage_layout.json",
    );

    fs.writeFileSync(
        layoutSavedPath,
        JSON.stringify(result.storageLayouts, null, 2),
    );

    const configJsonSavedPath = path.join(
        __dirname,
        "../../deployments/genesis_config.json",
    );
    fs.writeFileSync(configJsonSavedPath, JSON.stringify(config));

    console.log("done");
    console.log(`alloc JSON saved to ${allocSavedPath}`);
    console.log(`layout JSON saved to ${layoutSavedPath}`);
    console.log(`config JSON saved to ${configJsonSavedPath}`);
}

main().catch(console.error);
