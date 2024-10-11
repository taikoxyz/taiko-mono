// SPDX-License-Identifier: MIT
// Test has been referenced from
// https://github.com/ethyla/bls12-381-hash-to-curve/blob/main/test/hashToField.sol
pragma solidity ^0.8.24;

import "../BaseTest.sol";
import "src/layer1/preconf/libs/BLS12381.sol";

contract BLSHashToFieldFp2 is BaseTest {
    bytes internal hash_to_dst = "QUUX-V01-CS02-with-BLS12381G2_XMD:SHA-256_SSWU_RO_";

    function test_hashToFieldFp2_empty_msg() public {
        BLS12381.FieldPoint2[2] memory result = BLS12381.hashToFieldFp2("", hash_to_dst);
        bytes memory expected_u0 =
            hex"0000000000000000000000000000000003dbc2cce174e91ba93cbb08f26b917f98194a2ea08d1cce75b2b9cc9f21689d80bd79b594a613d0a68eb807dfdc1cf8";
        bytes memory expected_u0_I =
            hex"0000000000000000000000000000000005a2acec64114845711a54199ea339abd125ba38253b70a92c876df10598bd1986b739cad67961eb94f7076511b3b39a";
        bytes memory expected_u1 =
            hex"0000000000000000000000000000000002f99798e8a5acdeed60d7e18e9120521ba1f47ec090984662846bc825de191b5b7641148c0dbc237726a334473eee94";
        bytes memory expected_u1_I =
            hex"00000000000000000000000000000000145a81e418d4010cc027a68f14391b30074e89e60ee7a22f87217b2f6eb0c4b94c9115b436e6fa4607e95a98de30a435";

        assertEq(bytes.concat(bytes32(result[0].u[0]), bytes32(result[0].u[1])), expected_u0);
        assertEq(bytes.concat(bytes32(result[0].u_I[0]), bytes32(result[0].u_I[1])), expected_u0_I);
        assertEq(bytes.concat(bytes32(result[1].u[0]), bytes32(result[1].u[1])), expected_u1);
        assertEq(bytes.concat(bytes32(result[1].u_I[0]), bytes32(result[1].u_I[1])), expected_u1_I);
    }

    function test_hashToFieldFp2_msg_abc() public {
        BLS12381.FieldPoint2[2] memory result = BLS12381.hashToFieldFp2("abc", hash_to_dst);
        bytes memory expected_u0 =
            hex"0000000000000000000000000000000015f7c0aa8f6b296ab5ff9c2c7581ade64f4ee6f1bf18f55179ff44a2cf355fa53dd2a2158c5ecb17d7c52f63e7195771";
        bytes memory expected_u0_I =
            hex"0000000000000000000000000000000001c8067bf4c0ba709aa8b9abc3d1cef589a4758e09ef53732d670fd8739a7274e111ba2fcaa71b3d33df2a3a0c8529dd";
        bytes memory expected_u1 =
            hex"00000000000000000000000000000000187111d5e088b6b9acfdfad078c4dacf72dcd17ca17c82be35e79f8c372a693f60a033b461d81b025864a0ad051a06e4";
        bytes memory expected_u1_I =
            hex"0000000000000000000000000000000008b852331c96ed983e497ebc6dee9b75e373d923b729194af8e72a051ea586f3538a6ebb1e80881a082fa2b24df9f566";

        assertEq(bytes.concat(bytes32(result[0].u[0]), bytes32(result[0].u[1])), expected_u0);
        assertEq(bytes.concat(bytes32(result[0].u_I[0]), bytes32(result[0].u_I[1])), expected_u0_I);
        assertEq(bytes.concat(bytes32(result[1].u[0]), bytes32(result[1].u[1])), expected_u1);
        assertEq(bytes.concat(bytes32(result[1].u_I[0]), bytes32(result[1].u_I[1])), expected_u1_I);
    }

    function test_hash_to_field_msg_fp2_abcdef0123456789() public {
        BLS12381.FieldPoint2[2] memory result =
            BLS12381.hashToFieldFp2("abcdef0123456789", hash_to_dst);
        bytes memory expected_u0 =
            hex"000000000000000000000000000000000313d9325081b415bfd4e5364efaef392ecf69b087496973b229303e1816d2080971470f7da112c4eb43053130b785e1";
        bytes memory expected_u0_I =
            hex"00000000000000000000000000000000062f84cb21ed89406890c051a0e8b9cf6c575cf6e8e18ecf63ba86826b0ae02548d83b483b79e48512b82a6c0686df8f";
        bytes memory expected_u1 =
            hex"000000000000000000000000000000001739123845406baa7be5c5dc74492051b6d42504de008c635f3535bb831d478a341420e67dcc7b46b2e8cba5379cca97";
        bytes memory expected_u1_I =
            hex"0000000000000000000000000000000001897665d9cb5db16a27657760bbea7951f67ad68f8d55f7113f24ba6ddd82caef240a9bfa627972279974894701d975";

        assertEq(bytes.concat(bytes32(result[0].u[0]), bytes32(result[0].u[1])), expected_u0);
        assertEq(bytes.concat(bytes32(result[0].u_I[0]), bytes32(result[0].u_I[1])), expected_u0_I);
        assertEq(bytes.concat(bytes32(result[1].u[0]), bytes32(result[1].u[1])), expected_u1);
        assertEq(bytes.concat(bytes32(result[1].u_I[0]), bytes32(result[1].u_I[1])), expected_u1_I);
    }

    function test_hashToFieldFp2_msg_q128() public {
        BLS12381.FieldPoint2[2] memory result = BLS12381.hashToFieldFp2(
            "q128_qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
            hash_to_dst
        );
        bytes memory expected_u0 =
            hex"00000000000000000000000000000000025820cefc7d06fd38de7d8e370e0da8a52498be9b53cba9927b2ef5c6de1e12e12f188bbc7bc923864883c57e49e253";
        bytes memory expected_u0_I =
            hex"00000000000000000000000000000000034147b77ce337a52e5948f66db0bab47a8d038e712123bb381899b6ab5ad20f02805601e6104c29df18c254b8618c7b";
        bytes memory expected_u1 =
            hex"000000000000000000000000000000000930315cae1f9a6017c3f0c8f2314baa130e1cf13f6532bff0a8a1790cd70af918088c3db94bda214e896e1543629795";
        bytes memory expected_u1_I =
            hex"0000000000000000000000000000000010c4df2cacf67ea3cb3108b00d4cbd0b3968031ebc8eac4b1ebcefe84d6b715fde66bef0219951ece29d1facc8a520ef";

        assertEq(bytes.concat(bytes32(result[0].u[0]), bytes32(result[0].u[1])), expected_u0);
        assertEq(bytes.concat(bytes32(result[0].u_I[0]), bytes32(result[0].u_I[1])), expected_u0_I);
        assertEq(bytes.concat(bytes32(result[1].u[0]), bytes32(result[1].u[1])), expected_u1);
        assertEq(bytes.concat(bytes32(result[1].u_I[0]), bytes32(result[1].u_I[1])), expected_u1_I);
    }

    function test_hashToFieldFp2_msg_a512() public {
        BLS12381.FieldPoint2[2] memory result = BLS12381.hashToFieldFp2(
            "a512_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            hash_to_dst
        );
        bytes memory expected_u0 =
            hex"00000000000000000000000000000000190b513da3e66fc9a3587b78c76d1d132b1152174d0b83e3c1114066392579a45824c5fa17649ab89299ddd4bda54935";
        bytes memory expected_u0_I =
            hex"0000000000000000000000000000000012ab625b0fe0ebd1367fe9fac57bb1168891846039b4216b9d94007b674de2d79126870e88aeef54b2ec717a887dcf39";
        bytes memory expected_u1 =
            hex"000000000000000000000000000000000e6a42010cf435fb5bacc156a585e1ea3294cc81d0ceb81924d95040298380b164f702275892cedd81b62de3aba3f6b5";
        bytes memory expected_u1_I =
            hex"00000000000000000000000000000000117d9a0defc57a33ed208428cb84e54c85a6840e7648480ae428838989d25d97a0af8e3255be62b25c2a85630d2dddd8";

        assertEq(bytes.concat(bytes32(result[0].u[0]), bytes32(result[0].u[1])), expected_u0);
        assertEq(bytes.concat(bytes32(result[0].u_I[0]), bytes32(result[0].u_I[1])), expected_u0_I);
        assertEq(bytes.concat(bytes32(result[1].u[0]), bytes32(result[1].u[1])), expected_u1);
        assertEq(bytes.concat(bytes32(result[1].u_I[0]), bytes32(result[1].u_I[1])), expected_u1_I);
    }
}
