import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

export type ConformanceKind =
    | "root-artifact"
    | "deployable"
    | "creation-only"
    | "external-dependency"
    | "source-inline";
export type CanonicalSourceRoot = "shared" | "layer1" | "layer2";
export type SourceKind =
    | "interface"
    | "internal-library"
    | "free-definitions"
    | "abstract-base"
    | "not-applicable";
export type ArtifactScope =
    | "root-set"
    | "standalone"
    | "creation-only"
    | "external"
    | "source-inline";
export type AddressReusePolicy =
    | "protocol-lifetime"
    | "fresh-per-release"
    | "campaign-role-helper"
    | "descriptor-selected"
    | "legacy-fixed"
    | "external"
    | "not-applicable";
export type RetentionPolicy =
    | "permanent"
    | "historical"
    | "ephemeral-inert"
    | "external"
    | "source-inline";
export type ReactivationPolicy = "never" | "not-applicable";
export type ConformanceStatus = "missing" | "red" | "passing" | "reviewed";

export interface ConformanceEntry {
    id: string;
    name: string;
    aliases: string[];
    kind: ConformanceKind;
    normativeRefs: string[];
    provenance: "pr-owned" | "external";
    artifactOwnerProfile: CanonicalSourceRoot | null;
    canonicalSourceRoot: CanonicalSourceRoot | null;
    allowedConsumerProfiles: CanonicalSourceRoot[];
    sourceKind: SourceKind;
    artifactScope: ArtifactScope;
    addressReusePolicy: AddressReusePolicy;
    retentionPolicy: RetentionPolicy;
    reactivationPolicy: ReactivationPolicy;
    abiOrEncoding: string[];
    sourcePaths: string[];
    testPaths: string[];
    failureBranches: string[];
    limits: string[];
    status: ConformanceStatus;
    reviewedSourceHashes: Record<string, string>;
    reviewedTestHashes: Record<string, string>;
}

export interface ConformanceLedger {
    schemaVersion: 1;
    protocolVersion: "2.27";
    normativeCommit: "2008937506ece50821440744ff0ee6f73a5485ce";
    rootArtifactCount: 18;
    entries: ConformanceEntry[];
}

const LEDGER_FIELDS = [
    "schemaVersion",
    "protocolVersion",
    "normativeCommit",
    "rootArtifactCount",
    "entries",
] as const;
const ENTRY_FIELDS = [
    "id",
    "name",
    "aliases",
    "kind",
    "normativeRefs",
    "provenance",
    "artifactOwnerProfile",
    "canonicalSourceRoot",
    "allowedConsumerProfiles",
    "sourceKind",
    "artifactScope",
    "addressReusePolicy",
    "retentionPolicy",
    "reactivationPolicy",
    "abiOrEncoding",
    "sourcePaths",
    "testPaths",
    "failureBranches",
    "limits",
    "status",
    "reviewedSourceHashes",
    "reviewedTestHashes",
] as const;
const KINDS = new Set<ConformanceKind>([
    "root-artifact",
    "deployable",
    "creation-only",
    "external-dependency",
    "source-inline",
]);
const OWNER_PROFILES = new Set<CanonicalSourceRoot>([
    "shared",
    "layer1",
    "layer2",
]);
const SOURCE_KINDS = new Set<SourceKind>([
    "interface",
    "internal-library",
    "free-definitions",
    "abstract-base",
    "not-applicable",
]);
const ARTIFACT_SCOPES = new Set<ArtifactScope>([
    "root-set",
    "standalone",
    "creation-only",
    "external",
    "source-inline",
]);
const ADDRESS_REUSE_POLICIES = new Set<AddressReusePolicy>([
    "protocol-lifetime",
    "fresh-per-release",
    "campaign-role-helper",
    "descriptor-selected",
    "legacy-fixed",
    "external",
    "not-applicable",
]);
const RETENTION_POLICIES = new Set<RetentionPolicy>([
    "permanent",
    "historical",
    "ephemeral-inert",
    "external",
    "source-inline",
]);
const REACTIVATION_POLICIES = new Set<ReactivationPolicy>([
    "never",
    "not-applicable",
]);
const STATUSES = new Set<ConformanceStatus>([
    "missing",
    "red",
    "passing",
    "reviewed",
]);
const COMMIT_PATTERN = /^[0-9a-f]{40}$/;
const HASH_PATTERN = /^0x[0-9a-f]{64}$/;
const ID_PATTERN = /^[a-z][a-z0-9]*(?:[.-][a-z0-9]+)*$/;

export class ConformanceError extends Error {
    public constructor(
        public readonly code: string,
        message: string,
    ) {
        super(`${code}: ${message}`);
        this.name = "ConformanceError";
    }
}

function fail(code: string, message: string): never {
    throw new ConformanceError(code, message);
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function assertExactFields(
    value: Record<string, unknown>,
    expected: readonly string[],
    code: string,
    label: string,
): void {
    const actual = Object.keys(value).sort();
    const wanted = [...expected].sort();
    const unknown = actual.filter((key) => !wanted.includes(key));
    const missing = wanted.filter((key) => !actual.includes(key));
    if (unknown.length !== 0)
        fail(code, `${label} has unknown fields: ${unknown.join(",")}`);
    if (missing.length !== 0)
        fail(code, `${label} is missing fields: ${missing.join(",")}`);
}

function assertStringArray(
    value: unknown,
    field: string,
    allowEmpty: boolean,
    allowDuplicates = false,
): string[] {
    if (
        !Array.isArray(value) ||
        value.some((item) => typeof item !== "string" || item.trim() === "")
    ) {
        fail(
            "INVALID_ENTRY_FIELD",
            `${field} must contain only non-empty strings`,
        );
    }
    if (!allowEmpty && value.length === 0) fail("EMPTY_ENTRY_FIELD", field);
    if (!allowDuplicates && new Set(value).size !== value.length)
        fail("DUPLICATE_VALUE", field);
    return value;
}

function assertPath(value: string, field: string): void {
    if (path.isAbsolute(value) || value.includes("\\")) {
        fail("INVALID_PATH", `${field}: ${value}`);
    }
    if (
        path.posix.normalize(value) !== value ||
        value === "." ||
        value.startsWith("../")
    ) {
        fail("NON_CANONICAL_PATH", `${field}: ${value}`);
    }
}

function assertPaths(value: unknown, field: string): string[] {
    const paths = assertStringArray(value, field, true, true);
    if (new Set(paths).size !== paths.length) fail("DUPLICATE_PATH", field);
    for (const candidate of paths) assertPath(candidate, field);
    return paths;
}

function assertHashMap(
    value: unknown,
    field: string,
    paths: string[],
    required: boolean,
): Record<string, string> {
    if (!isRecord(value))
        fail("INVALID_ENTRY_FIELD", `${field} must be an object`);
    const keys = Object.keys(value).sort();
    if (!required && keys.length !== 0)
        fail("HASHES_ON_UNREVIEWED_ENTRY", field);
    if (
        required &&
        (keys.length === 0 || keys.join("\0") !== [...paths].sort().join("\0"))
    ) {
        fail(
            "REVIEWED_WITHOUT_HASHES",
            `${field} must hash every declared path`,
        );
    }
    for (const key of keys) {
        assertPath(key, field);
        const hash = value[key];
        if (typeof hash !== "string" || !HASH_PATTERN.test(hash)) {
            fail("INVALID_REVIEW_HASH", `${field}.${key}`);
        }
    }
    return value as Record<string, string>;
}

function validateEntry(value: unknown, index: number): ConformanceEntry {
    if (!isRecord(value)) fail("INVALID_ENTRY", `entries[${index}]`);
    assertExactFields(
        value,
        ENTRY_FIELDS,
        "UNKNOWN_ENTRY_FIELD",
        `entries[${index}]`,
    );

    const id = value.id;
    if (typeof id !== "string" || !ID_PATTERN.test(id))
        fail("INVALID_ENTRY_ID", `${id}`);
    if (typeof value.name !== "string" || value.name.trim() === "") {
        fail("INVALID_ENTRY_FIELD", `${id}.name`);
    }
    const aliases = assertStringArray(value.aliases, `${id}.aliases`, true);
    if (
        typeof value.kind !== "string" ||
        !KINDS.has(value.kind as ConformanceKind)
    ) {
        fail("INVALID_ENTRY_KIND", id);
    }
    if (value.provenance !== "pr-owned" && value.provenance !== "external") {
        fail("INVALID_PROVENANCE", id);
    }
    if (
        value.artifactOwnerProfile !== null &&
        (typeof value.artifactOwnerProfile !== "string" ||
            !OWNER_PROFILES.has(
                value.artifactOwnerProfile as CanonicalSourceRoot,
            ))
    ) {
        fail("INVALID_OWNER_PROFILE", id);
    }
    if (
        value.canonicalSourceRoot !== null &&
        (typeof value.canonicalSourceRoot !== "string" ||
            !OWNER_PROFILES.has(
                value.canonicalSourceRoot as CanonicalSourceRoot,
            ))
    ) {
        fail("INVALID_SOURCE_ROOT", id);
    }
    const allowedConsumerProfiles = assertStringArray(
        value.allowedConsumerProfiles,
        `${id}.allowedConsumerProfiles`,
        true,
    );
    if (
        allowedConsumerProfiles.some(
            (profile) => !OWNER_PROFILES.has(profile as CanonicalSourceRoot),
        )
    ) {
        fail("INVALID_CONSUMER_PROFILE", id);
    }
    if (
        typeof value.sourceKind !== "string" ||
        !SOURCE_KINDS.has(value.sourceKind as SourceKind)
    ) {
        fail("INVALID_SOURCE_KIND", id);
    }
    if (
        typeof value.artifactScope !== "string" ||
        !ARTIFACT_SCOPES.has(value.artifactScope as ArtifactScope)
    ) {
        fail("INVALID_ARTIFACT_SCOPE", id);
    }
    if (
        typeof value.addressReusePolicy !== "string" ||
        !ADDRESS_REUSE_POLICIES.has(
            value.addressReusePolicy as AddressReusePolicy,
        )
    ) {
        fail("INVALID_ADDRESS_REUSE_POLICY", id);
    }
    if (
        typeof value.retentionPolicy !== "string" ||
        !RETENTION_POLICIES.has(value.retentionPolicy as RetentionPolicy)
    ) {
        fail("INVALID_RETENTION_POLICY", id);
    }
    if (
        typeof value.reactivationPolicy !== "string" ||
        !REACTIVATION_POLICIES.has(
            value.reactivationPolicy as ReactivationPolicy,
        )
    ) {
        fail("INVALID_REACTIVATION_POLICY", id);
    }
    if (
        typeof value.status !== "string" ||
        !STATUSES.has(value.status as ConformanceStatus)
    ) {
        fail("INVALID_STATUS", id);
    }

    const kind = value.kind as ConformanceKind;
    const provenance = value.provenance as "pr-owned" | "external";
    const artifactOwnerProfile =
        value.artifactOwnerProfile as CanonicalSourceRoot | null;
    const canonicalSourceRoot =
        value.canonicalSourceRoot as CanonicalSourceRoot | null;
    const sourceKind = value.sourceKind as SourceKind;
    const artifactScope = value.artifactScope as ArtifactScope;
    const addressReusePolicy = value.addressReusePolicy as AddressReusePolicy;
    const retentionPolicy = value.retentionPolicy as RetentionPolicy;
    const reactivationPolicy = value.reactivationPolicy as ReactivationPolicy;
    const external = kind === "external-dependency";
    const sourceInline = kind === "source-inline";
    if (
        external !== (provenance === "external") ||
        external !== (artifactScope === "external") ||
        external !== (addressReusePolicy === "external") ||
        external !== (retentionPolicy === "external") ||
        (external &&
            (artifactOwnerProfile !== null || canonicalSourceRoot !== null))
    ) {
        fail("INVALID_EXTERNAL_OWNERSHIP", id);
    }
    if (
        sourceInline !== (artifactScope === "source-inline") ||
        sourceInline !== (retentionPolicy === "source-inline") ||
        (sourceInline &&
            (artifactOwnerProfile !== null ||
                canonicalSourceRoot === null ||
                sourceKind === "not-applicable" ||
                addressReusePolicy !== "not-applicable" ||
                reactivationPolicy !== "not-applicable"))
    ) {
        fail("INVALID_SOURCE_INLINE_OWNERSHIP", id);
    }
    if (
        !external &&
        !sourceInline &&
        (provenance !== "pr-owned" ||
            artifactOwnerProfile === null ||
            canonicalSourceRoot !== artifactOwnerProfile ||
            sourceKind !== "not-applicable" ||
            reactivationPolicy !== "never")
    ) {
        fail("INVALID_ARTIFACT_OWNERSHIP", id);
    }
    if (
        (kind === "root-artifact" &&
            (artifactOwnerProfile !== "layer1" ||
                artifactScope !== "root-set")) ||
        (kind === "creation-only" && artifactScope !== "creation-only") ||
        (kind === "deployable" && artifactScope !== "standalone")
    ) {
        fail("INVALID_KIND_SCOPE", id);
    }

    const normativeRefs = assertStringArray(
        value.normativeRefs,
        `${id}.normativeRefs`,
        false,
    );
    const abiOrEncoding = assertStringArray(
        value.abiOrEncoding,
        `${id}.abiOrEncoding`,
        false,
    );
    const sourcePaths = assertPaths(value.sourcePaths, `${id}.sourcePaths`);
    const testPaths = assertPaths(value.testPaths, `${id}.testPaths`);
    const failureBranches = assertStringArray(
        value.failureBranches,
        `${id}.failureBranches`,
        false,
    );
    const limits = assertStringArray(value.limits, `${id}.limits`, false);
    const reviewed = value.status === "reviewed";
    const reviewedSourceHashes = assertHashMap(
        value.reviewedSourceHashes,
        `${id}.reviewedSourceHashes`,
        sourcePaths,
        reviewed && sourcePaths.length !== 0,
    );
    const reviewedTestHashes = assertHashMap(
        value.reviewedTestHashes,
        `${id}.reviewedTestHashes`,
        testPaths,
        reviewed,
    );
    if (reviewed && testPaths.length === 0) fail("REVIEWED_WITHOUT_TESTS", id);

    return {
        id,
        name: value.name as string,
        aliases,
        kind,
        normativeRefs,
        provenance,
        artifactOwnerProfile,
        canonicalSourceRoot,
        allowedConsumerProfiles:
            allowedConsumerProfiles as CanonicalSourceRoot[],
        sourceKind,
        artifactScope,
        addressReusePolicy,
        retentionPolicy,
        reactivationPolicy,
        abiOrEncoding,
        sourcePaths,
        testPaths,
        failureBranches,
        limits,
        status: value.status as ConformanceStatus,
        reviewedSourceHashes,
        reviewedTestHashes,
    };
}

export function validateConformanceLedger(value: unknown): ConformanceLedger {
    if (!isRecord(value)) fail("INVALID_LEDGER", "root must be an object");
    assertExactFields(value, LEDGER_FIELDS, "UNKNOWN_LEDGER_FIELD", "ledger");
    if (value.schemaVersion !== 1)
        fail("INVALID_SCHEMA_VERSION", `${value.schemaVersion}`);
    if (value.protocolVersion !== "2.27")
        fail("INVALID_PROTOCOL_VERSION", `${value.protocolVersion}`);
    if (
        typeof value.normativeCommit !== "string" ||
        !COMMIT_PATTERN.test(value.normativeCommit) ||
        value.normativeCommit !== "2008937506ece50821440744ff0ee6f73a5485ce"
    ) {
        fail("INVALID_NORMATIVE_COMMIT", `${value.normativeCommit}`);
    }
    if (value.rootArtifactCount !== 18) {
        fail("INVALID_ROOT_ARTIFACT_COUNT", `${value.rootArtifactCount}`);
    }
    if (!Array.isArray(value.entries) || value.entries.length === 0)
        fail("EMPTY_LEDGER", "entries");

    const entries = value.entries.map(validateEntry);
    const ids = entries.map(({ id }) => id);
    if (new Set(ids).size !== ids.length) fail("DUPLICATE_ENTRY_ID", "entries");
    const roots = entries.filter(({ kind }) => kind === "root-artifact");
    if (roots.length !== 0 && roots.length !== value.rootArtifactCount) {
        fail(
            "ROOT_ARTIFACT_SET_MISMATCH",
            `found ${roots.length}, expected ${value.rootArtifactCount}`,
        );
    }
    return {
        schemaVersion: 1,
        protocolVersion: "2.27",
        normativeCommit: "2008937506ece50821440744ff0ee6f73a5485ce",
        rootArtifactCount: 18,
        entries,
    };
}

function walkSolidity(directory: string, protocolRoot: string): string[] {
    if (!fs.existsSync(directory)) return [];
    const result: string[] = [];
    for (const item of fs.readdirSync(directory, { withFileTypes: true })) {
        const absolute = path.join(directory, item.name);
        if (item.isDirectory())
            result.push(...walkSolidity(absolute, protocolRoot));
        if (item.isFile() && item.name.endsWith(".sol")) {
            result.push(
                path.relative(protocolRoot, absolute).split(path.sep).join("/"),
            );
        }
    }
    return result;
}

function sha256File(absolute: string): string {
    return `0x${crypto.createHash("sha256").update(fs.readFileSync(absolute)).digest("hex")}`;
}

export function checkConformanceLedger(
    ledgerPath: string,
    protocolRoot: string,
): ConformanceLedger {
    const ledger = validateConformanceLedger(
        JSON.parse(fs.readFileSync(ledgerPath, "utf8")),
    );
    const sourceOwners = new Map<string, string>();
    for (const entry of ledger.entries) {
        for (const sourcePath of entry.sourcePaths) {
            const previous = sourceOwners.get(sourcePath);
            if (previous !== undefined) {
                fail(
                    "DUPLICATE_SOURCE_OWNER",
                    `${sourcePath}: ${previous},${entry.id}`,
                );
            }
            sourceOwners.set(sourcePath, entry.id);
        }

        if (entry.status === "passing" || entry.status === "reviewed") {
            for (const candidate of [
                ...entry.sourcePaths,
                ...entry.testPaths,
            ]) {
                if (!fs.existsSync(path.join(protocolRoot, candidate))) {
                    fail("PASSING_PATH_MISSING", `${entry.id}: ${candidate}`);
                }
            }
        }
        if (entry.status === "reviewed") {
            for (const [candidate, expected] of Object.entries(
                entry.reviewedSourceHashes,
            )) {
                if (
                    sha256File(path.join(protocolRoot, candidate)) !== expected
                ) {
                    fail("REVIEWED_HASH_DRIFT", `${entry.id}: ${candidate}`);
                }
            }
            for (const [candidate, expected] of Object.entries(
                entry.reviewedTestHashes,
            )) {
                if (
                    sha256File(path.join(protocolRoot, candidate)) !== expected
                ) {
                    fail("REVIEWED_HASH_DRIFT", `${entry.id}: ${candidate}`);
                }
            }
        }
    }

    const actualSources = [
        ...walkSolidity(
            path.join(protocolRoot, "contracts/shared/slotchain"),
            protocolRoot,
        ),
        ...walkSolidity(
            path.join(protocolRoot, "contracts/layer1/slotchain"),
            protocolRoot,
        ),
        ...walkSolidity(
            path.join(protocolRoot, "contracts/layer2/slotchain"),
            protocolRoot,
        ),
    ];
    for (const sourcePath of actualSources) {
        if (!sourceOwners.has(sourcePath))
            fail("UNCLASSIFIED_SOURCE", sourcePath);
    }
    for (const sourcePath of sourceOwners.keys()) {
        if (
            sourcePath.startsWith("contracts/") &&
            sourcePath.includes("/slotchain/") &&
            !actualSources.includes(sourcePath) &&
            ledger.entries.find(
                (entry) => entry.id === sourceOwners.get(sourcePath),
            )?.status !== "missing"
        ) {
            fail("CLASSIFIED_SOURCE_MISSING", sourcePath);
        }
    }
    return ledger;
}

function main(): void {
    const protocolRoot = path.resolve(__dirname, "../..");
    const ledgerPath = path.join(
        protocolRoot,
        "utils/slotchain/conformance-ledger.v2.27.json",
    );
    const ledger = checkConformanceLedger(ledgerPath, protocolRoot);
    const counts = Object.fromEntries(
        [...STATUSES].map((status) => [
            status,
            ledger.entries.filter((entry) => entry.status === status).length,
        ]),
    );
    process.stdout.write(
        `verified ${ledger.entries.length} v2.27 conformance rows ${JSON.stringify(counts)}\n`,
    );
}

if (require.main === module) {
    try {
        main();
    } catch (error) {
        process.stderr.write(`${(error as Error).message}\n`);
        process.exitCode = 1;
    }
}
