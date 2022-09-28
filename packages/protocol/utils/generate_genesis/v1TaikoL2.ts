import { Config, Result } from "./interface"
const path = require("path")
const { ethers } = require("ethers")
// eslint-disable-next-line node/no-extraneous-require
const linker = require("solc/linker")
const {
    computeStorageSlots,
    getStorageLayout,
} = require("@defi-wonderland/smock/dist/src/utils")
const ARTIFACTS_PATH = path.join(__dirname, "../../artifacts/contracts")

// deployV1TaikoL2 generates a L2 genesis alloc of the V1TaikoL2 contract.
export async function deployV1TaikoL2(
    config: Config,
    result: Result
): Promise<Result> {
    const { contractOwner, chainId, seedAccounts, ethDepositor } = config

    const alloc: any = {}

    let etherVaultBalance = ethers.BigNumber.from("2").pow(128).sub(1) // MaxUint128

    for (const seedAccount of seedAccounts) {
        const accountAddress = Object.keys(seedAccount)[0]
        const balance = ethers.utils.parseEther(
            `${Object.values(seedAccount)[0]}`
        )

        console.log(`seedAccountAddress: ${accountAddress}`)
        console.log(`premintBalance: ${balance}`)

        alloc[accountAddress] = { balance: balance.toHexString() }

        etherVaultBalance = etherVaultBalance.sub(balance)
    }

    console.log({ etherVaultBalance })
    console.log("\n")

    const contractConfigs: any = await generateContractConfigs(
        contractOwner,
        chainId,
        ethDepositor
    )

    const storageLayouts: any = {}

    for (const contractName of Object.keys(contractConfigs)) {
        console.log(`generating genesis.alloc for ${contractName}`)

        const contractConfig = contractConfigs[contractName]

        alloc[contractConfig.address] = {
            contractName,
            storage: {},
            code: contractConfig.deployedBytecode,
        }

        // pre-mint ETHs for EtherVault contract
        alloc[contractConfig.address].balance =
            contractName === "EtherVault"
                ? etherVaultBalance.toHexString()
                : "0x0"

        // since we enable storageLayout compiler output in hardhat.config.ts,
        // rollup/artifacts/build-info will contain storage layouts, here
        // reading it using smock package.
        storageLayouts[contractName] = await getStorageLayout(contractName)

        // initialize contract variables, we only care about the variables
        // that need to be initialized with non-zero value.
        const slots = computeStorageSlots(
            storageLayouts[contractName],
            contractConfigs[contractName].variables
        )

        for (const slot of slots) {
            alloc[contractConfig.address].storage[slot.key] = slot.val
        }
    }

    result.alloc = Object.assign(result.alloc, alloc)
    result.storageLayouts = Object.assign(result.storageLayouts, storageLayouts)

    return result
}

// generateContractConfigs returns all L2 contracts address, deployedBytecode,
// and initialized variables.
async function generateContractConfigs(
    contractOwner: string,
    chainId: number,
    ethDepositor: string
): Promise<any> {
    const contractArtifacts: any = {
        // Libraries
        LibTrieProof: require(path.join(
            ARTIFACTS_PATH,
            "./libs/LibTrieProof.sol/LibTrieProof.json"
        )),
        LibBridgeRetry: require(path.join(
            ARTIFACTS_PATH,
            "./bridge/libs/LibBridgeRetry.sol/LibBridgeRetry.json"
        )),
        LibBridgeProcess: require(path.join(
            ARTIFACTS_PATH,
            "./bridge/libs/LibBridgeProcess.sol/LibBridgeProcess.json"
        )),
        LibTxDecoder: require(path.join(
            ARTIFACTS_PATH,
            "./libs/LibTxDecoder.sol/LibTxDecoder.json"
        )),
        // Contracts
        AddressManager: require(path.join(
            ARTIFACTS_PATH,
            "./thirdparty/AddressManager.sol/AddressManager.json"
        )),
        V1TaikoL2: require(path.join(
            ARTIFACTS_PATH,
            "./L2/V1TaikoL2.sol/V1TaikoL2.json"
        )),
        Bridge: require(path.join(
            ARTIFACTS_PATH,
            "./bridge/Bridge.sol/Bridge.json"
        )),
        TokenVault: require(path.join(
            ARTIFACTS_PATH,
            "./bridge/TokenVault.sol/TokenVault.json"
        )),
        EtherVault: require(path.join(
            ARTIFACTS_PATH,
            "./bridge/EtherVault.sol/EtherVault.json"
        )),
    }

    const addressMap: any = {}

    for (const [contractName, artifact] of Object.entries(contractArtifacts)) {
        let bytecode = (artifact as any).bytecode

        if (contractName === "V1TaikoL2") {
            if (!addressMap.LibTxDecoder) {
                throw new Error("LibTxDecoder not initialized")
            }

            bytecode = linkV1TaikoL2Bytecode(bytecode, addressMap)
        } else if (contractName === "LibBridgeProcess") {
            if (!addressMap.LibTrieProof) {
                throw new Error("LibTrieProof not initialized")
            }

            bytecode = linkLibBridgeProcessBytecode(bytecode, addressMap)
        } else if (contractName === "Bridge") {
            if (
                !addressMap.LibTrieProof ||
                !addressMap.LibBridgeRetry ||
                !addressMap.LibBridgeProcess
            ) {
                throw new Error(
                    "LibTrieProof/LibBridgeRetry/LibBridgeProcess not initialized"
                )
            }

            bytecode = linkBridgeBytecode(bytecode, addressMap)
        }

        addressMap[contractName] = ethers.utils.getCreate2Address(
            contractOwner,
            ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes(`${chainId}${contractName}`)
            ),
            ethers.utils.keccak256(ethers.utils.toUtf8Bytes(bytecode))
        )
    }

    console.log("pre-computed addresses:")
    console.log(addressMap)

    return {
        // Libraries
        LibTrieProof: {
            address: addressMap.LibTrieProof,
            deployedBytecode: contractArtifacts.LibTrieProof.deployedBytecode,
            variables: {},
        },
        LibBridgeRetry: {
            address: addressMap.LibBridgeRetry,
            deployedBytecode: contractArtifacts.LibBridgeRetry.deployedBytecode,
            variables: {},
        },
        LibBridgeProcess: {
            address: addressMap.LibBridgeProcess,
            deployedBytecode: linkLibBridgeProcessBytecode(
                contractArtifacts.LibBridgeProcess.deployedBytecode,
                addressMap
            ),
            variables: {},
        },
        LibTxDecoder: {
            address: addressMap.LibTxDecoder,
            deployedBytecode: contractArtifacts.LibTxDecoder.deployedBytecode,
            variables: {},
        },
        AddressManager: {
            address: addressMap.AddressManager,
            deployedBytecode: contractArtifacts.AddressManager.deployedBytecode,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // OwnableUpgradeable
                _owner: contractOwner,
                // AddressManager
                addresses: {
                    // keccak256(abi.encodePacked(_name))
                    [`${ethers.utils.solidityKeccak256(
                        ["string"],
                        [`${chainId}.taiko`]
                    )}`]: addressMap.V1TaikoL2,
                    [`${ethers.utils.solidityKeccak256(
                        ["string"],
                        [`${chainId}.bridge`]
                    )}`]: addressMap.Bridge,
                    [`${ethers.utils.solidityKeccak256(
                        ["string"],
                        [`${chainId}.token_vault`]
                    )}`]: addressMap.TokenVault,
                    [`${ethers.utils.solidityKeccak256(
                        ["string"],
                        [`${chainId}.ether_vault`]
                    )}`]: addressMap.EtherVault,
                },
            },
        },
        V1TaikoL2: {
            address: addressMap.V1TaikoL2,
            deployedBytecode: linkV1TaikoL2Bytecode(
                contractArtifacts.V1TaikoL2.deployedBytecode,
                addressMap
            ),
            variables: {
                // ReentrancyGuardUpgradeable
                _status: 1, // _NOT_ENTERED
                // AddressResolver
                _addressManager: addressMap.AddressManager,
                // V1TaikoL2
                // keccak256(abi.encodePacked(block.chainid, basefee, ancestors))
                publicInputHash: `${ethers.utils.solidityKeccak256(
                    ["uint256", "uint256", "uint256", "bytes32[255]"],
                    [
                        chainId,
                        0,
                        0,
                        new Array(255).fill(ethers.constants.HashZero),
                    ]
                )}`,
            },
        },
        Bridge: {
            address: addressMap.Bridge,
            deployedBytecode: linkBridgeBytecode(
                contractArtifacts.Bridge.deployedBytecode,
                addressMap
            ),
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _status: 1, // _NOT_ENTERED
                // OwnableUpgradeable
                _owner: contractOwner,
                // AddressResolver
                _addressManager: addressMap.AddressManager,
                // Bridge
                state: {},
            },
        },
        TokenVault: {
            address: addressMap.TokenVault,
            deployedBytecode: contractArtifacts.TokenVault.deployedBytecode,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _status: 1, // _NOT_ENTERED
                // OwnableUpgradeable
                _owner: contractOwner,
                // AddressResolver
                _addressManager: addressMap.AddressManager,
            },
        },
        EtherVault: {
            address: addressMap.EtherVault,
            deployedBytecode: contractArtifacts.EtherVault.deployedBytecode,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _status: 1, // _NOT_ENTERED
                // OwnableUpgradeable
                _owner: contractOwner,
                // AddressResolver
                _addressManager: addressMap.AddressManager,
                // EtherVault
                authorizedAddrs: { [`${addressMap.Bridge}`]: true },
            },
        },
    }
}

// linkL2RollupBytecode tries to link V1TaikoL2 deployedBytecode to its library.
// Ref: https://docs.soliditylang.org/en/latest/using-the-compiler.html#library-linking
function linkV1TaikoL2Bytecode(byteCode: string, addressMap: any): string {
    const refs = linker.findLinkReferences(byteCode)

    if (Object.keys(refs).length !== 1) {
        throw new Error(
            `wrong link references amount, expected: 1, get: ${
                Object.keys(refs).length
            }`
        )
    }

    const linkedBytecode: string = linker.linkBytecode(byteCode, {
        [Object.keys(refs)[0]]: addressMap.LibTxDecoder,
    })

    if (linkedBytecode.includes("$__")) {
        throw new Error("failed to link")
    }

    return linkedBytecode
}

// linkLibBridgeProcessBytecode tries to link LibBridgeProcess deployedBytecode
// to its libraries.
// Ref: https://docs.soliditylang.org/en/latest/using-the-compiler.html#library-linking
function linkLibBridgeProcessBytecode(
    byteCode: string,
    addressMap: any
): string {
    const refs = linker.findLinkReferences(byteCode)

    if (Object.keys(refs).length !== 1) {
        throw new Error(
            `wrong link references amount, expected: 1, get: ${
                Object.keys(refs).length
            }`
        )
    }

    const linkedBytecode: string = linker.linkBytecode(byteCode, {
        [Object.keys(refs)[0]]: addressMap.LibTrieProof,
    })

    if (linkedBytecode.includes("$__")) {
        throw new Error("failed to link")
    }

    return linkedBytecode
}

// linkBridgeBytecode tries to link Bridge deployedBytecode to its libraries.
// Ref: https://docs.soliditylang.org/en/latest/using-the-compiler.html#library-linking
function linkBridgeBytecode(byteCode: string, addressMap: any): string {
    const refs = linker.findLinkReferences(byteCode)

    if (Object.keys(refs).length !== 3) {
        throw new Error(
            `wrong link references amount, expected: 3, get: ${
                Object.keys(refs).length
            }`
        )
    }

    const linkedBytecode: string = linker.linkBytecode(byteCode, {
        [Object.keys(refs)[0]]: addressMap.LibBridgeProcess,
        [Object.keys(refs)[1]]: addressMap.LibBridgeRetry,
        [Object.keys(refs)[2]]: addressMap.LibTrieProof,
    })

    if (ethers.utils.toUtf8Bytes(linkedBytecode).includes("$__")) {
        throw new Error("failed to link")
    }

    return linkedBytecode
}
