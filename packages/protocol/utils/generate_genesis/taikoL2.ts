import { Config, Result } from "./interface";
const path = require("path");
const { ethers } = require("ethers");
// eslint-disable-next-line node/no-extraneous-require
const linker = require("solc/linker");
const {
    computeStorageSlots,
    getStorageLayout,
} = require("@defi-wonderland/smock/dist/src/utils");
const ARTIFACTS_PATH = path.join(__dirname, "../../out");

const IMPLEMENTATION_SLOT =
    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

const ADMIN_SLOT =
    "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";

// deployTaikoL2 generates a L2 genesis alloc of the TaikoL2 contract.
export async function deployTaikoL2(
    config: Config,
    result: Result
): Promise<Result> {
    const { contractOwner, chainId, seedAccounts, contractAdmin } = config;

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
        contractAdmin,
        chainId,
        config.contractAddresses,
        config.param1559
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
            contractName === "EtherVaultProxy"
                ? etherVaultBalance.toHexString()
                : "0x0";

        // since we enable storageLayout compiler output in hardhat.config.ts,
        // rollup/artifacts/build-info will contain storage layouts, here
        // reading it using smock package.
        let storageLayoutName = contractName;
        if (contractConfig.isProxy) {
            storageLayoutName = contractName.replace("Proxy", "");
            storageLayoutName = `Proxied${storageLayoutName}`;
        }

        storageLayouts[contractName] = await getStorageLayout(
            storageLayoutName
        );
        // initialize contract variables, we only care about the variables
        // that need to be initialized with non-zero value.
        const slots = computeStorageSlots(
            storageLayouts[contractName],
            contractConfigs[contractName].variables
        );

        for (const slot of slots) {
            alloc[contractConfig.address].storage[slot.key] = slot.val;
        }

        if (contractConfigs[contractName].slots) {
            for (const [slot, val] of Object.entries(
                contractConfigs[contractName].slots
            )) {
                alloc[contractConfig.address].storage[slot] = val;
            }
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
    contractAdmin: string,
    chainId: number,
    hardCodedAddresses: any,
    param1559: any
): Promise<any> {
    const contractArtifacts: any = {
        // Libraries
        LibTrieProof: require(path.join(
            ARTIFACTS_PATH,
            "./LibTrieProof.sol/LibTrieProof.json"
        )),
        LibBridgeRetry: require(path.join(
            ARTIFACTS_PATH,
            "./LibBridgeRetry.sol/LibBridgeRetry.json"
        )),
        LibBridgeProcess: require(path.join(
            ARTIFACTS_PATH,
            "./LibBridgeProcess.sol/LibBridgeProcess.json"
        )),
        // Contracts
        ProxiedAddressManager: require(path.join(
            ARTIFACTS_PATH,
            "./AddressManager.sol/ProxiedAddressManager.json"
        )),
        ProxiedTaikoL2: require(path.join(
            ARTIFACTS_PATH,
            "./TaikoL2.sol/ProxiedTaikoL2.json"
        )),
        ProxiedBridge: require(path.join(
            ARTIFACTS_PATH,
            "./Bridge.sol/ProxiedBridge.json"
        )),
        ProxiedTokenVault: require(path.join(
            ARTIFACTS_PATH,
            "./TokenVault.sol/ProxiedTokenVault.json"
        )),
        ProxiedEtherVault: require(path.join(
            ARTIFACTS_PATH,
            "./EtherVault.sol/ProxiedEtherVault.json"
        )),
        ProxiedSignalService: require(path.join(
            ARTIFACTS_PATH,
            "./SignalService.sol/ProxiedSignalService.json"
        )),
    };

    const proxy = require(path.join(
        ARTIFACTS_PATH,
        "./TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json"
    ));
    contractArtifacts.TaikoL2Proxy = proxy;
    contractArtifacts.BridgeProxy = proxy;
    contractArtifacts.TokenVaultProxy = proxy;
    contractArtifacts.EtherVaultProxy = proxy;
    contractArtifacts.SignalServiceProxy = proxy;
    contractArtifacts.AddressManagerProxy = proxy;

    const addressMap: any = {};

    for (const [contractName, artifact] of Object.entries(contractArtifacts)) {
        let bytecode = (artifact as any).bytecode;

        switch (contractName) {
            case "ProxiedTaikoL2":
                bytecode = linkContractLibs(
                    contractArtifacts.ProxiedTaikoL2,
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
            case "ProxiedBridge":
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
                    contractArtifacts.ProxiedBridge,
                    addressMap
                );
                break;
            case "ProxiedSignalService":
                if (!addressMap.LibTrieProof) {
                    throw new Error("LibTrieProof not initialized");
                }

                bytecode = linkContractLibs(
                    contractArtifacts.ProxiedSignalService,
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
            deployedBytecode:
                contractArtifacts.LibTrieProof.deployedBytecode.object,
            variables: {},
        },
        LibBridgeRetry: {
            address: addressMap.LibBridgeRetry,
            deployedBytecode:
                contractArtifacts.LibBridgeRetry.deployedBytecode.object,
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
        ProxiedAddressManager: {
            address: addressMap.ProxiedAddressManager,
            deployedBytecode:
                contractArtifacts.ProxiedAddressManager.deployedBytecode.object,
        },
        AddressManagerProxy: {
            address: addressMap.AddressManagerProxy,
            deployedBytecode:
                contractArtifacts.AddressManagerProxy.deployedBytecode.object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // OwnableUpgradeable
                _owner: contractOwner,
                // AddressManager
                addresses: {
                    [chainId]: {
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("taiko")
                        )]: addressMap.TaikoL2Proxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridge")
                        )]: addressMap.BridgeProxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("token_vault")
                        )]: addressMap.TokenVaultProxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("ether_vault")
                        )]: addressMap.EtherVaultProxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("signal_service")
                        )]: addressMap.SignalServiceProxy,
                    },
                },
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedAddressManager,
            },
            isProxy: true,
        },
        ProxiedTaikoL2: {
            address: addressMap.ProxiedTaikoL2,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedTaikoL2,
                addressMap
            ),
        },
        TaikoL2Proxy: {
            address: addressMap.TaikoL2Proxy,
            deployedBytecode:
                contractArtifacts.TaikoL2Proxy.deployedBytecode.object,
            variables: {
                // TaikoL2
                // keccak256(abi.encodePacked(block.chainid, basefee, ancestors))
                publicInputHash: `${ethers.utils.solidityKeccak256(
                    ["bytes32[256]"],
                    [
                        new Array(255)
                            .fill(ethers.constants.HashZero)
                            .concat([
                                ethers.utils.hexZeroPad(
                                    ethers.utils.hexlify(chainId),
                                    32
                                ),
                            ]),
                    ]
                )}`,
                _eip1559Config: {
                    yscale: ethers.BigNumber.from(param1559.yscale),
                    xscale: ethers.BigNumber.from(param1559.xscale),
                    gasIssuedPerSecond: ethers.BigNumber.from(
                        param1559.gasIssuedPerSecond
                    ),
                },
                parentTimestamp: Math.floor(new Date().getTime() / 1000),
                gasExcess: ethers.BigNumber.from(param1559.gasExcess),
                // AddressResolver
                _addressManager: addressMap.AddressManagerProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedTaikoL2,
            },
            isProxy: true,
        },
        ProxiedBridge: {
            address: addressMap.ProxiedBridge,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedBridge,
                addressMap
            ),
        },
        BridgeProxy: {
            address: addressMap.BridgeProxy,
            deployedBytecode:
                contractArtifacts.BridgeProxy.deployedBytecode.object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _status: 1, // _NOT_ENTERED
                // OwnableUpgradeable
                _owner: contractOwner,
                // AddressResolver
                _addressManager: addressMap.AddressManagerProxy,
                // Bridge
                _state: {},
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedBridge,
            },
            isProxy: true,
        },
        ProxiedTokenVault: {
            address: addressMap.ProxiedTokenVault,
            deployedBytecode:
                contractArtifacts.ProxiedTokenVault.deployedBytecode.object,
        },
        TokenVaultProxy: {
            address: addressMap.TokenVaultProxy,
            deployedBytecode:
                contractArtifacts.TokenVaultProxy.deployedBytecode.object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _status: 1, // _NOT_ENTERED
                // OwnableUpgradeable
                _owner: contractOwner,
                // AddressResolver
                _addressManager: addressMap.AddressManagerProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedTokenVault,
            },
            isProxy: true,
        },
        ProxiedEtherVault: {
            address: addressMap.ProxiedEtherVault,
            deployedBytecode:
                contractArtifacts.ProxiedEtherVault.deployedBytecode.object,
        },
        EtherVaultProxy: {
            address: addressMap.EtherVaultProxy,
            deployedBytecode:
                contractArtifacts.EtherVaultProxy.deployedBytecode.object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _status: 1, // _NOT_ENTERED
                // OwnableUpgradeable
                _owner: contractOwner,
                // AddressResolver
                _addressManager: addressMap.AddressManagerProxy,
                // EtherVault
                // Authorize L2 bridge
                _authorizedAddrs: { [`${addressMap.BridgeProxy}`]: true },
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedEtherVault,
            },
            isProxy: true,
        },
        ProxiedSignalService: {
            address: addressMap.ProxiedSignalService,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedSignalService,
                addressMap
            ),
        },
        SignalServiceProxy: {
            address: addressMap.SignalServiceProxy,
            deployedBytecode:
                contractArtifacts.SignalServiceProxy.deployedBytecode.object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _status: 1, // _NOT_ENTERED
                // OwnableUpgradeable
                _owner: contractOwner,
                // AddressResolver
                _addressManager: addressMap.AddressManagerProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedSignalService,
            },
            isProxy: true,
        },
    };
}

// linkContractLibs tries to link contract deployedBytecode to its libraries.
// Ref: https://docs.soliditylang.org/en/latest/using-the-compiler.html#library-linking
function linkContractLibs(artifact: any, addressMap: any) {
    const linkedBytecode: string = linker.linkBytecode(
        artifact.deployedBytecode.object,
        getLinkLibs(
            artifact,
            linker.findLinkReferences(artifact.deployedBytecode.object),
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

    Object.values(artifact.deployedBytecode.linkReferences).forEach(
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
