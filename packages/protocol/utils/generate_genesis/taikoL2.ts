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
            storageLayoutName = `${storageLayoutName}`;
        }
        storageLayoutName = contractName.includes("AddressManager")
            ? "AddressManager"
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
        Bridge: require(path.join(ARTIFACTS_PATH, "./Bridge.sol/Bridge.json")),
        ERC20Vault: require(
            path.join(ARTIFACTS_PATH, "./ERC20Vault.sol/ERC20Vault.json"),
        ),
        ERC721Vault: require(
            path.join(ARTIFACTS_PATH, "./ERC721Vault.sol/ERC721Vault.json"),
        ),
        ERC1155Vault: require(
            path.join(ARTIFACTS_PATH, "./ERC1155Vault.sol/ERC1155Vault.json"),
        ),
        SignalService: require(
            path.join(ARTIFACTS_PATH, "./SignalService.sol/SignalService.json"),
        ),
        AddressManagerForSingletons: require(
            path.join(
                ARTIFACTS_PATH,
                "./AddressManager.sol/AddressManager.json",
            ),
        ),
        BridgedERC20: require(
            path.join(ARTIFACTS_PATH, "./BridgedERC20.sol/BridgedERC20.json"),
        ),
        BridgedERC721: require(
            path.join(ARTIFACTS_PATH, "./BridgedERC721.sol/BridgedERC721.json"),
        ),
        BridgedERC1155: require(
            path.join(
                ARTIFACTS_PATH,
                "./BridgedERC1155.sol/BridgedERC1155.json",
            ),
        ),
        ERC20NativeRegistry: require(
            path.join(
                ARTIFACTS_PATH,
                "./ERC20NativeRegistry.sol/ERC20NativeRegistry.json",
            ),
        ),
        BridgedERC20Adapter: require(
            path.join(
                ARTIFACTS_PATH,
                "./BridgedERC20Adapter.sol/BridgedERC20Adapter.json",
            ),
        ),
        UsdcAdapter: require(
            path.join(ARTIFACTS_PATH, "./UsdcAdapter.sol/UsdcAdapter.json"),
        ),
        // Non-singletons
        TaikoL2: require(
            path.join(ARTIFACTS_PATH, "./TaikoL2.sol/TaikoL2.json"),
        ),
        AddressManager: require(
            path.join(
                ARTIFACTS_PATH,
                "./AddressManager.sol/AddressManager.json",
            ),
        ),
    };

    // TODO(david): use ERC1967Proxy please
    const proxy = require(
        path.join(ARTIFACTS_PATH, "./ERC1967Proxy.sol/ERC1967Proxy.json"),
    );

    // Singletons
    contractArtifacts.SingletonBridgeProxy = proxy;
    contractArtifacts.SingletonERC20VaultProxy = proxy;
    contractArtifacts.SingletonERC721VaultProxy = proxy;
    contractArtifacts.SingletonERC1155VaultProxy = proxy;
    contractArtifacts.SingletonSignalServiceProxy = proxy;
    contractArtifacts.SingletonAddressManagerForSingletonsProxy = proxy;
    contractArtifacts.SingletonERC20NativeRegistryProxy = proxy;
    // Non-singletons
    contractArtifacts.SingletonTaikoL2Proxy = proxy;
    contractArtifacts.AddressManagerProxy = proxy;

    const addressMap: any = {};

    for (const [contractName, artifact] of Object.entries(contractArtifacts)) {
        let bytecode = (artifact as any).bytecode;

        switch (contractName) {
            case "TaikoL2":
                bytecode = linkContractLibs(
                    contractArtifacts.TaikoL2,
                    addressMap,
                );
                break;
            case "Bridge":
                bytecode = linkContractLibs(
                    contractArtifacts.Bridge,
                    addressMap,
                );
                break;
            case "SignalService":
                bytecode = linkContractLibs(
                    contractArtifacts.SignalService,
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
        AddressManagerForSingletons: {
            address: addressMap.AddressManagerForSingletons,
            deployedBytecode:
                contractArtifacts.AddressManagerForSingletons.deployedBytecode
                    .object,
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
                // Ownable2Upgradeable
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
                        )]: addressMap.BridgedERC20,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridged_erc721"),
                        )]: addressMap.BridgedERC721,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridged_erc1155"),
                        )]: addressMap.BridgedERC1155,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("erc20_native_registry"),
                        )]: addressMap.SingletonERC20NativeRegistryProxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridged_erc20_adapter"),
                        )]: addressMap.BridgedERC20Adapter,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("usdc_adapter"),
                        )]: addressMap.UsdcAdapter,
                    },
                },
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.AddressManagerForSingletons,
            },
            isProxy: true,
        },
        Bridge: {
            address: addressMap.Bridge,
            deployedBytecode: linkContractLibs(
                contractArtifacts.Bridge,
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
                // Ownable2Upgradeable
                _owner: contractOwner,
                // AddressResolver
                addressManager:
                    addressMap.SingletonAddressManagerForSingletonsProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.Bridge,
            },
            isProxy: true,
        },
        ERC20Vault: {
            address: addressMap.ERC20Vault,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ERC20Vault,
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
                // Ownable2Upgradeable
                _owner: contractOwner,
                // AddressResolver
                addressManager:
                    addressMap.SingletonAddressManagerForSingletonsProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ERC20Vault,
            },
            isProxy: true,
        },
        ERC721Vault: {
            address: addressMap.ERC721Vault,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ERC721Vault,
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
                // Ownable2Upgradeable
                _owner: contractOwner,
                // AddressResolver
                addressManager:
                    addressMap.SingletonAddressManagerForSingletonsProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ERC721Vault,
            },
            isProxy: true,
        },
        ERC1155Vault: {
            address: addressMap.ERC1155Vault,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ERC1155Vault,
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
                // Ownable2Upgradeable
                _owner: contractOwner,
                // AddressResolver
                addressManager:
                    addressMap.SingletonAddressManagerForSingletonsProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ERC1155Vault,
            },
            isProxy: true,
        },
        SignalService: {
            address: addressMap.SignalService,
            deployedBytecode: linkContractLibs(
                contractArtifacts.SignalService,
                addressMap,
            ),
        },
        BridgedERC20: {
            address: addressMap.BridgedERC20,
            deployedBytecode:
                contractArtifacts.BridgedERC20.deployedBytecode.object,
        },
        BridgedERC721: {
            address: addressMap.BridgedERC721,
            deployedBytecode:
                contractArtifacts.BridgedERC721.deployedBytecode.object,
        },
        BridgedERC1155: {
            address: addressMap.BridgedERC1155,
            deployedBytecode:
                contractArtifacts.BridgedERC1155.deployedBytecode.object,
        },
        ERC20NativeRegistry: {
            address: addressMap.ERC20NativeRegistry,
            deployedBytecode:
                contractArtifacts.ERC20NativeRegistry.deployedBytecode.object,
        },
        SingletonERC20NativeRegistryProxy: {
            address: addressMap.SingletonERC20NativeRegistryProxy,
            deployedBytecode:
                contractArtifacts.SingletonERC20NativeRegistryProxy
                    .deployedBytecode.object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _reentry: 1, // _FALSE
                _paused: 1, // _FALSE
                // Ownable2Upgradeable
                _owner: contractOwner,
                // AddressResolver
                addressManager:
                    addressMap.SingletonAddressManagerForSingletonsProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ERC20NativeRegistry,
            },
            isProxy: true,
        },
        BridgedERC20Adapter: {
            address: addressMap.BridgedERC20Adapter,
            deployedBytecode:
                contractArtifacts.BridgedERC20Adapter.deployedBytecode.object,
        },
        UsdcAdapter: {
            address: addressMap.UsdcAdapter,
            deployedBytecode:
                contractArtifacts.UsdcAdapter.deployedBytecode.object,
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
                // Ownable2Upgradeable
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
                [IMPLEMENTATION_SLOT]: addressMap.SignalService,
            },
            isProxy: true,
        },
        AddressManager: {
            address: addressMap.AddressManager,
            deployedBytecode:
                contractArtifacts.AddressManager.deployedBytecode.object,
        },
        // Non-singletons
        TaikoL2: {
            address: addressMap.TaikoL2,
            deployedBytecode: linkContractLibs(
                contractArtifacts.TaikoL2,
                addressMap,
            ),
        },
        SingletonTaikoL2Proxy: {
            address: addressMap.SingletonTaikoL2Proxy,
            deployedBytecode:
                contractArtifacts.SingletonTaikoL2Proxy.deployedBytecode.object,
            variables: {
                // TaikoL2
                // Ownable2Upgradeable
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
                [IMPLEMENTATION_SLOT]: addressMap.TaikoL2,
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
                // Ownable2Upgradeable
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
                [IMPLEMENTATION_SLOT]: addressMap.AddressManager,
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
