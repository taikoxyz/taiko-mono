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

assert.equal(vectors.length, 764);
assert.equal(vectors.filter((vector) => vector.kind === "hex").length, 624);
assert.equal(vectors.filter((vector) => vector.kind === "uint").length, 140);

const round4BuilderVectorAllowlist = [
    "builder_active_equivocation_witness_hash",
    "builder_active_equivocation_witness_length",
    "builder_active_tranche_release_witness_hash",
    "builder_active_tranche_release_witness_length",
    "builder_admission_state_return_hash",
    "builder_admission_state_selector",
    "builder_cell_63_admission_root",
    "builder_claim_builder_lease_credit_selector",
    "builder_claim_credit_calldata_hash",
    "builder_claim_credit_calldata_length",
    "builder_claim_credit_return_hash",
    "builder_claim_credit_return_length",
    "builder_equivocation_calldata_hash",
    "builder_equivocation_calldata_length",
    "builder_equivocation_return_hash",
    "builder_equivocation_return_length",
    "builder_expire_schedule_calldata_hash",
    "builder_expire_schedule_calldata_length",
    "builder_expire_schedule_return_hash",
    "builder_expire_schedule_return_length",
    "builder_expire_schedule_windows_selector",
    "builder_generation_release_witness_hash",
    "builder_generation_release_witness_length",
    "builder_liability_equivocation_witness_hash",
    "builder_liability_equivocation_witness_length",
    "builder_liability_tranche_release_witness_hash",
    "builder_liability_tranche_release_witness_length",
    "builder_maintenance_calldata_hash",
    "builder_maintenance_calldata_length",
    "builder_maintenance_return_hash",
    "builder_maintenance_return_length",
    "builder_maintenance_witness_hash",
    "builder_maintenance_witness_length",
    "builder_move_final_root",
    "builder_move_intermediate_root",
    "builder_move_pre_root",
    "builder_movement_witness_hash",
    "builder_movement_witness_length",
    "builder_normalize_builder_tranches_selector",
    "builder_normalize_calldata_hash",
    "builder_normalize_calldata_length",
    "builder_normalize_noop_witness_hash",
    "builder_normalize_noop_witness_length",
    "builder_normalize_return_hash",
    "builder_normalize_return_length",
    "builder_normalize_witness_hash",
    "builder_normalize_witness_length",
    "builder_process_builder_maintenance_selector",
    "builder_register_builder_selector",
    "builder_register_calldata_hash",
    "builder_register_calldata_length",
    "builder_register_return_hash",
    "builder_register_return_length",
    "builder_registry_configuration_hash",
    "builder_registry_header_slot",
    "builder_registry_header_trie_key",
    "builder_registry_header_word",
    "builder_registry_root_slot",
    "builder_registry_root_trie_key",
    "builder_release_builder_generation_selector",
    "builder_release_builder_tranche_selector",
    "builder_release_generation_calldata_hash",
    "builder_release_generation_calldata_length",
    "builder_release_generation_return_hash",
    "builder_release_generation_return_length",
    "builder_release_tranche_calldata_hash",
    "builder_release_tranche_calldata_length",
    "builder_release_tranche_return_hash",
    "builder_release_tranche_return_length",
    "builder_request_builder_exit_selector",
    "builder_request_exit_calldata_hash",
    "builder_request_exit_calldata_length",
    "builder_request_exit_return_hash",
    "builder_request_exit_return_length",
    "builder_reserve_builder_window_selector",
    "builder_reserve_calldata_hash",
    "builder_reserve_calldata_length",
    "builder_reserve_return_hash",
    "builder_reserve_return_length",
    "builder_reserve_witness_hash",
    "builder_reserve_witness_length",
    "builder_schedule_registry_state_return_hash",
    "builder_schedule_registry_state_selector",
    "builder_schedule_window_release_return_hash",
    "builder_schedule_window_release_selector",
    "builder_settlement_schedule_release_return_hash",
    "builder_settlement_schedule_release_selector",
    "builder_submit_builder_equivocation_selector",
    "builder_vacancy_registration_witness_hash",
    "builder_vacancy_registration_witness_length",
] as const;
assert.deepEqual(
    vectors
        .filter((vector) => vector.name.startsWith("builder_"))
        .map((vector) => vector.name),
    round4BuilderVectorAllowlist,
);

const requiredRound4Lengths = {
    builder_active_equivocation_witness_length: "2366",
    builder_active_tranche_release_witness_length: "480",
    builder_claim_credit_calldata_length: "36",
    builder_claim_credit_return_length: "96",
    builder_equivocation_calldata_length: "2436",
    builder_equivocation_return_length: "256",
    builder_expire_schedule_calldata_length: "36",
    builder_expire_schedule_return_length: "96",
    builder_generation_release_witness_length: "352",
    builder_liability_equivocation_witness_length: "2366",
    builder_liability_tranche_release_witness_length: "288",
    builder_maintenance_calldata_length: "1316",
    builder_maintenance_return_length: "160",
    builder_maintenance_witness_length: "1197",
    builder_movement_witness_length: "1193",
    builder_normalize_calldata_length: "644",
    builder_normalize_noop_witness_length: "1",
    builder_normalize_return_length: "160",
    builder_normalize_witness_length: "489",
    builder_register_calldata_length: "708",
    builder_register_return_length: "192",
    builder_release_generation_calldata_length: "484",
    builder_release_generation_return_length: "192",
    builder_release_tranche_calldata_length: "644",
    builder_release_tranche_return_length: "224",
    builder_request_exit_calldata_length: "36",
    builder_request_exit_return_length: "128",
    builder_reserve_calldata_length: "932",
    builder_reserve_return_length: "160",
    builder_reserve_witness_length: "777",
    builder_vacancy_registration_witness_length: "544",
} as const;
for (const [name, value] of Object.entries(requiredRound4Lengths)) {
    assert.deepEqual(
        vectors.find((vector) => vector.name === name),
        { kind: "uint", name, value },
        `${name} must stay pinned to the c2635 witness/ABI grammar`,
    );
}

const requiredRound4Selectors = {
    builder_admission_state_selector: "4a9dfa3f",
    builder_claim_builder_lease_credit_selector: "8f73793c",
    builder_expire_schedule_windows_selector: "b1357479",
    builder_normalize_builder_tranches_selector: "5e7c8afe",
    builder_process_builder_maintenance_selector: "0e1ffc68",
    builder_register_builder_selector: "5fc42c69",
    builder_release_builder_generation_selector: "e7bae370",
    builder_release_builder_tranche_selector: "f8668bb9",
    builder_request_builder_exit_selector: "c8f20b55",
    builder_reserve_builder_window_selector: "46a53315",
    builder_schedule_registry_state_selector: "ad95cea1",
    builder_schedule_window_release_selector: "f4cd9a5e",
    builder_settlement_schedule_release_selector: "a4574c77",
    builder_submit_builder_equivocation_selector: "979c1f72",
} as const;
for (const [name, value] of Object.entries(requiredRound4Selectors)) {
    assert.deepEqual(
        vectors.find((vector) => vector.name === name),
        { kind: "hex", name, value },
        `${name} must stay pinned to the c2635 ABI grammar`,
    );
}

const solidity = renderSolidity(vectors);
assert.match(solidity, /uint256 internal constant GOLDEN_VECTOR_COUNT = 764;/);
assert.match(solidity, /bytes32 internal constant CANDIDATE_COMMITMENT =/);
assert.match(solidity, /bytes internal constant V11_BRIDGE_DESCRIPTOR =/);
assert.match(
    solidity,
    /uint256 internal constant BUILDER_ACTIVE_EQUIVOCATION_WITNESS_LENGTH = 2366;/,
);
assert.match(
    solidity,
    /bytes32 internal constant BUILDER_REGISTER_CALLDATA_HASH =/,
);
const descriptorStart = solidity.indexOf(
    "bytes internal constant V11_BRIDGE_DESCRIPTOR =",
);
const descriptorEnd = solidity.indexOf(";", descriptorStart);
const descriptorDeclaration = solidity.slice(descriptorStart, descriptorEnd);
const descriptorChunks = Array.from(
    descriptorDeclaration.matchAll(/hex"([0-9a-f]+)"/g),
    (match) => match[1],
);
const descriptorVector = vectors.find(
    (vector) => vector.name === "v11_bridge_descriptor",
);
assert.ok(
    descriptorChunks.length > 1 &&
        descriptorChunks.every((chunk) => chunk.length <= 60),
    "long byte constants must use bounded hex-literal chunks",
);
assert.equal(descriptorChunks.join(""), descriptorVector?.value);

function encoded(copy: TypedVector[]): string {
    return `${JSON.stringify(copy)}\n`;
}

assert.throws(
    () => validateTypedVectorJson(JSON.stringify(vectors.slice(1))),
    /expected 764/,
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
