import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import {
    renderSolidity,
    TypedVector,
    validateTypedVectorJson,
} from "./generateGoldenVectors";

const protocolRoot = path.resolve(__dirname, "../..");
const jsonPath = path.join(
    protocolRoot,
    "test/shared/slotchain/vectors/slot-chain-commitments.json",
);
const canonicalJson = fs.readFileSync(jsonPath, "utf8");
const vectors = validateTypedVectorJson(
    JSON.stringify(JSON.parse(canonicalJson) as TypedVector[]),
);

assert.equal(vectors.length, 654);
assert.equal(vectors.filter((vector) => vector.kind === "hex").length, 547);
assert.equal(vectors.filter((vector) => vector.kind === "uint").length, 107);

const solidity = renderSolidity(vectors);
assert.match(solidity, /uint256 internal constant GOLDEN_VECTOR_COUNT = 654;/);
assert.match(solidity, /bytes32 internal constant CANDIDATE_COMMITMENT =/);
assert.match(solidity, /bytes internal constant V11_BRIDGE_DESCRIPTOR =/);

function encoded(copy: TypedVector[]): string {
    return `${JSON.stringify(copy)}\n`;
}

assert.throws(
    () => validateTypedVectorJson(JSON.stringify(vectors.slice(1))),
    /expected 654/,
);

const duplicate = structuredClone(vectors);
duplicate[1].name = duplicate[0].name;
assert.throws(
    () => validateTypedVectorJson(encoded(duplicate)),
    /duplicate vector name/,
);

const unordered = structuredClone(vectors);
[unordered[0], unordered[1]] = [unordered[1], unordered[0]];
assert.throws(
    () => validateTypedVectorJson(encoded(unordered)),
    /strict deterministic order/,
);

const unexpectedKind = structuredClone(vectors) as unknown as Array<{
    kind: string;
    name: string;
    value: string;
}>;
unexpectedKind[0].kind = "bytes";
assert.throws(
    () => validateTypedVectorJson(`${JSON.stringify(unexpectedKind)}\n`),
    /unsupported kind/,
);

const badHex = structuredClone(vectors);
const hexIndex = badHex.findIndex((vector) => vector.kind === "hex");
badHex[hexIndex].value = "AA";
assert.throws(
    () => validateTypedVectorJson(encoded(badHex)),
    /canonical lowercase/,
);

const badUint = structuredClone(vectors);
const uintIndex = badUint.findIndex((vector) => vector.kind === "uint");
badUint[uintIndex].value = "01";
assert.throws(
    () => validateTypedVectorJson(encoded(badUint)),
    /canonical unsigned decimal/,
);

const maxUint256 = structuredClone(vectors);
maxUint256[uintIndex].value =
    "115792089237316195423570985008687907853269984665640564039457584007913129639935";
assert.doesNotThrow(() => validateTypedVectorJson(encoded(maxUint256)));

const overflowingUint256 = structuredClone(vectors);
overflowingUint256[uintIndex].value =
    "115792089237316195423570985008687907853269984665640564039457584007913129639936";
assert.throws(
    () => validateTypedVectorJson(encoded(overflowingUint256)),
    /exceeds uint256/,
);

const duplicateObjectKey = JSON.stringify(vectors).replace(
    '{"kind":"hex",',
    '{"kind":"hex","kind":"hex",',
);
assert.throws(
    () => validateTypedVectorJson(duplicateObjectKey),
    /not canonical JSON/,
);

const extraObjectKey = JSON.parse(canonicalJson) as Array<
    Record<string, string>
>;
extraObjectKey[0].extra = "unexpected";
assert.throws(
    () => validateTypedVectorJson(`${JSON.stringify(extraObjectKey)}\n`),
    /exactly kind, name, value/,
);

const round2PrimitiveAllowlist = [
    "hashEip712Domain",
    "hashSlotChainBlock",
    "hashSlotChainDigest",
    "hashCanonicalCore",
    "hashBaseCanonical",
    "hashNormalContext",
    "hashMigrationData",
    "hashCandidate",
    "hashWinningData",
    "hashScheduleList",
    "hashSessionList",
    "hashExecutionOutputs",
    "hashSettlementStatement",
    "hashRewardReceipt",
    "hashRegistryLeaf",
    "hashAdmissionLeaf",
    "hashTrancheLeaf",
    "hashRankedEntry",
    "hashRegistryNode",
    "hashAdmissionNode",
    "hashRankedEntryNode",
    "hashTrancheNode",
    "encodeKind0Descriptor",
    "encodeKind1Descriptor",
    "hashForcedUserLeaf",
    "hashForcedBridgeLeaf",
    "hashForcedDescriptorList",
    "hashForcedEmptyLeaf",
    "hashForcedNode",
    "hashForcedRoot",
    "hashSessionId",
    "hashBody",
    "hashBodyChunk",
    "hashDataLeaf",
    "hashDataNode",
    "hashDataBag",
    "hashManifestEmptyLeaf",
    "hashManifestLeaf",
    "hashManifestNode",
    "hashManifestRoot",
    "hashDispositions",
    "hashRecoveryId",
    "hashSourceContext",
    "hashDestinationContext",
    "hashSourceDomain",
    "hashDestinationDomain",
    "hashBridgeCreditId",
    "hashBridgeCreditResult",
    "hashBridgeEscrowId",
    "hashInboxCreditSlot",
    "hashTerminalLeaf",
    "hashTerminalEmptyLeaf",
    "hashTerminalNode",
    "hashTerminalRoot",
    "hashLiquiditySettlement",
] as const;
const encodingSource = fs.readFileSync(
    path.join(
        protocolRoot,
        "contracts/shared/slotchain/libs/LibSlotChainEncoding.sol",
    ),
    "utf8",
);
const implementedRound2Primitives = Array.from(
    encodingSource.matchAll(/\bfunction\s+(\w+)\s*\(/g),
    (match) => match[1],
).filter((name) => !name.startsWith("_"));
assert.deepEqual(implementedRound2Primitives, round2PrimitiveAllowlist);

const encodingConformanceTest = fs.readFileSync(
    path.join(
        protocolRoot,
        "test/shared/slotchain/libs/LibSlotChainEncoding.t.sol",
    ),
    "utf8",
);
for (const primitive of round2PrimitiveAllowlist) {
    assert.match(
        encodingConformanceTest,
        new RegExp(`LibSlotChainEncoding\\.${primitive}\\s*\\(`),
        `${primitive} is missing direct Round-2 conformance coverage`,
    );
}

process.stdout.write("golden-vector generator validation tests passed\n");
