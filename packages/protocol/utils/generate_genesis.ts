const fs = require("fs")
const path = require("path")
const { ethers } = require("ethers")
// eslint-disable-next-line node/no-extraneous-require
const linker = require("solc/linker")
const {
    computeStorageSlots,
    getStorageLayout,
} = require("@defi-wonderland/smock/dist/src/utils")

const ARTIFACTS_PATH = path.join(__dirname, "../artifacts/contracts")

if (process.argv.length < 3) {
    throw new Error("missing config json")
}

const config = require(path.isAbsolute(process.argv[2])
    ? process.argv[2]
    : path.join(process.cwd(), process.argv[2]))

const contractOwner = config.contractOwner
const ethDepositor = config.ethDepositor
const chainId = config.chainId
const premintEthAccounts = config.premintEthAccounts

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
    })
) {
    throw new Error(
        `invalid input: ${JSON.stringify({
            contractOwner,
            chainId,
            premintEthAccounts,
        })}`
    )
}

generateL2Genesis(
    contractOwner as string,
    chainId as number,
    premintEthAccounts as Array<any>
).catch(console.error)

// generateL2Genesis generates a L2 genesis `alloc`.
// ref: https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
async function generateL2Genesis(
    contractOwner: string,
    chainId: number,
    premintEthAccounts: Array<any>
) {
    console.log(`contractOwner: ${contractOwner}`)
    console.log(`chainId: ${chainId}`)

    const alloc: any = {}

    let bridgeBalance = ethers.BigNumber.from("2").pow(128).sub(1) // MaxUint128

    for (const premintEthAccount of premintEthAccounts) {
        const accountAddress = Object.keys(premintEthAccount)[0]
        const balance = ethers.utils.parseEther(
            `${Object.values(premintEthAccount)[0]}`
        )

        console.log(`premintAccountAddress: ${accountAddress}`)
        console.log(`premintBalance: ${balance}`)

        alloc[accountAddress] = { balance: balance.toHexString() }

        bridgeBalance = bridgeBalance.sub(balance)
    }

    console.log(`bridgeBalance: ${bridgeBalance}`)
    console.log("\n")

    const contractConfigs: any = await generateContractConfigs(
        contractOwner,
        chainId
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

        // pre-mint ETHs for Bridge contract
        // NOTE: since L2 bridge contract hasn't finished yet, temporarily move
        // L2 bridge's balance to V1TaikoL2 contract address.
        alloc[contractConfig.address].balance =
            contractName === "V1TaikoL2" ? bridgeBalance.toHexString() : "0x0"

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

    const allocSavedPath = path.join(
        __dirname,
        "../deployments/genesis_alloc.json"
    )

    fs.writeFileSync(allocSavedPath, JSON.stringify(alloc, null, 2))

    const layoutSavedPath = path.join(
        __dirname,
        "../deployments/genesis_storage_layout.json"
    )

    fs.writeFileSync(layoutSavedPath, JSON.stringify(storageLayouts, null, 2))

    console.log("done")
    console.log(`alloc JSON saved to ${allocSavedPath}`)
    console.log(`layout JSON saved to ${layoutSavedPath}`)
}

// generateContractConfigs returns all L2 contracts address, deployedBytecode,
// and initialized variables.
async function generateContractConfigs(
    contractOwner: string,
    chainId: number
): Promise<any> {
    const contractArtifacts: any = {
        AddressManager: require(path.join(
            ARTIFACTS_PATH,
            "./thirdparty/AddressManager.sol/AddressManager.json"
        )),
        LibTxDecoder: require(path.join(
            ARTIFACTS_PATH,
            "./libs/LibTxDecoder.sol/LibTxDecoder.json"
        )),
        V1TaikoL2: require(path.join(
            ARTIFACTS_PATH,
            "./L2/V1TaikoL2.sol/V1TaikoL2.json"
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
                        [`${config.chainId}.eth_depositor`]
                    )}`]: config.ethDepositor,
                },
            },
        },
        LibTxDecoder: {
            address: addressMap.LibTxDecoder,
            deployedBytecode: contractArtifacts.LibTxDecoder.deployedBytecode,
            variables: {},
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
                        config.chainId,
                        0,
                        0,
                        new Array(255).fill(ethers.constants.HashZero),
                    ]
                )}`,
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
