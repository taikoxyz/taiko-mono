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
        // L2 bridge's balance to TaikoL2 contract address.
        alloc[contractConfig.address].balance =
            contractName === "TaikoL2" ? bridgeBalance.toHexString() : "0x0"

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
        LibTxListDecoder: require(path.join(
            ARTIFACTS_PATH,
            "./libs/LibTxListDecoder.sol/LibTxListDecoder.json"
        )),
        TaikoL2: require(path.join(
            ARTIFACTS_PATH,
            "./L2/TaikoL2.sol/TaikoL2.json"
        )),
    }

    const addressMap: any = {}

    for (const [contractName, artifact] of Object.entries(contractArtifacts)) {
        let bytecode = (artifact as any).bytecode

        if (contractName === "TaikoL2") {
            if (!addressMap.LibTxListDecoder) {
                throw new Error("LibTxListDecoder not initialized")
            }

            bytecode = linkTaikoL2Bytecode(bytecode, addressMap)
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
                        ["eth_depositor"]
                    )}`]: config.ethDepositor,
                },
            },
        },
        LibTxListDecoder: {
            address: addressMap.LibTxListDecoder,
            deployedBytecode:
                contractArtifacts.LibTxListDecoder.deployedBytecode,
            variables: {},
        },
        TaikoL2: {
            address: addressMap.TaikoL2,
            deployedBytecode: linkTaikoL2Bytecode(
                contractArtifacts.TaikoL2.deployedBytecode,
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
                _chainId: config.chainId,
            },
        },
    }
}

// linkL2RollupBytecode tries to link TaikoL2 deployedBytecode to its library.
// Ref: https://docs.soliditylang.org/en/latest/using-the-compiler.html#library-linking
function linkTaikoL2Bytecode(byteCode: string, addressMap: any): string {
    const refs = linker.findLinkReferences(byteCode)

    if (Object.keys(refs).length !== 2) {
        throw new Error(
            `wrong link references amount, expected: 2, get: ${
                Object.keys(refs).length
            }`
        )
    }

    const linkedBytecode: string = linker.linkBytecode(byteCode, {
        [Object.keys(refs)[0]]: addressMap.LibTxListDecoder,
    })

    if (linkedBytecode.includes("$__")) {
        throw new Error("failed to link")
    }

    return linkedBytecode
}
