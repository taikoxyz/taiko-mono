import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

import { ethers } from "ethers";

export type ProfileName =
    | "default"
    | "genesis"
    | "layer1"
    | "layer1o"
    | "layer2"
    | "shared";
export type OwnerProfileName = "shared" | "layer1" | "layer2";
export type SourceInlineKind =
    | "interface"
    | "internal-library"
    | "free-definitions";
export type ConsumptionMode = "abi-interface" | "raw-creation-bytecode";
export type FactoryClass =
    | "direct-create-test"
    | "erc-2470-singleton"
    | "protocol-root-source-factory"
    | "root-one-shot-create";
export type LifecycleScope =
    | "test-only"
    | "protocol-lifetime"
    | "release-scoped";

export interface OwnershipProfile {
    out: string;
    required: boolean;
    src: string;
    test: string;
    script: string;
    cachePath: string;
    solcVersion: string;
    metadataCompilerVersion: string;
    evmVersion: string;
    optimizer: boolean;
    optimizerRuns: number;
    viaIr: boolean;
    ast: boolean;
    buildInfo: boolean;
    metadataBytecodeHash: "ipfs" | "bzzr1" | "none";
    metadataAppendCbor: boolean;
    metadataUseLiteralContent: boolean;
    skip: string[];
}

export interface SourceInlineModule {
    ownership: "source-inline";
    sourcePath: string;
    contractName?: string;
    kind: SourceInlineKind;
    sourceHash: string;
    abiHash: string;
    allowedProfiles: OwnerProfileName[];
    requiredProfiles: OwnerProfileName[];
}

export interface ArtifactOwnedModule {
    ownership: "artifact-owned";
    sourcePath: string;
    contractName: string;
    ownerProfile: OwnerProfileName;
    artifactPath: string;
    sourceHash: string;
    abiHash: string;
    creationCodeHash: string;
    runtimeCodeHash: string;
    creationLinkReferencesHash: string;
    runtimeLinkReferencesHash: string;
    immutableReferencesHash: string;
    consumptionModes: ConsumptionMode[];
    factoryClass: FactoryClass;
    lifecycleScope: LifecycleScope;
    requiredConsumerProfiles: OwnerProfileName[];
}

export type OwnershipModule = SourceInlineModule | ArtifactOwnedModule;

export interface ArtifactUsage {
    module: string;
    consumerModule: string;
    consumerProfile: OwnerProfileName;
    modes: ConsumptionMode[];
    interfaceModule?: string;
    factoryClass: FactoryClass;
    lifecycleScope: LifecycleScope;
}

export interface OwnershipManifest {
    schemaVersion: 1;
    slotChainPathSegment: "/slotchain/";
    profiles: Record<ProfileName, OwnershipProfile>;
    modules: OwnershipModule[];
    usages: ArtifactUsage[];
}

export interface OwnershipInventory {
    digest: string;
    modules: Array<{
        fqn: string;
        ownership: OwnershipModule["ownership"];
        profiles: ProfileName[];
        fingerprint: string;
    }>;
}

interface AstNode {
    nodeType?: string;
    name?: string;
    contractKind?: string;
    visibility?: string;
    stateVariable?: boolean;
    nodes?: AstNode[];
}

interface SourceUnitAst extends AstNode {
    nodeType: "SourceUnit";
    nodes: AstNode[];
}

interface FoundryArtifact {
    abi?: unknown[];
    bytecode?: { object?: string; linkReferences?: unknown };
    deployedBytecode?: {
        object?: string;
        linkReferences?: unknown;
        immutableReferences?: unknown;
    };
    metadata?: {
        compiler?: { version?: string };
        settings?: {
            compilationTarget?: Record<string, string>;
            evmVersion?: string;
            optimizer?: { enabled?: boolean; runs?: number };
            viaIR?: boolean;
        };
        sources?: Record<string, { keccak256?: string }>;
    };
    ast?: AstNode;
}

interface CompilerContractOutput {
    abi?: unknown[];
    metadata?: string;
    evm?: {
        bytecode?: { object?: string; linkReferences?: unknown };
        deployedBytecode?: {
            object?: string;
            linkReferences?: unknown;
            immutableReferences?: unknown;
        };
    };
}

interface FoundryBuildInfo {
    _format?: string;
    language?: string;
    solcVersion?: string;
    solcLongVersion?: string;
    source_id_to_path?: Record<string, string>;
    input?: {
        version?: string;
        settings?: {
            evmVersion?: string;
            optimizer?: { enabled?: boolean; runs?: number };
            viaIR?: boolean;
            metadata?: {
                bytecodeHash?: string;
                appendCBOR?: boolean;
                useLiteralContent?: boolean;
            };
        };
        sources?: Record<string, { content?: string }>;
    };
    output?: {
        sources?: Record<string, { ast?: AstNode }>;
        contracts?: Record<string, Record<string, CompilerContractOutput>>;
    };
}

interface ArtifactRecord {
    profile: ProfileName;
    relativePath: string;
    sourcePath: string;
    contractName: string;
    artifact: FoundryArtifact;
}

interface CompilerOutputRecord {
    profile: ProfileName;
    sourcePath: string;
    contractName: string;
    sourceContent: string;
    sourceAst: AstNode;
    contract: CompilerContractOutput;
}

interface CompilerSourceRecord {
    content: string;
    ast: SourceUnitAst;
}

interface CompilerLinkConsumer {
    profile: ProfileName;
    sourcePath: string;
    contractName: string;
    creationLinkReferences: unknown;
    runtimeLinkReferences: unknown;
}

const PROFILE_NAMES: ProfileName[] = [
    "default",
    "genesis",
    "layer1",
    "layer1o",
    "layer2",
    "shared",
];
const OWNER_PROFILE_NAMES: OwnerProfileName[] = ["layer1", "layer2", "shared"];
const SOURCE_INLINE_KINDS = new Set<SourceInlineKind>([
    "interface",
    "internal-library",
    "free-definitions",
]);
const CONSUMPTION_MODES = new Set<ConsumptionMode>([
    "abi-interface",
    "raw-creation-bytecode",
]);
const FACTORY_CLASSES = new Set<FactoryClass>([
    "direct-create-test",
    "erc-2470-singleton",
    "protocol-root-source-factory",
    "root-one-shot-create",
]);
const LIFECYCLE_SCOPES = new Set<LifecycleScope>([
    "test-only",
    "protocol-lifetime",
    "release-scoped",
]);
const HASH_PATTERN = /^0x[0-9a-f]{64}$/;

export class OwnershipError extends Error {
    public constructor(
        public readonly code: string,
        message: string,
    ) {
        super(`${code}: ${message}`);
        this.name = "OwnershipError";
    }
}

function fail(code: string, message: string): never {
    throw new OwnershipError(code, message);
}

function normalizeRelative(value: string, field: string): string {
    if (!value || path.isAbsolute(value) || value.includes("\\")) {
        fail(
            "INVALID_PATH",
            `${field} must be a non-empty POSIX relative path: ${value}`,
        );
    }
    const normalized = path.posix.normalize(value);
    if (
        normalized === ".." ||
        normalized.startsWith("../") ||
        normalized !== value
    ) {
        fail("PATH_ESCAPE", `${field} escapes or is not canonical: ${value}`);
    }
    return normalized;
}

function assertHash(value: string, field: string): void {
    if (!HASH_PATTERN.test(value)) {
        fail("INVALID_HASH", `${field} must be a lowercase bytes32: ${value}`);
    }
}

function assertUnique<T>(values: T[], field: string): void {
    if (new Set(values).size !== values.length) {
        fail("DUPLICATE_VALUE", `${field} contains duplicate values`);
    }
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function requireSourceUnitAst(value: unknown, id: string): SourceUnitAst {
    if (
        value === undefined ||
        value === null ||
        value === false ||
        value === 0 ||
        value === ""
    ) {
        fail("MISSING_BUILD_OUTPUT_AST", id);
    }
    if (
        !isRecord(value) ||
        value.nodeType !== "SourceUnit" ||
        !Array.isArray(value.nodes) ||
        value.nodes.some(
            (node) => !isRecord(node) || typeof node.nodeType !== "string",
        )
    ) {
        fail("MALFORMED_SOURCE_AST", id);
    }
    return value as unknown as SourceUnitAst;
}

function assertKeys(
    value: Record<string, unknown>,
    allowed: string[],
    field: string,
): void {
    const unknown = Object.keys(value).filter((key) => !allowed.includes(key));
    if (unknown.length !== 0)
        fail("UNKNOWN_MANIFEST_FIELD", `${field}.${unknown.sort().join(",")}`);
}

function fqn(sourcePath: string, contractName: string): string {
    return `${sourcePath}:${contractName}`;
}

function moduleId(module: OwnershipModule): string {
    return `${module.sourcePath}:${module.contractName ?? "<free-definitions>"}`;
}

function compareUtf8(left: string, right: string): number {
    return Buffer.compare(
        Buffer.from(left, "utf8"),
        Buffer.from(right, "utf8"),
    );
}

function canonicalize(value: unknown): string {
    if (Array.isArray(value)) {
        return `[${value.map(canonicalize).join(",")}]`;
    }
    if (value !== null && typeof value === "object") {
        const record = value as Record<string, unknown>;
        return `{${Object.keys(record)
            .sort()
            .map((key) => `${JSON.stringify(key)}:${canonicalize(record[key])}`)
            .join(",")}}`;
    }
    return JSON.stringify(value);
}

function normalizeCompilerMetadata(value: unknown): unknown {
    if (!isRecord(value)) return value;
    const normalized = JSON.parse(JSON.stringify(value)) as Record<
        string,
        unknown
    >;
    const settings = normalized.settings;
    if (isRecord(settings) && Array.isArray(settings.remappings)) {
        settings.remappings = settings.remappings.map((entry) =>
            typeof entry === "string" && entry.startsWith(":")
                ? entry.slice(1)
                : entry,
        );
    }
    const output = normalized.output;
    if (isRecord(output) && Array.isArray(output.abi)) {
        for (const entry of output.abi) {
            if (
                isRecord(entry) &&
                Array.isArray(entry.outputs) &&
                entry.outputs.length === 0
            ) {
                delete entry.outputs;
            }
        }
    }
    return normalized;
}

export function canonicalHash(value: unknown): string {
    return ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(canonicalize(value)),
    );
}

export function bytecodeHash(value: string): string {
    if (!/^0x(?:[0-9a-fA-F]{2})*$/.test(value)) {
        fail(
            "MALFORMED_BYTECODE",
            "bytecode is not a complete hexadecimal byte string",
        );
    }
    return ethers.utils.keccak256(value);
}

export function sourceHash(contents: Buffer | string): string {
    return ethers.utils.keccak256(
        typeof contents === "string"
            ? ethers.utils.toUtf8Bytes(contents)
            : contents,
    );
}

function readJson(filePath: string): unknown {
    try {
        return JSON.parse(fs.readFileSync(filePath, "utf8"));
    } catch (error) {
        fail("MALFORMED_JSON", `${filePath}: ${(error as Error).message}`);
    }
}

function walk(root: string, predicate: (file: string) => boolean): string[] {
    if (!fs.existsSync(root)) return [];
    if (fs.lstatSync(root).isSymbolicLink()) fail("SYMLINK_NOT_ALLOWED", root);
    const result: string[] = [];
    const visit = (directory: string): void => {
        for (const entry of fs.readdirSync(directory, {
            withFileTypes: true,
        })) {
            const absolute = path.join(directory, entry.name);
            if (entry.isSymbolicLink()) fail("SYMLINK_NOT_ALLOWED", absolute);
            if (entry.isDirectory()) visit(absolute);
            else if (entry.isFile() && predicate(absolute))
                result.push(absolute);
        }
    };
    visit(root);
    return result.sort();
}

function isManagedSource(sourcePath: string, segment: string): boolean {
    return `/${sourcePath}`.includes(segment) && sourcePath.endsWith(".sol");
}

function compilationTarget(
    artifact: FoundryArtifact,
    artifactPath: string,
): { sourcePath: string; contractName: string } | undefined {
    const target = artifact.metadata?.settings?.compilationTarget;
    if (!target) return undefined;
    const entries = Object.entries(target);
    if (entries.length !== 1) {
        fail(
            "AMBIGUOUS_COMPILATION_TARGET",
            `${artifactPath} has ${entries.length} targets`,
        );
    }
    return { sourcePath: entries[0][0], contractName: entries[0][1] };
}

function loadArtifacts(
    root: string,
    manifest: OwnershipManifest,
): {
    artifacts: ArtifactRecord[];
    compilerOutputs: CompilerOutputRecord[];
    linkConsumers: CompilerLinkConsumer[];
    buildInputs: Map<ProfileName, Set<string>>;
    buildSources: Map<ProfileName, Map<string, CompilerSourceRecord>>;
} {
    const artifacts: ArtifactRecord[] = [];
    const compilerOutputs: CompilerOutputRecord[] = [];
    const linkConsumers: CompilerLinkConsumer[] = [];
    const buildInputs = new Map<ProfileName, Set<string>>();
    const buildSources = new Map<
        ProfileName,
        Map<string, CompilerSourceRecord>
    >();
    const compilerOutputIds = new Set<string>();
    const managedArtifactDirectories = new Set(
        manifest.modules.map((candidate) =>
            path.posix.basename(candidate.sourcePath),
        ),
    );

    for (const profileName of PROFILE_NAMES) {
        const profile = manifest.profiles[profileName];
        const outputRoot = path.join(root, profile.out);
        const nestedProfileRoots = PROFILE_NAMES.filter(
            (candidate) => candidate !== profileName,
        )
            .map((candidate) =>
                path.join(root, manifest.profiles[candidate].out),
            )
            .filter((candidateRoot) => {
                const relative = path.relative(outputRoot, candidateRoot);
                return (
                    relative !== "" &&
                    !relative.startsWith("..") &&
                    !path.isAbsolute(relative)
                );
            });
        const profileInputs = new Set<string>();
        buildInputs.set(profileName, profileInputs);
        const profileSources = new Map<string, CompilerSourceRecord>();
        buildSources.set(profileName, profileSources);

        const buildInfoPaths = walk(
            path.join(outputRoot, "build-info"),
            (file) => file.endsWith(".json"),
        );
        if (profile.required && buildInfoPaths.length === 0) {
            fail("MISSING_PROFILE_BUILD", `${profileName}:${profile.out}`);
        }
        for (const buildInfoPath of buildInfoPaths) {
            const buildInfo = readJson(buildInfoPath) as FoundryBuildInfo;
            if (!profile.required && buildInfo._format === undefined) {
                if (!isRecord(buildInfo.source_id_to_path)) {
                    fail("MALFORMED_BUILD_INFO", buildInfoPath);
                }
                for (const sourcePath of Object.values(
                    buildInfo.source_id_to_path,
                )) {
                    if (typeof sourcePath !== "string")
                        fail("MALFORMED_BUILD_INFO", buildInfoPath);
                    profileInputs.add(sourcePath);
                    if (
                        isManagedSource(
                            sourcePath,
                            manifest.slotChainPathSegment,
                        )
                    ) {
                        fail(
                            "FORBIDDEN_PROFILE_INPUT",
                            `${profileName}:${sourcePath}`,
                        );
                    }
                }
                continue;
            }
            if (buildInfo._format !== "ethers-rs-sol-build-info-1") {
                fail("BUILD_INFO_FORMAT_MISMATCH", buildInfoPath);
            }
            if (
                buildInfo.language !== "Solidity" ||
                buildInfo.solcVersion !== profile.solcVersion ||
                buildInfo.solcLongVersion !== profile.solcVersion ||
                buildInfo.input?.version !== profile.solcVersion
            ) {
                fail(
                    "BUILD_INFO_COMPILER_MISMATCH",
                    `${profileName}:${buildInfoPath}`,
                );
            }
            const settings = buildInfo.input?.settings;
            if (
                settings?.evmVersion !== profile.evmVersion ||
                settings.optimizer?.enabled !== profile.optimizer ||
                settings.optimizer?.runs !== profile.optimizerRuns ||
                (settings.viaIR ?? false) !== profile.viaIr ||
                settings.metadata?.bytecodeHash !==
                    profile.metadataBytecodeHash ||
                settings.metadata?.appendCBOR !== profile.metadataAppendCbor ||
                settings.metadata?.useLiteralContent !==
                    profile.metadataUseLiteralContent
            ) {
                fail(
                    "BUILD_INFO_SETTINGS_MISMATCH",
                    `${profileName}:${buildInfoPath}`,
                );
            }
            if (
                !buildInfo.source_id_to_path ||
                typeof buildInfo.source_id_to_path !== "object"
            ) {
                fail(
                    "MALFORMED_BUILD_INFO",
                    `${buildInfoPath} has no source_id_to_path map`,
                );
            }
            if (
                !buildInfo.input?.sources ||
                !buildInfo.output?.sources ||
                !buildInfo.output.contracts
            ) {
                fail(
                    "MALFORMED_BUILD_INFO",
                    `${buildInfoPath} lacks standard input/output`,
                );
            }
            const indexedSourcePaths = Object.values(
                buildInfo.source_id_to_path,
            ).sort(compareUtf8);
            const inputSourcePaths = Object.keys(buildInfo.input.sources).sort(
                compareUtf8,
            );
            if (
                canonicalize(indexedSourcePaths) !==
                canonicalize(inputSourcePaths)
            ) {
                fail("BUILD_INFO_SOURCE_INDEX_MISMATCH", buildInfoPath);
            }
            for (const [sourcePath, contracts] of Object.entries(
                buildInfo.output.contracts,
            )) {
                if (
                    !Object.prototype.hasOwnProperty.call(
                        buildInfo.input.sources,
                        sourcePath,
                    )
                ) {
                    fail(
                        "BUILD_INFO_OUTPUT_SOURCE_MISMATCH",
                        `${profileName}:${sourcePath}`,
                    );
                }
                for (const [contractName, contract] of Object.entries(
                    contracts,
                )) {
                    linkConsumers.push({
                        profile: profileName,
                        sourcePath,
                        contractName,
                        creationLinkReferences:
                            contract.evm?.bytecode?.linkReferences ?? {},
                        runtimeLinkReferences:
                            contract.evm?.deployedBytecode?.linkReferences ??
                            {},
                    });
                }
            }
            for (const sourcePath of indexedSourcePaths) {
                if (typeof sourcePath !== "string") {
                    fail(
                        "MALFORMED_BUILD_INFO",
                        `${buildInfoPath} contains a non-string source path`,
                    );
                }
                profileInputs.add(sourcePath);
                if (!isManagedSource(sourcePath, manifest.slotChainPathSegment))
                    continue;
                const content = buildInfo.input.sources[sourcePath]?.content;
                const sourceAst = requireSourceUnitAst(
                    buildInfo.output.sources[sourcePath]?.ast,
                    `${profileName}:${sourcePath}`,
                );
                if (typeof content !== "string") {
                    fail(
                        "MISSING_BUILD_INPUT_CONTENT",
                        `${profileName}:${sourcePath}`,
                    );
                }
                const contracts = buildInfo.output.contracts[sourcePath] ?? {};
                if (profileSources.has(sourcePath)) {
                    for (const contractName of Object.keys(contracts)) {
                        const outputId = `${profileName}:${fqn(sourcePath, contractName)}`;
                        if (compilerOutputIds.has(outputId)) {
                            fail("DUPLICATE_COMPILER_OUTPUT", outputId);
                        }
                    }
                    fail(
                        "DUPLICATE_BUILD_INPUT",
                        `${profileName}:${sourcePath}`,
                    );
                }
                profileSources.set(sourcePath, { content, ast: sourceAst });
                for (const [contractName, contract] of Object.entries(
                    contracts,
                )) {
                    const outputId = `${profileName}:${fqn(sourcePath, contractName)}`;
                    if (compilerOutputIds.has(outputId)) {
                        fail("DUPLICATE_COMPILER_OUTPUT", outputId);
                    }
                    compilerOutputIds.add(outputId);
                    compilerOutputs.push({
                        profile: profileName,
                        sourcePath,
                        contractName,
                        sourceContent: content,
                        sourceAst,
                        contract,
                    });
                }
            }
        }

        for (const artifactPath of walk(outputRoot, (file) =>
            file.endsWith(".json"),
        )) {
            if (artifactPath.includes(`${path.sep}build-info${path.sep}`))
                continue;
            if (
                nestedProfileRoots.some((nestedRoot) => {
                    const relative = path.relative(nestedRoot, artifactPath);
                    return (
                        relative === "" ||
                        (!relative.startsWith("..") &&
                            !path.isAbsolute(relative))
                    );
                })
            ) {
                continue;
            }
            const artifact = readJson(artifactPath) as FoundryArtifact;
            const target = compilationTarget(artifact, artifactPath);
            if (!target) {
                const relativeArtifactPath = path
                    .relative(outputRoot, artifactPath)
                    .split(path.sep)
                    .join("/");
                if (
                    managedArtifactDirectories.has(
                        relativeArtifactPath.split("/")[0],
                    )
                ) {
                    fail("MISSING_COMPILATION_TARGET", artifactPath);
                }
                continue;
            }
            if (
                !isManagedSource(
                    target.sourcePath,
                    manifest.slotChainPathSegment,
                )
            )
                continue;
            artifacts.push({
                profile: profileName,
                relativePath: path
                    .relative(root, artifactPath)
                    .split(path.sep)
                    .join("/"),
                sourcePath: target.sourcePath,
                contractName: target.contractName,
                artifact,
            });
        }
    }

    const compilerById = new Map(
        compilerOutputs.map((record) => [
            `${record.profile}:${fqn(record.sourcePath, record.contractName)}`,
            record,
        ]),
    );
    const artifactIds = new Set<string>();
    for (const record of artifacts) {
        const id = `${record.profile}:${fqn(record.sourcePath, record.contractName)}`;
        if (artifactIds.has(id)) fail("DUPLICATE_ARTIFACT", id);
        artifactIds.add(id);
        const compilerRecord = compilerById.get(id);
        if (!compilerRecord)
            fail(
                "ARTIFACT_BUILD_INFO_MISMATCH",
                `${id}:missing compiler output`,
            );
        const contract = compilerRecord.contract;
        const buildMetadata = contract.metadata
            ? JSON.parse(contract.metadata)
            : undefined;
        const buildValues = {
            abi: contract.abi ?? [],
            creationCode: `0x${contract.evm?.bytecode?.object ?? ""}`,
            runtimeCode: `0x${contract.evm?.deployedBytecode?.object ?? ""}`,
            creationLinks: contract.evm?.bytecode?.linkReferences ?? {},
            runtimeLinks: contract.evm?.deployedBytecode?.linkReferences ?? {},
            immutables:
                contract.evm?.deployedBytecode?.immutableReferences ?? {},
            metadata: normalizeCompilerMetadata(buildMetadata),
            ast: compilerRecord.sourceAst,
        };
        const artifactValues = {
            abi: record.artifact.abi ?? [],
            creationCode: record.artifact.bytecode?.object ?? "0x",
            runtimeCode: record.artifact.deployedBytecode?.object ?? "0x",
            creationLinks: record.artifact.bytecode?.linkReferences ?? {},
            runtimeLinks:
                record.artifact.deployedBytecode?.linkReferences ?? {},
            immutables:
                record.artifact.deployedBytecode?.immutableReferences ?? {},
            metadata: normalizeCompilerMetadata(record.artifact.metadata),
            ast: record.artifact.ast,
        };
        if (canonicalize(buildValues) !== canonicalize(artifactValues)) {
            fail("ARTIFACT_BUILD_INFO_MISMATCH", id);
        }
    }
    for (const [id] of compilerById) {
        if (!artifactIds.has(id)) fail("MISSING_ARTIFACT_JSON", id);
    }

    return {
        artifacts,
        compilerOutputs,
        linkConsumers,
        buildInputs,
        buildSources,
    };
}

function validateManifest(
    manifest: OwnershipManifest,
): Map<string, OwnershipModule> {
    if (!isRecord(manifest))
        fail("MALFORMED_MANIFEST", "manifest must be an object");
    assertKeys(
        manifest as unknown as Record<string, unknown>,
        [
            "schemaVersion",
            "slotChainPathSegment",
            "profiles",
            "modules",
            "usages",
        ],
        "manifest",
    );
    if (manifest.schemaVersion !== 1)
        fail("UNSUPPORTED_SCHEMA", "schemaVersion must be 1");
    if (manifest.slotChainPathSegment !== "/slotchain/") {
        fail(
            "INVALID_SCOPE",
            "slotChainPathSegment must be exactly /slotchain/",
        );
    }
    if (!isRecord(manifest.profiles))
        fail("MALFORMED_MANIFEST", "profiles must be an object");
    assertKeys(manifest.profiles, PROFILE_NAMES, "profiles");
    for (const profile of PROFILE_NAMES) {
        const entry = manifest.profiles?.[profile];
        if (!isRecord(entry))
            fail("MISSING_PROFILE", `missing profile ${profile}`);
        assertKeys(
            entry,
            [
                "out",
                "required",
                "src",
                "test",
                "script",
                "cachePath",
                "solcVersion",
                "metadataCompilerVersion",
                "evmVersion",
                "optimizer",
                "optimizerRuns",
                "viaIr",
                "ast",
                "buildInfo",
                "metadataBytecodeHash",
                "metadataAppendCbor",
                "metadataUseLiteralContent",
                "skip",
            ],
            `profiles.${profile}`,
        );
        const stringFields = [
            "out",
            "src",
            "test",
            "script",
            "cachePath",
            "solcVersion",
            "metadataCompilerVersion",
            "evmVersion",
            "metadataBytecodeHash",
        ];
        const booleanFields = [
            "required",
            "optimizer",
            "viaIr",
            "ast",
            "buildInfo",
            "metadataAppendCbor",
            "metadataUseLiteralContent",
        ];
        if (
            stringFields.some((field) => typeof entry[field] !== "string") ||
            booleanFields.some((field) => typeof entry[field] !== "boolean") ||
            !Number.isSafeInteger(entry.optimizerRuns) ||
            !Array.isArray(entry.skip) ||
            entry.skip.some((value) => typeof value !== "string")
        ) {
            fail("MALFORMED_PROFILE", profile);
        }
        for (const field of [
            "out",
            "src",
            "test",
            "script",
            "cachePath",
        ] as const) {
            normalizeRelative(
                entry[field] as string,
                `profiles.${profile}.${field}`,
            );
        }
    }
    if (!Array.isArray(manifest.modules) || !Array.isArray(manifest.usages)) {
        fail("MALFORMED_MANIFEST", "modules and usages must be arrays");
    }

    const modules = new Map<string, OwnershipModule>();
    for (const module of manifest.modules) {
        if (!isRecord(module))
            fail("MALFORMED_MODULE", "module must be an object");
        const commonFields = [
            "ownership",
            "sourcePath",
            "contractName",
            "sourceHash",
            "abiHash",
        ];
        if (module.ownership === "source-inline") {
            assertKeys(
                module,
                [
                    ...commonFields,
                    "kind",
                    "allowedProfiles",
                    "requiredProfiles",
                ],
                "module",
            );
        } else if (module.ownership === "artifact-owned") {
            assertKeys(
                module,
                [
                    ...commonFields,
                    "ownerProfile",
                    "artifactPath",
                    "creationCodeHash",
                    "runtimeCodeHash",
                    "creationLinkReferencesHash",
                    "runtimeLinkReferencesHash",
                    "immutableReferencesHash",
                    "consumptionModes",
                    "factoryClass",
                    "lifecycleScope",
                    "requiredConsumerProfiles",
                ],
                "module",
            );
        } else {
            fail("INVALID_OWNERSHIP", String(module.ownership));
        }
        if (
            typeof module.sourcePath !== "string" ||
            typeof module.sourceHash !== "string" ||
            typeof module.abiHash !== "string"
        ) {
            fail("MALFORMED_MODULE", "module path and hashes must be strings");
        }
        normalizeRelative(module.sourcePath, "module.sourcePath");
        if (
            !isManagedSource(module.sourcePath, manifest.slotChainPathSegment)
        ) {
            fail(
                "OUT_OF_SCOPE_MODULE",
                `${module.sourcePath} is outside Slot Chain V2`,
            );
        }
        if (!/^(contracts|script|test)\//.test(module.sourcePath)) {
            fail("OUT_OF_SCOPE_MODULE", module.sourcePath);
        }
        const freeDefinitions =
            module.ownership === "source-inline" &&
            module.kind === "free-definitions";
        if (
            freeDefinitions
                ? module.contractName !== undefined
                : typeof module.contractName !== "string" ||
                  !/^[A-Za-z_$][A-Za-z0-9_$]*$/.test(module.contractName)
        ) {
            fail(
                "INVALID_CONTRACT_NAME",
                `${module.sourcePath}:${module.contractName}`,
            );
        }
        for (const field of ["sourceHash", "abiHash"] as const)
            assertHash(module[field], field);
        const id = moduleId(module);
        if (modules.has(id)) fail("DUPLICATE_MODULE", id);
        modules.set(id, module);

        if (module.ownership === "source-inline") {
            if (!SOURCE_INLINE_KINDS.has(module.kind))
                fail("INVALID_SOURCE_INLINE_KIND", id);
            if (
                !Array.isArray(module.allowedProfiles) ||
                !Array.isArray(module.requiredProfiles) ||
                module.requiredProfiles.length === 0
            ) {
                fail("MALFORMED_SOURCE_INLINE_PROFILES", id);
            }
            assertUnique(module.allowedProfiles, `${id}.allowedProfiles`);
            assertUnique(module.requiredProfiles, `${id}.requiredProfiles`);
            for (const profile of [
                ...module.allowedProfiles,
                ...module.requiredProfiles,
            ]) {
                if (!OWNER_PROFILE_NAMES.includes(profile as OwnerProfileName))
                    fail("UNKNOWN_PROFILE", `${id}:${profile}`);
            }
            for (const required of module.requiredProfiles) {
                if (!module.allowedProfiles.includes(required)) {
                    fail("REQUIRED_PROFILE_NOT_ALLOWED", `${id}:${required}`);
                }
            }
            if (
                module.kind === "free-definitions" &&
                module.abiHash !== canonicalHash([])
            ) {
                fail("ABI_HASH_MISMATCH", id);
            }
        } else if (module.ownership === "artifact-owned") {
            if (!OWNER_PROFILE_NAMES.includes(module.ownerProfile))
                fail("UNKNOWN_PROFILE", id);
            if (
                typeof module.artifactPath !== "string" ||
                !Array.isArray(module.consumptionModes) ||
                !Array.isArray(module.requiredConsumerProfiles)
            ) {
                fail("MALFORMED_ARTIFACT_OWNED_MODULE", id);
            }
            normalizeRelative(module.artifactPath, `${id}.artifactPath`);
            for (const field of [
                "creationCodeHash",
                "runtimeCodeHash",
                "creationLinkReferencesHash",
                "runtimeLinkReferencesHash",
                "immutableReferencesHash",
            ] as const) {
                assertHash(module[field], `${id}.${field}`);
            }
            assertUnique(module.consumptionModes, `${id}.consumptionModes`);
            assertUnique(
                module.requiredConsumerProfiles,
                `${id}.requiredConsumerProfiles`,
            );
            for (const profile of module.requiredConsumerProfiles) {
                if (!OWNER_PROFILE_NAMES.includes(profile))
                    fail("UNKNOWN_PROFILE", `${id}:${profile}`);
            }
            for (const mode of module.consumptionModes) {
                if (!CONSUMPTION_MODES.has(mode))
                    fail("INVALID_CONSUMPTION_MODE", `${id}:${mode}`);
            }
            if (!FACTORY_CLASSES.has(module.factoryClass))
                fail("INVALID_FACTORY_CLASS", id);
            if (!LIFECYCLE_SCOPES.has(module.lifecycleScope))
                fail("INVALID_LIFECYCLE_SCOPE", id);
            assertFactoryLifecycle(
                module.factoryClass,
                module.lifecycleScope,
                id,
            );
        } else {
            fail("INVALID_OWNERSHIP", id);
        }
    }
    return modules;
}

function validateSourceCoverage(
    root: string,
    manifest: OwnershipManifest,
    modules: Map<string, OwnershipModule>,
): void {
    const classifiedSources = new Set(
        [...modules.values()].map((module) => module.sourcePath),
    );
    for (const sourceRoot of ["contracts", "test", "script"]) {
        for (const absolute of walk(path.join(root, sourceRoot), (file) =>
            file.endsWith(".sol"),
        )) {
            const sourcePath = path
                .relative(root, absolute)
                .split(path.sep)
                .join("/");
            if (
                isManagedSource(sourcePath, manifest.slotChainPathSegment) &&
                !classifiedSources.has(sourcePath)
            ) {
                fail("UNCLASSIFIED_MODULE", sourcePath);
            }
        }
    }
}

function contractDefinition(
    artifact: FoundryArtifact,
    contractName: string,
): AstNode | undefined {
    return artifact.ast?.nodes?.find(
        (node) =>
            node.nodeType === "ContractDefinition" &&
            node.name === contractName,
    );
}

function assertNoLibraryLinks(
    consumers: CompilerLinkConsumer[],
    module: SourceInlineModule,
): void {
    const contractName = module.contractName;
    if (!contractName) fail("INVALID_CONTRACT_NAME", moduleId(module));
    for (const record of consumers) {
        for (const [where, references] of [
            ["creation", record.creationLinkReferences],
            ["runtime", record.runtimeLinkReferences],
        ] as const) {
            const sourceReferences = (
                references as
                    | Record<string, Record<string, unknown>>
                    | undefined
            )?.[module.sourcePath];
            if (
                sourceReferences &&
                Object.prototype.hasOwnProperty.call(
                    sourceReferences,
                    contractName,
                )
            ) {
                fail(
                    "SOURCE_INLINE_LINK_REFERENCE",
                    `${fqn(module.sourcePath, contractName)} linked by ${fqn(
                        record.sourcePath,
                        record.contractName,
                    )} in ${record.profile} (${where})`,
                );
            }
        }
    }
}

function verifyCompilerSettings(
    profile: OwnershipProfile,
    id: string,
    artifact: FoundryArtifact,
): void {
    const metadata = artifact.metadata;
    if (
        profile.metadataCompilerVersion &&
        metadata?.compiler?.version !== profile.metadataCompilerVersion
    ) {
        fail(
            "COMPILER_VERSION_MISMATCH",
            `${id}:${metadata?.compiler?.version}`,
        );
    }
    if (
        profile.evmVersion &&
        metadata?.settings?.evmVersion !== profile.evmVersion
    ) {
        fail("EVM_VERSION_MISMATCH", `${id}:${metadata?.settings?.evmVersion}`);
    }
    if (
        profile.optimizer !== undefined &&
        metadata?.settings?.optimizer?.enabled !== profile.optimizer
    ) {
        fail("OPTIMIZER_MISMATCH", id);
    }
    if (
        profile.optimizerRuns !== undefined &&
        metadata?.settings?.optimizer?.runs !== profile.optimizerRuns
    ) {
        fail("OPTIMIZER_RUNS_MISMATCH", id);
    }
    if (
        profile.viaIr !== undefined &&
        (metadata?.settings?.viaIR ?? false) !== profile.viaIr
    ) {
        fail("VIA_IR_MISMATCH", id);
    }
}

function verifySourceInline(
    manifest: OwnershipManifest,
    module: SourceInlineModule,
    records: ArtifactRecord[],
    buildInputs: Map<ProfileName, Set<string>>,
    buildSources: Map<ProfileName, Map<string, CompilerSourceRecord>>,
): void {
    const id = moduleId(module);
    const contractName = module.contractName;
    const observedInputs = PROFILE_NAMES.filter(
        (profile) => buildInputs.get(profile)?.has(module.sourcePath) ?? false,
    );
    const observed = [...new Set(records.map((record) => record.profile))].sort(
        compareUtf8,
    );
    if (records.length !== observed.length) fail("DUPLICATE_ARTIFACT", id);
    for (const profile of observedInputs) {
        if (
            !OWNER_PROFILE_NAMES.includes(profile as OwnerProfileName) ||
            !module.allowedProfiles.includes(profile as OwnerProfileName)
        )
            fail("SOURCE_INLINE_PROFILE_DRIFT", `${id}:${profile}`);
    }
    for (const profile of module.requiredProfiles) {
        if (!observedInputs.includes(profile))
            fail("SOURCE_INLINE_PROFILE_MISSING", `${id}:${profile}`);
        if (module.kind !== "free-definitions" && !observed.includes(profile)) {
            fail("SOURCE_INLINE_ARTIFACT_MISSING", `${id}:${profile}`);
        }
    }

    if (module.kind === "free-definitions") {
        if (records.length !== 0) fail("ADDRESSABLE_SOURCE_INLINE", id);
        for (const profile of module.requiredProfiles) {
            const sourceAst = buildSources
                .get(profile)
                ?.get(module.sourcePath)?.ast;
            if (!sourceAst)
                fail("MISSING_BUILD_OUTPUT_AST", `${id}:${profile}`);
            if (
                sourceAst.nodes.some(
                    (node) => node.nodeType === "ContractDefinition",
                )
            ) {
                fail("SOURCE_INLINE_KIND_MISMATCH", `${id}:${profile}`);
            }
        }
        return;
    }
    if (!contractName) fail("INVALID_CONTRACT_NAME", id);

    for (const record of records) {
        if (
            record.relativePath !==
            expectedArtifactPath(manifest.profiles[record.profile], module)
        ) {
            fail("ARTIFACT_PATH_MISMATCH", `${id}:${record.relativePath}`);
        }
        verifyCompilerSettings(
            manifest.profiles[record.profile],
            `${id}:${record.profile}`,
            record.artifact,
        );
        if (
            record.artifact.metadata?.sources?.[module.sourcePath]
                ?.keccak256 !== module.sourceHash
        ) {
            fail("SOURCE_METADATA_HASH_MISMATCH", `${id}:${record.profile}`);
        }
        if (canonicalHash(record.artifact.abi ?? []) !== module.abiHash) {
            fail("ABI_HASH_MISMATCH", `${id}:${record.profile}`);
        }
        const definition = contractDefinition(record.artifact, contractName);
        if (module.kind === "interface") {
            if (definition?.contractKind !== "interface")
                fail("SOURCE_INLINE_KIND_MISMATCH", id);
            if ((record.artifact.bytecode?.object ?? "0x") !== "0x") {
                fail(
                    "ADDRESSABLE_SOURCE_INLINE",
                    `${id} has creation bytecode`,
                );
            }
            if ((record.artifact.deployedBytecode?.object ?? "0x") !== "0x") {
                fail("ADDRESSABLE_SOURCE_INLINE", `${id} has runtime bytecode`);
            }
        } else if (module.kind === "internal-library") {
            if (definition?.contractKind !== "library")
                fail("SOURCE_INLINE_KIND_MISMATCH", id);
            if ((record.artifact.abi ?? []).length !== 0)
                fail("ADDRESSABLE_SOURCE_INLINE", `${id} has ABI`);
            for (const node of definition.nodes ?? []) {
                if (
                    node.nodeType === "FunctionDefinition" &&
                    (node.visibility === "public" ||
                        node.visibility === "external")
                ) {
                    fail(
                        "ADDRESSABLE_SOURCE_INLINE",
                        `${id} has ${node.visibility} function ${node.name}`,
                    );
                }
                if (
                    node.nodeType === "VariableDeclaration" &&
                    node.stateVariable &&
                    node.visibility === "public"
                ) {
                    fail(
                        "ADDRESSABLE_SOURCE_INLINE",
                        `${id} has public state ${node.name}`,
                    );
                }
            }
        } else if (definition) {
            fail(
                "SOURCE_INLINE_KIND_MISMATCH",
                `${id} declares a contract definition`,
            );
        }
    }
}

function expectedArtifactPath(
    profile: OwnershipProfile,
    module: OwnershipModule,
): string {
    return `${profile.out}/${path.posix.basename(module.sourcePath)}/${module.contractName}.json`;
}

function verifyArtifactOwned(
    manifest: OwnershipManifest,
    module: ArtifactOwnedModule,
    records: ArtifactRecord[],
    buildInputs: Map<ProfileName, Set<string>>,
): void {
    const id = fqn(module.sourcePath, module.contractName);
    if (records.length !== 1 || records[0].profile !== module.ownerProfile) {
        fail(
            "ARTIFACT_OWNER_VIOLATION",
            `${id} expected once in ${module.ownerProfile}, observed ${
                records.map((record) => record.profile).join(",") || "none"
            }`,
        );
    }
    for (const profile of PROFILE_NAMES) {
        const present =
            buildInputs.get(profile)?.has(module.sourcePath) ?? false;
        if (profile === module.ownerProfile ? !present : present) {
            fail(
                "SOURCE_OWNER_VIOLATION",
                `${id}:${profile}:${present ? "present" : "missing"}`,
            );
        }
    }

    const record = records[0];
    if (record.relativePath !== module.artifactPath) {
        fail("ARTIFACT_PATH_MISMATCH", `${id}:${record.relativePath}`);
    }
    if (
        module.artifactPath !==
        expectedArtifactPath(manifest.profiles[module.ownerProfile], module)
    ) {
        fail("NONCANONICAL_ARTIFACT_PATH", `${id}:${module.artifactPath}`);
    }
    const metadata = record.artifact.metadata;
    verifyCompilerSettings(
        manifest.profiles[module.ownerProfile],
        id,
        record.artifact,
    );

    const sourceMetadataHash =
        metadata?.sources?.[module.sourcePath]?.keccak256;
    if (sourceMetadataHash !== module.sourceHash)
        fail("SOURCE_METADATA_HASH_MISMATCH", id);
    const actual = {
        abiHash: canonicalHash(record.artifact.abi ?? []),
        creationCodeHash: bytecodeHash(
            record.artifact.bytecode?.object ?? "0x",
        ),
        runtimeCodeHash: bytecodeHash(
            record.artifact.deployedBytecode?.object ?? "0x",
        ),
        creationLinkReferencesHash: canonicalHash(
            record.artifact.bytecode?.linkReferences ?? {},
        ),
        runtimeLinkReferencesHash: canonicalHash(
            record.artifact.deployedBytecode?.linkReferences ?? {},
        ),
        immutableReferencesHash: canonicalHash(
            record.artifact.deployedBytecode?.immutableReferences ?? {},
        ),
    };
    for (const [field, value] of Object.entries(actual)) {
        if (value !== module[field as keyof ArtifactOwnedModule]) {
            fail("ARTIFACT_HASH_MISMATCH", `${id}:${field}`);
        }
    }
}

function astSome(
    value: unknown,
    predicate: (node: Record<string, unknown>) => boolean,
): boolean {
    if (Array.isArray(value))
        return value.some((entry) => astSome(entry, predicate));
    if (!isRecord(value)) return false;
    if (predicate(value)) return true;
    return Object.values(value).some((entry) => astSome(entry, predicate));
}

function hasImport(ast: AstNode, sourcePath: string): boolean {
    return astSome(
        ast,
        (node) =>
            node.nodeType === "ImportDirective" &&
            node.absolutePath === sourcePath,
    );
}

function hasVmGetCodeCall(ast: AstNode, artifactPath: string): boolean {
    return astSome(ast, (node) => {
        if (node.nodeType !== "FunctionCall" || !isRecord(node.expression))
            return false;
        const memberAccess = node.expression;
        if (
            memberAccess.nodeType !== "MemberAccess" ||
            memberAccess.memberName !== "getCode" ||
            !isRecord(memberAccess.expression) ||
            memberAccess.expression.nodeType !== "Identifier" ||
            memberAccess.expression.name !== "vm" ||
            !Array.isArray(node.arguments)
        ) {
            return false;
        }
        return node.arguments.some(
            (argument) =>
                isRecord(argument) &&
                argument.nodeType === "Literal" &&
                argument.kind === "string" &&
                argument.value === artifactPath,
        );
    });
}

function hasCreateCall(ast: AstNode): boolean {
    return astSome(
        ast,
        (node) =>
            node.nodeType === "YulFunctionCall" &&
            isRecord(node.functionName) &&
            node.functionName.name === "create",
    );
}

function validateUsages(
    manifest: OwnershipManifest,
    modules: Map<string, OwnershipModule>,
    buildInputs: Map<ProfileName, Set<string>>,
    buildSources: Map<ProfileName, Map<string, CompilerSourceRecord>>,
): void {
    const usageIds = new Set<string>();
    const consumedProfiles = new Map<string, Set<OwnerProfileName>>();
    for (const usage of manifest.usages) {
        if (!isRecord(usage))
            fail("MALFORMED_USAGE", "usage must be an object");
        assertKeys(
            usage,
            [
                "module",
                "consumerModule",
                "consumerProfile",
                "modes",
                "interfaceModule",
                "factoryClass",
                "lifecycleScope",
            ],
            "usage",
        );
        const module = modules.get(usage.module);
        if (!module) fail("UNKNOWN_USAGE_MODULE", usage.module);
        if (module.ownership !== "artifact-owned")
            fail("SOURCE_INLINE_USAGE", usage.module);
        if (typeof usage.consumerModule !== "string")
            fail("MALFORMED_USAGE", `${usage.module}:consumerModule`);
        if (!OWNER_PROFILE_NAMES.includes(usage.consumerProfile))
            fail("UNKNOWN_PROFILE", usage.consumerProfile);
        if (!Array.isArray(usage.modes)) fail("MALFORMED_USAGE", usage.module);
        assertUnique(usage.modes, `${usage.module}.usage.modes`);
        if (usage.modes.length === 0) fail("EMPTY_USAGE_MODES", usage.module);
        for (const mode of usage.modes) {
            if (
                !CONSUMPTION_MODES.has(mode) ||
                !module.consumptionModes.includes(mode)
            ) {
                fail("UNAPPROVED_CONSUMPTION_MODE", `${usage.module}:${mode}`);
            }
        }
        if (usage.factoryClass !== module.factoryClass)
            fail("FACTORY_CLASS_MISMATCH", usage.module);
        if (usage.lifecycleScope !== module.lifecycleScope)
            fail("LIFECYCLE_SCOPE_MISMATCH", usage.module);
        assertFactoryLifecycle(
            usage.factoryClass,
            usage.lifecycleScope,
            usage.module,
        );

        const consumer = modules.get(usage.consumerModule);
        if (!consumer) fail("UNKNOWN_CONSUMER_MODULE", usage.consumerModule);
        if (consumer.ownership !== "artifact-owned")
            fail("SOURCE_INLINE_CONSUMER", usage.consumerModule);
        if (consumer.ownerProfile !== usage.consumerProfile) {
            fail(
                "CONSUMER_PROFILE_MISMATCH",
                `${usage.consumerModule}:${usage.consumerProfile}`,
            );
        }
        if (usage.consumerModule === usage.module)
            fail("SELF_CONSUMPTION", usage.module);
        if (!buildInputs.get(usage.consumerProfile)?.has(consumer.sourcePath)) {
            fail(
                "CONSUMER_BUILD_INPUT_MISSING",
                `${usage.consumerProfile}:${usage.consumerModule}`,
            );
        }
        const consumerAst = buildSources
            .get(usage.consumerProfile)
            ?.get(consumer.sourcePath)?.ast;
        if (!consumerAst) fail("CONSUMER_AST_MISSING", usage.consumerModule);
        if (
            usage.lifecycleScope === "test-only" &&
            !consumer.sourcePath.endsWith(".t.sol")
        ) {
            fail("TEST_USAGE_NOT_IN_TEST", usage.consumerModule);
        }

        if (usage.modes.includes("raw-creation-bytecode")) {
            if (!hasVmGetCodeCall(consumerAst, module.artifactPath)) {
                fail(
                    "ARTIFACT_PATH_EVIDENCE_MISSING",
                    `${usage.consumerModule}:${module.artifactPath}`,
                );
            }
        }
        if (usage.modes.includes("abi-interface")) {
            if (typeof usage.interfaceModule !== "string")
                fail("INTERFACE_MODULE_MISSING", usage.consumerModule);
            const interfaceModule = modules.get(usage.interfaceModule);
            if (
                !interfaceModule ||
                interfaceModule.ownership !== "source-inline" ||
                interfaceModule.kind !== "interface"
            ) {
                fail("INVALID_INTERFACE_MODULE", usage.interfaceModule);
            }
            if (interfaceModule.abiHash !== module.abiHash) {
                fail(
                    "INTERFACE_ABI_MISMATCH",
                    `${usage.interfaceModule}:${usage.module}`,
                );
            }
            if (
                !interfaceModule.allowedProfiles.includes(
                    usage.consumerProfile,
                ) ||
                !interfaceModule.requiredProfiles.includes(
                    usage.consumerProfile,
                ) ||
                !buildInputs
                    .get(usage.consumerProfile)
                    ?.has(interfaceModule.sourcePath)
            ) {
                fail(
                    "INTERFACE_PROFILE_MISMATCH",
                    `${usage.interfaceModule}:${usage.consumerProfile}`,
                );
            }
            if (!hasImport(consumerAst, interfaceModule.sourcePath)) {
                fail(
                    "INTERFACE_IMPORT_EVIDENCE_MISSING",
                    `${usage.consumerModule}:${interfaceModule.sourcePath}`,
                );
            }
        } else if (usage.interfaceModule !== undefined) {
            fail("UNUSED_INTERFACE_MODULE", usage.consumerModule);
        }
        if (usage.factoryClass === "direct-create-test") {
            if (
                !usage.modes.includes("raw-creation-bytecode") ||
                !hasCreateCall(consumerAst)
            ) {
                fail("DIRECT_CREATE_EVIDENCE_MISSING", usage.consumerModule);
            }
        }

        const usageId = `${usage.module}:${usage.consumerModule}`;
        if (usageIds.has(usageId)) fail("DUPLICATE_USAGE", usageId);
        usageIds.add(usageId);
        const profiles = consumedProfiles.get(usage.module) ?? new Set();
        profiles.add(usage.consumerProfile);
        consumedProfiles.set(usage.module, profiles);
    }
    for (const module of modules.values()) {
        if (module.ownership !== "artifact-owned") continue;
        const id = fqn(module.sourcePath, module.contractName);
        for (const profile of module.requiredConsumerProfiles) {
            if (!consumedProfiles.get(id)?.has(profile))
                fail("MISSING_REQUIRED_USAGE", `${id}:${profile}`);
        }
    }
}

function assertFactoryLifecycle(
    factoryClass: FactoryClass,
    lifecycleScope: LifecycleScope,
    id: string,
): void {
    const expected: Record<FactoryClass, LifecycleScope> = {
        "direct-create-test": "test-only",
        "erc-2470-singleton": "release-scoped",
        "protocol-root-source-factory": "release-scoped",
        "root-one-shot-create": "protocol-lifetime",
    };
    if (expected[factoryClass] !== lifecycleScope) {
        fail(
            "FACTORY_LIFECYCLE_MISMATCH",
            `${id}:${factoryClass}:${lifecycleScope}`,
        );
    }
}

export function validateArtifactOwnership(
    root: string,
    manifest: OwnershipManifest,
): OwnershipInventory {
    const resolvedRoot = path.resolve(root);
    const modules = validateManifest(manifest);
    validateSourceCoverage(resolvedRoot, manifest, modules);
    const {
        artifacts,
        compilerOutputs,
        linkConsumers,
        buildInputs,
        buildSources,
    } = loadArtifacts(resolvedRoot, manifest);

    const byFqn = new Map<string, ArtifactRecord[]>();
    for (const record of artifacts) {
        const id = fqn(record.sourcePath, record.contractName);
        if (!modules.has(id))
            fail("UNCLASSIFIED_ARTIFACT", `${id}:${record.profile}`);
        byFqn.set(id, [...(byFqn.get(id) ?? []), record]);
    }
    for (const record of compilerOutputs) {
        const id = fqn(record.sourcePath, record.contractName);
        if (!modules.has(id))
            fail("UNCLASSIFIED_COMPILER_OUTPUT", `${id}:${record.profile}`);
    }

    const inventory: OwnershipInventory["modules"] = [];
    for (const [id, module] of [...modules.entries()].sort(([left], [right]) =>
        compareUtf8(left, right),
    )) {
        const absoluteSource = path.join(resolvedRoot, module.sourcePath);
        if (!fs.existsSync(absoluteSource))
            fail("MISSING_SOURCE", module.sourcePath);
        if (sourceHash(fs.readFileSync(absoluteSource)) !== module.sourceHash) {
            fail("SOURCE_HASH_MISMATCH", module.sourcePath);
        }
        for (const profile of PROFILE_NAMES) {
            const compilerSource = buildSources
                .get(profile)
                ?.get(module.sourcePath);
            if (
                compilerSource &&
                sourceHash(compilerSource.content) !== module.sourceHash
            ) {
                fail("BUILD_INPUT_SOURCE_HASH_MISMATCH", `${id}:${profile}`);
            }
        }
        const records = byFqn.get(id) ?? [];
        if (module.ownership === "source-inline") {
            verifySourceInline(
                manifest,
                module,
                records,
                buildInputs,
                buildSources,
            );
            if (module.kind === "internal-library")
                assertNoLibraryLinks(linkConsumers, module);
        } else {
            verifyArtifactOwned(manifest, module, records, buildInputs);
        }
        inventory.push({
            fqn: id,
            ownership: module.ownership,
            profiles: (module.ownership === "source-inline"
                ? PROFILE_NAMES.filter(
                      (profile) =>
                          buildInputs.get(profile)?.has(module.sourcePath) ??
                          false,
                  )
                : [...new Set(records.map((record) => record.profile))]
            ).sort(compareUtf8) as ProfileName[],
            fingerprint: canonicalHash(module),
        });
    }

    validateUsages(manifest, modules, buildInputs, buildSources);

    const usages = [...manifest.usages].sort((left, right) =>
        compareUtf8(canonicalize(left), canonicalize(right)),
    );
    return {
        digest: canonicalHash({ modules: inventory, usages }),
        modules: inventory,
    };
}

function assertConfigValue(
    profile: ProfileName,
    field: string,
    expected: unknown,
    actual: unknown,
): void {
    const matches =
        typeof expected === "object" && expected !== null
            ? canonicalize(actual) === canonicalize(expected)
            : actual === expected;
    if (!matches) {
        fail(
            "PROFILE_CONFIG_MISMATCH",
            `${profile}.${field}: expected ${expected}, got ${actual}`,
        );
    }
}

export function validateProfileConfigs(
    root: string,
    manifest: OwnershipManifest,
): void {
    for (const profileName of PROFILE_NAMES) {
        const expected = manifest.profiles[profileName];
        let config: Record<string, unknown>;
        try {
            config = JSON.parse(
                execFileSync("forge", ["config", "--json"], {
                    cwd: root,
                    env: Object.assign({}, process.env, {
                        FOUNDRY_PROFILE: profileName,
                    }),
                    encoding: "utf8",
                }),
            ) as Record<string, unknown>;
        } catch (error) {
            fail(
                "FORGE_CONFIG_FAILED",
                `${profileName}: ${(error as Error).message}`,
            );
        }
        assertConfigValue(profileName, "out", expected.out, config.out);
        assertConfigValue(profileName, "src", expected.src, config.src);
        assertConfigValue(profileName, "test", expected.test, config.test);
        assertConfigValue(
            profileName,
            "script",
            expected.script,
            config.script,
        );
        assertConfigValue(
            profileName,
            "cache_path",
            expected.cachePath,
            config.cache_path,
        );
        assertConfigValue(
            profileName,
            "solc",
            expected.solcVersion,
            config.solc,
        );
        assertConfigValue(
            profileName,
            "evm_version",
            expected.evmVersion,
            config.evm_version,
        );
        assertConfigValue(
            profileName,
            "optimizer",
            expected.optimizer,
            config.optimizer,
        );
        assertConfigValue(
            profileName,
            "optimizer_runs",
            expected.optimizerRuns,
            config.optimizer_runs,
        );
        assertConfigValue(profileName, "via_ir", expected.viaIr, config.via_ir);
        assertConfigValue(profileName, "ast", expected.ast, config.ast);
        assertConfigValue(
            profileName,
            "build_info",
            expected.buildInfo,
            config.build_info,
        );
        assertConfigValue(
            profileName,
            "bytecode_hash",
            expected.metadataBytecodeHash,
            config.bytecode_hash,
        );
        assertConfigValue(
            profileName,
            "cbor_metadata",
            expected.metadataAppendCbor,
            config.cbor_metadata,
        );
        assertConfigValue(
            profileName,
            "use_literal_content",
            expected.metadataUseLiteralContent,
            config.use_literal_content,
        );
        assertConfigValue(profileName, "skip", expected.skip, config.skip);
    }
}

export function loadOwnedArtifact(
    root: string,
    manifest: OwnershipManifest,
    moduleId: string,
): FoundryArtifact {
    validateArtifactOwnership(root, manifest);
    const module = manifest.modules.find(
        (candidate) =>
            moduleId ===
            `${candidate.sourcePath}:${candidate.contractName ?? ""}`,
    );
    if (!module) fail("UNKNOWN_MODULE", moduleId);
    if (module.ownership !== "artifact-owned")
        fail("NOT_ARTIFACT_OWNED", moduleId);
    const artifactPath = path.resolve(root, module.artifactPath);
    const relative = path.relative(path.resolve(root), artifactPath);
    if (relative.startsWith("..") || path.isAbsolute(relative))
        fail("PATH_ESCAPE", module.artifactPath);
    const artifact = readJson(artifactPath) as FoundryArtifact;
    const target = compilationTarget(artifact, artifactPath);
    if (!target || fqn(target.sourcePath, target.contractName) !== moduleId) {
        fail("ARTIFACT_IDENTITY_MISMATCH", moduleId);
    }
    const observedHashes = [
        ["abiHash", canonicalHash(artifact.abi ?? [])],
        ["creationCodeHash", bytecodeHash(artifact.bytecode?.object ?? "0x")],
        [
            "runtimeCodeHash",
            bytecodeHash(artifact.deployedBytecode?.object ?? "0x"),
        ],
        [
            "creationLinkReferencesHash",
            canonicalHash(artifact.bytecode?.linkReferences ?? {}),
        ],
        [
            "runtimeLinkReferencesHash",
            canonicalHash(artifact.deployedBytecode?.linkReferences ?? {}),
        ],
        [
            "immutableReferencesHash",
            canonicalHash(artifact.deployedBytecode?.immutableReferences ?? {}),
        ],
    ] as const;
    for (const [field, observed] of observedHashes) {
        if (observed !== module[field])
            fail("ARTIFACT_HASH_MISMATCH", `${moduleId}:${field}`);
    }
    return artifact;
}

function main(): void {
    const root = path.resolve(__dirname, "../..");
    const manifestPath = path.join(__dirname, "artifact-ownership.json");
    const manifest = readJson(manifestPath) as OwnershipManifest;
    validateProfileConfigs(root, manifest);
    const inventory = validateArtifactOwnership(root, manifest);
    console.log(`slot chain artifact ownership: PASS (${inventory.digest})`);
}

if (require.main === module) main();
