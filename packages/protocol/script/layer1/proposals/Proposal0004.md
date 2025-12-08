# PROPOSAL-0004: Protocol Security Enhancement and Verifier Upgrade

## Executive Summary

This proposal implements security enhancements and protocol upgrades for the Taiko Alethia protocol on Ethereum mainnet. The upgrade introduces new trusted ZK proof images for SP1 and Risc0 verifiers, upgrades verifier implementations to improve functionality and performance, and updates SGX attestation parameters to ensure only authorized enclaves can generate valid proofs.

## Rationale

### Background

The Taiko protocol relies on multiple proof systems (ZK and SGX) to ensure the validity of L2 state transitions. As the protocol evolves and security research advances, it is essential to:

1. Update trusted proof images to incorporate the latest optimizations and security patches
2. Upgrade verifier contracts to improve gas efficiency and add necessary functionality
3. Maintain strict control over SGX attestation to prevent unauthorized proof generation

## Technical Specification

### 1. ZK Verifier Image Updates

#### 1.1 SP1 (Succinct) Verifier Updates

**Contract**: `0xbee1040D0Aab17AE19454384904525aE4A3602B9`

New trusted images to be added:

- `0x008f96447139673b3f2d29b30ad4b43fe6ccb3f31d40f6e61478ac5640201d9e`
- `0x47cb22384e59cecf65a536612d4b43fe36659f987503db9828f158ac40201d9e`
- `0x00a32a15ab7a74a9a79f3b97a71d1b014cd4361b37819004b9322b502b5f5be1`
- `0x51950ad55e9d2a6973e772f471d1b01466a1b0d95e064012726456a02b5f5be1`

#### 1.2 Risc0 Verifier Updates

**Contract**: `0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE`

New trusted images to be added:

- `0x3d933868e2ac698df98209b45e6c34c435df2d3c97754bb6739d541d5fd312e3`
- `0x77ff0953ded4fb48bb52b1099cc36c6b8bf603dc4ed9211608c039c7ec31b82b`

### 2. Contract Implementation Upgrades

#### 2.1 Risc0 Verifier Upgrade

**Proxy Contract**: `0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE`
**New Implementation**: `0xDF6327caafC5FeB8910777Ac811e0B1d27dCdf36`

Key changes:

- Modified `proposeBatch` function return data structure
- Updated Groth16 verifier dependency (the `_riscoGroth16Verifier` parameter value in the constructor) from `0x34Eda8BfFb539AeC33078819847B36D221c6641c` to `0x7CCA385bdC790c25924333F5ADb7F4967F5d1599`

[View implementation diff](https://codediff.taiko.xyz/?addr=0x73Ee496dA20e5C65340c040B0D8c3C891C1f74AE&newimpl=0xDF6327caafC5FeB8910777Ac811e0B1d27dCdf36&chainid=1&filter=changed)

[View _riscoGroth16Verifier diff](https://codediff.taiko.xyz/?addr=0x34Eda8BfFb539AeC33078819847B36D221c6641c&newimpl=0x7CCA385bdC790c25924333F5ADb7F4967F5d1599&chainid=1&filter=changed)


#### 2.2 PreconfRouter Upgrade

**Proxy Contract**: `0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a`
**New Implementation**: `0xafCEDDe020dB8D431Fa86dF6B14C20f327382709`

Key changes:

- Added `getConfig()` view function for improved protocol observability

[View implementation diff](https://codediff.taiko.xyz/?addr=0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a&newimpl=0xafCEDDe020dB8D431Fa86dF6B14C20f327382709&chainid=1&filter=changed)

### 3. SGX Attestation Updates

#### 3.1 SGX-GETH Attester

**Contract**: `0x0ffa4A625ED9DB32B70F99180FD00759fc3e9261`

New MR_ENCLAVE value:

- `0x3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0`

_Note: Built with EGo framework (non-EDMM support only)_

#### 3.2 SGX-RETH Attester

**Contract**: `0x8d7C954960a36a7596d7eA4945dDf891967ca8A3`

New MR_ENCLAVE values:

- `0xe5774b71990b0d5f3eca8d4d22546764dd9549c743a1a6d4d4863d97f6b8c67a` (Non-EDMM mode)
- `0x605ad10c1a56ed7289f198d64a39a952cd3b8a0bed3fcb19c8301c1847dc3a2f` (EDMM-enabled mode)

_Note: Built with Gramine framework (supports both EDMM-enabled and EDMM-disabled SGX)_

## Verification Procedures

### ZK Image Verification

To verify the ZK image IDs:

1. Check out the official release from the repository
2. Run `./script/publish-image.sh` to build the corresponding ZK images
3. Compare the output logs with the proposed image IDs

Example verification output for Risc0:

```
#41 550.0 risc0 elf image id: 3d933868e2ac698df98209b45e6c34c435df2d3c97754bb6739d541d5fd312e3
#41 551.7 risc0 elf image id: 77ff0953ded4fb48bb52b1099cc36c6b8bf603dc4ed9211608c039c7ec31b82b
```

Example verification output for SP1:

```
#43 131.2 sp1 elf vk bn256 is: 0x008f96447139673b3f2d29b30ad4b43fe6ccb3f31d40f6e61478ac5640201d9e
#43 131.2 sp1 elf vk hash_bytes is: 47cb22384e59cecf65a536612d4b43fe36659f987503db9828f158ac40201d9e
#43 143.6 sp1 elf vk bn256 is: 0x00a32a15ab7a74a9a79f3b97a71d1b014cd4361b37819004b9322b502b5f5be1
#43 143.6 sp1 elf vk hash_bytes is: 51950ad55e9d2a6973e772f471d1b01466a1b0d95e064012726456a02b5f5be1
```

### MR_ENCLAVE Verification

To verify MR_ENCLAVE values:

1. Check out the official release (v1.12.0)
2. Run `./script/publish-image.sh [0|1]` (0 for non-EDMM, 1 for EDMM)
3. Compare the output with the proposed values

Example verification output:

```
# Non-EDMM mode
#30 0.205 2025/10/09 03:10:00 INFO EGo version=1.7.0 git_commit=3a3f54a1d1cd9318dd1ade411f9f439f53bb6694
#30 0.205 3e6113a23bbdf9231520153253047d02db8f1dd38a9b52914ab7943278f52db0
#48 3.653     mr_enclave: e5774b71990b0d5f3eca8d4d22546764dd9549c743a1a6d4d4863d97f6b8c67a

# EDMM mode
#48 3.653     mr_enclave: 605ad10c1a56ed7289f198d64a39a952cd3b8a0bed3fcb19c8301c1847dc3a2f
```

## Security Contacts

- Primary: security@taiko.xyz
- Bug Bounty Program: [Link to program]

## References

- [Raiko Release v1.12.0](https://github.com/taikoxyz/raiko/blob/v1.12.0/RELEASE.md)
- [SP1 Documentation](https://docs.succinct.xyz)
- [Risc0 Documentation](https://docs.risczero.com)
- [Gramine Project](https://gramineproject.io)
- [EGo Framework](https://github.com/edgelesssys/ego)
- [Etherscan - Risc0 Groth16 Verifier](https://etherscan.io/address/0x7CCA385bdC790c25924333F5ADb7F4967F5d1599#code)

## Appendix

### A. Glossary

- **MR_ENCLAVE**: Measurement Register Enclave - A cryptographic hash (SHA-256) of the SGX Enclave binary, serving as a unique fingerprint of the code
- **EDMM**: Enclave Dynamic Memory Management - A feature in newer SGX processors allowing dynamic memory allocation
- **BN256**: A pairing-friendly elliptic curve used in ZK-SNARK constructions
- **Groth16**: An efficient ZK-SNARK proof system

## Q&A

### Q1: Where is the source code for the upgraded implementations coming from?

**A:** The currently deployed mainnet version is based on the `taiko-alethia-protocol-v2.3.1` branch, not the main branch.

The source files for the upgraded implementations can be found at:

- [ITaikoInbox.sol](https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v2.3.1/packages/protocol/contracts/layer1/based/ITaikoInbox.sol)
- [PreconfRouter.sol](https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v2.3.1/packages/protocol/contracts/layer1/preconf/impl/PreconfRouter.sol)
- [IPreconfRouter.sol](https://github.com/taikoxyz/taiko-mono/blob/taiko-alethia-protocol-v2.3.1/packages/protocol/contracts/layer1/preconf/iface/IPreconfRouter.sol)

This branch is also referenced in the repository [README](https://github.com/taikoxyz/taiko-mono/blob/main/README.md).

### Q2: What is the CONTROL_ROOT value in the new Risc0 Groth16 Verifier, and why doesn't it relate to the trusted images?

**A:** The `CONTROL_ROOT` value (`0xa54dc85ac99f851c92d7c96d7318af41dbe7c0194edfcc37eb4d422a998c1f56`) is part of Risc0's proof versioning mechanism and is separate from the image IDs we publish.

**Key distinction:**

- **Image IDs**: Correspond to our specific code logic. When our logic changes, the image ID changes.
- **CONTROL_ROOT**: Tied to the Risc0 SDK version used. It remains constant as long as we don't upgrade the Risc0 SDK itself.

This separation allows us to update our proof logic (new image IDs) without requiring verifier contract upgrades, as long as the underlying SDK version remains compatible.

**Further reading:** [Risc0 Version Management Design](https://github.com/risc0/risc0-ethereum/blob/release-3.0/contracts/version-management-design.md)

