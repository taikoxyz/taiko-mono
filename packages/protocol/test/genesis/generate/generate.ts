import { Config } from "./interface";
const fs = require("fs");
const path = require("path");
const { ethers } = require("ethers");
const { deployTaikoAnchor } = require("./taikoAnchor");
const { deployERC20 } = require("./erc20");
const config: Config = require("../data/genesis_config.js");

// Generate a L2 genesis JSON based on the given configurations.
// ref: https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
async function main() {
    const contractOwner = config.contractOwner;
    const chainId = config.chainId;
    const seedAccounts = config.seedAccounts;
    const predeployERC20 = config.predeployERC20;

    if (
        !ethers.utils.isAddress(contractOwner) ||
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
                contractOwner,
                chainId,
                seedAccounts,
            })}`,
        );
    }

    console.log("config: %o", config);

    console.log("start deploy TaikoAnchor contract");

    let result = await deployTaikoAnchor(config, {
        alloc: {},
        storageLayouts: {},
    });

    if (config.predeployERC20) {
        console.log("start deploy an ERC-20 token");

        result = await deployERC20(config, result);
    }

    const allocSavedPath = path.join(__dirname, "../data/genesis_alloc.json");

    fs.writeFileSync(allocSavedPath, JSON.stringify(result.alloc, null, 2));

    const layoutSavedPath = path.join(
        __dirname,
        "../data/genesis_storage_layout.json",
    );

    fs.writeFileSync(
        layoutSavedPath,
        JSON.stringify(result.storageLayouts, null, 2),
    );

    const configJsonSavedPath = path.join(
        __dirname,
        "../data/genesis_config.json",
    );
    fs.writeFileSync(configJsonSavedPath, JSON.stringify(config));

    const fullGenesis = {
        config: {
            chainId: config.chainId,
            homesteadBlock: 0,
            eip150Block: 0,
            eip150Hash:
                "0x0000000000000000000000000000000000000000000000000000000000000000",
            eip155Block: 0,
            eip158Block: 0,
            byzantiumBlock: 0,
            constantinopleBlock: 0,
            petersburgBlock: 0,
            istanbulBlock: 0,
            muirGlacierBlock: 0,
            berlinBlock: 0,
            clique: {
                period: 0,
                epoch: 30000,
            },
        },
        gasLimit: "30000000",
        difficulty: "1",
        extraData:
            "0x0000000000000000000000000000000000000000000000000000000000000000df08f82de32b8d460adbe8d72043e3a7e25a3b390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        alloc: result.alloc,
    };

    const genesisJsonSavedPath = path.join(__dirname, "../data/genesis.json");
    fs.writeFileSync(
        genesisJsonSavedPath,
        JSON.stringify(fullGenesis, null, 2),
    );

    console.log("done");
    console.log(`alloc JSON saved to ${allocSavedPath}`);
    console.log(`layout JSON saved to ${layoutSavedPath}`);
    console.log(`config JSON saved to ${configJsonSavedPath}`);
    console.log(`full genesis JSON saved to ${genesisJsonSavedPath}`);
}

main().catch(console.error);
