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
    result: Result,
): Promise<Result> {
    const { contractOwner, chainId, seedAccounts, contractAdmin } = config;

    const alloc: any = {};

    // Premint 1 billion ethers to the bridge, current Ethereum's supply is ~120.27M.
    let bridgeInitialEtherBalance = ethers.utils.parseEther(`${1_000_000_000}`);

    for (const seedAccount of seedAccounts) {
        const accountAddress = Object.keys(seedAccount)[0];
        const balance = ethers.utils.parseEther(
            `${Object.values(seedAccount)[0]}`,
        );

        console.log(`seedAccountAddress: ${accountAddress}`);
        console.log(`premintBalance: ${balance}`);

        alloc[accountAddress] = { balance: balance.toHexString() };

        bridgeInitialEtherBalance = bridgeInitialEtherBalance.sub(balance);
    }

    console.log({ bridgeInitialEtherBalance });
    console.log("\n");

    const contractConfigs: any = await generateContractConfigs(
        contractOwner,
        contractAdmin,
        chainId,
        config.contractAddresses,
        config.param1559,
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

        // pre-mint ETHs for Bridge contract
        alloc[contractConfig.address].balance =
            contractName === "SingletonBridgeProxy"
                ? bridgeInitialEtherBalance.toHexString()
                : "0x0";

        // since we enable storageLayout compiler output in hardhat.config.ts,
        // rollup/artifacts/build-info will contain storage layouts, here
        // reading it using smock package.
        let storageLayoutName = contractName;
        if (contractConfig.isProxy) {
            storageLayoutName = contractName.replace("Proxy", "");
            storageLayoutName = `Proxied${storageLayoutName}`;
        }
        storageLayoutName = contractName.includes("AddressManager")
            ? "ProxiedAddressManager"
            : storageLayoutName;

        storageLayouts[contractName] =
            await getStorageLayout(storageLayoutName);
        // initialize contract variables, we only care about the variables
        // that need to be initialized with non-zero value.
        const slots = computeStorageSlots(
            storageLayouts[contractName],
            contractConfigs[contractName].variables,
        );

        for (const slot of slots) {
            alloc[contractConfig.address].storage[slot.key] = slot.val;
        }

        if (contractConfigs[contractName].slots) {
            for (const [slot, val] of Object.entries(
                contractConfigs[contractName].slots,
            )) {
                alloc[contractConfig.address].storage[slot] = val;
            }
        }
    }

    result.alloc = Object.assign(result.alloc, alloc);
    result.storageLayouts = Object.assign(
        result.storageLayouts,
        storageLayouts,
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
    param1559: any,
): Promise<any> {
    const contractArtifacts: any = {
        // ============ Contracts ============
        // Singletons
        ProxiedSingletonBridge: require(
            path.join(
                ARTIFACTS_PATH,
                "./Bridge.sol/ProxiedSingletonBridge.json",
            ),
        ),
        ProxiedSingletonERC20Vault: require(
            path.join(
                ARTIFACTS_PATH,
                "./ERC20Vault.sol/ProxiedSingletonERC20Vault.json",
            ),
        ),
        ProxiedSingletonERC721Vault: require(
            path.join(
                ARTIFACTS_PATH,
                "./ERC721Vault.sol/ProxiedSingletonERC721Vault.json",
            ),
        ),
        ProxiedSingletonERC1155Vault: require(
            path.join(
                ARTIFACTS_PATH,
                "./ERC1155Vault.sol/ProxiedSingletonERC1155Vault.json",
            ),
        ),
        ProxiedSingletonSignalService: require(
            path.join(
                ARTIFACTS_PATH,
                "./SignalService.sol/ProxiedSingletonSignalService.json",
            ),
        ),
        ProxiedSingletonAddressManagerForSingletons: require(
            path.join(
                ARTIFACTS_PATH,
                "./AddressManager.sol/ProxiedAddressManager.json",
            ),
        ),
        ProxiedBridgedERC20: require(
            path.join(
                ARTIFACTS_PATH,
                "./BridgedERC20.sol/ProxiedBridgedERC20.json",
            ),
        ),
        ProxiedBridgedERC721: require(
            path.join(
                ARTIFACTS_PATH,
                "./BridgedERC721.sol/ProxiedBridgedERC721.json",
            ),
        ),
        ProxiedBridgedERC1155: require(
            path.join(
                ARTIFACTS_PATH,
                "./BridgedERC1155.sol/ProxiedBridgedERC1155.json",
            ),
        ),
        // Non-singletons
        ProxiedSingletonTaikoL2: require(
            path.join(
                ARTIFACTS_PATH,
                "./TaikoL2.sol/ProxiedSingletonTaikoL2.json",
            ),
        ),
        ProxiedAddressManager: require(
            path.join(
                ARTIFACTS_PATH,
                "./AddressManager.sol/ProxiedAddressManager.json",
            ),
        ),
    };

    const proxy = require(
        path.join(
            ARTIFACTS_PATH,
            "./TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json",
        ),
    );

    // Singletons
    contractArtifacts.SingletonBridgeProxy = proxy;
    contractArtifacts.SingletonERC20VaultProxy = proxy;
    contractArtifacts.SingletonERC721VaultProxy = proxy;
    contractArtifacts.SingletonERC1155VaultProxy = proxy;
    contractArtifacts.SingletonSignalServiceProxy = proxy;
    contractArtifacts.SingletonAddressManagerForSingletonsProxy = proxy;
    // Non-singletons
    contractArtifacts.SingletonTaikoL2Proxy = proxy;
    contractArtifacts.AddressManagerProxy = proxy;

    const addressMap: any = {};

    for (const [contractName, artifact] of Object.entries(contractArtifacts)) {
        let bytecode = (artifact as any).bytecode;

        switch (contractName) {
            case "ProxiedSingletonTaikoL2":
                bytecode = linkContractLibs(
                    contractArtifacts.ProxiedSingletonTaikoL2,
                    addressMap,
                );
                break;
            case "ProxiedSingletonBridge":
                bytecode = linkContractLibs(
                    contractArtifacts.ProxiedSingletonBridge,
                    addressMap,
                );
                break;
            case "ProxiedSingletonSignalService":
                bytecode = linkContractLibs(
                    contractArtifacts.ProxiedSingletonSignalService,
                    addressMap,
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
                    ethers.utils.toUtf8Bytes(`${chainId}${contractName}`),
                ),
                ethers.utils.keccak256(ethers.utils.toUtf8Bytes(bytecode)),
            );
        }
    }

    console.log("pre-computed addresses:");
    console.log(addressMap);

    return {
        // Singletons
        ProxiedSingletonAddressManagerForSingletons: {
            address: addressMap.ProxiedSingletonAddressManagerForSingletons,
            deployedBytecode:
                contractArtifacts.ProxiedSingletonAddressManagerForSingletons
                    .deployedBytecode.object,
        },
        SingletonAddressManagerForSingletonsProxy: {
            address: addressMap.SingletonAddressManagerForSingletonsProxy,
            deployedBytecode:
                contractArtifacts.SingletonAddressManagerForSingletonsProxy
                    .deployedBytecode.object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                // AddressManager
                addresses: {
                    [chainId]: {
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridge"),
                        )]: addressMap.SingletonBridgeProxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("erc20_vault"),
                        )]: addressMap.SingletonERC20VaultProxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("erc721_vault"),
                        )]: addressMap.SingletonERC721VaultProxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("erc1155_vault"),
                        )]: addressMap.SingletonERC1155VaultProxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("signal_service"),
                        )]: addressMap.SingletonSignalServiceProxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridged_erc20"),
                        )]: addressMap.ProxiedBridgedERC20,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridged_erc721"),
                        )]: addressMap.ProxiedBridgedERC721,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridged_erc1155"),
                        )]: addressMap.ProxiedBridgedERC1155,
                    },
                },
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]:
                    addressMap.ProxiedSingletonAddressManagerForSingletons,
            },
            isProxy: true,
        },
        ProxiedSingletonBridge: {
            address: addressMap.ProxiedSingletonBridge,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedSingletonBridge,
                addressMap,
            ),
        },
        SingletonBridgeProxy: {
            address: addressMap.SingletonBridgeProxy,
            deployedBytecode:
                contractArtifacts.SingletonBridgeProxy.deployedBytecode.object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _reentry: 1, // _FALSE
                _paused: 1, // _FALSE
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                // AddressResolver
                addressManager:
                    addressMap.SingletonAddressManagerForSingletonsProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedSingletonBridge,
            },
            isProxy: true,
        },
        ProxiedSingletonERC20Vault: {
            address: addressMap.ProxiedSingletonERC20Vault,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedSingletonERC20Vault,
                addressMap,
            ),
        },
        SingletonERC20VaultProxy: {
            address: addressMap.SingletonERC20VaultProxy,
            deployedBytecode:
                contractArtifacts.SingletonERC20VaultProxy.deployedBytecode
                    .object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _reentry: 1, // _FALSE
                _paused: 1, // _FALSE
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                // AddressResolver
                addressManager:
                    addressMap.SingletonAddressManagerForSingletonsProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedSingletonERC20Vault,
            },
            isProxy: true,
        },
        ProxiedSingletonERC721Vault: {
            address: addressMap.ProxiedSingletonERC721Vault,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedSingletonERC721Vault,
                addressMap,
            ),
        },
        SingletonERC721VaultProxy: {
            address: addressMap.SingletonERC721VaultProxy,
            deployedBytecode:
                contractArtifacts.SingletonERC721VaultProxy.deployedBytecode
                    .object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _reentry: 1, // _FALSE
                _paused: 1, // _FALSE
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                // AddressResolver
                addressManager:
                    addressMap.SingletonAddressManagerForSingletonsProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedSingletonERC721Vault,
            },
            isProxy: true,
        },
        ProxiedSingletonERC1155Vault: {
            address: addressMap.ProxiedSingletonERC1155Vault,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedSingletonERC1155Vault,
                addressMap,
            ),
        },
        SingletonERC1155VaultProxy: {
            address: addressMap.SingletonERC1155VaultProxy,
            deployedBytecode:
                contractArtifacts.SingletonERC1155VaultProxy.deployedBytecode
                    .object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _reentry: 1, // _FALSE
                _paused: 1, // _FALSE
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                // AddressResolver
                addressManager:
                    addressMap.SingletonAddressManagerForSingletonsProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedSingletonERC1155Vault,
            },
            isProxy: true,
        },
        ProxiedSingletonSignalService: {
            address: addressMap.ProxiedSingletonSignalService,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedSingletonSignalService,
                addressMap,
            ),
        },
        ProxiedBridgedERC20: {
            address: addressMap.ProxiedBridgedERC20,
            deployedBytecode:
                contractArtifacts.ProxiedBridgedERC20.deployedBytecode.object,
        },
        ProxiedBridgedERC721: {
            address: addressMap.ProxiedBridgedERC721,
            deployedBytecode:
                contractArtifacts.ProxiedBridgedERC721.deployedBytecode.object,
        },
        ProxiedBridgedERC1155: {
            address: addressMap.ProxiedBridgedERC1155,
            deployedBytecode:
                contractArtifacts.ProxiedBridgedERC1155.deployedBytecode.object,
        },
        SingletonSignalServiceProxy: {
            address: addressMap.SingletonSignalServiceProxy,
            deployedBytecode:
                contractArtifacts.SingletonSignalServiceProxy.deployedBytecode
                    .object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _reentry: 1, // _FALSE
                _paused: 1, // _FALSE
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                authorizedAddresses: {
                    [addressMap.SingletonTaikoL2Proxy]: ethers.utils.hexZeroPad(
                        ethers.utils.hexlify(chainId),
                        32,
                    ),
                },
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedSingletonSignalService,
            },
            isProxy: true,
        },
        ProxiedAddressManager: {
            address: addressMap.ProxiedAddressManager,
            deployedBytecode:
                contractArtifacts.ProxiedAddressManager.deployedBytecode.object,
        },
        // Non-singletons
        ProxiedSingletonTaikoL2: {
            address: addressMap.ProxiedSingletonTaikoL2,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedSingletonTaikoL2,
                addressMap,
            ),
        },
        SingletonTaikoL2Proxy: {
            address: addressMap.SingletonTaikoL2Proxy,
            deployedBytecode:
                contractArtifacts.SingletonTaikoL2Proxy.deployedBytecode.object,
            variables: {
                // TaikoL2
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                signalService: addressMap.SingletonSignalServiceProxy,
                gasExcess: param1559.gasExcess,
                // keccak256(abi.encodePacked(block.chainid, basefee, ancestors))
                publicInputHash: `${ethers.utils.solidityKeccak256(
                    ["bytes32[256]"],
                    [
                        new Array(255)
                            .fill(ethers.constants.HashZero)
                            .concat([
                                ethers.utils.hexZeroPad(
                                    ethers.utils.hexlify(chainId),
                                    32,
                                ),
                            ]),
                    ],
                )}`,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedSingletonTaikoL2,
            },
            isProxy: true,
        },
        AddressManagerProxy: {
            address: addressMap.AddressManagerProxy,
            deployedBytecode:
                contractArtifacts.AddressManagerProxy.deployedBytecode.object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                // AddressManager
                addresses: {
                    [chainId]: {
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("taiko"),
                        )]: addressMap.SingletonTaikoL2Proxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("signal_service"),
                        )]: addressMap.SingletonSignalServiceProxy,
                    },
                },
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedAddressManager,
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
            addressMap,
        ),
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
                    linkReference[contractName][0].start + 1,
            );

            result[linkRefKey] = addressMap[contractName];
        },
    );

    return result;
}
