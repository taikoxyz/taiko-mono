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

    let bridgeInitialEtherBalance = ethers.BigNumber.from("2").pow(128).sub(1); // MaxUint128

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
            contractName === "BridgeProxy"
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
        // Libraries
        LibDeploy: require(
            path.join(ARTIFACTS_PATH, "./LibDeploy.sol/LibDeploy.json"),
        ),
        // Contracts
        ProxiedAddressManager: require(
            path.join(
                ARTIFACTS_PATH,
                "./AddressManager.sol/ProxiedAddressManager.json",
            ),
        ),
        ProxiedTaikoL2: require(
            path.join(ARTIFACTS_PATH, "./TaikoL2.sol/ProxiedTaikoL2.json"),
        ),
        ProxiedBridge: require(
            path.join(ARTIFACTS_PATH, "./Bridge.sol/ProxiedBridge.json"),
        ),
        ProxiedERC20Vault: require(
            path.join(
                ARTIFACTS_PATH,
                "./ERC20Vault.sol/ProxiedERC20Vault.json",
            ),
        ),
        ProxiedERC721Vault: require(
            path.join(
                ARTIFACTS_PATH,
                "./ERC721Vault.sol/ProxiedERC721Vault.json",
            ),
        ),
        ProxiedERC1155Vault: require(
            path.join(
                ARTIFACTS_PATH,
                "./ERC1155Vault.sol/ProxiedERC1155Vault.json",
            ),
        ),
        ProxiedSignalService: require(
            path.join(
                ARTIFACTS_PATH,
                "./SignalService.sol/ProxiedSignalService.json",
            ),
        ),
    };

    const proxy = require(
        path.join(
            ARTIFACTS_PATH,
            "./TransparentUpgradeableProxy.sol/TransparentUpgradeableProxy.json",
        ),
    );
    contractArtifacts.TaikoL2Proxy = proxy;
    contractArtifacts.BridgeProxy = proxy;
    contractArtifacts.ERC20VaultProxy = proxy;
    contractArtifacts.ERC721VaultProxy = proxy;
    contractArtifacts.ERC1155VaultProxy = proxy;
    contractArtifacts.SignalServiceProxy = proxy;
    contractArtifacts.AddressManagerProxy = proxy;

    const addressMap: any = {};

    for (const [contractName, artifact] of Object.entries(contractArtifacts)) {
        let bytecode = (artifact as any).bytecode;

        switch (contractName) {
            case "ProxiedTaikoL2":
                bytecode = linkContractLibs(
                    contractArtifacts.ProxiedTaikoL2,
                    addressMap,
                );
                break;
            case "ProxiedBridge":
                bytecode = linkContractLibs(
                    contractArtifacts.ProxiedBridge,
                    addressMap,
                );
                break;
            case "ProxiedSignalService":
                bytecode = linkContractLibs(
                    contractArtifacts.ProxiedSignalService,
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
        // Libraries
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
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                _pendingOwner: ethers.constants.AddressZero,
                // AddressManager
                addresses: {
                    [chainId]: {
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("taiko"),
                        )]: addressMap.TaikoL2Proxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridge"),
                        )]: addressMap.BridgeProxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("erc20_vault"),
                        )]: addressMap.ERC20VaultProxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("erc721_vault"),
                        )]: addressMap.ERC721VaultProxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("erc1155_vault"),
                        )]: addressMap.ERC1155VaultProxy,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("signal_service"),
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
                addressMap,
            ),
        },
        TaikoL2Proxy: {
            address: addressMap.TaikoL2Proxy,
            deployedBytecode:
                contractArtifacts.TaikoL2Proxy.deployedBytecode.object,
            variables: {
                // TaikoL2
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                _pendingOwner: ethers.constants.AddressZero,
                signalService: addressMap.SignalServiceProxy,
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
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedTaikoL2,
            },
            isProxy: true,
        },
        ProxiedBridge: {
            address: addressMap.ProxiedBridge,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedBridge,
                addressMap,
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
                _reentry: 1, // _FALSE
                _paused: 1, // _FALSE
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                _pendingOwner: ethers.constants.AddressZero,
                // AddressResolver
                addressManager: addressMap.AddressManagerProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedBridge,
            },
            isProxy: true,
        },
        ProxiedERC20Vault: {
            address: addressMap.ProxiedERC20Vault,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedERC20Vault,
                addressMap,
            ),
        },
        ERC20VaultProxy: {
            address: addressMap.ERC20VaultProxy,
            deployedBytecode:
                contractArtifacts.ERC20VaultProxy.deployedBytecode.object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _reentry: 1, // _FALSE
                _paused: 1, // _FALSE
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                _pendingOwner: ethers.constants.AddressZero,
                // AddressResolver
                addressManager: addressMap.AddressManagerProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedERC20Vault,
            },
            isProxy: true,
        },
        ProxiedERC721Vault: {
            address: addressMap.ProxiedERC721Vault,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedERC721Vault,
                addressMap,
            ),
        },
        ERC721VaultProxy: {
            address: addressMap.ERC721VaultProxy,
            deployedBytecode:
                contractArtifacts.ERC721VaultProxy.deployedBytecode.object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _reentry: 1, // _FALSE
                _paused: 1, // _FALSE
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                _pendingOwner: ethers.constants.AddressZero,
                // AddressResolver
                addressManager: addressMap.AddressManagerProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedERC721Vault,
            },
            isProxy: true,
        },
        ProxiedERC1155Vault: {
            address: addressMap.ProxiedERC1155Vault,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedERC1155Vault,
                addressMap,
            ),
        },
        ERC1155VaultProxy: {
            address: addressMap.ERC1155VaultProxy,
            deployedBytecode:
                contractArtifacts.ERC1155VaultProxy.deployedBytecode.object,
            variables: {
                // initializer
                _initialized: 1,
                _initializing: false,
                // ReentrancyGuardUpgradeable
                _reentry: 1, // _FALSE
                _paused: 1, // _FALSE
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                _pendingOwner: ethers.constants.AddressZero,
                // AddressResolver
                addressManager: addressMap.AddressManagerProxy,
            },
            slots: {
                [ADMIN_SLOT]: contractAdmin,
                [IMPLEMENTATION_SLOT]: addressMap.ProxiedERC1155Vault,
            },
            isProxy: true,
        },
        ProxiedSignalService: {
            address: addressMap.ProxiedSignalService,
            deployedBytecode: linkContractLibs(
                contractArtifacts.ProxiedSignalService,
                addressMap,
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
                _reentry: 1, // _FALSE
                _paused: 1, // _FALSE
                // Ownable2StepUpgradeable
                _owner: contractOwner,
                _pendingOwner: ethers.constants.AddressZero,
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
