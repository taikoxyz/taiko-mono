// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { AnyTwoVerifier } from "src/layer1/verifiers/compose/AnyTwoVerifier.sol";
import { AnyVerifier } from "src/layer1/verifiers/compose/AnyVerifier.sol";
import { ComposeVerifier } from "src/layer1/verifiers/compose/ComposeVerifier.sol";
import { SgxAndZkVerifier } from "src/layer1/verifiers/compose/SgxAndZkVerifier.sol";

contract StubVerifier is IProofVerifier {
    function verifyProof(uint256, bytes32, bytes calldata) external view { }
}

contract ComposeVerifierTest is Test {
    uint8 private constant NONE = 0;
    uint8 private constant SGX_RETH = 4;
    uint8 private constant RISC0_RETH = 5;
    uint8 private constant SP1_RETH = 6;

    StubVerifier internal sgx;
    StubVerifier internal risc0;
    StubVerifier internal sp1;

    AnyVerifier internal anyVerifier;
    AnyTwoVerifier internal anyTwoVerifier;
    SgxAndZkVerifier internal sgxAndZkVerifier;

    bytes32 private constant TRANSITIONS_HASH = bytes32(uint256(0x1234));

    function setUp() external {
        sgx = new StubVerifier();
        risc0 = new StubVerifier();
        sp1 = new StubVerifier();

        anyVerifier = new AnyVerifier(address(sgx), address(risc0), address(sp1));
        anyTwoVerifier = new AnyTwoVerifier(address(sgx), address(risc0), address(sp1));
        sgxAndZkVerifier = new SgxAndZkVerifier(address(sgx), address(risc0), address(sp1));
    }

    // ---------------------------------------------------------------
    // AnyVerifier
    // ---------------------------------------------------------------

    function test_anyVerifier_AllowsSingleSgxProof() external {
        bytes memory data = _encodeProof(_toArray(SGX_RETH), _toBytesArray(bytes("sgx")));

        vm.expectCall(
            address(sgx),
            abi.encodeCall(IProofVerifier.verifyProof, (0, TRANSITIONS_HASH, bytes("sgx")))
        );

        anyVerifier.verifyProof(0, TRANSITIONS_HASH, data);
    }

    function test_anyVerifier_RevertWhen_InvalidVerifierId() external {
        bytes memory data = _encodeProof(_toArray(NONE), _toBytesArray(bytes("bad")));

        vm.expectRevert(ComposeVerifier.CV_INVALID_SUB_VERIFIER.selector);
        anyVerifier.verifyProof(0, TRANSITIONS_HASH, data);
    }

    function test_anyVerifier_RevertWhen_TooManyVerifiers() external {
        bytes memory data =
            _encodeProof(_toArray(SGX_RETH, RISC0_RETH), _toBytesArray(bytes("sgx"), bytes("r0")));

        vm.expectCall(
            address(sgx),
            abi.encodeCall(IProofVerifier.verifyProof, (0, TRANSITIONS_HASH, bytes("sgx")))
        );
        vm.expectCall(
            address(risc0),
            abi.encodeCall(IProofVerifier.verifyProof, (0, TRANSITIONS_HASH, bytes("r0")))
        );

        vm.expectRevert(ComposeVerifier.CV_VERIFIERS_INSUFFICIENT.selector);
        anyVerifier.verifyProof(0, TRANSITIONS_HASH, data);
    }

    function test_anyVerifier_RevertWhen_OrderNotIncreasing() external {
        bytes memory data =
            _encodeProof(_toArray(SGX_RETH, SGX_RETH), _toBytesArray(bytes("a"), bytes("b")));

        vm.expectCall(
            address(sgx),
            abi.encodeCall(IProofVerifier.verifyProof, (0, TRANSITIONS_HASH, bytes("a")))
        );

        vm.expectRevert(ComposeVerifier.CV_INVALID_SUB_VERIFIER_ORDER.selector);
        anyVerifier.verifyProof(0, TRANSITIONS_HASH, data);
    }

    // ---------------------------------------------------------------
    // AnyTwoVerifier
    // ---------------------------------------------------------------

    function test_anyTwoVerifier_AllowsSgxAndRisc0() external {
        bytes memory data =
            _encodeProof(_toArray(SGX_RETH, RISC0_RETH), _toBytesArray(bytes("sgx"), bytes("r0")));

        vm.expectCall(
            address(sgx),
            abi.encodeCall(IProofVerifier.verifyProof, (0, TRANSITIONS_HASH, bytes("sgx")))
        );
        vm.expectCall(
            address(risc0),
            abi.encodeCall(IProofVerifier.verifyProof, (0, TRANSITIONS_HASH, bytes("r0")))
        );

        anyTwoVerifier.verifyProof(0, TRANSITIONS_HASH, data);
    }

    function test_anyTwoVerifier_RevertWhen_OrderNotIncreasing() external {
        bytes memory data =
            _encodeProof(_toArray(SGX_RETH, SGX_RETH), _toBytesArray(bytes("sgx"), bytes("sgx2")));

        vm.expectCall(
            address(sgx),
            abi.encodeCall(IProofVerifier.verifyProof, (0, TRANSITIONS_HASH, bytes("sgx")))
        );

        vm.expectRevert(ComposeVerifier.CV_INVALID_SUB_VERIFIER_ORDER.selector);
        anyTwoVerifier.verifyProof(0, TRANSITIONS_HASH, data);
    }

    // ---------------------------------------------------------------
    // SgxAndZkVerifier
    // ---------------------------------------------------------------

    function test_sgxAndZkVerifier_AllowsSgxAndSp1() external {
        bytes memory data =
            _encodeProof(_toArray(SGX_RETH, SP1_RETH), _toBytesArray(bytes("sgx"), bytes("sp1")));

        vm.expectCall(
            address(sgx),
            abi.encodeCall(IProofVerifier.verifyProof, (0, TRANSITIONS_HASH, bytes("sgx")))
        );
        vm.expectCall(
            address(sp1),
            abi.encodeCall(IProofVerifier.verifyProof, (0, TRANSITIONS_HASH, bytes("sp1")))
        );

        sgxAndZkVerifier.verifyProof(0, TRANSITIONS_HASH, data);
    }

    function test_sgxAndZkVerifier_RevertWhen_SgxNotFirst() external {
        bytes memory data =
            _encodeProof(_toArray(RISC0_RETH, SP1_RETH), _toBytesArray(bytes("r0"), bytes("sp1")));

        vm.expectCall(
            address(risc0),
            abi.encodeCall(IProofVerifier.verifyProof, (0, TRANSITIONS_HASH, bytes("r0")))
        );
        vm.expectCall(
            address(sp1),
            abi.encodeCall(IProofVerifier.verifyProof, (0, TRANSITIONS_HASH, bytes("sp1")))
        );

        vm.expectRevert(ComposeVerifier.CV_VERIFIERS_INSUFFICIENT.selector);
        sgxAndZkVerifier.verifyProof(0, TRANSITIONS_HASH, data);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _encodeProof(
        uint8[] memory ids,
        bytes[] memory payloads
    )
        private
        pure
        returns (bytes memory)
    {
        ComposeVerifier.SubProof[] memory proofs = new ComposeVerifier.SubProof[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            proofs[i] = ComposeVerifier.SubProof({ verifierId: ids[i], proof: payloads[i] });
        }
        return abi.encode(proofs);
    }

    function _toArray(uint8 a) private pure returns (uint8[] memory arr) {
        arr = new uint8[](1);
        arr[0] = a;
    }

    function _toArray(uint8 a, uint8 b) private pure returns (uint8[] memory arr) {
        arr = new uint8[](2);
        arr[0] = a;
        arr[1] = b;
    }

    function _toBytesArray(bytes memory a) private pure returns (bytes[] memory arr) {
        arr = new bytes[](1);
        arr[0] = a;
    }

    function _toBytesArray(
        bytes memory a,
        bytes memory b
    )
        private
        pure
        returns (bytes[] memory arr)
    {
        arr = new bytes[](2);
        arr[0] = a;
        arr[1] = b;
    }
}
