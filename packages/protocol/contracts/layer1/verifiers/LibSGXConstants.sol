// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibSGXConstants
/// @custom:security-contact security@taiko.xyz
library LibSGXConstants {
    bytes32 internal constant V0_8_0_RC1_SGXGETH_MR_ENCLAVE =
        0x5f7da556f3b75dcc71465030e1b7274e82df9e9120c0b3eaf5bb76246a514005;
    bytes32 internal constant V0_8_0_RC1_SGXRETH_NON_EDMM_MR_ENCLAVE =
        0x3564b6a30089fcb3e2f69c19b22d23f84ce148387cd7a15f5c1df165b2ae5847;
    bytes32 internal constant V0_8_0_RC1_SGXRETH_EDMM_MR_ENCLAVE =
        0xae2c7b92b2a71238226cb624ecd1171b66bf943cc372314affca0e6748ccecdf;

    bytes32 internal constant V0_9_0_RC1_SGXGETH_MR_ENCLAVE =
        0x51701ed3fbd0bfdcea24a2e47ce9e30c5448ca9e4ad9b48bd1530d4a9c022fe4;
    bytes32 internal constant V0_9_0_RC1_SGXRETH_NON_EDMM_MR_ENCLAVE =
        0xdc994928718200e16e0eb643486ea90e49970a897fd164e39b6ae11262b69ab9;
    bytes32 internal constant V0_9_0_RC1_SGXRETH_EDMM_MR_ENCLAVE =
        0x7aaf74aaa95cf967844819e5e4504f28308541c0504e6642a12a75a4669f66a3;

    bytes32 internal constant V0_9_0_SGXGETH_MR_ENCLAVE =
        0x8c23c79045b9b6bb827eab208e0fe58d7446a57a55f3dfc825c90e904953105b;
    bytes32 internal constant V0_9_0_SGXRETH_NON_EDMM_MR_ENCLAVE =
        0xfeabd725eb5bb621b5c6a5071d1702bcbe06a643b42a0db8f381d5bc07dd81bf;
    bytes32 internal constant V0_9_0_SGXRETH_EDMM_MR_ENCLAVE =
        0x6f3c8c55ec62fe48b83e57463e8717aa9f8594418203c9520f0f80e6f4fc4d87;
}
