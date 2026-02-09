// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import { IAttestation } from "src/layer1/automata-attestation/interfaces/IAttestation.sol";
import { V3Struct } from "src/layer1/automata-attestation/lib/QuoteV3Auth/V3Struct.sol";
import { LibPublicInput } from "src/layer1/verifiers/LibPublicInput.sol";
import { SgxVerifier } from "src/layer1/verifiers/SgxVerifier.sol";

contract MockAttestation is IAttestation {
    bool private _shouldSucceed;

    function setResult(bool _result) external {
        _shouldSucceed = _result;
    }

    function verifyAttestation(bytes calldata) external view override returns (bool) {
        return _shouldSucceed;
    }

    function verifyParsedQuote(V3Struct.ParsedV3QuoteStruct calldata)
        external
        view
        override
        returns (bool success, bytes memory retData)
    {
        return (_shouldSucceed, "");
    }
}

contract SgxVerifierTest is Test {
    uint64 private constant CHAIN_ID = 167;

    MockAttestation internal attestation;
    SgxVerifier internal verifier;

    function setUp() external {
        attestation = new MockAttestation();
        verifier = new SgxVerifier(CHAIN_ID, address(this), address(attestation));
    }

    // ---------------------------------------------------------------
    // Instance management
    // ---------------------------------------------------------------

    function test_addInstances_StoresEntries() external {
        address instance1 = address(0xA11CE);
        address instance2 = address(0xB0B);
        address[] memory instances = new address[](2);
        instances[0] = instance1;
        instances[1] = instance2;

        vm.expectEmit(true, true, true, true);
        emit SgxVerifier.InstanceAdded(0, instance1, address(0), block.timestamp);
        vm.expectEmit(true, true, true, true);
        emit SgxVerifier.InstanceAdded(1, instance2, address(0), block.timestamp);

        verifier.addInstances(instances);

        (address stored1, uint64 validSince1) = verifier.instances(0);
        (address stored2, uint64 validSince2) = verifier.instances(1);

        assertEq(stored1, instance1);
        assertEq(stored2, instance2);
        assertEq(validSince1, uint64(block.timestamp));
        assertEq(validSince2, uint64(block.timestamp));
    }

    function test_addInstances_RevertWhen_DuplicateAddress() external {
        address[] memory instances = new address[](1);
        instances[0] = address(0xA11CE);
        verifier.addInstances(instances);

        vm.expectRevert(SgxVerifier.SGX_ALREADY_ATTESTED.selector);
        verifier.addInstances(instances);
    }

    function test_deleteInstances_RemovesInstance() external {
        address[] memory instances = new address[](2);
        instances[0] = address(0xA11CE);
        instances[1] = address(0xB0B);
        verifier.addInstances(instances);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;

        vm.expectEmit(true, true, false, false);
        emit SgxVerifier.InstanceDeleted(0, instances[0]);

        verifier.deleteInstances(ids);

        (address stored,) = verifier.instances(0);
        assertEq(stored, address(0));
    }

    function test_registerInstance_AddsWhenAttestationValid() external {
        attestation.setResult(true);
        address newInstance = address(0xC0FFEE);

        vm.expectEmit(true, true, true, true);
        emit SgxVerifier.InstanceAdded(0, newInstance, address(0), block.timestamp);

        uint256 id = verifier.registerInstance(_makeQuote(newInstance));
        assertEq(id, 0);

        (address stored, uint64 validSince) = verifier.instances(id);
        assertEq(stored, newInstance);
        assertEq(validSince, uint64(block.timestamp));
    }

    function test_registerInstance_RevertWhen_AttestationInvalid() external {
        attestation.setResult(false);
        address newInstance = address(0xDEAD);

        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(_makeQuote(newInstance));
    }

    // ---------------------------------------------------------------
    // Proof verification
    // ---------------------------------------------------------------

    function test_verifyProof_SucceedsWithValidSignature() external {
        uint256 instanceKey = 0xA11CE;

        (bytes memory proof, bytes32 aggregatedHash) = _prepareValidProof(instanceKey);

        verifier.verifyProof(0, aggregatedHash, proof);
    }

    function test_verifyProof_RevertWhen_ProofLengthInvalid() external {
        vm.expectRevert(SgxVerifier.SGX_INVALID_PROOF.selector);
        verifier.verifyProof(0, bytes32(uint256(1)), hex"1234");
    }

    function test_verifyProof_RevertWhen_InstanceIdUnknown() external {
        uint256 instanceKey = 0xA11CE;
        // Prepare valid proof to ensure only id mismatch triggers failure.
        (bytes memory proof,) = _prepareValidProof(instanceKey);

        bytes memory badIdProof = new bytes(proof.length);
        bytes memory newId = abi.encodePacked(uint32(1));
        for (uint256 i; i < 4; ++i) {
            badIdProof[i] = newId[i];
        }
        for (uint256 i; i < proof.length - 4; ++i) {
            badIdProof[i + 4] = proof[i + 4];
        }

        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, bytes32(uint256(1)), badIdProof);
    }

    function test_verifyProof_RevertWhen_AggregatedHashZero() external {
        uint256 instanceKey = 0xA11CE;

        (bytes memory proof,) = _prepareValidProof(instanceKey);

        vm.expectRevert(LibPublicInput.InvalidAggregatedProvingHash.selector);
        verifier.verifyProof(0, bytes32(0), proof);
    }

    function test_verifyProof_RevertWhen_InstanceExpired() external {
        uint256 instanceKey = 0xA11CE;

        (bytes memory proof, bytes32 aggregatedHash) = _prepareValidProof(instanceKey);

        vm.warp(block.timestamp + uint256(verifier.INSTANCE_EXPIRY()) + 1);

        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggregatedHash, proof);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _makeQuote(address _instance)
        private
        pure
        returns (V3Struct.ParsedV3QuoteStruct memory quote)
    {
        bytes memory padding = new bytes(44);
        quote.localEnclaveReport.reportData =
            bytes.concat(abi.encodePacked(bytes20(_instance)), padding);
    }

    function _prepareValidProof(uint256 instanceKey)
        private
        returns (bytes memory proof, bytes32 aggregatedHash)
    {
        address instance = vm.addr(instanceKey);

        address[] memory instances = new address[](1);
        instances[0] = instance;
        verifier.addInstances(instances);

        aggregatedHash = bytes32(uint256(0x1234));
        bytes32 signatureHash = LibPublicInput.hashPublicInputs(
            aggregatedHash, address(verifier), instance, CHAIN_ID
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(instanceKey, signatureHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        proof = abi.encodePacked(uint32(0), bytes20(instance), signature);
    }
}
