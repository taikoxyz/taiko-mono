import { Config, Result } from "./interface";
const path = require("path");
const { ethers } = require("ethers");
// eslint-disable-next-line node/no-extraneous-require
const linker = require("solc/linker");
const {
    computeStorageSlots,
    getStorageLayout,
} = require("@defi-wonderland/smock/dist/src/utils");
const ARTIFACTS_PATH = path.join(__dirname, "../../artifacts/contracts");

// deployTaikoL2 generates a L2 genesis alloc of the TaikoL2 contract.
export async function deployTaikoL2(
    config: Config,
    result: Result
): Promise<Result> {
    const { contractOwner, chainId, seedAccounts } = config;

    const alloc: any = {};

    let etherVaultBalance = ethers.BigNumber.from("2").pow(128).sub(1); // MaxUint128

    for (const seedAccount of seedAccounts) {
        const accountAddress = Object.keys(seedAccount)[0];
        const balance = ethers.utils.parseEther(
            `${Object.values(seedAccount)[0]}`
        );

        console.log(`seedAccountAddress: ${accountAddress}`);
        console.log(`premintBalance: ${balance}`);

        alloc[accountAddress] = { balance: balance.toHexString() };

        etherVaultBalance = etherVaultBalance.sub(balance);
    }

    console.log({ etherVaultBalance });
    console.log("\n");

    const contractConfigs: any = await generateContractConfigs(
        contractOwner,
        chainId,
        config.contractAddresses
    );

    const storageLayouts: any = {};

    for (const contractName of Object.keys(contractConfigs)) {
        console.log(`generating genesis.alloc for ${contractName}`);

        const contractConfig = contractConfigs[contractName];

        alloc[contractConfig.address] = {
            contractName,
            storage: {},
            code: contractConfig.deployedBytecode,
        };

        // pre-mint ETHs for EtherVault contract
        alloc[contractConfig.address].balance =
            contractName === "EtherVault"
                ? etherVaultBalance.toHexString()
                : "0x0";

        // since we enable storageLayout compiler output in hardhat.config.ts,
        // rollup/artifacts/build-info will contain storage layouts, here
        // reading it using smock package.
        storageLayouts[contractName] = await getStorageLayout(contractName);

        // initialize contract variables, we only care about the variables
        // that need to be initialized with non-zero value.
        const slots = computeStorageSlots(
            storageLayouts[contractName],
            contractConfigs[contractName].variables
        );

        for (const slot of slots) {
            alloc[contractConfig.address].storage[slot.key] = slot.val;
        }
    }

    result.alloc = Object.assign(result.alloc, alloc);
    result.storageLayouts = Object.assign(
        result.storageLayouts,
        storageLayouts
    );

    return result;
}

// generateContractConfigs returns all L2 contracts address, deployedBytecode,
// and initialized variables.
async function generateContractConfigs(
    contractOwner: string,
    chainId: number,
    hardCodedAddresses: any
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
        TaikoL2: require(path.join(
            ARTIFACTS_PATH,
            "./L2/TaikoL2.sol/TaikoL2.json"
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
        SignalService: require(path.join(
            ARTIFACTS_PATH,
            "./signal/SignalService.sol/SignalService.json"
        )),
    };

    const addressMap: any = {};

    for (const [contractName, artifact] of Object.entries(contractArtifacts)) {
        let bytecode = (artifact as any).bytecode;

        switch (contractName) {
            case "TaikoL2":
                if (!addressMap.LibTxDecoder) {
                    throw new Error("LibTxDecoder not initialized");
                }

                bytecode = linkContractLibs(
                    contractArtifacts.TaikoL2,
                    addressMap
                );
                break;
            case "LibBridgeProcess":
                if (!addressMap.LibTrieProof) {
                    throw new Error("LibTrieProof not initialized");
                }

                bytecode = linkContractLibs(
                    contractArtifacts.LibBridgeProcess,
                    addressMap
                );
                break;
            case "Bridge":
                if (
                    !addressMap.LibTrieProof ||
                    !addressMap.LibBridgeRetry ||
                    !addressMap.LibBridgeProcess
                ) {
                    throw new Error(
                        "LibTrieProof/LibBridgeRetry/LibBridgeProcess not initialized"
                    );
                }

                bytecode = linkContractLibs(
                    contractArtifacts.Bridge,
                    addressMap
                );
                break;
            case "SignalService":
                if (!addressMap.LibTrieProof) {
                    throw new Error("LibTrieProof not initialized");
                }

                bytecode = linkContractLibs(
                    contractArtifacts.SignalService,
                    addressMap
                );
                break;
            default:
                break;
        }

        if (
            hardCodedAddresses &&
            ethers.utils.isAddress(hardCodedAddresses[contractName])
        ) {
            addressMap[contractName] = hardCodedAddresses[contractName];
        } else {
            addressMap[contractName] = ethers.utils.getCreate2Address(
                contractOwner,
                ethers.utils.keccak256(
                    ethers.utils.toUtf8Bytes(`${chainId}${contractName}`)
                ),
                ethers.utils.keccak256(ethers.utils.toUtf8Bytes(bytecode))
            );
        }
    }

    console.log("pre-computed addresses:");
    console.log(addressMap);

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
            deployedBytecode: linkContractLibs(
                contractArtifacts.LibBridgeProcess,
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
                    )}`]: addressMap.TaikoL2,
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
                    [`${ethers.utils.solidityKeccak256(
                        ["string"],
                        [`${chainId}.signal_service`]
                    )}`]: addressMap.SignalService,
                },
            },
        },
        TaikoL2: {
            address: addressMap.TaikoL2,
            deployedBytecode: linkContractLibs(
                contractArtifacts.TaikoL2,
                addressMap
            ),
            variables: {
                // ReentrancyGuardUpgradeable
                _status: 1, // _NOT_ENTERED
                // AddressResolver
                _addressManager: addressMap.AddressManager,
                // TaikoL2
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
            deployedBytecode: linkContractLibs(
                contractArtifacts.Bridge,
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
                _state: {},
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
                // Authorize L2 bridge
                _authorizedAddrs: { [`${addressMap.Bridge}`]: true },
            },
        },
        SignalService: {
            address: addressMap.SignalService,
            deployedBytecode: linkContractLibs(
                contractArtifacts.SignalService,
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
            },
        },
    };
}

// linkContractLibs tries to link contract deployedBytecode to its libraries.
// Ref: https://docs.soliditylang.org/en/latest/using-the-compiler.html#library-linking
function linkContractLibs(artifact: any, addressMap: any) {
    const linkedBytecode: string = linker.linkBytecode(
        artifact.deployedBytecode,
        getLinkLibs(
            artifact,
            linker.findLinkReferences(artifact.deployedBytecode),
            addressMap
        )
    );

    if (ethers.utils.toUtf8Bytes(linkedBytecode).includes("$__")) {
        throw new Error("failed to link");
    }

    return linkedBytecode;
}

// getLinkLibs tries to get all linked libraries addresses from the given address map, and then
// assembles a `libraries` param of `linker.linkBytecode(bytecode, libraries)`.
function getLinkLibs(artifact: any, linkRefs: any, addressMap: any) {
    const result: any = {};

    Object.values(artifact.deployedLinkReferences).forEach(
        (linkReference: any) => {
            const contractName = Object.keys(linkReference)[0];
            const linkRefKey: any = Object.keys(linkRefs).find(
                (key) =>
                    linkRefs[key][0].start ===
                    linkReference[contractName][0].start + 1
            );

            result[linkRefKey] = addressMap[contractName];
        }
    );

    return result;
}
