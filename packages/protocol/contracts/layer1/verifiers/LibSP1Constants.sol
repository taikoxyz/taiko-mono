// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibSP1Constants
/// @custom:security-contact security@taiko.xyz
library LibSP1Constants {
    bytes32 internal constant V0_6_0_PROPOSAL_PROGRAM_VKEY_BN254 =
        0x00ad090221a8fa0f09e1be7a53feb67be010f01310d4b2314a69d10152ee1ce0;
    bytes32 internal constant V0_6_0_PROPOSAL_PROGRAM_VKEY_HASH_BYTES =
        0x568481106a3e83c23c37cf4a3feb67be008780984352c8c514d3a20252ee1ce0;
    bytes32 internal constant V0_6_0_AGGREGATION_PROGRAM_VKEY_BN254 =
        0x000b11691352e55fcf64f62620cefaa700161600093f2751032fe71ea912264d;
    bytes32 internal constant V0_6_0_AGGREGATION_PROGRAM_VKEY_HASH_BYTES =
        0x0588b48954b957f36c9ec4c40cefaa7000b0b00024fc9d44065fce3d2912264d;

    bytes32 internal constant V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_BN254 =
        0x0025425c22e827507428a3d9c7b0f89635be5462f34bb6780563e3d6086be7c7;
    bytes32 internal constant V0_8_0_RC1_PROPOSAL_PROGRAM_VKEY_HASH_BYTES =
        0x12a12e113a09d41d05147b387b0f89632df2a3174d2ed9e00ac7c7ac086be7c7;
    bytes32 internal constant V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_BN254 =
        0x0051ac1d9e8cfd4196e37f9cfefd08e9b0f7ce653bad4634cd1ee84b71ca3be6;
    bytes32 internal constant V0_8_0_RC1_AGGREGATION_PROGRAM_VKEY_HASH_BYTES =
        0x28d60ecf233f50655c6ff39f6fd08e9b07be73296eb518d31a3dd09671ca3be6;
}
