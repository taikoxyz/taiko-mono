import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@nomicfoundation/hardhat-foundry";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";
import "hardhat-gas-reporter";
import "hardhat-preprocessor";
import { HardhatUserConfig } from "hardhat/config";
import "solidity-coverage";
import "solidity-docgen";
import fs from "fs";

function getRemappings() {
    return fs
        .readFileSync("remappings.txt", "utf8")
        .split("\n")
        .filter(Boolean) // remove empty lines
        .map((line) => line.trim().split("="));
}

const hardhatMnemonic =
    "test test test test test test test test test test test taik";
const config: HardhatUserConfig = {
    docgen: {
        exclude: [
            "bridge/libs/",
            "L1/libs/",
            "libs/",
            "test/",
            "thirdparty/",
            "common/EssentialContract.sol",
        ],
        outputDir: "../website/pages/docs/reference/contract-documentation/",
        pages: "files",
        templates: "./solidity-docgen/templates",
    },

    gasReporter: {
        currency: "USD",
        enabled: true,
        gasPriceApi:
            "https://api.etherscan.io/api?module=proxy&action=eth_gasPrice",
        token: "ETH",
    },
    mocha: {
        timeout: 300000,
    },
    networks: {
        goerli: {
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
            url: process.env.GOERLI_URL || "",
        },
        hardhat: {
            accounts: {
                mnemonic: hardhatMnemonic,
            },
            gas: 8000000,
        },
        mainnet: {
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
            url: process.env.MAINNET_URL || "",
        },
        l1_test: {
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : { mnemonic: hardhatMnemonic },
            url: "http://127.0.0.1:18545" || "",
        },
        l2_test: {
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : { mnemonic: hardhatMnemonic },
            url: "http://127.0.0.1:28545" || "",
        },
        localhost: {
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
            url: "http://127.0.0.1:8545" || "",
        },
        ropsten: {
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
            url: process.env.ROPSTEN_URL || "",
        },
        internal_devnet_l1: {
            url: "https://l1rpc.internal.taiko.xyz/",
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
        },
        internal_devnet_l2: {
            url: "https://l2rpc.internal.taiko.xyz/",
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
        },
    },
    etherscan: {
        apiKey: {
            internal_devnet_l1: "internal_devnet_l1_key",
            internal_devnet_l2: "internal_devnet_l2_key",
        },
        customChains: [
            {
                network: "internal_devnet_l1",
                chainId: 31336,
                urls: {
                    apiURL: "https://l1explorer.internal.taiko.xyz/api",
                    browserURL: "https://l1explorer.internal.taiko.xyz",
                },
            },
            {
                network: "internal_devnet_l2",
                chainId: 167001,
                urls: {
                    apiURL: "https://l2explorer.internal.taiko.xyz/api",
                    browserURL: "https://l2explorer.internal.taiko.xyz",
                },
            },
        ],
    },
    solidity: {
        settings: {
            optimizer: {
                enabled: true,
                runs: 10000,
            },
            outputSelection: {
                "*": {
                    "*": ["storageLayout"],
                },
            },
        },
        version: "0.8.20",
    },
    preprocess: {
        eachLine: (hre) => ({
            transform: (line: string) => {
                if (line.match(/^\s*import /i)) {
                    for (const [from, to] of getRemappings()) {
                        if (line.includes(from)) {
                            line = line.replace(from, to);
                            break;
                        }
                    }
                }
                return line;
            },
        }),
    },
    paths: {
        sources: "./contracts",
        cache: "./cache_hardhat",
    },
};

export default config;
