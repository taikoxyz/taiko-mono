import "./tasks/deploy_L1"
import "@nomiclabs/hardhat-etherscan"
import "@nomiclabs/hardhat-waffle"
import "@openzeppelin/hardhat-upgrades"
import "@typechain/hardhat"
import "hardhat-abi-exporter"
import "hardhat-gas-reporter"
import "hardhat-preprocessor"
import "solidity-coverage"
import "solidity-docgen"
import { HardhatUserConfig } from "hardhat/config"

const hardhatMnemonic =
    "test test test test test test test test test test test taik"
const config: HardhatUserConfig = {
    docgen: {
        pages: "files",
        templates: "./solidity-docgen/templates",
    },
    gasReporter: {
        currency: "USD",
        enabled: process.env.REPORT_GAS === "true",
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
        version: "0.8.9",
    },
    preprocess: {
        eachLine: () => ({
            transform: (line) => {
                if (
                    process.env.CHAIN_ID &&
                    line.includes("uint256 public constant K_CHAIN_ID")
                ) {
                    return `${line.slice(0, line.indexOf(" ="))} = ${
                        process.env.CHAIN_ID
                    };`
                }

                if (
                    process.env.COMMIT_DELAY_CONFIRMATIONS &&
                    line.includes(
                        "uint256 public constant K_COMMIT_DELAY_CONFIRMS"
                    )
                ) {
                    return `${line.slice(0, line.indexOf(" ="))} = ${
                        process.env.COMMIT_DELAY_CONFIRMATIONS
                    };`
                }

                return line
            },
            files: "libs/LibConstants.sol",
        }),
    },
}

export default config
