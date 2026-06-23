// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import { IAttestation } from "src/layer1/automata-attestation/interfaces/IAttestation.sol";
import { V3Struct } from "src/layer1/automata-attestation/lib/QuoteV3Auth/V3Struct.sol";
import { TCBInfoStruct } from "src/layer1/automata-attestation/lib/TCBInfoStruct.sol";
import { InsecureSgxVerifier } from "src/layer1/verifiers/InsecureSgxVerifier.sol";
import { LibPublicInput } from "src/layer1/verifiers/LibPublicInput.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
import { SgxVerifier } from "src/layer1/verifiers/SgxVerifier.sol";

contract MockAttestation is IAttestation {
    bool private _shouldSucceed;
    uint8 private _tcbStatus;

    function setResult(bool _result) external {
        _shouldSucceed = _result;
    }

    function setTcbStatus(uint8 _status) external {
        _tcbStatus = _status;
    }

    function verifyAttestation(bytes calldata) external view override returns (bool) {
        return _shouldSucceed;
    }

    function verifyParsedQuote(V3Struct.ParsedV3QuoteStruct calldata _quote)
        external
        view
        override
        returns (bool success, bytes memory retData)
    {
        // Mirror AutomataDcapV3Attestation: on a successful verification the return data is
        // abi.encodePacked(sha256(quote), uint8 tcbStatus), so the TCB status is the 33rd byte.
        return (_shouldSucceed, abi.encodePacked(sha256(abi.encode(_quote)), _tcbStatus));
    }
}

/// @dev Shared test suite for every `SgxVerifier` subclass. Concrete subclasses only supply the
/// verifier under test via `_deployVerifier`, so each subclass is exercised against the full suite.
abstract contract SgxVerifierTestBase is Test {
    uint64 internal constant CHAIN_ID = 167;

    MockAttestation internal attestation;
    SgxVerifier internal verifier;

    function setUp() external {
        attestation = new MockAttestation();
        // registrar is address(0): registerInstance is permissionless.
        verifier = _deployVerifier(CHAIN_ID, address(this), address(attestation), address(0));
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

    function test_registerInstance_RevertWhen_DebugModeEnabled() external {
        attestation.setResult(true);
        address newInstance = address(0xC0FFEE);

        V3Struct.ParsedV3QuoteStruct memory quote = _makeQuote(newInstance);
        quote.localEnclaveReport.attributes = bytes16(0x07000000000000000700000000000000);

        vm.expectRevert(SgxVerifier.SGX_FORBIDDEN_ATTRIBUTES.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_ProvisionKeyEnabled() external {
        attestation.setResult(true);
        address newInstance = address(0xC0FFEE);

        V3Struct.ParsedV3QuoteStruct memory quote = _makeQuote(newInstance);
        quote.localEnclaveReport.attributes = bytes16(0x10000000000000000000000000000000);

        vm.expectRevert(SgxVerifier.SGX_FORBIDDEN_ATTRIBUTES.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_AllowsDebugBitOutsideFlagsByte() external {
        attestation.setResult(true);
        address newInstance = address(0xC0FFEE);

        V3Struct.ParsedV3QuoteStruct memory quote = _makeQuote(newInstance);
        quote.localEnclaveReport.attributes = bytes16(0x00020000000000000000000000000000);

        uint256 id = verifier.registerInstance(quote);
        assertEq(id, 0);
    }

    function test_registerInstance_AllowsProductionAttributes() external {
        attestation.setResult(true);
        address newInstance = address(0xC0FFEE);

        V3Struct.ParsedV3QuoteStruct memory quote = _makeQuote(newInstance);
        quote.localEnclaveReport.attributes = bytes16(0x0500000000000000e700000000000000);

        uint256 id = verifier.registerInstance(quote);
        assertEq(id, 0);
    }

    function test_registerInstance_AcceptsSwHardeningNeededTcb() external {
        // `TCB_SW_HARDENING_NEEDED` is an up-to-date status accepted by every network policy.
        attestation.setResult(true);
        attestation.setTcbStatus(uint8(TCBInfoStruct.TCBStatus.TCB_SW_HARDENING_NEEDED));

        uint256 id = verifier.registerInstance(_makeQuote(address(0xC0FFEE)));
        assertEq(id, 0);
    }

    function test_registerInstance_AllowsRegistrarWhenSet() external {
        address registrar = address(0x5151);
        SgxVerifier gatedVerifier =
            _deployVerifier(CHAIN_ID, address(this), address(attestation), registrar);

        attestation.setResult(true);
        address newInstance = address(0xC0FFEE);

        vm.expectEmit(true, true, true, true);
        emit SgxVerifier.InstanceAdded(0, newInstance, address(0), block.timestamp);

        vm.prank(registrar);
        uint256 id = gatedVerifier.registerInstance(_makeQuote(newInstance));
        assertEq(id, 0);

        (address stored,) = gatedVerifier.instances(id);
        assertEq(stored, newInstance);
    }

    function test_registerInstance_RevertWhen_CallerNotRegistrar() external {
        address registrar = address(0x5151);
        SgxVerifier gatedVerifier =
            _deployVerifier(CHAIN_ID, address(this), address(attestation), registrar);

        attestation.setResult(true);

        vm.expectRevert(SgxVerifier.SGX_NOT_REGISTRAR.selector);
        vm.prank(address(0xBAD));
        gatedVerifier.registerInstance(_makeQuote(address(0xC0FFEE)));
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

    /// @dev Deploys the concrete `SgxVerifier` subclass under test.
    function _deployVerifier(
        uint64 _chainId,
        address _owner,
        address _attestation,
        address _registrar
    )
        internal
        virtual
        returns (SgxVerifier);

    function _makeQuote(address _instance)
        internal
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

contract SecureSgxVerifierTest is SgxVerifierTestBase {
    function _deployVerifier(
        uint64 _chainId,
        address _owner,
        address _attestation,
        address _registrar
    )
        internal
        override
        returns (SgxVerifier)
    {
        return new SecureSgxVerifier(_chainId, _owner, _attestation, _registrar);
    }

    function test_registerInstance_RevertWhen_TcbOutOfDate() external {
        // The strict mainnet policy rejects out-of-date platforms even though the attestation's own
        // (lenient) check accepts them.
        attestation.setResult(true);
        attestation.setTcbStatus(uint8(TCBInfoStruct.TCBStatus.TCB_OUT_OF_DATE));

        vm.expectRevert(SgxVerifier.SGX_INVALID_TCB_STATUS.selector);
        verifier.registerInstance(_makeQuote(address(0xC0FFEE)));
    }

    function test_isTcbStatusAccepted_StrictPolicy() external view {
        assertTrue(verifier.isTcbStatusAccepted(uint8(TCBInfoStruct.TCBStatus.OK)));
        assertTrue(
            verifier.isTcbStatusAccepted(uint8(TCBInfoStruct.TCBStatus.TCB_SW_HARDENING_NEEDED))
        );
        assertTrue(
            verifier.isTcbStatusAccepted(
                uint8(TCBInfoStruct.TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED)
            )
        );
        assertFalse(verifier.isTcbStatusAccepted(uint8(TCBInfoStruct.TCBStatus.TCB_OUT_OF_DATE)));
        assertFalse(verifier.isTcbStatusAccepted(uint8(TCBInfoStruct.TCBStatus.TCB_REVOKED)));
    }

    /// @dev `OK` is enum index 0 and the policy uses exact equality, so it is matched only by the
    /// byte 0 - never over-scoped onto another status. Exhaustively check all 256 possible status
    /// bytes: exactly {OK, TCB_SW_HARDENING_NEEDED, TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED} are
    /// accepted; every other value (the out-of-date statuses and any out-of-enum byte) is rejected.
    function test_isTcbStatusAccepted_StrictPolicyIsExact() external view {
        assertEq(uint8(TCBInfoStruct.TCBStatus.OK), 0);
        for (uint256 s; s <= type(uint8).max; ++s) {
            bool expected = s == uint8(TCBInfoStruct.TCBStatus.OK)
                || s == uint8(TCBInfoStruct.TCBStatus.TCB_SW_HARDENING_NEEDED)
                || s == uint8(TCBInfoStruct.TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED);
            assertEq(verifier.isTcbStatusAccepted(uint8(s)), expected);
        }
    }
}

contract InsecureSgxVerifierTest is SgxVerifierTestBase {
    function _deployVerifier(
        uint64 _chainId,
        address _owner,
        address _attestation,
        address _registrar
    )
        internal
        override
        returns (SgxVerifier)
    {
        return new InsecureSgxVerifier(_chainId, _owner, _attestation, _registrar);
    }

    function test_registerInstance_AcceptsOutOfDateTcb() external {
        // The lenient testnet policy accepts out-of-date platforms for dev-hardware liveness.
        attestation.setResult(true);
        attestation.setTcbStatus(uint8(TCBInfoStruct.TCBStatus.TCB_OUT_OF_DATE));

        uint256 id = verifier.registerInstance(_makeQuote(address(0xC0FFEE)));
        assertEq(id, 0);
    }

    function test_isTcbStatusAccepted_LenientPolicy() external view {
        assertTrue(verifier.isTcbStatusAccepted(uint8(TCBInfoStruct.TCBStatus.OK)));
        assertTrue(verifier.isTcbStatusAccepted(uint8(TCBInfoStruct.TCBStatus.TCB_OUT_OF_DATE)));
        assertTrue(
            verifier.isTcbStatusAccepted(
                uint8(TCBInfoStruct.TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED)
            )
        );
        assertFalse(verifier.isTcbStatusAccepted(uint8(TCBInfoStruct.TCBStatus.TCB_REVOKED)));
    }

    /// @dev Exhaustively check all 256 possible status bytes: the lenient policy accepts exactly the
    /// up-to-date statuses plus the out-of-date statuses, and rejects everything else
    /// (config-needed, revoked, unrecognized, and any out-of-enum byte) - exact, not over-scoped.
    function test_isTcbStatusAccepted_LenientPolicyIsExact() external view {
        for (uint256 s; s <= type(uint8).max; ++s) {
            bool expected = s == uint8(TCBInfoStruct.TCBStatus.OK)
                || s == uint8(TCBInfoStruct.TCBStatus.TCB_SW_HARDENING_NEEDED)
                || s == uint8(TCBInfoStruct.TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED)
                || s == uint8(TCBInfoStruct.TCBStatus.TCB_OUT_OF_DATE)
                || s == uint8(TCBInfoStruct.TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED);
            assertEq(verifier.isTcbStatusAccepted(uint8(s)), expected);
        }
    }
}
