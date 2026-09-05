import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import {
    checkConformanceLedger,
    ConformanceError,
    ConformanceLedger,
    validateConformanceLedger,
} from "../../utils/slotchain/checkConformanceLedger";

function entry(
    overrides: Partial<ConformanceLedger["entries"][number]> = {},
): ConformanceLedger["entries"][number] {
    return {
        id: "shared.test-interface",
        name: "TestInterface",
        aliases: [],
        kind: "source-inline",
        normativeRefs: ["main.tex:11180-12520"],
        provenance: "pr-owned",
        artifactOwnerProfile: null,
        canonicalSourceRoot: "shared",
        allowedConsumerProfiles: ["shared", "layer1", "layer2"],
        sourceKind: "interface",
        artifactScope: "source-inline",
        addressReusePolicy: "not-applicable",
        retentionPolicy: "source-inline",
        reactivationPolicy: "not-applicable",
        abiOrEncoding: ["componentConfigHashV2():bytes32"],
        sourcePaths: ["contracts/shared/slotchain/iface/ITestInterface.sol"],
        testPaths: ["test/shared/slotchain/ITestInterface.t.sol"],
        failureBranches: ["dirty-padding"],
        limits: ["returnBytes=32"],
        status: "missing",
        reviewedSourceHashes: {},
        reviewedTestHashes: {},
        ...overrides,
    };
}

function ledger(
    entries: ConformanceLedger["entries"] = [entry()],
): ConformanceLedger {
    return {
        schemaVersion: 1,
        protocolVersion: "2.27",
        normativeCommit: "cd9df2ed2ad5000427f74efcefb1bfc31a689e0c",
        rootArtifactCount: 18,
        entries,
    };
}

function expectCode(candidate: unknown, code: string): void {
    assert.throws(
        () => validateConformanceLedger(candidate),
        (error: unknown) =>
            error instanceof ConformanceError && error.code === code,
    );
}

assert.doesNotThrow(() => validateConformanceLedger(ledger()));

expectCode({ ...ledger(), extra: true }, "UNKNOWN_LEDGER_FIELD");
expectCode({ ...ledger(), schemaVersion: 2 }, "INVALID_SCHEMA_VERSION");
expectCode(
    { ...ledger(), protocolVersion: "2.25" },
    "INVALID_PROTOCOL_VERSION",
);
expectCode(
    { ...ledger(), normativeCommit: "200893750" },
    "INVALID_NORMATIVE_COMMIT",
);
expectCode(
    { ...ledger(), rootArtifactCount: 17 },
    "INVALID_ROOT_ARTIFACT_COUNT",
);
expectCode(ledger([]), "EMPTY_LEDGER");
expectCode(ledger([entry(), entry()]), "DUPLICATE_ENTRY_ID");
expectCode(ledger([entry({ id: "Not Canonical" })]), "INVALID_ENTRY_ID");
expectCode(ledger([entry({ kind: "unknown" as never })]), "INVALID_ENTRY_KIND");
expectCode(
    ledger([entry({ artifactOwnerProfile: "default" as never })]),
    "INVALID_OWNER_PROFILE",
);
expectCode(
    ledger([entry({ addressReusePolicy: "proxy" as never })]),
    "INVALID_ADDRESS_REUSE_POLICY",
);
expectCode(ledger([entry({ status: "complete" as never })]), "INVALID_STATUS");
expectCode(ledger([entry({ normativeRefs: [] })]), "EMPTY_ENTRY_FIELD");
expectCode(ledger([entry({ abiOrEncoding: [] })]), "EMPTY_ENTRY_FIELD");
expectCode(ledger([entry({ failureBranches: [] })]), "EMPTY_ENTRY_FIELD");
expectCode(ledger([entry({ limits: [] })]), "EMPTY_ENTRY_FIELD");
expectCode(
    ledger([
        entry({
            sourcePaths: ["/absolute/ITestInterface.sol"],
        }),
    ]),
    "INVALID_PATH",
);
expectCode(
    ledger([
        entry({
            sourcePaths: ["contracts/shared/slotchain/../Escape.sol"],
        }),
    ]),
    "NON_CANONICAL_PATH",
);
expectCode(
    ledger([
        entry({
            sourcePaths: [
                "contracts/shared/slotchain/iface/ITestInterface.sol",
                "contracts/shared/slotchain/iface/ITestInterface.sol",
            ],
        }),
    ]),
    "DUPLICATE_PATH",
);
expectCode(
    ledger([
        entry({
            kind: "root-artifact",
        }),
    ]),
    "INVALID_SOURCE_INLINE_OWNERSHIP",
);
expectCode(
    ledger([
        entry({
            provenance: "external",
        }),
    ]),
    "INVALID_EXTERNAL_OWNERSHIP",
);
expectCode(
    ledger([
        entry({
            status: "reviewed",
            reviewedSourceHashes: {},
            reviewedTestHashes: {},
        }),
    ]),
    "REVIEWED_WITHOUT_HASHES",
);
expectCode(
    ledger([
        entry({
            status: "passing",
            reviewedSourceHashes: {
                "contracts/shared/slotchain/iface/ITestInterface.sol":
                    "0x1111111111111111111111111111111111111111111111111111111111111111",
            },
        }),
    ]),
    "HASHES_ON_UNREVIEWED_ENTRY",
);
expectCode(
    ledger([
        entry({
            status: "reviewed",
            reviewedSourceHashes: {
                "contracts/shared/slotchain/iface/ITestInterface.sol": "0x12",
            },
            reviewedTestHashes: {
                "test/shared/slotchain/ITestInterface.t.sol":
                    "0x2222222222222222222222222222222222222222222222222222222222222222",
            },
        }),
    ]),
    "INVALID_REVIEW_HASH",
);

const roots = Array.from({ length: 18 }, (_, index) =>
    entry({
        id: `root.artifact-${index + 1}`,
        name: `RootArtifact${index + 1}`,
        kind: "root-artifact",
        artifactOwnerProfile: "layer1",
        canonicalSourceRoot: "layer1",
        allowedConsumerProfiles: ["layer1"],
        sourceKind: "not-applicable",
        artifactScope: "root-set",
        addressReusePolicy:
            index < 12 ? "protocol-lifetime" : "fresh-per-release",
        retentionPolicy: index < 12 ? "permanent" : "historical",
        reactivationPolicy: "never",
        sourcePaths: [
            `contracts/layer1/slotchain/root/RootArtifact${index + 1}.sol`,
        ],
        testPaths: [
            `test/layer1/slotchain/root/RootArtifact${index + 1}.t.sol`,
        ],
    }),
);
assert.doesNotThrow(() => validateConformanceLedger(ledger(roots)));
expectCode(ledger(roots.slice(0, 17)), "ROOT_ARTIFACT_SET_MISMATCH");
expectCode(
    ledger([
        ...roots,
        entry({
            id: "root.artifact-19",
            kind: "root-artifact",
            artifactOwnerProfile: "layer1",
            canonicalSourceRoot: "layer1",
            allowedConsumerProfiles: ["layer1"],
            sourceKind: "not-applicable",
            artifactScope: "root-set",
            addressReusePolicy: "protocol-lifetime",
            retentionPolicy: "permanent",
            reactivationPolicy: "never",
        }),
    ]),
    "ROOT_ARTIFACT_SET_MISMATCH",
);

const temporaryRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), "slotchain-conformance-ledger-"),
);
try {
    const sourcePath = "contracts/shared/slotchain/iface/ITestInterface.sol";
    const testPath = "test/shared/slotchain/ITestInterface.t.sol";
    fs.mkdirSync(path.join(temporaryRoot, path.dirname(sourcePath)), {
        recursive: true,
    });
    fs.mkdirSync(path.join(temporaryRoot, path.dirname(testPath)), {
        recursive: true,
    });
    fs.writeFileSync(
        path.join(temporaryRoot, sourcePath),
        "interface ITestInterface {}\n",
    );
    fs.writeFileSync(
        path.join(temporaryRoot, testPath),
        "contract ITestInterfaceTest {}\n",
    );
    const ledgerPath = path.join(temporaryRoot, "ledger.json");
    const passing = ledger([entry({ status: "passing" })]);
    fs.writeFileSync(ledgerPath, JSON.stringify(passing));
    assert.doesNotThrow(() =>
        checkConformanceLedger(ledgerPath, temporaryRoot),
    );

    const unclassified = "contracts/layer1/slotchain/Unclassified.sol";
    fs.mkdirSync(path.join(temporaryRoot, path.dirname(unclassified)), {
        recursive: true,
    });
    fs.writeFileSync(
        path.join(temporaryRoot, unclassified),
        "contract Unclassified {}\n",
    );
    assert.throws(
        () => checkConformanceLedger(ledgerPath, temporaryRoot),
        (error: unknown) =>
            error instanceof ConformanceError &&
            error.code === "UNCLASSIFIED_SOURCE",
    );
    fs.unlinkSync(path.join(temporaryRoot, unclassified));

    const sourceHash = `0x${crypto
        .createHash("sha256")
        .update(fs.readFileSync(path.join(temporaryRoot, sourcePath)))
        .digest("hex")}`;
    const testHash = `0x${crypto
        .createHash("sha256")
        .update(fs.readFileSync(path.join(temporaryRoot, testPath)))
        .digest("hex")}`;
    const reviewed = ledger([
        entry({
            status: "reviewed",
            reviewedSourceHashes: { [sourcePath]: sourceHash },
            reviewedTestHashes: { [testPath]: testHash },
        }),
    ]);
    fs.writeFileSync(ledgerPath, JSON.stringify(reviewed));
    assert.doesNotThrow(() =>
        checkConformanceLedger(ledgerPath, temporaryRoot),
    );
    fs.appendFileSync(path.join(temporaryRoot, sourcePath), "// drift\n");
    assert.throws(
        () => checkConformanceLedger(ledgerPath, temporaryRoot),
        (error: unknown) =>
            error instanceof ConformanceError &&
            error.code === "REVIEWED_HASH_DRIFT",
    );
} finally {
    fs.rmSync(temporaryRoot, { recursive: true });
}

process.stdout.write("conformance-ledger validation tests passed\n");
