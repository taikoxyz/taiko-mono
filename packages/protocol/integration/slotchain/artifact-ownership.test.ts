/* eslint-disable node/no-unsupported-features/es-builtins, node/no-unsupported-features/es-syntax */
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import {
    ArtifactOwnedModule,
    ArtifactUsage,
    bytecodeHash,
    canonicalHash,
    loadOwnedArtifact,
    OwnershipError,
    OwnershipManifest,
    OwnershipProfile,
    sourceHash,
    SourceInlineModule,
    validateArtifactOwnership,
} from "../../utils/slotchain/checkArtifactOwnership";

interface Fixture {
    root: string;
    manifest: OwnershipManifest;
    artifactPath: string;
    sourcePath: string;
}

function writeJson(filePath: string, value: unknown): void {
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function clone<T>(value: T): T {
    return structuredClone(value);
}

function profile(
    out: string,
    required: boolean,
    overrides: Partial<OwnershipProfile> = {},
): OwnershipProfile {
    return {
        out,
        required,
        src: "contracts",
        test: "test",
        script: "script",
        cachePath: `cache/${path.posix.basename(out)}`,
        solcVersion: "0.8.30",
        metadataCompilerVersion: "0.8.30+commit.73712a01",
        evmVersion: "osaka",
        optimizer: true,
        optimizerRuns: 200,
        viaIr: false,
        ast: true,
        buildInfo: true,
        metadataBytecodeHash: "ipfs",
        metadataAppendCbor: true,
        metadataUseLiteralContent: false,
        skip: [],
        ...overrides,
    };
}

function buildInfo(
    buildProfile: OwnershipProfile,
    sources: Record<string, { content: string; ast: Record<string, any> }> = {},
    contracts: Record<string, Record<string, Record<string, any>>> = {},
): Record<string, any> {
    return {
        _format: "ethers-rs-sol-build-info-1",
        language: "Solidity",
        solcVersion: buildProfile.solcVersion,
        solcLongVersion: buildProfile.solcVersion,
        source_id_to_path: Object.fromEntries(
            Object.keys(sources).map((sourcePath, index) => [
                String(index),
                sourcePath,
            ]),
        ),
        input: {
            version: buildProfile.solcVersion,
            settings: {
                evmVersion: buildProfile.evmVersion,
                optimizer: {
                    enabled: buildProfile.optimizer,
                    runs: buildProfile.optimizerRuns,
                },
                viaIR: buildProfile.viaIr,
                metadata: {
                    bytecodeHash: buildProfile.metadataBytecodeHash,
                    appendCBOR: buildProfile.metadataAppendCbor,
                    useLiteralContent: buildProfile.metadataUseLiteralContent,
                },
            },
            sources: Object.fromEntries(
                Object.entries(sources).map(([sourcePath, source]) => [
                    sourcePath,
                    { content: source.content },
                ]),
            ),
        },
        output: {
            sources: Object.fromEntries(
                Object.entries(sources).map(([sourcePath, source]) => [
                    sourcePath,
                    { ast: source.ast },
                ]),
            ),
            contracts,
        },
    };
}

function compilerContract(artifact: Record<string, any>): Record<string, any> {
    return {
        abi: artifact.abi,
        metadata: JSON.stringify(artifact.metadata),
        evm: {
            bytecode: {
                object: artifact.bytecode.object.slice(2),
                linkReferences: artifact.bytecode.linkReferences,
            },
            deployedBytecode: {
                object: artifact.deployedBytecode.object.slice(2),
                linkReferences: artifact.deployedBytecode.linkReferences,
                immutableReferences:
                    artifact.deployedBytecode.immutableReferences,
            },
        },
    };
}

function validFixture(): Fixture {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "slotchain-owner-"));
    const sourcePath = "contracts/shared/slotchain/Owned.sol";
    const contents = "contract Owned {}\n";
    const artifactPath = "out/shared/Owned.sol/Owned.json";
    fs.mkdirSync(path.join(root, path.dirname(sourcePath)), {
        recursive: true,
    });
    fs.writeFileSync(path.join(root, sourcePath), contents);

    const artifact = {
        abi: [],
        bytecode: { object: "0x6000", linkReferences: {} },
        deployedBytecode: {
            object: "0x6001",
            linkReferences: {},
            immutableReferences: {},
        },
        metadata: {
            compiler: { version: "0.8.30+commit.73712a01" },
            settings: {
                compilationTarget: { [sourcePath]: "Owned" },
                evmVersion: "osaka",
                optimizer: { enabled: true, runs: 200 },
                viaIR: false,
            },
            sources: { [sourcePath]: { keccak256: sourceHash(contents) } },
        },
        ast: {
            nodeType: "SourceUnit",
            nodes: [
                {
                    nodeType: "ContractDefinition",
                    name: "Owned",
                    contractKind: "contract",
                    nodes: [],
                },
            ],
        },
    };
    const module: ArtifactOwnedModule = {
        ownership: "artifact-owned",
        sourcePath,
        contractName: "Owned",
        ownerProfile: "shared",
        artifactPath,
        sourceHash: sourceHash(contents),
        abiHash: canonicalHash(artifact.abi),
        creationCodeHash: bytecodeHash(artifact.bytecode.object),
        runtimeCodeHash: bytecodeHash(artifact.deployedBytecode.object),
        creationLinkReferencesHash: canonicalHash({}),
        runtimeLinkReferencesHash: canonicalHash({}),
        immutableReferencesHash: canonicalHash({}),
        consumptionModes: [],
        factoryClass: "direct-create-test",
        lifecycleScope: "test-only",
        requiredConsumerProfiles: [],
    };
    const manifest: OwnershipManifest = {
        schemaVersion: 1,
        slotChainPathSegment: "/slotchain/",
        profiles: {
            default: profile("out", false, { ast: false, buildInfo: false }),
            genesis: profile("out/genesis", false, {
                ast: false,
                buildInfo: false,
            }),
            layer1: profile("out/layer1", true),
            layer1o: profile("out/layer1o", false, {
                viaIr: true,
                ast: false,
                buildInfo: false,
            }),
            layer2: profile("out/layer2", true),
            shared: profile("out/shared", true),
        },
        modules: [module],
        usages: [],
    };
    writeJson(path.join(root, artifactPath), artifact);
    writeJson(
        path.join(root, "out/shared/build-info/shared.json"),
        buildInfo(
            manifest.profiles.shared,
            { [sourcePath]: { content: contents, ast: artifact.ast } },
            { [sourcePath]: { Owned: compilerContract(artifact) } },
        ),
    );
    writeJson(
        path.join(root, "out/layer1/build-info/layer1.json"),
        buildInfo(manifest.profiles.layer1),
    );
    writeJson(
        path.join(root, "out/layer2/build-info/layer2.json"),
        buildInfo(manifest.profiles.layer2),
    );
    return { root, manifest, artifactPath, sourcePath };
}

function addArtifactOwnedFixtureModule(
    fixture: Fixture,
    sourcePath: string,
    contractName: string,
): ArtifactOwnedModule {
    const contents = `contract ${contractName} {}\n`;
    const artifactPath = `out/shared/${path.posix.basename(sourcePath)}/${contractName}.json`;
    const artifact = readArtifact(fixture);
    artifact.metadata.settings.compilationTarget = {
        [sourcePath]: contractName,
    };
    artifact.metadata.sources = {
        [sourcePath]: { keccak256: sourceHash(contents) },
    };
    artifact.ast.nodes[0].name = contractName;

    fs.mkdirSync(path.join(fixture.root, path.dirname(sourcePath)), {
        recursive: true,
    });
    fs.writeFileSync(path.join(fixture.root, sourcePath), contents);
    writeJson(path.join(fixture.root, artifactPath), artifact);

    const module: ArtifactOwnedModule = {
        ownership: "artifact-owned",
        sourcePath,
        contractName,
        ownerProfile: "shared",
        artifactPath,
        sourceHash: sourceHash(contents),
        abiHash: canonicalHash(artifact.abi),
        creationCodeHash: bytecodeHash(artifact.bytecode.object),
        runtimeCodeHash: bytecodeHash(artifact.deployedBytecode.object),
        creationLinkReferencesHash: canonicalHash(
            artifact.bytecode.linkReferences,
        ),
        runtimeLinkReferencesHash: canonicalHash(
            artifact.deployedBytecode.linkReferences,
        ),
        immutableReferencesHash: canonicalHash(
            artifact.deployedBytecode.immutableReferences,
        ),
        consumptionModes: [],
        factoryClass: "direct-create-test",
        lifecycleScope: "test-only",
        requiredConsumerProfiles: [],
    };
    fixture.manifest.modules.push(module);
    mutateBuildInfo(fixture, "shared", (value) => {
        value.source_id_to_path[
            String(Object.keys(value.source_id_to_path).length)
        ] = sourcePath;
        value.input.sources[sourcePath] = { content: contents };
        value.output.sources[sourcePath] = { ast: artifact.ast };
        value.output.contracts[sourcePath] = {
            [contractName]: compilerContract(artifact),
        };
    });
    return module;
}

function readArtifact(fixture: Fixture): Record<string, any> {
    return JSON.parse(
        fs.readFileSync(path.join(fixture.root, fixture.artifactPath), "utf8"),
    );
}

function mutateArtifact(
    fixture: Fixture,
    callback: (artifact: Record<string, any>) => void,
): void {
    const artifact = readArtifact(fixture);
    callback(artifact);
    writeJson(path.join(fixture.root, fixture.artifactPath), artifact);
}

function mutateModuleArtifact(
    fixture: Fixture,
    module: ArtifactOwnedModule,
    callback: (artifact: Record<string, any>) => void,
): void {
    const artifactFile = path.join(fixture.root, module.artifactPath);
    const artifact = JSON.parse(fs.readFileSync(artifactFile, "utf8"));
    callback(artifact);
    writeJson(artifactFile, artifact);
    mutateBuildInfo(fixture, module.ownerProfile, (value) => {
        value.output.contracts[module.sourcePath][module.contractName] =
            compilerContract(artifact);
    });
}

function buildInfoPath(
    fixture: Fixture,
    buildProfile: "shared" | "layer1" | "layer2",
): string {
    return path.join(
        fixture.root,
        `out/${buildProfile}/build-info/${buildProfile}.json`,
    );
}

function readBuildInfo(
    fixture: Fixture,
    buildProfile: "shared" | "layer1" | "layer2",
): Record<string, any> {
    return JSON.parse(
        fs.readFileSync(buildInfoPath(fixture, buildProfile), "utf8"),
    );
}

function mutateBuildInfo(
    fixture: Fixture,
    buildProfile: "shared" | "layer1" | "layer2",
    callback: (value: Record<string, any>) => void,
): void {
    const value = readBuildInfo(fixture, buildProfile);
    callback(value);
    writeJson(buildInfoPath(fixture, buildProfile), value);
}

function syncSharedCompilerOutput(fixture: Fixture): void {
    const artifact = readArtifact(fixture);
    mutateBuildInfo(fixture, "shared", (value) => {
        value.output.sources[fixture.sourcePath].ast = artifact.ast;
        value.output.contracts[fixture.sourcePath].Owned =
            compilerContract(artifact);
    });
}

function addSourceToBuildInfo(
    fixture: Fixture,
    buildProfile: "layer1" | "layer2",
    withContract: boolean,
): void {
    const artifact = readArtifact(fixture);
    const contents = fs.readFileSync(
        path.join(fixture.root, fixture.sourcePath),
        "utf8",
    );
    mutateBuildInfo(fixture, buildProfile, (value) => {
        value.source_id_to_path = { "0": fixture.sourcePath };
        value.input.sources = { [fixture.sourcePath]: { content: contents } };
        value.output.sources = { [fixture.sourcePath]: { ast: artifact.ast } };
        value.output.contracts = withContract
            ? { [fixture.sourcePath]: { Owned: compilerContract(artifact) } }
            : {};
    });
}

function expectCode(code: string, callback: () => void): void {
    assert.throws(callback, (error: unknown) => {
        return error instanceof OwnershipError && error.code === code;
    });
}

function expectCodeAndMessage(
    code: string,
    message: string,
    callback: () => void,
): void {
    assert.throws(callback, (error: unknown) => {
        return (
            error instanceof OwnershipError &&
            error.code === code &&
            error.message === `${code}: ${message}`
        );
    });
}

function makeSourceInlineLibrary(
    fixture: Fixture,
    abi: Record<string, any>[],
    nodes: Record<string, any>[],
): void {
    const owned = fixture.manifest.modules[0] as ArtifactOwnedModule;
    fixture.manifest.modules[0] = {
        ownership: "source-inline",
        sourcePath: owned.sourcePath,
        contractName: owned.contractName,
        kind: "internal-library",
        sourceHash: owned.sourceHash,
        abiHash: canonicalHash(abi),
        allowedProfiles: ["shared"],
        requiredProfiles: ["shared"],
    };
    mutateArtifact(fixture, (artifact) => {
        artifact.abi = abi;
        artifact.ast.nodes[0].contractKind = "library";
        artifact.ast.nodes[0].nodes = nodes;
    });
    syncSharedCompilerOutput(fixture);
}

function run(name: string, callback: () => void): void {
    callback();
    console.log(`PASS ${name}`);
}

function addConsumer(fixture: Fixture): ArtifactOwnedModule {
    const owner = fixture.manifest.modules[0] as ArtifactOwnedModule;
    const sourcePath = "test/layer1/slotchain/Consumer.t.sol";
    const contractName = "ConsumerTest";
    const artifactPath = `out/layer1/Consumer.t.sol/${contractName}.json`;
    const contents = [
        "contract ConsumerTest {",
        "    function consume() external {",
        `        vm.getCode("${owner.artifactPath}");`,
        "        assembly { let deployed := create(0, 0, 0) }",
        "    }",
        "}",
        "",
    ].join("\n");
    const artifact = clone(readArtifact(fixture));
    artifact.metadata.settings.compilationTarget = {
        [sourcePath]: contractName,
    };
    artifact.metadata.sources = {
        [sourcePath]: { keccak256: sourceHash(contents) },
    };
    artifact.ast.nodes[0].name = contractName;
    artifact.ast.nodes[0].nodes = [
        {
            nodeType: "FunctionDefinition",
            body: {
                nodeType: "Block",
                statements: [
                    {
                        nodeType: "FunctionCall",
                        expression: {
                            nodeType: "MemberAccess",
                            memberName: "getCode",
                            expression: { nodeType: "Identifier", name: "vm" },
                        },
                        arguments: [
                            {
                                nodeType: "Literal",
                                kind: "string",
                                value: owner.artifactPath,
                            },
                        ],
                    },
                    {
                        nodeType: "InlineAssembly",
                        AST: {
                            nodeType: "YulBlock",
                            statements: [
                                {
                                    nodeType: "YulFunctionCall",
                                    functionName: {
                                        nodeType: "YulIdentifier",
                                        name: "create",
                                    },
                                },
                            ],
                        },
                    },
                ],
            },
        },
    ];
    const consumer: ArtifactOwnedModule = {
        ownership: "artifact-owned",
        sourcePath,
        contractName,
        ownerProfile: "layer1",
        artifactPath,
        sourceHash: sourceHash(contents),
        abiHash: canonicalHash(artifact.abi),
        creationCodeHash: bytecodeHash(artifact.bytecode.object),
        runtimeCodeHash: bytecodeHash(artifact.deployedBytecode.object),
        creationLinkReferencesHash: canonicalHash(
            artifact.bytecode.linkReferences,
        ),
        runtimeLinkReferencesHash: canonicalHash(
            artifact.deployedBytecode.linkReferences,
        ),
        immutableReferencesHash: canonicalHash(
            artifact.deployedBytecode.immutableReferences,
        ),
        consumptionModes: [],
        factoryClass: "direct-create-test",
        lifecycleScope: "test-only",
        requiredConsumerProfiles: [],
    };
    fs.mkdirSync(path.join(fixture.root, path.dirname(sourcePath)), {
        recursive: true,
    });
    fs.writeFileSync(path.join(fixture.root, sourcePath), contents);
    writeJson(path.join(fixture.root, artifactPath), artifact);
    mutateBuildInfo(fixture, "layer1", (value) => {
        value.source_id_to_path = { "0": sourcePath };
        value.input.sources = { [sourcePath]: { content: contents } };
        value.output.sources = { [sourcePath]: { ast: artifact.ast } };
        value.output.contracts = {
            [sourcePath]: { [contractName]: compilerContract(artifact) },
        };
    });
    fixture.manifest.modules.push(consumer);
    return consumer;
}

function syncModuleSource(fixture: Fixture, module: ArtifactOwnedModule): void {
    const contents = fs.readFileSync(
        path.join(fixture.root, module.sourcePath),
        "utf8",
    );
    const artifact = JSON.parse(
        fs.readFileSync(path.join(fixture.root, module.artifactPath), "utf8"),
    ) as Record<string, any>;
    module.sourceHash = sourceHash(contents);
    artifact.metadata.sources[module.sourcePath].keccak256 = module.sourceHash;
    writeJson(path.join(fixture.root, module.artifactPath), artifact);
    mutateBuildInfo(fixture, module.ownerProfile, (value) => {
        value.input.sources[module.sourcePath].content = contents;
        value.output.sources[module.sourcePath].ast = artifact.ast;
        value.output.contracts[module.sourcePath][module.contractName] =
            compilerContract(artifact);
    });
}

function addUsage(fixture: Fixture): void {
    const module = fixture.manifest.modules[0] as ArtifactOwnedModule;
    const consumer = addConsumer(fixture);
    module.consumptionModes = ["raw-creation-bytecode"];
    module.requiredConsumerProfiles = ["layer1"];
    const usage: ArtifactUsage = {
        module: `${module.sourcePath}:${module.contractName}`,
        consumerModule: `${consumer.sourcePath}:${consumer.contractName}`,
        consumerProfile: "layer1",
        modes: ["raw-creation-bytecode"],
        factoryClass: "direct-create-test",
        lifecycleScope: "test-only",
    };
    fixture.manifest.usages.push(usage);
}

run("ownership checker rebuilds after all executable tests", () => {
    const packageJson = JSON.parse(
        fs.readFileSync(path.resolve(__dirname, "../../package.json"), "utf8"),
    ) as { scripts: Record<string, string> };
    assert.match(
        packageJson.scripts["slotchain:artifact-owner:check"],
        /^pnpm compile:shared && pnpm compile:l1 && pnpm compile:l2 && /,
    );
    assert.equal(
        packageJson.scripts["slotchain:ownership:ci"].endsWith(
            "pnpm slotchain:artifact-owner:check",
        ),
        true,
    );
});

run("valid manifest is deterministic", () => {
    const fixture = validFixture();
    const first = validateArtifactOwnership(fixture.root, fixture.manifest);
    const second = validateArtifactOwnership(
        fixture.root,
        clone(fixture.manifest),
    );
    assert.equal(first.digest, second.digest);
    assert.equal(first.modules.length, 1);
});

run("build-info format drift fails", () => {
    const fixture = validFixture();
    mutateBuildInfo(fixture, "shared", (value) => {
        value._format = "unknown-build-info";
    });
    expectCode("BUILD_INFO_FORMAT_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("build-info settings drift fails", () => {
    const fixture = validFixture();
    mutateBuildInfo(fixture, "shared", (value) => {
        value.input.settings.optimizer.runs = 201;
    });
    expectCode("BUILD_INFO_SETTINGS_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("build-info source content drift fails", () => {
    const fixture = validFixture();
    mutateBuildInfo(fixture, "shared", (value) => {
        value.input.sources[fixture.sourcePath].content += "// drift\n";
    });
    expectCode("BUILD_INPUT_SOURCE_HASH_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("artifact and compiler output mismatch fails", () => {
    const fixture = validFixture();
    mutateArtifact(fixture, (artifact) => {
        artifact.bytecode.object = "0x6002";
    });
    expectCode("ARTIFACT_BUILD_INFO_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("artifact and compiler ABI mismatch fails", () => {
    const fixture = validFixture();
    mutateArtifact(fixture, (artifact) => {
        artifact.abi = [
            {
                type: "function",
                name: "unexpected",
                inputs: [],
                outputs: [],
            },
        ];
    });
    expectCode("ARTIFACT_BUILD_INFO_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("fallback and receive empty-input metadata is normalized", () => {
    const fixture = validFixture();
    mutateArtifact(fixture, (artifact) => {
        artifact.metadata.output = {
            abi: [
                {
                    type: "fallback",
                    stateMutability: "nonpayable",
                    inputs: [],
                },
                {
                    type: "receive",
                    stateMutability: "payable",
                    inputs: [],
                },
            ],
        };
    });
    syncSharedCompilerOutput(fixture);
    mutateBuildInfo(fixture, "shared", (value) => {
        const contract = value.output.contracts[fixture.sourcePath].Owned;
        const metadata = JSON.parse(contract.metadata);
        for (const entry of metadata.output.abi) delete entry.inputs;
        contract.metadata = JSON.stringify(metadata);
    });
    validateArtifactOwnership(fixture.root, fixture.manifest);
});

run("metadata normalization preserves nonempty input drift", () => {
    const fixture = validFixture();
    mutateArtifact(fixture, (artifact) => {
        artifact.metadata.output = {
            abi: [
                {
                    type: "function",
                    name: "owned",
                    stateMutability: "view",
                    inputs: [{ name: "value", type: "uint256" }],
                    outputs: [],
                },
            ],
        };
    });
    syncSharedCompilerOutput(fixture);
    mutateBuildInfo(fixture, "shared", (value) => {
        const contract = value.output.contracts[fixture.sourcePath].Owned;
        const metadata = JSON.parse(contract.metadata);
        metadata.output.abi[0].inputs[0].type = "address";
        contract.metadata = JSON.stringify(metadata);
    });
    expectCode("ARTIFACT_BUILD_INFO_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("foundry-stripped contract devdoc metadata is normalized", () => {
    const fixture = validFixture();
    mutateArtifact(fixture, (artifact) => {
        artifact.metadata.output = {
            devdoc: { kind: "dev", methods: {}, version: 1 },
        };
    });
    syncSharedCompilerOutput(fixture);
    mutateBuildInfo(fixture, "shared", (value) => {
        const contract = value.output.contracts[fixture.sourcePath].Owned;
        const metadata = JSON.parse(contract.metadata);
        metadata.output.devdoc.title = "Owned contract";
        metadata.output.devdoc.details = "Contract-level details";
        metadata.output.devdoc["custom:security-contact"] =
            "security@example.invalid";
        contract.metadata = JSON.stringify(metadata);
    });
    validateArtifactOwnership(fixture.root, fixture.manifest);
});

run("foundry-stripped contract userdoc metadata is normalized", () => {
    const fixture = validFixture();
    mutateArtifact(fixture, (artifact) => {
        artifact.metadata.output = {
            userdoc: { kind: "user", methods: {}, version: 1 },
        };
    });
    syncSharedCompilerOutput(fixture);
    mutateBuildInfo(fixture, "shared", (value) => {
        const contract = value.output.contracts[fixture.sourcePath].Owned;
        const metadata = JSON.parse(contract.metadata);
        metadata.output.userdoc.notice = "Owned contract";
        contract.metadata = JSON.stringify(metadata);
    });
    validateArtifactOwnership(fixture.root, fixture.manifest);
});

run("userdoc method metadata drift fails", () => {
    const fixture = validFixture();
    mutateArtifact(fixture, (artifact) => {
        artifact.metadata.output = {
            userdoc: {
                kind: "user",
                methods: { "owned()": { notice: "expected" } },
                version: 1,
            },
        };
    });
    syncSharedCompilerOutput(fixture);
    mutateBuildInfo(fixture, "shared", (value) => {
        const contract = value.output.contracts[fixture.sourcePath].Owned;
        const metadata = JSON.parse(contract.metadata);
        metadata.output.userdoc.methods["owned()"].notice = "semantic drift";
        contract.metadata = JSON.stringify(metadata);
    });
    expectCode("ARTIFACT_BUILD_INFO_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("non-normalized devdoc metadata drift fails", () => {
    const fixture = validFixture();
    mutateArtifact(fixture, (artifact) => {
        artifact.metadata.output = {
            devdoc: {
                kind: "dev",
                methods: { "owned()": { details: "expected" } },
                version: 1,
            },
        };
    });
    syncSharedCompilerOutput(fixture);
    mutateBuildInfo(fixture, "shared", (value) => {
        const contract = value.output.contracts[fixture.sourcePath].Owned;
        const metadata = JSON.parse(contract.metadata);
        metadata.output.devdoc.methods["owned()"].details = "semantic drift";
        contract.metadata = JSON.stringify(metadata);
    });
    expectCode("ARTIFACT_BUILD_INFO_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("non-document compiler metadata drift fails", () => {
    const fixture = validFixture();
    mutateBuildInfo(fixture, "shared", (value) => {
        const contract = value.output.contracts[fixture.sourcePath].Owned;
        const metadata = JSON.parse(contract.metadata);
        metadata.settings.compilationTarget[fixture.sourcePath] = "Other";
        contract.metadata = JSON.stringify(metadata);
    });
    expectCode("ARTIFACT_BUILD_INFO_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("duplicate compiler output fails", () => {
    const fixture = validFixture();
    writeJson(
        path.join(fixture.root, "out/shared/build-info/duplicate.json"),
        readBuildInfo(fixture, "shared"),
    );
    expectCode("DUPLICATE_COMPILER_OUTPUT", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("free definitions require observed AST without contracts", () => {
    const fixture = validFixture();
    const freePath = "contracts/shared/slotchain/Types.sol";
    const freeContents = "struct SlotChainType { uint256 value; }\n";
    const freeAst = {
        nodeType: "SourceUnit",
        nodes: [{ nodeType: "StructDefinition", name: "SlotChainType" }],
    };
    fs.writeFileSync(path.join(fixture.root, freePath), freeContents);
    fixture.manifest.modules.push({
        ownership: "source-inline",
        sourcePath: freePath,
        kind: "free-definitions",
        sourceHash: sourceHash(freeContents),
        abiHash: canonicalHash([]),
        allowedProfiles: ["shared"],
        requiredProfiles: ["shared"],
    });
    mutateBuildInfo(fixture, "shared", (value) => {
        value.source_id_to_path["1"] = freePath;
        value.input.sources[freePath] = { content: freeContents };
        value.output.sources[freePath] = { ast: freeAst };
    });
    const inventory = validateArtifactOwnership(fixture.root, fixture.manifest);
    assert.equal(inventory.modules.length, 2);
});

run("free definitions reject contract AST", () => {
    const fixture = validFixture();
    const freePath = "contracts/shared/slotchain/Types.sol";
    const freeContents = "contract Hidden {}\n";
    fs.writeFileSync(path.join(fixture.root, freePath), freeContents);
    fixture.manifest.modules.push({
        ownership: "source-inline",
        sourcePath: freePath,
        kind: "free-definitions",
        sourceHash: sourceHash(freeContents),
        abiHash: canonicalHash([]),
        allowedProfiles: ["shared"],
        requiredProfiles: ["shared"],
    });
    mutateBuildInfo(fixture, "shared", (value) => {
        value.source_id_to_path["1"] = freePath;
        value.input.sources[freePath] = { content: freeContents };
        value.output.sources[freePath] = {
            ast: {
                nodeType: "SourceUnit",
                nodes: [
                    {
                        nodeType: "ContractDefinition",
                        name: "Hidden",
                        contractKind: "contract",
                    },
                ],
            },
        };
    });
    expectCode("SOURCE_INLINE_KIND_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("free definitions reject malformed source-unit AST", () => {
    const malformedAsts: unknown[] = [
        {},
        { nodeType: "SourceUnit" },
        { nodeType: "SourceUnit", nodes: null },
        { nodeType: "SourceUnit", nodes: {} },
        { nodeType: "ContractDefinition", nodes: [] },
        { nodeType: "SourceUnit", nodes: [{}] },
    ];

    for (const ast of malformedAsts) {
        const fixture = validFixture();
        const freePath = "contracts/shared/slotchain/Types.sol";
        const freeContents = "contract Hidden {}\n";
        fs.writeFileSync(path.join(fixture.root, freePath), freeContents);
        fixture.manifest.modules.push({
            ownership: "source-inline",
            sourcePath: freePath,
            kind: "free-definitions",
            sourceHash: sourceHash(freeContents),
            abiHash: canonicalHash([]),
            allowedProfiles: ["shared"],
            requiredProfiles: ["shared"],
        });
        mutateBuildInfo(fixture, "shared", (value) => {
            value.source_id_to_path["1"] = freePath;
            value.input.sources[freePath] = { content: freeContents };
            value.output.sources[freePath] = { ast };
        });
        expectCode("MALFORMED_SOURCE_AST", () =>
            validateArtifactOwnership(fixture.root, fixture.manifest),
        );
    }
});

run("free definitions reject non-empty ABI commitments", () => {
    const fixture = validFixture();
    const freePath = "contracts/shared/slotchain/Types.sol";
    const freeContents = "struct SlotChainType { uint256 value; }\n";
    fs.writeFileSync(path.join(fixture.root, freePath), freeContents);
    fixture.manifest.modules.push({
        ownership: "source-inline",
        sourcePath: freePath,
        kind: "free-definitions",
        sourceHash: sourceHash(freeContents),
        abiHash: canonicalHash([{ type: "function", name: "phantom" }]),
        allowedProfiles: ["shared"],
        requiredProfiles: ["shared"],
    });
    expectCode("ABI_HASH_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("source-inline requires at least one profile", () => {
    const fixture = validFixture();
    const owned = fixture.manifest.modules[0] as ArtifactOwnedModule;
    fixture.manifest.modules[0] = {
        ownership: "source-inline",
        sourcePath: owned.sourcePath,
        contractName: owned.contractName,
        kind: "internal-library",
        sourceHash: owned.sourceHash,
        abiHash: owned.abiHash,
        allowedProfiles: [],
        requiredProfiles: [],
    };
    expectCode("MALFORMED_SOURCE_INLINE_PROFILES", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("forbidden profile cannot own artifact", () => {
    const fixture = validFixture();
    (
        fixture.manifest.modules[0] as unknown as Record<string, unknown>
    ).ownerProfile = "default";
    expectCode("UNKNOWN_PROFILE", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("unclassified source fails closed", () => {
    const fixture = validFixture();
    fs.writeFileSync(
        path.join(fixture.root, "contracts/shared/slotchain/Unclassified.sol"),
        "contract Unclassified {}\n",
    );
    expectCode("UNCLASSIFIED_MODULE", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("unclassified artifact fails closed", () => {
    const fixture = validFixture();
    const artifact = readArtifact(fixture);
    artifact.metadata.settings.compilationTarget[fixture.sourcePath] = "Sneaky";
    artifact.ast.nodes[0].name = "Sneaky";
    writeJson(
        path.join(fixture.root, "out/shared/Owned.sol/Sneaky.json"),
        artifact,
    );
    expectCode("ARTIFACT_BUILD_INFO_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("missing required profile build fails", () => {
    const fixture = validFixture();
    fs.unlinkSync(path.join(fixture.root, "out/layer2/build-info/layer2.json"));
    expectCode("MISSING_PROFILE_BUILD", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("missing owner artifact fails", () => {
    const fixture = validFixture();
    fs.unlinkSync(path.join(fixture.root, fixture.artifactPath));
    expectCode("MISSING_ARTIFACT_JSON", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("duplicate owner artifact fails", () => {
    const fixture = validFixture();
    writeJson(
        path.join(fixture.root, "out/shared/Duplicate/Owned.json"),
        readArtifact(fixture),
    );
    expectCode("DUPLICATE_ARTIFACT", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("cross-profile artifact fails", () => {
    const fixture = validFixture();
    writeJson(
        path.join(fixture.root, "out/layer1/Owned.sol/Owned.json"),
        readArtifact(fixture),
    );
    addSourceToBuildInfo(fixture, "layer1", true);
    expectCode("ARTIFACT_OWNER_VIOLATION", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("transitive source recompilation fails", () => {
    const fixture = validFixture();
    addSourceToBuildInfo(fixture, "layer1", false);
    expectCode("SOURCE_OWNER_VIOLATION", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("compiler drift fails", () => {
    const fixture = validFixture();
    fixture.manifest.profiles.shared.metadataCompilerVersion =
        "0.8.31+commit.invalid";
    expectCode("COMPILER_VERSION_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("source drift fails", () => {
    const fixture = validFixture();
    fs.appendFileSync(
        path.join(fixture.root, fixture.sourcePath),
        "// drift\n",
    );
    expectCode("SOURCE_HASH_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("bytecode drift fails", () => {
    const fixture = validFixture();
    const module = fixture.manifest.modules[0] as ArtifactOwnedModule;
    const observed = bytecodeHash("0x6002");
    mutateArtifact(fixture, (artifact) => {
        artifact.bytecode.object = "0x6002";
    });
    syncSharedCompilerOutput(fixture);
    expectCodeAndMessage(
        "ARTIFACT_HASH_MISMATCH",
        `${fixture.sourcePath}:Owned:creationCodeHash:expected=${module.creationCodeHash}:observed=${observed}`,
        () => validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("hash drift aggregates all modules and fields deterministically", () => {
    const fixture = validFixture();
    const first = fixture.manifest.modules[0] as ArtifactOwnedModule;
    const second = addArtifactOwnedFixtureModule(
        fixture,
        "contracts/shared/slotchain/Second.sol",
        "Second",
    );
    const firstCreation = "0x6002";
    const firstRuntime = "0x6003";
    const secondCreation = "0x6004";
    const secondImmutables = { "1": [{ start: 0, length: 32 }] };

    mutateModuleArtifact(fixture, first, (artifact) => {
        artifact.bytecode.object = firstCreation;
        artifact.deployedBytecode.object = firstRuntime;
    });
    mutateModuleArtifact(fixture, second, (artifact) => {
        artifact.bytecode.object = secondCreation;
        artifact.deployedBytecode.immutableReferences = secondImmutables;
    });
    fixture.manifest.modules.reverse();

    expectCodeAndMessage(
        "ARTIFACT_HASH_MISMATCH",
        [
            `${first.sourcePath}:${first.contractName}:creationCodeHash:expected=${first.creationCodeHash}:observed=${bytecodeHash(firstCreation)}`,
            `${first.sourcePath}:${first.contractName}:runtimeCodeHash:expected=${first.runtimeCodeHash}:observed=${bytecodeHash(firstRuntime)}`,
            `${second.sourcePath}:${second.contractName}:creationCodeHash:expected=${second.creationCodeHash}:observed=${bytecodeHash(secondCreation)}`,
            `${second.sourcePath}:${second.contractName}:immutableReferencesHash:expected=${second.immutableReferencesHash}:observed=${canonicalHash(secondImmutables)}`,
        ].join("\n"),
        () => validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("malformed artifact JSON fails", () => {
    const fixture = validFixture();
    fs.writeFileSync(path.join(fixture.root, fixture.artifactPath), "{");
    expectCode("MALFORMED_JSON", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("missing compilation target fails", () => {
    const fixture = validFixture();
    mutateArtifact(fixture, (artifact) => {
        delete artifact.metadata.settings.compilationTarget;
    });
    expectCode("MISSING_COMPILATION_TARGET", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("path escape fails", () => {
    const fixture = validFixture();
    (fixture.manifest.modules[0] as ArtifactOwnedModule).artifactPath =
        "../Owned.json";
    expectCode("PATH_ESCAPE", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("managed source symlink fails", () => {
    const fixture = validFixture();
    const source = path.join(fixture.root, fixture.sourcePath);
    const target = path.join(fixture.root, "outside.sol");
    fs.writeFileSync(target, "contract Owned {}\n");
    fs.unlinkSync(source);
    fs.symlinkSync(target, source);
    expectCode("SYMLINK_NOT_ALLOWED", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("profile output root symlink fails", () => {
    const fixture = validFixture();
    const outputRoot = path.join(fixture.root, "out/layer2");
    const target = path.join(fixture.root, "external-layer2-output");
    fs.renameSync(outputRoot, target);
    fs.symlinkSync(target, outputRoot);
    expectCode("SYMLINK_NOT_ALLOWED", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("unknown manifest field fails", () => {
    const fixture = validFixture();
    (fixture.manifest as unknown as Record<string, unknown>).typo = true;
    expectCode("UNKNOWN_MANIFEST_FIELD", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("factory mismatch fails", () => {
    const fixture = validFixture();
    addUsage(fixture);
    fixture.manifest.usages[0].factoryClass = "erc-2470-singleton";
    expectCode("FACTORY_CLASS_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("lifecycle mismatch fails", () => {
    const fixture = validFixture();
    addUsage(fixture);
    fixture.manifest.usages[0].lifecycleScope = "release-scoped";
    expectCode("LIFECYCLE_SCOPE_MISMATCH", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("unknown consumer module fails", () => {
    const fixture = validFixture();
    addUsage(fixture);
    fixture.manifest.usages[0].consumerModule =
        "test/layer1/slotchain/Missing.t.sol:MissingTest";
    expectCode("UNKNOWN_CONSUMER_MODULE", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("consumer evidence must name the owned artifact path", () => {
    const fixture = validFixture();
    addUsage(fixture);
    const consumer = fixture.manifest.modules[1] as ArtifactOwnedModule;
    const source = path.join(fixture.root, consumer.sourcePath);
    fs.writeFileSync(
        source,
        fs
            .readFileSync(source, "utf8")
            .replace(fixture.artifactPath, "out/shared/Other.sol/Other.json"),
    );
    const artifactFile = path.join(fixture.root, consumer.artifactPath);
    const artifact = JSON.parse(
        fs.readFileSync(artifactFile, "utf8"),
    ) as Record<string, any>;
    artifact.ast.nodes[0].nodes[0].body.statements[0].arguments[0].value =
        "out/shared/Other.sol/Other.json";
    writeJson(artifactFile, artifact);
    syncModuleSource(fixture, consumer);
    expectCode("ARTIFACT_PATH_EVIDENCE_MISSING", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("missing required usage fails", () => {
    const fixture = validFixture();
    const module = fixture.manifest.modules[0] as ArtifactOwnedModule;
    module.consumptionModes = ["abi-interface"];
    module.requiredConsumerProfiles = ["layer1"];
    expectCode("MISSING_REQUIRED_USAGE", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("addressable source-inline interface fails", () => {
    const fixture = validFixture();
    const owned = fixture.manifest.modules[0] as ArtifactOwnedModule;
    const inline: SourceInlineModule = {
        ownership: "source-inline",
        sourcePath: owned.sourcePath,
        contractName: owned.contractName,
        kind: "interface",
        sourceHash: owned.sourceHash,
        abiHash: owned.abiHash,
        allowedProfiles: ["shared"],
        requiredProfiles: ["shared"],
    };
    fixture.manifest.modules[0] = inline;
    mutateArtifact(fixture, (artifact) => {
        artifact.ast.nodes[0].contractKind = "interface";
    });
    syncSharedCompilerOutput(fixture);
    expectCode("ADDRESSABLE_SOURCE_INLINE", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("source-inline internal library permits an error-only ABI", () => {
    const fixture = validFixture();
    makeSourceInlineLibrary(
        fixture,
        [
            {
                type: "error",
                name: "InvalidCandidate",
                inputs: [{ name: "candidate", type: "bytes32" }],
            },
        ],
        [
            { nodeType: "ErrorDefinition", name: "InvalidCandidate" },
            {
                nodeType: "VariableDeclaration",
                name: "DOMAIN",
                stateVariable: true,
                visibility: "private",
            },
            {
                nodeType: "FunctionDefinition",
                name: "hashCandidate",
                visibility: "internal",
            },
            {
                nodeType: "FunctionDefinition",
                name: "validateCandidate",
                visibility: "private",
            },
        ],
    );
    const inventory = validateArtifactOwnership(fixture.root, fixture.manifest);
    assert.equal(inventory.modules[0].ownership, "source-inline");
});

run("source-inline internal library rejects callable ABI entries", () => {
    for (const type of [
        "function",
        "constructor",
        "fallback",
        "receive",
        "event",
    ]) {
        const fixture = validFixture();
        makeSourceInlineLibrary(
            fixture,
            [{ type, name: "callable", inputs: [], outputs: [] }],
            [
                {
                    nodeType: "FunctionDefinition",
                    name: "helper",
                    visibility: "internal",
                },
            ],
        );
        expectCode("ADDRESSABLE_SOURCE_INLINE", () =>
            validateArtifactOwnership(fixture.root, fixture.manifest),
        );
    }
});

run("source-inline internal library rejects malformed ABI containers", () => {
    const fixture = validFixture();
    makeSourceInlineLibrary(fixture, [], []);
    mutateArtifact(fixture, (artifact) => {
        artifact.abi = { type: "error", name: "NotAnArray" };
    });
    syncSharedCompilerOutput(fixture);
    (fixture.manifest.modules[0] as SourceInlineModule).abiHash = canonicalHash(
        { type: "error", name: "NotAnArray" },
    );
    expectCode("ADDRESSABLE_SOURCE_INLINE", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run(
    "source-inline internal library rejects events even with error-only ABI",
    () => {
        const fixture = validFixture();
        makeSourceInlineLibrary(
            fixture,
            [{ type: "error", name: "Failure", inputs: [] }],
            [
                { nodeType: "ErrorDefinition", name: "Failure" },
                { nodeType: "EventDefinition", name: "Observed" },
            ],
        );
        expectCode("ADDRESSABLE_SOURCE_INLINE", () =>
            validateArtifactOwnership(fixture.root, fixture.manifest),
        );
    },
);

run("source-inline internal library rejects non-internal functions", () => {
    for (const visibility of ["public", "external", undefined]) {
        const fixture = validFixture();
        makeSourceInlineLibrary(
            fixture,
            [],
            [
                {
                    nodeType: "FunctionDefinition",
                    name: "callable",
                    visibility,
                },
            ],
        );
        expectCode("ADDRESSABLE_SOURCE_INLINE", () =>
            validateArtifactOwnership(fixture.root, fixture.manifest),
        );
    }
});

run("source-inline internal library rejects non-internal state", () => {
    for (const visibility of ["public", "external", undefined]) {
        const fixture = validFixture();
        makeSourceInlineLibrary(
            fixture,
            [],
            [
                {
                    nodeType: "VariableDeclaration",
                    name: "STATE",
                    stateVariable: true,
                    visibility,
                },
            ],
        );
        expectCode("ADDRESSABLE_SOURCE_INLINE", () =>
            validateArtifactOwnership(fixture.root, fixture.manifest),
        );
    }
});

run("source-inline internal library requires a complete member AST", () => {
    const fixture = validFixture();
    makeSourceInlineLibrary(fixture, [], []);
    mutateArtifact(fixture, (artifact) => {
        delete artifact.ast.nodes[0].nodes;
    });
    syncSharedCompilerOutput(fixture);
    expectCode("MALFORMED_SOURCE_AST", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("source-inline library link reference fails", () => {
    const fixture = validFixture();
    const owned = fixture.manifest.modules[0] as ArtifactOwnedModule;
    const inline: SourceInlineModule = {
        ownership: "source-inline",
        sourcePath: owned.sourcePath,
        contractName: owned.contractName,
        kind: "internal-library",
        sourceHash: owned.sourceHash,
        abiHash: owned.abiHash,
        allowedProfiles: ["shared"],
        requiredProfiles: ["shared"],
    };
    fixture.manifest.modules[0] = inline;
    mutateArtifact(fixture, (artifact) => {
        artifact.ast.nodes[0].contractKind = "library";
        artifact.bytecode.linkReferences = {
            [fixture.sourcePath]: { Owned: [{ start: 1, length: 20 }] },
        };
    });
    syncSharedCompilerOutput(fixture);
    expectCode("SOURCE_INLINE_LINK_REFERENCE", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("source-inline library cannot carry links to another library", () => {
    const fixture = validFixture();
    makeSourceInlineLibrary(
        fixture,
        [],
        [
            {
                nodeType: "FunctionDefinition",
                name: "hashCandidate",
                visibility: "internal",
            },
        ],
    );
    mutateArtifact(fixture, (artifact) => {
        artifact.deployedBytecode.linkReferences = {
            "contracts/External.sol": {
                External: [{ start: 1, length: 20 }],
            },
        };
    });
    syncSharedCompilerOutput(fixture);
    expectCode("SOURCE_INLINE_LINK_REFERENCE", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("non-managed compiler output cannot link source-inline library", () => {
    const fixture = validFixture();
    const owned = fixture.manifest.modules[0] as ArtifactOwnedModule;
    fixture.manifest.modules[0] = {
        ownership: "source-inline",
        sourcePath: owned.sourcePath,
        contractName: owned.contractName,
        kind: "internal-library",
        sourceHash: owned.sourceHash,
        abiHash: owned.abiHash,
        allowedProfiles: ["shared"],
        requiredProfiles: ["shared"],
    };
    mutateArtifact(fixture, (artifact) => {
        artifact.ast.nodes[0].contractKind = "library";
    });
    syncSharedCompilerOutput(fixture);
    const externalPath = "contracts/ExternalConsumer.sol";
    const externalContents = "contract ExternalConsumer {}\n";
    const externalAst = {
        nodeType: "SourceUnit",
        nodes: [
            {
                nodeType: "ContractDefinition",
                name: "ExternalConsumer",
                contractKind: "contract",
                nodes: [],
            },
        ],
    };
    mutateBuildInfo(fixture, "shared", (value) => {
        value.source_id_to_path["1"] = externalPath;
        value.input.sources[externalPath] = { content: externalContents };
        value.output.sources[externalPath] = { ast: externalAst };
        value.output.contracts[externalPath] = {
            ExternalConsumer: {
                abi: [],
                evm: {
                    bytecode: {
                        object: "6000",
                        linkReferences: {
                            [fixture.sourcePath]: {
                                Owned: [{ start: 1, length: 20 }],
                            },
                        },
                    },
                    deployedBytecode: {
                        object: "6001",
                        linkReferences: {},
                        immutableReferences: {},
                    },
                },
            },
        };
    });
    expectCode("SOURCE_INLINE_LINK_REFERENCE", () =>
        validateArtifactOwnership(fixture.root, fixture.manifest),
    );
});

run("owned artifact loader revalidates hashes", () => {
    const fixture = validFixture();
    mutateArtifact(fixture, (artifact) => {
        artifact.deployedBytecode.object = "0x6002";
    });
    syncSharedCompilerOutput(fixture);
    expectCode("ARTIFACT_HASH_MISMATCH", () =>
        loadOwnedArtifact(
            fixture.root,
            fixture.manifest,
            `${fixture.sourcePath}:Owned`,
        ),
    );
});

console.log("artifact ownership tests: PASS");
