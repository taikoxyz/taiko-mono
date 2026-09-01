import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import {
    bytecodeHash,
    loadOwnedArtifact,
    OwnershipManifest,
    validateArtifactOwnership,
} from "../../utils/slotchain/checkArtifactOwnership";

const root = path.resolve(__dirname, "../..");
const manifest = JSON.parse(
    fs.readFileSync(
        path.join(root, "utils/slotchain/artifact-ownership.json"),
        "utf8",
    ),
) as OwnershipManifest;
const sharedId =
    "test/shared/slotchain/fixtures/SharedArtifactProbe.sol:SharedArtifactProbe";

const inventory = validateArtifactOwnership(root, manifest);
const sharedArtifact = loadOwnedArtifact(root, manifest, sharedId);
const sharedModule = manifest.modules.find(
    (module) => `${module.sourcePath}:${module.contractName}` === sharedId,
);
assert(sharedModule?.ownership === "artifact-owned");
assert.equal(
    bytecodeHash(sharedArtifact.bytecode?.object ?? "0x"),
    sharedModule.creationCodeHash,
);

for (const profile of ["layer1", "layer2"] as const) {
    assert.equal(
        fs.existsSync(
            path.join(
                root,
                `out/${profile}/SharedArtifactProbe.sol/SharedArtifactProbe.json`,
            ),
        ),
        false,
        `${profile} must not compile or emit the shared implementation`,
    );
    assert.equal(
        fs.existsSync(
            path.join(
                root,
                `out/${profile}/ISharedArtifactProbe.sol/ISharedArtifactProbe.json`,
            ),
        ),
        true,
        `${profile} must compile the ABI-only interface`,
    );
    assert.equal(
        fs.existsSync(
            path.join(
                root,
                `out/${profile}/LibSourceInlineProbe.sol/LibSourceInlineProbe.json`,
            ),
        ),
        true,
        `${profile} must compile the internal-only source-inline library`,
    );
}

assert.equal(
    inventory.modules
        .find((module) => module.fqn === sharedId)
        ?.profiles.join(","),
    "shared",
);
console.log(`shared artifact consumption tests: PASS (${inventory.digest})`);
