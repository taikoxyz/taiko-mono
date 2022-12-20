import "@nomiclabs/hardhat-etherscan"
import "@nomiclabs/hardhat-waffle"
import "@openzeppelin/hardhat-upgrades"
import "@typechain/hardhat"
import "hardhat-abi-exporter"
import "hardhat-gas-reporter"
import "hardhat-preprocessor"
import { HardhatUserConfig } from "hardhat/config"
import { config as dotenvConfig } from "dotenv"
import { resolve } from "path"
import "solidity-coverage"
import "solidity-docgen"
import "./tasks/deploy_L1"

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env"
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) })

const hardhatMnemonic =
    "test test test test test test test test test test test taik"
const config: HardhatUserConfig = {
    docgen: {
        exclude: [
            "bridge/libs/",
            "L1/v1/",
            "libs/",
            "test/",
            "thirdparty/",
            "common/EssentialContract.sol",
        ],
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
                const CONSTANTS = Object.keys(process.env).filter((k) =>
                    k.startsWith("K_")
                )

                for (let i = 0; i < CONSTANTS.length; i++) {
                    const name = CONSTANTS[i]
                    if (line.includes(`public constant ${name}`)) {
                        return `${line.slice(0, line.indexOf(" = "))} = ${
                            process.env[name]
                        };`
                    }
                }

                return line
            },
            files: "libs/LibConstants.sol",
        }),
    },
}

export default config
