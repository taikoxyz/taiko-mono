import { Config, Result } from "./interface";
const path = require("path");
const { ethers } = require("ethers");
// eslint-disable-next-line node/no-extraneous-require
const linker = require("solc/linker");
const { computeStorageSlots, getStorageLayout } = require("./utils");
const ARTIFACTS_PATH = path.join(__dirname, "../../../out/layer2");
// const SHARED_ARTIFACTS_PATH = path.join(__dirname, "../../../out/shared");

const IMPLEMENTATION_SLOT =
    "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

// deployTaikoAnchor generates a L2 genesis alloc of the TaikoAnchor contract.
export async function deployTaikoAnchor(
    config: Config,
    result: Result,
): Promise<Result> {
    const { contractOwner, l1ChainId, chainId, seedAccounts } = config;

    const alloc: any = {};

    // Premint 999_999_800 ethers to the bridge, current Ethereum's supply is ~120.27M.
    let bridgeInitialEtherBalance = ethers.utils.parseEther(`${999_999_800}`);

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
        l1ChainId,
        chainId,
        config.contractAddresses,
        config.param1559,
        config.pacayaTaikoAnchor,
        config.remoteSignalService,
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
            contractName === "Bridge"
                ? bridgeInitialEtherBalance.toHexString()
                : "0x0";

        // since we enable storageLayout compiler output in hardhat.config.ts,
        // rollup/artifacts/build-info will contain storage layouts, here
        // reading it using smock package.
        let storageLayoutName = contractName;
        if (!contractConfig.isProxy)
            storageLayoutName = `${contractName.replace("Impl", "")}`;

        storageLayoutName = contractName.includes("Resolver")
            ? "DefaultResolver"
            : storageLayoutName;

        storageLayoutName =
            storageLayoutName === "TaikoAnchor" ? "Anchor" : storageLayoutName;

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

        if (contractName === "TaikoAnchor") {
            const routerLayout = await getStorageLayout("AnchorForkRouter");
            const routerSlots = computeStorageSlots(routerLayout, {
                _initialized: 1,
                _initializing: false,
                _owner: contractOwner,
                _pendingOwner: ethers.constants.AddressZero,
            });

            for (const slot of routerSlots) {
                alloc[contractConfig.address].storage[slot.key] = slot.val;
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
    l1ChainId: number,
    chainId: number,
    hardCodedAddresses: any,
    param1559: any,
    pacayaTaikoAnchor: string,
    remoteSignalService: string,
): Promise<any> {
    const contractArtifacts: any = {
        // ============ Contracts ============
        // Shared Contracts
        BridgeImpl: require(
            path.join(ARTIFACTS_PATH, "./Bridge.sol/Bridge.json"),
        ),
        ERC20VaultImpl: require(
            path.join(ARTIFACTS_PATH, "./ERC20Vault.sol/ERC20Vault.json"),
        ),
        ERC721VaultImpl: require(
            path.join(ARTIFACTS_PATH, "./ERC721Vault.sol/ERC721Vault.json"),
        ),
        ERC1155VaultImpl: require(
            path.join(ARTIFACTS_PATH, "./ERC1155Vault.sol/ERC1155Vault.json"),
        ),
        SignalServiceImpl: require(
            path.join(ARTIFACTS_PATH, "./SignalService.sol/SignalService.json"),
        ),
        SharedResolverImpl: require(
            path.join(
                ARTIFACTS_PATH,
                "./DefaultResolver.sol/DefaultResolver.json",
            ),
        ),
        // Bridged Token Contracts
        BridgedERC20Impl: require(
            path.join(ARTIFACTS_PATH, "./BridgedERC20.sol/BridgedERC20.json"),
        ),
        BridgedERC721Impl: require(
            path.join(ARTIFACTS_PATH, "./BridgedERC721.sol/BridgedERC721.json"),
        ),
        BridgedERC1155Impl: require(
            path.join(
                ARTIFACTS_PATH,
                "./BridgedERC1155.sol/BridgedERC1155.json",
            ),
        ),
        // Rollup Contracts
        TaikoAnchorImpl: require(
            path.join(ARTIFACTS_PATH, "./Anchor.sol/Anchor.json"),
        ),
        RollupResolverImpl: require(
            path.join(
                ARTIFACTS_PATH,
                "./DefaultResolver.sol/DefaultResolver.json",
            ),
        ),
        AnchorForkRouterImpl: require(
            path.join(
                ARTIFACTS_PATH,
                "./AnchorForkRouter.sol/AnchorForkRouter.json",
            ),
        ),
        // Libraries
        LibNetwork: require(
            path.join(ARTIFACTS_PATH, "./LibNetwork.sol/LibNetwork.json"),
        ),
    };

    const proxy = require(
        path.join(ARTIFACTS_PATH, "./ERC1967Proxy.sol/ERC1967Proxy.json"),
    );

    // Shared Contracts
    contractArtifacts.Bridge = proxy;
    contractArtifacts.ERC20Vault = proxy;
    contractArtifacts.ERC721Vault = proxy;
    contractArtifacts.ERC1155Vault = proxy;
    contractArtifacts.SignalService = proxy;
    contractArtifacts.SharedResolver = proxy;
    // Rollup Contracts
    contractArtifacts.TaikoAnchor = proxy;
    contractArtifacts.RollupResolver = proxy;

    const addressMap: any = {};

    const essentialContractReferencesMap: any = getImmutableReference(
        "EssentialContract",
        ["__resolver"],
    );
    const uupsImmutableReferencesMap: any = getImmutableReference(
        "UUPSUpgradeable",
        ["__self"],
    );
    const taikoAnchorReferencesMap: any = Object.assign(
        {},
        getImmutableReference("Anchor", ["checkpointStore", "l1ChainId"]),
    );
    const anchorForkRouterReferencesMap: any = getImmutableReference(
        "AnchorForkRouter",
        ["oldFork", "newFork"],
    );
    const bridgeReferencesMap: any = getImmutableReference("Bridge", [
        "signalService",
    ]);
    const bridgedERC20ReferencesMap: any = getImmutableReference(
        "BridgedERC20",
        ["erc20Vault"],
    );
    const bridgedERC721ReferencesMap: any = getImmutableReference(
        "BridgedERC721",
        ["erc721Vault"],
    );
    const bridgedERC1155ReferencesMap: any = getImmutableReference(
        "BridgedERC1155",
        ["erc1155Vault"],
    );
    const signalServiceReferencesMap: any = getImmutableReference(
        "SignalService",
        ["_authorizedSyncer", "_remoteSignalService"],
    );

    for (const [contractName, artifact] of Object.entries(contractArtifacts)) {
        const bytecode = (artifact as any).bytecode;

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
        // Shared Contracts
        SharedResolverImpl: {
            address: addressMap.SharedResolverImpl,
            deployedBytecode: replaceImmutableValue(
                contractArtifacts.SharedResolverImpl,
                uupsImmutableReferencesMap.__self.id,
                ethers.utils.hexZeroPad(addressMap.SharedResolverImpl, 32),
            ).deployedBytecode.object,
            variables: {
                _owner: contractOwner,
            },
        },
        SharedResolver: {
            address: addressMap.SharedResolver,
            deployedBytecode:
                contractArtifacts.SharedResolver.deployedBytecode.object,
            variables: {
                // EssentialContract
                __reentry: 1, // _FALSE
                __paused: 1, // _FALSE
                // EssentialContract => UUPSUpgradeable => Initializable
                _initialized: 1,
                _initializing: false,
                // EssentialContract => Ownable2StepUpgradeable
                _owner: contractOwner,
                // DefaultResolver
                __addresses: {
                    [chainId]: {
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridge"),
                        )]: addressMap.Bridge,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("erc20_vault"),
                        )]: addressMap.ERC20Vault,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("erc721_vault"),
                        )]: addressMap.ERC721Vault,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("erc1155_vault"),
                        )]: addressMap.ERC1155Vault,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("signal_service"),
                        )]: addressMap.SignalService,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridged_erc20"),
                        )]: addressMap.BridgedERC20Impl,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridged_erc721"),
                        )]: addressMap.BridgedERC721Impl,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridged_erc1155"),
                        )]: addressMap.BridgedERC1155Impl,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("taiko"),
                        )]: addressMap.TaikoAnchor,
                    },
                },
            },
            slots: {
                [IMPLEMENTATION_SLOT]: addressMap.SharedResolverImpl,
            },
            isProxy: true,
        },
        BridgeImpl: {
            address: addressMap.BridgeImpl,
            deployedBytecode: linkContractLibs(
                replaceImmutableValues(contractArtifacts.BridgeImpl, [
                    {
                        id: uupsImmutableReferencesMap.__self.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.BridgeImpl,
                            32,
                        ),
                    },
                    {
                        id: essentialContractReferencesMap.__resolver.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.SharedResolver,
                            32,
                        ),
                    },
                    {
                        id: bridgeReferencesMap.signalService.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.SignalService,
                            32,
                        ),
                    },
                ]),
                addressMap,
            ),
            variables: {
                _owner: contractOwner,
            },
        },
        Bridge: {
            address: addressMap.Bridge,
            deployedBytecode: contractArtifacts.Bridge.deployedBytecode.object,
            variables: {
                // EssentialContract
                __reentry: 1, // _FALSE
                __paused: 1, // _FALSE
                // EssentialContract => UUPSUpgradeable => Initializable
                _initialized: 1,
                _initializing: false,
                // EssentialContract => Ownable2StepUpgradeable
                _owner: contractOwner,
            },
            slots: {
                [IMPLEMENTATION_SLOT]: addressMap.BridgeImpl,
            },
            isProxy: true,
        },
        ERC20VaultImpl: {
            address: addressMap.ERC20VaultImpl,
            deployedBytecode: linkContractLibs(
                replaceImmutableValues(contractArtifacts.ERC20VaultImpl, [
                    {
                        id: uupsImmutableReferencesMap.__self.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.ERC20VaultImpl,
                            32,
                        ),
                    },
                    {
                        id: essentialContractReferencesMap.__resolver.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.SharedResolver,
                            32,
                        ),
                    },
                ]),
                addressMap,
            ),
            variables: {
                _owner: contractOwner,
            },
        },
        ERC20Vault: {
            address: addressMap.ERC20Vault,
            deployedBytecode:
                contractArtifacts.ERC20Vault.deployedBytecode.object,
            variables: {
                // EssentialContract
                __reentry: 1, // _FALSE
                __paused: 2, // _TRUE
                // EssentialContract => UUPSUpgradeable => Initializable
                _initialized: 1,
                _initializing: false,
                // EssentialContract => Ownable2StepUpgradeable
                _owner: contractOwner,
            },
            slots: {
                [IMPLEMENTATION_SLOT]: addressMap.ERC20VaultImpl,
            },
            isProxy: true,
        },
        ERC721VaultImpl: {
            address: addressMap.ERC721VaultImpl,
            deployedBytecode: linkContractLibs(
                replaceImmutableValues(contractArtifacts.ERC721VaultImpl, [
                    {
                        id: uupsImmutableReferencesMap.__self.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.ERC721VaultImpl,
                            32,
                        ),
                    },
                    {
                        id: essentialContractReferencesMap.__resolver.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.SharedResolver,
                            32,
                        ),
                    },
                ]),
                addressMap,
            ),
            variables: {
                _owner: contractOwner,
            },
        },
        ERC721Vault: {
            address: addressMap.ERC721Vault,
            deployedBytecode:
                contractArtifacts.ERC721Vault.deployedBytecode.object,
            variables: {
                // EssentialContract
                __reentry: 1, // _FALSE
                __paused: 1, // _FALSE
                // EssentialContract => UUPSUpgradeable => Initializable
                _initialized: 1,
                _initializing: false,
                // EssentialContract => Ownable2StepUpgradeable
                _owner: contractOwner,
            },
            slots: {
                [IMPLEMENTATION_SLOT]: addressMap.ERC721VaultImpl,
            },
            isProxy: true,
        },
        ERC1155VaultImpl: {
            address: addressMap.ERC1155VaultImpl,
            deployedBytecode: linkContractLibs(
                replaceImmutableValues(contractArtifacts.ERC1155VaultImpl, [
                    {
                        id: uupsImmutableReferencesMap.__self.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.ERC1155VaultImpl,
                            32,
                        ),
                    },
                    {
                        id: essentialContractReferencesMap.__resolver.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.SharedResolver,
                            32,
                        ),
                    },
                ]),
                addressMap,
            ),
            variables: {
                _owner: contractOwner,
            },
        },
        ERC1155Vault: {
            address: addressMap.ERC1155Vault,
            deployedBytecode:
                contractArtifacts.ERC1155Vault.deployedBytecode.object,
            variables: {
                // EssentialContract
                __reentry: 1, // _FALSE
                __paused: 1, // _FALSE
                // EssentialContract => UUPSUpgradeable => Initializable
                _initialized: 1,
                _initializing: false,
                // EssentialContract => Ownable2StepUpgradeable
                _owner: contractOwner,
            },
            slots: {
                [IMPLEMENTATION_SLOT]: addressMap.ERC1155VaultImpl,
            },
            isProxy: true,
        },
        BridgedERC20: {
            address: addressMap.BridgedERC20Impl,
            deployedBytecode: linkContractLibs(
                replaceImmutableValues(contractArtifacts.BridgedERC20Impl, [
                    {
                        id: uupsImmutableReferencesMap.__self.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.BridgedERC20Impl,
                            32,
                        ),
                    },
                    {
                        id: bridgedERC20ReferencesMap.erc20Vault.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.ERC20Vault,
                            32,
                        ),
                    },
                ]),
                addressMap,
            ),
        },
        BridgedERC721: {
            address: addressMap.BridgedERC721Impl,
            deployedBytecode: linkContractLibs(
                replaceImmutableValues(contractArtifacts.BridgedERC721Impl, [
                    {
                        id: uupsImmutableReferencesMap.__self.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.BridgedERC721Impl,
                            32,
                        ),
                    },
                    {
                        id: bridgedERC721ReferencesMap.erc721Vault.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.ERC721Vault,
                            32,
                        ),
                    },
                ]),
                addressMap,
            ),
        },
        BridgedERC1155: {
            address: addressMap.BridgedERC1155Impl,
            deployedBytecode: linkContractLibs(
                replaceImmutableValues(contractArtifacts.BridgedERC1155Impl, [
                    {
                        id: uupsImmutableReferencesMap.__self.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.BridgedERC1155Impl,
                            32,
                        ),
                    },
                    {
                        id: bridgedERC1155ReferencesMap.erc1155Vault.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.ERC1155Vault,
                            32,
                        ),
                    },
                ]),
                addressMap,
            ),
        },
        SignalServiceImpl: {
            address: addressMap.SignalServiceImpl,
            deployedBytecode: linkContractLibs(
                replaceImmutableValues(contractArtifacts.SignalServiceImpl, [
                    {
                        id: uupsImmutableReferencesMap.__self.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.SignalServiceImpl,
                            32,
                        ),
                    },
                    {
                        id: essentialContractReferencesMap.__resolver.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.SharedResolver,
                            32,
                        ),
                    },
                    {
                        id: signalServiceReferencesMap._authorizedSyncer.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.TaikoAnchor,
                            32,
                        ),
                    },
                    {
                        id: signalServiceReferencesMap._remoteSignalService.id,
                        value: ethers.utils.hexZeroPad(remoteSignalService, 32),
                    },
                ]),
                addressMap,
            ),
            variables: {
                _owner: contractOwner,
            },
        },
        SignalService: {
            address: addressMap.SignalService,
            deployedBytecode:
                contractArtifacts.SignalService.deployedBytecode.object,
            variables: {
                // EssentialContract
                __reentry: 1, // _FALSE
                __paused: 1, // _FALSE
                // EssentialContract => UUPSUpgradeable => Initializable
                _initialized: 1,
                _initializing: false,
                // EssentialContract => Ownable2StepUpgradeable
                _owner: contractOwner,
            },
            slots: {
                [IMPLEMENTATION_SLOT]: addressMap.SignalServiceImpl,
            },
            isProxy: true,
        },
        AnchorForkRouterImpl: {
            address: addressMap.AnchorForkRouterImpl,
            deployedBytecode: replaceImmutableValues(
                contractArtifacts.AnchorForkRouterImpl,
                [
                    {
                        id: uupsImmutableReferencesMap.__self.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.AnchorForkRouterImpl,
                            32,
                        ),
                    },
                    {
                        id: anchorForkRouterReferencesMap.oldFork.id,
                        value: ethers.utils.hexZeroPad(pacayaTaikoAnchor, 32),
                    },
                    {
                        id: anchorForkRouterReferencesMap.newFork.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.TaikoAnchorImpl,
                            32,
                        ),
                    },
                ],
            ).deployedBytecode.object,
            variables: {
                _owner: contractOwner,
            },
        },
        TaikoAnchorImpl: {
            address: addressMap.TaikoAnchorImpl,
            deployedBytecode: linkContractLibs(
                replaceImmutableValues(contractArtifacts.TaikoAnchorImpl, [
                    {
                        id: taikoAnchorReferencesMap.checkpointStore.id,
                        value: ethers.utils.hexZeroPad(
                            addressMap.SignalService,
                            32,
                        ),
                    },
                    {
                        id: taikoAnchorReferencesMap.l1ChainId.id,
                        value: ethers.utils.hexZeroPad(
                            ethers.utils.hexlify(l1ChainId),
                            32,
                        ),
                    },
                ]),
                addressMap,
            ),
            variables: {
                _owner: contractOwner,
            },
        },
        TaikoAnchor: {
            address: addressMap.TaikoAnchor,
            deployedBytecode:
                contractArtifacts.TaikoAnchor.deployedBytecode.object,
            variables: {
                _owner: contractOwner,
                // TaikoAnchor - _blockState will be initialized by first anchor call
                _blockState: {
                    anchorBlockNumber: 0,
                    ancestorsHash: ethers.constants.HashZero,
                },
            },
            slots: {
                [IMPLEMENTATION_SLOT]: addressMap.AnchorForkRouterImpl,
            },
            isProxy: true,
        },
        RollupResolverImpl: {
            address: addressMap.RollupResolverImpl,
            deployedBytecode: replaceImmutableValue(
                contractArtifacts.RollupResolverImpl,
                uupsImmutableReferencesMap.__self.id,
                ethers.utils.hexZeroPad(addressMap.RollupResolverImpl, 32),
            ).deployedBytecode.object,
            variables: {
                _owner: contractOwner,
            },
        },
        RollupResolver: {
            address: addressMap.RollupResolver,
            deployedBytecode:
                contractArtifacts.RollupResolver.deployedBytecode.object,
            variables: {
                // EssentialContract
                __reentry: 1, // _FALSE
                __paused: 1, // _FALSE
                // EssentialContract => UUPSUpgradeable => Initializable
                _initialized: 1,
                _initializing: false,
                // EssentialContract => Ownable2StepUpgradeable
                _owner: contractOwner,
                // DefaultResolver
                __addresses: {
                    [chainId]: {
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("taiko"),
                        )]: addressMap.TaikoAnchor,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("bridge"),
                        )]: addressMap.Bridge,
                        [ethers.utils.hexlify(
                            ethers.utils.toUtf8Bytes("signal_service"),
                        )]: addressMap.SignalService,
                    },
                },
            },
            slots: {
                [IMPLEMENTATION_SLOT]: addressMap.RollupResolverImpl,
            },
            isProxy: true,
        },
        // Libraries
        LibNetwork: {
            address: addressMap.LibNetwork,
            deployedBytecode:
                contractArtifacts.LibNetwork.deployedBytecode.object,
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

function getImmutableReference(
    contractName: string,
    immutableValueNames: Array<string>,
    artifactsPath = ARTIFACTS_PATH,
) {
    const references: any = {};
    const artifactPath = path.join(
        artifactsPath,
        `./${contractName}.sol/${contractName}.json`,
    );

    console.log(`Loading artifact from: ${artifactPath}`);
    const artifact = require(artifactPath);

    if (!artifact.ast || !artifact.ast.nodes) {
        console.error(`No AST found in artifact for ${contractName}`);
        throw new Error(`No AST found in artifact for ${contractName}`);
    }

    for (const immutableValueName of immutableValueNames) {
        let found = false;
        for (const node of artifact.ast.nodes) {
            if (node.nodeType !== "ContractDefinition") continue;

            // Search in the current contract and its base contracts
            const searchInContract = (contractNode: any) => {
                for (const subNode of contractNode.nodes || []) {
                    if (subNode.name !== immutableValueName) continue;
                    references[immutableValueName] = {
                        name: immutableValueName,
                        id: subNode.id,
                    };
                    found = true;
                    console.log(
                        `Found immutable reference for ${immutableValueName} with id ${subNode.id} in contract ${contractNode.name}`,
                    );
                    return true;
                }
                return false;
            };

            // Check current contract
            if (searchInContract(node)) break;

            // Check base contracts
            if (node.baseContracts) {
                for (const baseContract of node.baseContracts) {
                    const baseContractName = baseContract.baseName.name;
                    console.log(`Checking base contract: ${baseContractName}`);
                    try {
                        const baseArtifact = require(
                            path.join(
                                ARTIFACTS_PATH,
                                `./${baseContractName}.sol/${baseContractName}.json`,
                            ),
                        );
                        for (const baseNode of baseArtifact.ast.nodes) {
                            if (
                                baseNode.nodeType !== "ContractDefinition" ||
                                baseNode.name !== baseContractName
                            )
                                continue;
                            if (searchInContract(baseNode)) break;
                        }
                    } catch (e) {
                        console.log(
                            `Could not load base contract ${baseContractName}: ${e}`,
                        );
                    }
                }
            }
        }
        if (!found) {
            console.error(
                `Could not find immutable reference for ${immutableValueName} in ${contractName} or its base contracts`,
            );
            throw new Error(
                `Could not find immutable reference for ${immutableValueName} in ${contractName} or its base contracts`,
            );
        }
    }

    return references;
}

function replaceImmutableValues(artifact: any, maps: Array<any>): any {
    for (let i = 0; i < maps.length; i++) {
        artifact = replaceImmutableValue(artifact, maps[i].id, maps[i].value);
    }

    return artifact;
}

function replaceImmutableValue(artifact: any, id: any, value: string): any {
    const offsets = artifact.deployedBytecode.immutableReferences[`${id}`];

    let deployedBytecodeWithoutPrefix =
        artifact.deployedBytecode.object.substring(2);
    if (value.startsWith("0x")) value = value.substring(2);

    for (const { start, length } of offsets) {
        const prefix = deployedBytecodeWithoutPrefix.substring(0, start * 2);
        const suffix = deployedBytecodeWithoutPrefix.substring(
            start * 2 + length * 2,
        );
        deployedBytecodeWithoutPrefix = `${prefix}${value}${suffix}`;
    }

    artifact.deployedBytecode.object = `0x${deployedBytecodeWithoutPrefix}`;
    return artifact;
}
