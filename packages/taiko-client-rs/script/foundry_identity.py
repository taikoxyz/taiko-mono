#!/usr/bin/env python3
"""Authenticate reviewed Forge binaries and canonicalize only their release-label alias.

Linux's official 1.5.1 asset says 1.5.1-v1.5.1; the reviewed macOS fixture
producer says 1.5.1-stable. Both have the exact same upstream source revision.
Binary digests, full source revision and build profile remain mandatory. This
normalizes provenance display metadata only, never compiler output or artifacts.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

REVISION = 'b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2'
CANONICAL = ['forge Version: 1.5.1-stable', 'Commit SHA: ' + REVISION]
APPROVED = {
    # Official foundry_v1.5.1_linux_amd64.tar.gz archive SHA256:
    # 73640b01bd9ed29fdb4965085099371f8cf0dbbec3e2086cf54564efc4dcfe88
    'a39fc1913b53dde6a35b603756f65d799e13817ef694107ec0d3704c20435cce':
        ('linux-amd64-official-v1.5.1', 'forge Version: 1.5.1-v1.5.1'),
    # Exact macOS arm64 producer used for the reviewed committed fixtures.
    'f5457831a5740157932b8324cb8fd05390941ad23ef0db092acd074f1753bd07':
        ('macos-arm64-reviewed-fixture-producer', 'forge Version: 1.5.1-stable'),
}


def identity(output, binary_sha256):
    """Accept only complete, consistent identity from an independently pinned binary."""
    if binary_sha256 not in APPROVED:
        raise ValueError('unreviewed Forge binary SHA256: ' + binary_sha256)
    source, version = APPROVED[binary_sha256]
    lines = output.strip().splitlines()
    if (len(lines) != 4 or lines[0] != version or lines[1] != CANONICAL[1]
            or not lines[2].startswith('Build Timestamp: ') or lines[2] == 'Build Timestamp: '
            or lines[3] != 'Build Profile: maxperf'):
        raise ValueError('Forge version/source/build identity differs from its approved binary')
    return {'binary_sha256': binary_sha256, 'binary_source': source,
            'observed': lines, 'canonical': CANONICAL.copy(),
            'normalization': 'reviewed release-label aliases only; artifact bytes remain exact'}


def checked_identity(executable=None):
    """Hash the actual PATH-selected executable before running its version command."""
    executable = executable or shutil.which('forge')
    if not executable:
        raise ValueError('Forge executable unavailable')
    executable = Path(executable).resolve(strict=True)
    digest = hashlib.sha256(executable.read_bytes()).hexdigest()
    if digest not in APPROVED:
        raise ValueError('unreviewed Forge binary SHA256: ' + digest)
    return identity(subprocess.check_output([str(executable), '--version'], text=True), digest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path)
    args = parser.parse_args()
    receipt = checked_identity()
    if args.manifest and json.loads(args.manifest.read_text())['foundryVersion'] != receipt['canonical']:
        raise ValueError('fixture Foundry source identity differs from the approved release')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    main()
