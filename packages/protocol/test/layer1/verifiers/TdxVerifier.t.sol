// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/src/Test.sol";
import { AzureTdxVerifier } from "src/layer1/verifiers/AzureTdxVerifier.sol";
import { GcpTdxVerifier } from "src/layer1/verifiers/GcpTdxVerifier.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { LibPublicInput } from "src/layer1/verifiers/LibPublicInput.sol";

contract MockAutomataDcapAttestation {
    bool internal verified = true;
    bytes internal output;

    function setResult(bool _verified, bytes memory _output) external {
        verified = _verified;
        output = _output;
    }

    function verifyAndAttestOnChain(bytes calldata) external view returns (bool, bytes memory) {
        return (verified, output);
    }
}

contract TdxVerifierTest is Test {
    uint64 private constant CHAIN_ID = 167_001;
    uint256 private constant OFF_TEE_TCB_SVN = 11;
    uint256 private constant OFF_MR_SEAM = 27;
    uint256 private constant OFF_MR_TD = 147;
    uint256 private constant OFF_RTMR0 = 339;
    uint256 private constant OFF_REPORT_DATA = 531;

    MockAutomataDcapAttestation internal automata;
    GcpTdxVerifier internal gcpVerifier;
    AzureTdxVerifier internal azureVerifier;

    function setUp() external {
        automata = new MockAutomataDcapAttestation();
        gcpVerifier = GcpTdxVerifier(
            address(
                new ERC1967Proxy(
                    address(new GcpTdxVerifier(CHAIN_ID, address(automata))),
                    abi.encodeCall(GcpTdxVerifier.init, (address(this)))
                )
            )
        );
        azureVerifier = AzureTdxVerifier(
            address(
                new ERC1967Proxy(
                    address(new AzureTdxVerifier(CHAIN_ID, address(automata))),
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

    function test_gcpBootstrapRegistration_EnforcesTrustedParamsUpdates() external {
        GcpTdxVerifier.TrustedParams memory matchingParams = _gcpTrustedParams();
        GcpTdxVerifier.TrustedParams memory differentParams = _gcpTrustedParams();
        differentParams.mrTd = _filledBytes(0x09, 48);

        gcpVerifier.setTrustedParams(0, matchingParams);
        address firstInstance = vm.addr(0xA11CE1);
        _registerGcpBootstrap(firstInstance, "nonce-1", matchingParams);
        assertGt(gcpVerifier.addressValidSince(firstInstance), 0);
        assertTrue(gcpVerifier.isInstanceRegistered(firstInstance));

        gcpVerifier.setTrustedParams(0, differentParams);
        address secondInstance = vm.addr(0xB0B2);
        _setGcpBootstrapResult(secondInstance, "nonce-2", matchingParams);
        vm.expectRevert(GcpTdxVerifier.TDX_INVALID_MR_TD.selector);
        gcpVerifier.registerInstance(
            0, hex"1234", abi.encodePacked(bytes20(secondInstance)), "nonce-2"
        );
        assertEq(gcpVerifier.addressValidSince(secondInstance), 0);

        gcpVerifier.setTrustedParams(0, matchingParams);
        address thirdInstance = vm.addr(0xCAFE3);
        _registerGcpBootstrap(thirdInstance, "nonce-3", matchingParams);
        assertGt(gcpVerifier.addressValidSince(thirdInstance), 0);
        assertTrue(gcpVerifier.isInstanceRegistered(thirdInstance));
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

    function _registerGcpBootstrap(
        address instance,
        bytes memory nonce,
        GcpTdxVerifier.TrustedParams memory params
    )
        private
    {
        _setGcpBootstrapResult(instance, nonce, params);
        gcpVerifier.registerInstance(0, hex"1234", abi.encodePacked(bytes20(instance)), nonce);
    }

    function _setGcpBootstrapResult(
        address instance,
        bytes memory nonce,
        GcpTdxVerifier.TrustedParams memory params
    )
        private
    {
        bytes memory userData = abi.encodePacked(bytes20(instance));
        automata.setResult(true, _gcpAttestationOutput(params, userData, nonce));
    }

    function _gcpTrustedParams() private pure returns (GcpTdxVerifier.TrustedParams memory params) {
        bytes[] memory rtmrs = new bytes[](1);
        rtmrs[0] = _filledBytes(0x04, 48);

        params = GcpTdxVerifier.TrustedParams({
            teeTcbSvn: 0x0102030405060708090a0b0c0d0e0f10,
            rtmrMask: 1,
            mrSeam: _filledBytes(0x02, 48),
            mrTd: _filledBytes(0x03, 48),
            rtmrs: rtmrs
        });
    }

    function _gcpAttestationOutput(
        GcpTdxVerifier.TrustedParams memory params,
        bytes memory userData,
        bytes memory nonce
    )
        private
        pure
        returns (bytes memory output)
    {
        output = new bytes(595);
        output[1] = 0x04;
        output[3] = 0x02;

        _copy(output, OFF_TEE_TCB_SVN, abi.encodePacked(params.teeTcbSvn));
        _copy(output, OFF_MR_SEAM, params.mrSeam);
        _copy(output, OFF_MR_TD, params.mrTd);
        _copy(output, OFF_RTMR0, params.rtmrs[0]);
        _copy(output, OFF_REPORT_DATA, abi.encodePacked(sha256(bytes.concat(userData, nonce))));
    }

    function _filledBytes(uint8 value, uint256 size) private pure returns (bytes memory data) {
        data = new bytes(size);
        for (uint256 i; i < size; ++i) {
            data[i] = bytes1(value);
        }
    }

    function _copy(bytes memory dst, uint256 offset, bytes memory src) private pure {
        for (uint256 i; i < src.length; ++i) {
            dst[offset + i] = src[i];
        }
    }
}
