// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/src/Test.sol";
import { AzureTdxVerifier } from "src/layer1/verifiers/AzureTdxVerifier.sol";
import { GcpTdxVerifier } from "src/layer1/verifiers/GcpTdxVerifier.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { LibPublicInput } from "src/layer1/verifiers/LibPublicInput.sol";

contract TdxVerifierTest is Test {
    uint64 private constant CHAIN_ID = 167_001;

    GcpTdxVerifier internal gcpVerifier;
    AzureTdxVerifier internal azureVerifier;

    function setUp() external {
        gcpVerifier = GcpTdxVerifier(
            address(
                new ERC1967Proxy(
                    address(new GcpTdxVerifier(CHAIN_ID, address(0xDCa1))),
                    abi.encodeCall(GcpTdxVerifier.init, (address(this)))
                )
            )
        );
        azureVerifier = AzureTdxVerifier(
            address(
                new ERC1967Proxy(
                    address(new AzureTdxVerifier(CHAIN_ID, address(0xDCa1))),
                    abi.encodeCall(AzureTdxVerifier.init, (address(this)))
                )
            )
        );
    }

    function test_gcpVerifyProof_SucceedsWithAddressKeyedProof() external {
        _assertAddressKeyedProofSucceeds(gcpVerifier, 0xA11CE);
    }

    function test_azureVerifyProof_SucceedsWithAddressKeyedProof() external {
        _assertAddressKeyedProofSucceeds(azureVerifier, 0xB0B);
    }

    function test_gcpVerifyProof_RevertWhen_InstanceAddressUnknown() external {
        bytes32 commitmentHash = bytes32(uint256(0x1234));
        bytes memory proof = _signAddressKeyedProof(gcpVerifier, 0xA11CE, commitmentHash);

        vm.expectRevert(GcpTdxVerifier.TDX_INVALID_INSTANCE.selector);
        gcpVerifier.verifyProof(0, commitmentHash, proof);
    }

    function _assertAddressKeyedProofSucceeds(
        IProofVerifier verifier,
        uint256 instanceKey
    )
        private
    {
        address instance = vm.addr(instanceKey);
        address[] memory instances = new address[](1);
        instances[0] = instance;

        if (address(verifier) == address(gcpVerifier)) {
            gcpVerifier.addInstances(instances);
        } else {
            azureVerifier.addInstances(instances);
        }

        bytes32 commitmentHash = bytes32(uint256(0x1234));
        bytes memory proof = _signAddressKeyedProof(verifier, instanceKey, commitmentHash);

        verifier.verifyProof(0, commitmentHash, proof);
    }

    function _signAddressKeyedProof(
        IProofVerifier verifier,
        uint256 instanceKey,
        bytes32 commitmentHash
    )
        private
        pure
        returns (bytes memory proof)
    {
        address instance = vm.addr(instanceKey);
        bytes32 signatureHash =
            LibPublicInput.hashPublicInputs(commitmentHash, address(verifier), instance, CHAIN_ID);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(instanceKey, signatureHash);

        proof = abi.encodePacked(bytes20(instance), r, s, v);
        assertEq(proof.length, 85);
    }
}
