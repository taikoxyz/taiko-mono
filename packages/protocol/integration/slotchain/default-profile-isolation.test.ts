import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const root = path.resolve(__dirname, "../..");
const tempRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), "slotchain-default-profile-"),
);
const outputRoot = path.join(tempRoot, "out");
const buildInfoRoot = path.join(tempRoot, "build-info");
const violations: string[] = [];

function visit(directory: string): void {
    if (!fs.existsSync(directory)) return;
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
        const absolute = path.join(directory, entry.name);
        if (entry.isDirectory()) {
            visit(absolute);
        } else if (entry.isFile() && entry.name.endsWith(".json")) {
            const contents = fs.readFileSync(absolute, "utf8");
            if (contents.includes("/slotchain/")) {
                violations.push(
                    path.relative(tempRoot, absolute).split(path.sep).join("/"),
                );
            }
        }
    }
}

try {
    execFileSync(
        "forge",
        [
            "build",
            "--force",
            "--out",
            outputRoot,
            "--cache-path",
            path.join(tempRoot, "cache"),
            "--build-info",
            "--build-info-path",
            buildInfoRoot,
            "--ast",
            "--skip",
            "*DeployAutomataDcapAttestation.s.sol",
        ],
        {
            cwd: root,
            env: Object.assign({}, process.env, { FOUNDRY_PROFILE: "default" }),
            stdio: "inherit",
        },
    );
    visit(outputRoot);
    visit(buildInfoRoot);
    assert.deepEqual(
        violations,
        [],
        `default profile compiled Slot Chain inputs: ${violations.join(", ")}`,
    );
    console.log("default profile isolation tests: PASS");
} finally {
    fs.rmSync(tempRoot, { recursive: true, force: true });
}
