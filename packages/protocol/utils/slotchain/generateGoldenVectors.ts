import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const EXPECTED_VECTOR_COUNT = 654;
const EXPECTED_HEX_VECTOR_COUNT = 547;
const EXPECTED_UINT_VECTOR_COUNT = 107;
const VECTOR_NAME_SCHEMA_SHA256 =
    "3f011fdb670388d6346a8c4a3118cd3187282213ee9797a2d3d0dc501bd8447c";
const MAX_UINT256_DECIMAL =
    "115792089237316195423570985008687907853269984665640564039457584007913129639935";
const MAX_BUFFER_BYTES = 16 * 1024 * 1024;
const PROBE_TIMEOUT_MS = 10_000;
const MODEL_TIMEOUT_MS = 120_000;
const FORMATTER_TIMEOUT_MS = 30_000;

const protocolRoot = path.resolve(__dirname, "../..");
const modelPath = path.join(
    protocolRoot,
    "docs/preconfirmation-v2/commitment-model.py",
);
const jsonPath = path.join(
    protocolRoot,
    "test/shared/slotchain/vectors/slot-chain-commitments.json",
);
const solidityPath = path.join(
    protocolRoot,
    "test/shared/slotchain/vectors/SlotChainGoldenVectors.sol",
);

export type TypedVector =
    | { kind: "hex"; name: string; value: string }
    | { kind: "uint"; name: string; value: string };

function fail(message: string): never {
    throw new Error(`golden-vector generation failed: ${message}`);
}

function runPython(
    interpreter: string,
    args: string[],
    purpose: string,
    timeout: number,
): string {
    const result = spawnSync(interpreter, args, {
        encoding: "utf8",
        env: process.env,
        maxBuffer: MAX_BUFFER_BYTES,
        shell: false,
        timeout,
    });

    if (result.error) {
        fail(`${purpose}: ${result.error.message}`);
    }
    if (result.signal !== null) {
        fail(`${purpose}: terminated by signal ${result.signal}`);
    }
    if (result.status !== 0) {
        const stderr = result.stderr.trim();
        fail(
            `${purpose}: exited with status ${String(result.status)}` +
                (stderr === "" ? "" : `: ${stderr}`),
        );
    }
    if (result.stderr !== "") {
        fail(`${purpose}: unexpected stderr: ${result.stderr.trim()}`);
    }
    return result.stdout;
}

function requireAssertionsEnabled(interpreter: string): void {
    const configuredOptimization = process.env.PYTHONOPTIMIZE;
    if (
        configuredOptimization !== undefined &&
        configuredOptimization !== "" &&
        !/^0+$/.test(configuredOptimization)
    ) {
        fail("PYTHONOPTIMIZE must be unset, empty, or zero");
    }

    const output = runPython(
        interpreter,
        ["-c", "import sys; print(sys.flags.optimize)"],
        "Python assertion probe",
        PROBE_TIMEOUT_MS,
    );
    if (output !== "0\n" && output !== "0\r\n") {
        fail(
            `Python assertions are disabled (optimization probe: ${output.trim()})`,
        );
    }
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
    return (
        typeof value === "object" &&
        value !== null &&
        !Array.isArray(value) &&
        Object.getPrototypeOf(value) === Object.prototype
    );
}

export function validateTypedVectorJson(rawJson: string): TypedVector[] {
    let parsed: unknown;
    try {
        parsed = JSON.parse(rawJson);
    } catch (error) {
        fail(`typed export is not valid JSON: ${(error as Error).message}`);
    }
    if (!Array.isArray(parsed)) {
        fail("typed export root must be an array");
    }
    if (parsed.length !== EXPECTED_VECTOR_COUNT) {
        fail(
            `typed export contains ${parsed.length} records, expected ${EXPECTED_VECTOR_COUNT}`,
        );
    }

    const vectors: TypedVector[] = [];
    const names = new Set<string>();
    let previousName: string | undefined;
    let hexCount = 0;
    let uintCount = 0;

    for (const [index, value] of parsed.entries()) {
        if (!isPlainObject(value)) {
            fail(`record ${index} must be a plain object`);
        }
        const keys = Object.keys(value);
        if (
            keys.length !== 3 ||
            keys[0] !== "kind" ||
            keys[1] !== "name" ||
            keys[2] !== "value"
        ) {
            fail(
                `record ${index} must contain exactly kind, name, value in canonical order`,
            );
        }
        if (value.kind !== "hex" && value.kind !== "uint") {
            fail(`record ${index} has unsupported kind`);
        }
        if (typeof value.name !== "string" || typeof value.value !== "string") {
            fail(`record ${index} name and value must be strings`);
        }
        if (!/^[a-z][a-z0-9_]*$/.test(value.name)) {
            fail(`record ${index} has an invalid name`);
        }
        if (names.has(value.name)) {
            fail(`duplicate vector name: ${value.name}`);
        }
        if (previousName !== undefined && value.name <= previousName) {
            fail(
                `vector names are not in strict deterministic order at ${value.name}`,
            );
        }

        if (value.kind === "hex") {
            if (
                value.value === "" ||
                value.value.length % 2 !== 0 ||
                !/^[0-9a-f]+$/.test(value.value)
            ) {
                fail(
                    `hex vector ${value.name} is not canonical lowercase whole-byte hex`,
                );
            }
            hexCount += 1;
        } else {
            if (!/^(0|[1-9][0-9]*)$/.test(value.value)) {
                fail(
                    `uint vector ${value.name} is not canonical unsigned decimal`,
                );
            }
            if (
                value.value.length > MAX_UINT256_DECIMAL.length ||
                (value.value.length === MAX_UINT256_DECIMAL.length &&
                    value.value > MAX_UINT256_DECIMAL)
            ) {
                fail(`uint vector ${value.name} exceeds uint256`);
            }
            uintCount += 1;
        }

        names.add(value.name);
        previousName = value.name;
        vectors.push(value as TypedVector);
    }

    if (
        hexCount !== EXPECTED_HEX_VECTOR_COUNT ||
        uintCount !== EXPECTED_UINT_VECTOR_COUNT
    ) {
        fail(
            `typed export kind counts are hex=${hexCount}, uint=${uintCount}; expected ` +
                `hex=${EXPECTED_HEX_VECTOR_COUNT}, uint=${EXPECTED_UINT_VECTOR_COUNT}`,
        );
    }
    const schemaHash = crypto
        .createHash("sha256")
        .update([...names].join("\0"), "ascii")
        .digest("hex");
    if (schemaHash !== VECTOR_NAME_SCHEMA_SHA256) {
        fail(`vector-name schema hash mismatch: ${schemaHash}`);
    }

    const canonicalJson = JSON.stringify(vectors);
    if (rawJson !== canonicalJson && rawJson !== `${canonicalJson}\n`) {
        fail(
            "typed export is not canonical JSON (including duplicate or reordered object keys)",
        );
    }
    return vectors;
}

function solidityIdentifier(name: string): string {
    return name.toUpperCase();
}

export function renderSolidity(vectors: TypedVector[]): string {
    const lines = [
        "// SPDX-License-Identifier: MIT",
        "pragma solidity 0.8.30;",
        "",
        "/// @dev Generated by utils/slotchain/generateGoldenVectors.ts. Do not edit.",
        "/// @custom:security-contact security@taiko.xyz",
        "library SlotChainGoldenVectors {",
        `    uint256 internal constant GOLDEN_VECTOR_COUNT = ${EXPECTED_VECTOR_COUNT};`,
        `    uint256 internal constant GOLDEN_HEX_VECTOR_COUNT = ${EXPECTED_HEX_VECTOR_COUNT};`,
        `    uint256 internal constant GOLDEN_UINT_VECTOR_COUNT = ${EXPECTED_UINT_VECTOR_COUNT};`,
        "    bytes32 internal constant GOLDEN_VECTOR_NAME_SCHEMA_SHA256 =",
        `        hex"${VECTOR_NAME_SCHEMA_SHA256}";`,
        "",
    ];

    for (const vector of vectors) {
        const identifier = solidityIdentifier(vector.name);
        if (vector.kind === "uint") {
            lines.push(
                `    uint256 internal constant ${identifier} = ${vector.value};`,
            );
        } else {
            const byteLength = vector.value.length / 2;
            const solidityType =
                byteLength <= 32 ? `bytes${byteLength}` : "bytes";
            lines.push(
                `    ${solidityType} internal constant ${identifier} = hex"${vector.value}";`,
            );
        }
    }

    lines.push("}", "");
    return lines.join("\n");
}

function formatSolidity(source: string): string {
    const result = spawnSync("forge", ["fmt", "--raw", "-"], {
        cwd: protocolRoot,
        encoding: "utf8",
        env: process.env,
        input: source,
        maxBuffer: MAX_BUFFER_BYTES,
        shell: false,
        timeout: FORMATTER_TIMEOUT_MS,
    });
    if (result.error) {
        fail(`Solidity formatter: ${result.error.message}`);
    }
    if (result.signal !== null) {
        fail(`Solidity formatter: terminated by signal ${result.signal}`);
    }
    if (result.status !== 0) {
        fail(`Solidity formatter: exited with status ${String(result.status)}`);
    }
    if (result.stderr !== "") {
        fail(`Solidity formatter: unexpected stderr: ${result.stderr.trim()}`);
    }
    return result.stdout;
}

function formatJson(source: string): string {
    const result = spawnSync("prettier", ["--parser", "json"], {
        cwd: protocolRoot,
        encoding: "utf8",
        env: process.env,
        input: source,
        maxBuffer: MAX_BUFFER_BYTES,
        shell: false,
        timeout: FORMATTER_TIMEOUT_MS,
    });
    if (result.error) {
        fail(`JSON formatter: ${result.error.message}`);
    }
    if (result.signal !== null) {
        fail(`JSON formatter: terminated by signal ${result.signal}`);
    }
    if (result.status !== 0) {
        fail(`JSON formatter: exited with status ${String(result.status)}`);
    }
    if (result.stderr !== "") {
        fail(`JSON formatter: unexpected stderr: ${result.stderr.trim()}`);
    }
    return result.stdout;
}

function assertFileMatches(targetPath: string, expected: string): void {
    let actual: string;
    try {
        actual = fs.readFileSync(targetPath, "utf8");
    } catch (error) {
        fail(
            `${path.relative(protocolRoot, targetPath)} is missing: ${(error as Error).message}`,
        );
    }
    if (actual !== expected) {
        fail(
            `${path.relative(protocolRoot, targetPath)} is stale; regenerate it`,
        );
    }
}

function writeFileAtomically(targetPath: string, contents: string): void {
    fs.mkdirSync(path.dirname(targetPath), { recursive: true });
    const suffix = crypto.randomBytes(8).toString("hex");
    const temporaryPath = path.join(
        path.dirname(targetPath),
        `.${path.basename(targetPath)}.${process.pid}.${suffix}.tmp`,
    );
    let descriptor: number | undefined;
    try {
        descriptor = fs.openSync(temporaryPath, "wx", 0o600);
        fs.writeFileSync(descriptor, contents, "utf8");
        fs.fsyncSync(descriptor);
        fs.closeSync(descriptor);
        descriptor = undefined;
        fs.renameSync(temporaryPath, targetPath);
    } finally {
        if (descriptor !== undefined) {
            fs.closeSync(descriptor);
        }
        if (fs.existsSync(temporaryPath)) {
            fs.unlinkSync(temporaryPath);
        }
    }
}

export function main(args: string[]): void {
    if (args.length > 1 || (args.length === 1 && args[0] !== "--check")) {
        fail("usage: generateGoldenVectors.ts [--check]");
    }
    const checkOnly = args[0] === "--check";
    const interpreter = process.env.SLOTCHAIN_PYTHON || "python3";

    requireAssertionsEnabled(interpreter);
    const normalOutput = runPython(
        interpreter,
        [modelPath],
        "commitment-model self-test",
        MODEL_TIMEOUT_MS,
    );
    if (
        !normalOutput.includes(
            "RESULTS: commitment encoding model — ALL 654 GOLDEN VECTORS / 1432 ASSERTION SITES PASS",
        )
    ) {
        fail(
            "commitment-model self-test did not print its complete success marker",
        );
    }

    const exportOutput = runPython(
        interpreter,
        [modelPath, "--export-json"],
        "commitment-model typed export",
        MODEL_TIMEOUT_MS,
    );
    const vectors = validateTypedVectorJson(exportOutput);
    const json = formatJson(JSON.stringify(vectors));
    const solidity = formatSolidity(renderSolidity(vectors));

    if (checkOnly) {
        assertFileMatches(jsonPath, json);
        assertFileMatches(solidityPath, solidity);
        process.stdout.write(
            `verified ${vectors.length} slot-chain golden vectors\n`,
        );
        return;
    }

    writeFileAtomically(jsonPath, json);
    writeFileAtomically(solidityPath, solidity);
    process.stdout.write(
        `generated ${vectors.length} slot-chain golden vectors\n`,
    );
}

if (require.main === module) {
    try {
        main(process.argv.slice(2));
    } catch (error) {
        process.stderr.write(`${(error as Error).message}\n`);
        process.exitCode = 1;
    }
}
