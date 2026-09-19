import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

import { ethers } from "ethers";

const EXPECTED_LAYOUT_HASH =
    "0x5b676bdd8dd5b37f6353a4b46a59d7d24f6b0cc66b28cf1222b3deafe36402bd";
const EXPECTED_LAYOUT_BYTES = 9_549;
const EXPECTED_STORAGE_ENTRIES = 53;
const EXPECTED_TYPE_NODES = 23;

const TARGETS = [
    "contracts/layer1/slotchain/impl/BuilderRegistryStorageV1.sol:BuilderRegistryStorageV1",
    "contracts/layer1/slotchain/impl/BuilderRegistry.sol:BuilderRegistryLogicV1",
    "contracts/layer1/slotchain/impl/BuilderRegistry.sol:BuilderRegistry",
    "contracts/layer1/slotchain/impl/BuilderRegistrySeatLifecycleFacetV1.sol:BuilderRegistrySeatLifecycleFacetV1",
    "contracts/layer1/slotchain/impl/BuilderRegistryLeaseLifecycleFacetV1.sol:BuilderRegistryLeaseLifecycleFacetV1",
] as const;

type JsonScalar = string | number | boolean | null;
export type JsonValue = JsonScalar | JsonValue[] | { [key: string]: JsonValue };

interface StorageEntry {
    [key: string]: JsonValue;
    label: string;
    slot: string;
    offset: number;
    type: string;
}

interface StorageLayout {
    storage: StorageEntry[];
    types: Record<string, JsonValue>;
}

const USER_DEFINED_TYPE =
    /(t_(?:struct|enum|contract|userDefinedValueType)\([^)]*\))\d+(?=_storage|[,)]|$)/g;

function fail(message: string): never {
    throw new Error(`BUILDER_REGISTRY_LAYOUT: ${message}`);
}

export function canonicalTypeIdentifier(value: string): string {
    return value.replace(USER_DEFINED_TYPE, "$1");
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function normalizeValue(value: unknown): JsonValue {
    if (
        value === null ||
        typeof value === "number" ||
        typeof value === "boolean"
    ) {
        return value;
    }
    if (typeof value === "string") return canonicalTypeIdentifier(value);
    if (Array.isArray(value)) return value.map(normalizeValue);
    if (!isRecord(value)) fail("unsupported JSON value");

    const normalized: Record<string, JsonValue> = {};
    for (const [rawKey, child] of Object.entries(value)) {
        if (rawKey === "astId" || rawKey === "contract") continue;
        const key = canonicalTypeIdentifier(rawKey);
        if (Object.prototype.hasOwnProperty.call(normalized, key)) {
            fail(`canonical key collision at ${key}`);
        }
        normalized[key] = normalizeValue(child);
    }
    return normalized;
}

function requireStorageEntry(value: unknown): StorageEntry {
    if (
        !isRecord(value) ||
        typeof value.label !== "string" ||
        typeof value.slot !== "string" ||
        typeof value.offset !== "number" ||
        typeof value.type !== "string"
    ) {
        fail("malformed storage entry");
    }
    return {
        label: value.label,
        slot: value.slot,
        offset: value.offset,
        type: canonicalTypeIdentifier(value.type),
    };
}

function typeReferences(
    value: JsonValue,
    known: Set<string>,
    output: Set<string>,
): void {
    if (typeof value === "string") {
        if (known.has(value)) output.add(value);
        return;
    }
    if (Array.isArray(value)) {
        for (const child of value) typeReferences(child, known, output);
        return;
    }
    if (value !== null && typeof value === "object") {
        for (const child of Object.values(value))
            typeReferences(child, known, output);
    }
}

function sortObjects(value: JsonValue): JsonValue {
    if (Array.isArray(value)) return value.map(sortObjects);
    if (value === null || typeof value !== "object") return value;
    const sorted: Record<string, JsonValue> = {};
    for (const key of Object.keys(value).sort())
        sorted[key] = sortObjects(value[key]);
    return sorted;
}

export function normalizeStorageLayout(value: unknown): StorageLayout {
    if (
        !isRecord(value) ||
        !Array.isArray(value.storage) ||
        !isRecord(value.types)
    ) {
        fail("expected storage and types objects");
    }
    const storage = value.storage.map(requireStorageEntry);
    const normalizedTypes = normalizeValue(value.types);
    if (!isRecord(normalizedTypes)) fail("malformed normalized types graph");
    const typeMap = normalizedTypes as Record<string, JsonValue>;
    const known = new Set(Object.keys(typeMap));
    const reachable = new Set<string>();
    const pending = storage.map((entry) => entry.type);
    while (pending.length !== 0) {
        const type = pending.pop()!;
        if (reachable.has(type)) continue;
        const node = typeMap[type];
        if (node === undefined) fail(`missing referenced type ${type}`);
        reachable.add(type);
        const references = new Set<string>();
        typeReferences(node, known, references);
        for (const reference of references) {
            if (!reachable.has(reference)) pending.push(reference);
        }
    }
    const types: Record<string, JsonValue> = {};
    for (const type of reachable) types[type] = typeMap[type];
    return sortObjects({ storage, types }) as unknown as StorageLayout;
}

export function encodeStorageLayout(value: unknown): string {
    return JSON.stringify(normalizeStorageLayout(value));
}

function assertCriticalSlots(layout: StorageLayout): void {
    const byLabel = new Map(
        layout.storage.map((entry) => [entry.label, entry]),
    );
    const expected = new Map<string, [string, number]>([
        ["_operationLock", ["5", 20]],
        ["_settlementChainId", ["6", 0]],
        ["_active", ["39", 0]],
        ["_liabilities", ["423", 0]],
        ["_nextRegistrationIndex", ["6861", 0]],
        ["_registryRoot", ["6864", 0]],
        ["_admissionRoot", ["6865", 0]],
        ["_tokenLock", ["6869", 0]],
    ]);
    for (const [label, [slot, offset]] of expected) {
        const entry = byLabel.get(label);
        if (entry?.slot !== slot || entry.offset !== offset) {
            fail(`${label} expected slot ${slot} offset ${offset}`);
        }
    }
}

function inspectLayout(
    protocolRoot: string,
    target: string,
    outputPath: string,
    cachePath: string,
): unknown {
    const output = execFileSync(
        "forge",
        [
            "inspect",
            target,
            "storage-layout",
            "--json",
            "--out",
            outputPath,
            "--cache-path",
            cachePath,
        ],
        {
            cwd: protocolRoot,
            encoding: "utf8",
            env: { ...process.env, FOUNDRY_PROFILE: "layer1", RUST_LOG: "off" },
            maxBuffer: 16 * 1024 * 1024,
        },
    );
    try {
        return JSON.parse(output);
    } catch {
        return fail(`${target} emitted non-JSON layout output`);
    }
}

export function checkBuilderRegistryLayouts(protocolRoot: string): void {
    const buildRoot = mkdtempSync(
        path.join(tmpdir(), "builder-registry-layout-"),
    );
    try {
        let expectedPreimage: string | undefined;
        for (const target of TARGETS) {
            const raw = inspectLayout(
                protocolRoot,
                target,
                path.join(buildRoot, "out"),
                path.join(buildRoot, "cache"),
            );
            const layout = normalizeStorageLayout(raw);
            const preimage = JSON.stringify(layout);
            const bytes = Buffer.byteLength(preimage, "utf8");
            const hash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes(preimage),
            );
            if (layout.storage.length !== EXPECTED_STORAGE_ENTRIES) {
                fail(`${target} has ${layout.storage.length} storage entries`);
            }
            if (Object.keys(layout.types).length !== EXPECTED_TYPE_NODES) {
                fail(
                    `${target} has ${Object.keys(layout.types).length} type nodes`,
                );
            }
            if (
                bytes !== EXPECTED_LAYOUT_BYTES ||
                hash !== EXPECTED_LAYOUT_HASH
            ) {
                fail(`${target} produced ${bytes} bytes / ${hash}`);
            }
            assertCriticalSlots(layout);
            if (
                expectedPreimage !== undefined &&
                preimage !== expectedPreimage
            ) {
                fail(`${target} differs from the common storage schema`);
            }
            expectedPreimage = preimage;
        }
    } finally {
        rmSync(buildRoot, { recursive: true, force: true });
    }
    console.log(
        `builder registry storage layouts: PASS (${EXPECTED_STORAGE_ENTRIES} entries, ` +
            `${EXPECTED_LAYOUT_BYTES} bytes, ${EXPECTED_LAYOUT_HASH})`,
    );
}

if (require.main === module) {
    checkBuilderRegistryLayouts(path.resolve(__dirname, "../.."));
}
