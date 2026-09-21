import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import {
    checkConformanceLedger,
    ConformanceError,
    ConformanceLedger,
    isUnpinnedNormativeCommit,
    LEDGER_FILE_NAME,
    UNPINNED_NORMATIVE_COMMIT,
    validateConformanceLedger,
} from "../../utils/slotchain/checkConformanceLedger";

const PINNED_COMMIT = "4cc7bc0e3cd96ea4cf0af72aa1a9e6e03bec8e52";

function entry(
    overrides: Partial<ConformanceLedger["entries"][number]> = {},
): ConformanceLedger["entries"][number] {
    return {
        id: "shared.test-interface",
        name: "TestInterface",
        aliases: [],
        kind: "source-inline",
        normativeRefs: ["main.tex:sec:implementation"],
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

function deployable(
    overrides: Partial<ConformanceLedger["entries"][number]> = {},
): ConformanceLedger["entries"][number] {
    return entry({
        id: "deployable.l1.test-proxy",
        name: "TestProxy",
        kind: "deployable",
        artifactOwnerProfile: "layer1",
        canonicalSourceRoot: "layer1",
        allowedConsumerProfiles: ["layer1"],
        sourceKind: "not-applicable",
        artifactScope: "standalone",
        addressReusePolicy: "owner-upgradeable",
        retentionPolicy: "permanent",
        reactivationPolicy: "never",
        sourcePaths: ["contracts/layer1/slotchain/impl/TestProxy.sol"],
        testPaths: ["test/layer1/slotchain/TestProxy.t.sol"],
        ...overrides,
    });
}

function external(
    overrides: Partial<ConformanceLedger["entries"][number]> = {},
): ConformanceLedger["entries"][number] {
    return entry({
        id: "dependency.test-dependency",
        name: "test-dependency",
        kind: "external-dependency",
        provenance: "external",
        artifactOwnerProfile: null,
        canonicalSourceRoot: null,
        allowedConsumerProfiles: [],
        sourceKind: "not-applicable",
        artifactScope: "external",
        addressReusePolicy: "external",
        retentionPolicy: "external",
        reactivationPolicy: "not-applicable",
        sourcePaths: [],
        testPaths: ["test/slotchain/dependencies/test-dependency.t.sol"],
        ...overrides,
    });
}

function ledger(
    entries: ConformanceLedger["entries"] = [entry()],
    normativeCommit: string = UNPINNED_NORMATIVE_COMMIT,
): ConformanceLedger {
    return {
        schemaVersion: 2,
        protocolVersion: "3.0",
        normativeCommit,
        entries,
    };
}

function expectCode(candidate: unknown, code: string): void {
    assert.throws(
        () => validateConformanceLedger(candidate),
        (error: unknown) =>
            error instanceof ConformanceError && error.code === code,
        code,
    );
}

assert.equal(LEDGER_FILE_NAME, "conformance-ledger.v3.0.json");
assert.doesNotThrow(() => validateConformanceLedger(ledger()));
assert.doesNotThrow(() => validateConformanceLedger(ledger([deployable()])));
assert.doesNotThrow(() => validateConformanceLedger(ledger([external()])));

// The normative commit is read from the ledger, never hardcoded: any 40-hex
// value is accepted and the all-zero placeholder is recognised as unpinned.
assert.equal(
    isUnpinnedNormativeCommit(validateConformanceLedger(ledger())),
    true,
);
assert.equal(
    isUnpinnedNormativeCommit(
        validateConformanceLedger(ledger([entry()], PINNED_COMMIT)),
    ),
    false,
);
assert.equal(
    validateConformanceLedger(ledger([entry()], PINNED_COMMIT)).normativeCommit,
    PINNED_COMMIT,
);
expectCode(ledger([entry()], "200893750"), "INVALID_NORMATIVE_COMMIT");
expectCode(
    ledger([entry()], PINNED_COMMIT.toUpperCase()),
    "INVALID_NORMATIVE_COMMIT",
);
expectCode(ledger([entry()], `${PINNED_COMMIT}0`), "INVALID_NORMATIVE_COMMIT");

expectCode({ ...ledger(), extra: true }, "UNKNOWN_LEDGER_FIELD");
expectCode({ ...ledger(), rootArtifactCount: 21 }, "UNKNOWN_LEDGER_FIELD");
expectCode({ ...ledger(), schemaVersion: 1 }, "INVALID_SCHEMA_VERSION");
expectCode(
    { ...ledger(), protocolVersion: "2.28" },
    "INVALID_PROTOCOL_VERSION",
);
expectCode(ledger([]), "EMPTY_LEDGER");
expectCode(ledger([entry(), entry()]), "DUPLICATE_ENTRY_ID");
expectCode(ledger([entry({ id: "Not Canonical" })]), "INVALID_ENTRY_ID");
expectCode(ledger([entry({ kind: "unknown" as never })]), "INVALID_ENTRY_KIND");
expectCode(
    ledger([entry({ kind: "root-artifact" as never })]),
    "INVALID_ENTRY_KIND",
);
expectCode(
    ledger([entry({ kind: "creation-only" as never })]),
    "INVALID_ENTRY_KIND",
);
expectCode(
    ledger([entry({ artifactOwnerProfile: "default" as never })]),
    "INVALID_OWNER_PROFILE",
);
expectCode(
    ledger([entry({ addressReusePolicy: "proxy" as never })]),
    "INVALID_ADDRESS_REUSE_POLICY",
);
for (const removed of [
    "protocol-lifetime",
    "fresh-per-release",
    "campaign-role-helper",
    "descriptor-selected",
    "legacy-fixed",
]) {
    expectCode(
        ledger([deployable({ addressReusePolicy: removed as never })]),
        "INVALID_ADDRESS_REUSE_POLICY",
    );
}
expectCode(
    ledger([deployable({ retentionPolicy: "ephemeral-inert" as never })]),
    "INVALID_RETENTION_POLICY",
);
expectCode(
    ledger([deployable({ artifactScope: "root-set" as never })]),
    "INVALID_ARTIFACT_SCOPE",
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
    ledger([entry({ kind: "deployable" })]),
    "INVALID_SOURCE_INLINE_OWNERSHIP",
);
expectCode(
    ledger([entry({ provenance: "external" })]),
    "INVALID_EXTERNAL_OWNERSHIP",
);
expectCode(
    ledger([external({ sourcePaths: ["contracts/Somewhere.sol"] })]),
    "INVALID_SOURCE_PATHS",
);
expectCode(ledger([deployable({ sourcePaths: [] })]), "INVALID_SOURCE_PATHS");

// Deployable semantics: proxies are owner-upgradeable and permanent, plain
// helpers are consumer-pinned and historical; nothing else is a deployable.
assert.doesNotThrow(() =>
    validateConformanceLedger(
        ledger([
            deployable({
                addressReusePolicy: "consumer-pinned",
                retentionPolicy: "historical",
            }),
        ]),
    ),
);
expectCode(
    ledger([deployable({ retentionPolicy: "historical" })]),
    "INVALID_DEPLOYABLE_SEMANTICS",
);
expectCode(
    ledger([
        deployable({
            addressReusePolicy: "consumer-pinned",
            retentionPolicy: "permanent",
        }),
    ]),
    "INVALID_DEPLOYABLE_SEMANTICS",
);
expectCode(
    ledger([deployable({ addressReusePolicy: "not-applicable" })]),
    "INVALID_DEPLOYABLE_SEMANTICS",
);
expectCode(
    ledger([deployable({ artifactScope: "source-inline" })]),
    "INVALID_SOURCE_INLINE_OWNERSHIP",
);
expectCode(
    ledger([deployable({ reactivationPolicy: "not-applicable" })]),
    "INVALID_ARTIFACT_OWNERSHIP",
);

expectCode(
    ledger([entry({ status: "passing", testPaths: [] })]),
    "PASSING_WITHOUT_PATHS",
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

const temporaryRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), "slotchain-conformance-ledger-"),
);
try {
    const sourcePath = "contracts/shared/slotchain/iface/ITestInterface.sol";
    const testPath = "test/shared/slotchain/ITestInterface.t.sol";
    const ledgerPath = path.join(temporaryRoot, "ledger.json");
    const expectCheckCode = (code: string): void => {
        assert.throws(
            () => checkConformanceLedger(ledgerPath, temporaryRoot),
            (error: unknown) =>
                error instanceof ConformanceError && error.code === code,
            code,
        );
    };

    // A missing row must not point at files that exist.
    fs.writeFileSync(ledgerPath, JSON.stringify(ledger([entry()])));
    assert.doesNotThrow(() =>
        checkConformanceLedger(ledgerPath, temporaryRoot),
    );
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
    expectCheckCode("MISSING_PATH_PRESENT");

    const passing = ledger([entry({ status: "passing" })]);
    fs.writeFileSync(ledgerPath, JSON.stringify(passing));
    assert.doesNotThrow(() =>
        checkConformanceLedger(ledgerPath, temporaryRoot),
    );

    // A red row keeps pointing at existing code.
    fs.writeFileSync(
        ledgerPath,
        JSON.stringify(
            ledger([
                entry({
                    status: "red",
                    sourcePaths: ["contracts/shared/slotchain/iface/IGone.sol"],
                }),
                entry({
                    id: "shared.present",
                    status: "red",
                }),
            ]),
        ),
    );
    expectCheckCode("RED_SOURCE_MISSING");

    fs.writeFileSync(
        ledgerPath,
        JSON.stringify(
            ledger([
                entry({
                    status: "passing",
                    testPaths: ["test/shared/slotchain/Absent.t.sol"],
                }),
            ]),
        ),
    );
    expectCheckCode("PASSING_PATH_MISSING");

    fs.writeFileSync(ledgerPath, JSON.stringify(passing));
    const unclassified = "contracts/layer1/slotchain/Unclassified.sol";
    fs.mkdirSync(path.join(temporaryRoot, path.dirname(unclassified)), {
        recursive: true,
    });
    fs.writeFileSync(
        path.join(temporaryRoot, unclassified),
        "contract Unclassified {}\n",
    );
    expectCheckCode("UNCLASSIFIED_SOURCE");
    fs.unlinkSync(path.join(temporaryRoot, unclassified));

    fs.writeFileSync(
        ledgerPath,
        JSON.stringify(
            ledger([
                entry({ status: "passing" }),
                entry({
                    id: "shared.duplicate-owner",
                    status: "missing",
                }),
            ]),
        ),
    );
    expectCheckCode("DUPLICATE_SOURCE_OWNER");

    const sourceHash = `0x${crypto
        .createHash("sha256")
        .update(fs.readFileSync(path.join(temporaryRoot, sourcePath)))
        .digest("hex")}`;
    const testHash = `0x${crypto
        .createHash("sha256")
        .update(fs.readFileSync(path.join(temporaryRoot, testPath)))
        .digest("hex")}`;
    const reviewed = ledger(
        [
            entry({
                status: "reviewed",
                reviewedSourceHashes: { [sourcePath]: sourceHash },
                reviewedTestHashes: { [testPath]: testHash },
            }),
        ],
        PINNED_COMMIT,
    );
    fs.writeFileSync(ledgerPath, JSON.stringify(reviewed));
    assert.doesNotThrow(() =>
        checkConformanceLedger(ledgerPath, temporaryRoot),
    );
    fs.appendFileSync(path.join(temporaryRoot, sourcePath), "// drift\n");
    expectCheckCode("REVIEWED_HASH_DRIFT");
} finally {
    fs.rmSync(temporaryRoot, { recursive: true });
}

process.stdout.write("conformance-ledger validation tests passed\n");
