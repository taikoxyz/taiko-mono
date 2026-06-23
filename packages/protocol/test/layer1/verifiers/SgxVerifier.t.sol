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

    /// @dev MRENCLAVE carried by every quote built with `_makeQuote`.
    bytes32 internal constant MR_ENCLAVE = bytes32(uint256(0xE5C1A5E));
    /// @dev The universal forbidden-attribute floor (DEBUG | PROVISION_KEY | EINITTOKEN_KEY),
    /// mirroring `SgxVerifier.SGX_FORBIDDEN_ATTRIBUTE_MASK`.
    bytes16 internal constant FORBIDDEN_FLOOR = bytes16(0x32000000000000000000000000000000);

    MockAttestation internal attestation;
    SgxVerifier internal verifier;

    function setUp() external {
        attestation = new MockAttestation();
        // registrar is address(0): registerInstance is permissionless.
        verifier = _deployVerifier(CHAIN_ID, address(this), address(attestation), address(0), 0);
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

    function test_registerInstance_RevertWhen_LaunchKeyEnabled() external {
        attestation.setResult(true);

        V3Struct.ParsedV3QuoteStruct memory quote = _makeQuote(address(0xC0FFEE));
        // EINITTOKEN_KEY (launch-token key) is bit 5 (0x20) of the FLAGS byte.
        quote.localEnclaveReport.attributes = bytes16(0x20000000000000000000000000000000);

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
            _deployVerifier(CHAIN_ID, address(this), address(attestation), registrar, 0);

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
            _deployVerifier(CHAIN_ID, address(this), address(attestation), registrar, 0);

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
    // Instance-validity delay
    // ---------------------------------------------------------------

    function test_registerInstance_AppliesValidityDelay() external {
        uint64 delay = 24 hours;
        SgxVerifier delayed =
            _deployVerifier(CHAIN_ID, address(this), address(attestation), address(0), delay);
        attestation.setResult(true);

        uint256 id = delayed.registerInstance(_makeQuote(address(0xC0FFEE)));
        (, uint64 validSince) = delayed.instances(id);
        assertEq(validSince, uint64(block.timestamp) + delay);
    }

    function test_addInstances_IgnoresValidityDelay() external {
        uint64 delay = 24 hours;
        SgxVerifier delayed =
            _deployVerifier(CHAIN_ID, address(this), address(attestation), address(0), delay);

        address[] memory instances = new address[](1);
        instances[0] = address(0xA11CE);
        delayed.addInstances(instances);

        // Owner registrations are trusted and take effect immediately, ignoring the delay.
        (, uint64 validSince) = delayed.instances(0);
        assertEq(validSince, uint64(block.timestamp));
    }

    function test_verifyProof_RevertWhen_WithinValidityDelay() external {
        uint64 delay = 24 hours;
        SgxVerifier delayed =
            _deployVerifier(CHAIN_ID, address(this), address(attestation), address(0), delay);
        attestation.setResult(true);

        uint256 key = 0xA11CE;
        address instance = vm.addr(key);
        uint256 id = delayed.registerInstance(_makeQuote(instance));

        bytes32 aggregatedHash = bytes32(uint256(0x1234));
        bytes32 signatureHash =
            LibPublicInput.hashPublicInputs(aggregatedHash, address(delayed), instance, CHAIN_ID);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, signatureHash);
        bytes memory proof = abi.encodePacked(uint32(id), bytes20(instance), r, s, v);

        // Still inside the validity delay: the self-registered instance cannot prove yet.
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        delayed.verifyProof(0, aggregatedHash, proof);

        // After the delay elapses, the same proof is accepted.
        vm.warp(block.timestamp + delay);
        delayed.verifyProof(0, aggregatedHash, proof);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Deploys the concrete `SgxVerifier` subclass under test.
    function _deployVerifier(
        uint64 _chainId,
        address _owner,
        address _attestation,
        address _registrar,
        uint64 _validityDelay
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
        quote.localEnclaveReport.mrEnclave = MR_ENCLAVE;
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
    bytes32 private constant STRICT_MR = bytes32(uint256(0x57217C7));
    // Pin all 8 FLAGS bytes (XFRM left unchecked); require INIT|MODE64BIT and clear every other bit.
    bytes16 private constant STRICT_MASK = bytes16(0xffffffffffffffff0000000000000000);
    bytes16 private constant STRICT_EXPECTED = bytes16(0x05000000000000000000000000000000);
    // A non-zero registrar used by the dedicated role tests: besides the owner it may remove pins.
    address private constant REGISTRAR = address(0x9111A40);

    function _deployVerifier(
        uint64 _chainId,
        address _owner,
        address _attestation,
        address _registrar,
        uint64 _validityDelay
    )
        internal
        override
        returns (SgxVerifier)
    {
        SecureSgxVerifier secureVerifier =
            new SecureSgxVerifier(_chainId, _owner, _attestation, _registrar, _validityDelay);
        // Permissive-but-configured pin for the shared suite's MRENCLAVE: check only the forbidden
        // floor, so the shared tests exercise the floor exactly. The dedicated tests below pin
        // tighter against STRICT_MR. `_owner` owns the verifier, so impersonate it to configure.
        vm.prank(_owner);
        secureVerifier.setEnclaveAttributePolicy(MR_ENCLAVE, FORBIDDEN_FLOOR, bytes16(0));
        return secureVerifier;
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

    // ---------------------------------------------------------------
    // Per-MRENCLAVE ATTRIBUTES pin
    // ---------------------------------------------------------------

    function test_registerInstance_RevertWhen_EnclaveAttributesNotConfigured() external {
        // Fail closed: an MRENCLAVE with no configured pin cannot register, even with otherwise
        // valid production attributes.
        attestation.setResult(true);

        V3Struct.ParsedV3QuoteStruct memory quote = _makeQuote(address(0xC0FFEE));
        quote.localEnclaveReport.mrEnclave = bytes32(uint256(0xDEADBEEF));
        quote.localEnclaveReport.attributes = bytes16(0x05000000000000000000000000000000);

        vm.expectRevert(SecureSgxVerifier.SGX_ATTRIBUTE_POLICY_NOT_SET.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_AttributesViolateStrictPolicy() external {
        SecureSgxVerifier(address(verifier))
            .setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);
        attestation.setResult(true);

        V3Struct.ParsedV3QuoteStruct memory quote = _makeQuote(address(0xC0FFEE));
        quote.localEnclaveReport.mrEnclave = STRICT_MR;
        // A bit set outside FLAGS byte 0 - allowed by the global deny-mask, but rejected by the pin
        // (and it also fails to assert the required INIT|MODE64BIT).
        quote.localEnclaveReport.attributes = bytes16(0x00020000000000000000000000000000);

        vm.expectRevert(SecureSgxVerifier.SGX_ATTRIBUTE_MISMATCH.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_SucceedsWhen_AttributesMatchStrictPolicy() external {
        SecureSgxVerifier(address(verifier))
            .setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);
        attestation.setResult(true);
        address newInstance = address(0xC0FFEE);

        V3Struct.ParsedV3QuoteStruct memory quote = _makeQuote(newInstance);
        quote.localEnclaveReport.mrEnclave = STRICT_MR;
        // INIT|MODE64BIT in FLAGS; AVX bits in XFRM (XFRM is not checked by STRICT_MASK).
        quote.localEnclaveReport.attributes = bytes16(0x05000000000000000700000000000000);

        vm.expectEmit(true, true, true, true);
        emit SgxVerifier.InstanceAdded(0, newInstance, address(0), block.timestamp);
        uint256 id = verifier.registerInstance(quote);
        assertEq(id, 0);
    }

    function test_setEnclaveAttributePolicy_RevertWhen_NotOwner() external {
        vm.prank(address(0xBAD));
        vm.expectRevert(); // Ownable2Step: caller is not the owner.
        SecureSgxVerifier(address(verifier))
            .setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);
    }

    function test_setEnclaveAttributePolicy_RevertWhen_ExpectedOutsideMask() external {
        bytes16 mask = bytes16(0xff000000000000000000000000000000); // checks byte 0 only
        bytes16 expected = bytes16(0x00010000000000000000000000000000); // asserts a byte-1 bit
        vm.expectRevert(SecureSgxVerifier.SGX_INVALID_ATTRIBUTE_POLICY.selector);
        SecureSgxVerifier(address(verifier)).setEnclaveAttributePolicy(STRICT_MR, mask, expected);
    }

    function test_setEnclaveAttributePolicy_RevertWhen_MaskMissesForbiddenBit() external {
        bytes16 mask = bytes16(0x01000000000000000000000000000000); // checks INIT, not the floor
        vm.expectRevert(SecureSgxVerifier.SGX_INVALID_ATTRIBUTE_POLICY.selector);
        SecureSgxVerifier(address(verifier)).setEnclaveAttributePolicy(STRICT_MR, mask, bytes16(0));
    }

    function test_setEnclaveAttributePolicy_RevertWhen_ExpectedHasForbiddenBit() external {
        // A pin that would *expect* DEBUG to be set must be rejected.
        bytes16 mask = bytes16(0xff000000000000000000000000000000);
        bytes16 expected = bytes16(0x02000000000000000000000000000000); // DEBUG
        vm.expectRevert(SecureSgxVerifier.SGX_INVALID_ATTRIBUTE_POLICY.selector);
        SecureSgxVerifier(address(verifier)).setEnclaveAttributePolicy(STRICT_MR, mask, expected);
    }

    function test_setEnclaveAttributePolicy_SetsAndEmits() external {
        vm.expectEmit(true, true, true, true);
        emit SecureSgxVerifier.EnclaveAttributePolicySet(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);
        SecureSgxVerifier(address(verifier))
            .setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);

        (bytes16 mask, bytes16 expected) =
            SecureSgxVerifier(address(verifier)).enclaveAttributePolicy(STRICT_MR);
        assertEq(bytes32(mask), bytes32(STRICT_MASK));
        assertEq(bytes32(expected), bytes32(STRICT_EXPECTED));
    }

    function test_removeEnclaveAttributePolicy_FailsClosedAfterRemoval() external {
        SecureSgxVerifier secure = SecureSgxVerifier(address(verifier));
        secure.setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);

        vm.expectEmit(true, true, true, true);
        emit SecureSgxVerifier.EnclaveAttributePolicyRemoved(STRICT_MR);
        secure.removeEnclaveAttributePolicy(STRICT_MR);

        (bytes16 mask,) = secure.enclaveAttributePolicy(STRICT_MR);
        assertEq(bytes32(mask), bytes32(0));

        attestation.setResult(true);
        V3Struct.ParsedV3QuoteStruct memory quote = _makeQuote(address(0xC0FFEE));
        quote.localEnclaveReport.mrEnclave = STRICT_MR;
        quote.localEnclaveReport.attributes = bytes16(0x05000000000000000000000000000000);
        vm.expectRevert(SecureSgxVerifier.SGX_ATTRIBUTE_POLICY_NOT_SET.selector);
        verifier.registerInstance(quote);
    }

    // ---------------------------------------------------------------
    // Registrar pin-removal role
    // ---------------------------------------------------------------

    /// @dev Deploys a SecureSgxVerifier owned by this test with `REGISTRAR` set, which besides the
    /// owner may remove pins.
    function _deployWithRegistrar() private returns (SecureSgxVerifier secure_) {
        secure_ = new SecureSgxVerifier(CHAIN_ID, address(this), address(attestation), REGISTRAR, 0);
        assertEq(secure_.registrar(), REGISTRAR);
    }

    function test_removeEnclaveAttributePolicy_ByRegistrar() external {
        SecureSgxVerifier secure = _deployWithRegistrar();
        secure.setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);

        // The registrar, not the owner, removes the pin.
        vm.expectEmit(true, true, true, true);
        emit SecureSgxVerifier.EnclaveAttributePolicyRemoved(STRICT_MR);
        vm.prank(REGISTRAR);
        secure.removeEnclaveAttributePolicy(STRICT_MR);

        (bytes16 mask,) = secure.enclaveAttributePolicy(STRICT_MR);
        assertEq(bytes32(mask), bytes32(0));
    }

    function test_removeEnclaveAttributePolicy_RevertWhen_NotOwnerOrRegistrar() external {
        SecureSgxVerifier secure = _deployWithRegistrar();
        secure.setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);

        vm.prank(address(0xBAD));
        vm.expectRevert(SecureSgxVerifier.SGX_NOT_AUTHORIZED.selector);
        secure.removeEnclaveAttributePolicy(STRICT_MR);
    }

    /// @dev The shared `verifier` has registrar == address(0), so removal is owner-only and a
    /// non-owner is rejected.
    function test_removeEnclaveAttributePolicy_RevertWhen_NoRegistrarConfigured() external {
        SecureSgxVerifier secure = SecureSgxVerifier(address(verifier));
        secure.setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);

        vm.prank(address(0xBAD));
        vm.expectRevert(SecureSgxVerifier.SGX_NOT_AUTHORIZED.selector);
        secure.removeEnclaveAttributePolicy(STRICT_MR);
    }

    /// @dev The registrar can only remove pins, never set them: setting stays owner-only.
    function test_setEnclaveAttributePolicy_RevertWhen_CalledByRegistrar() external {
        SecureSgxVerifier secure = _deployWithRegistrar();

        vm.prank(REGISTRAR);
        vm.expectRevert(); // Ownable2Step: caller is not the owner.
        secure.setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);
    }

    function test_constructor_RevertWhen_ValidityDelayTooLarge() external {
        uint64 tooLarge = uint64(verifier.INSTANCE_EXPIRY()) + 1;
        vm.expectRevert(SgxVerifier.SGX_INVALID_VALIDITY_DELAY.selector);
        new SecureSgxVerifier(CHAIN_ID, address(this), address(attestation), address(0), tooLarge);
    }
}

contract InsecureSgxVerifierTest is SgxVerifierTestBase {
    function _deployVerifier(
        uint64 _chainId,
        address _owner,
        address _attestation,
        address _registrar,
        uint64 _validityDelay
    )
        internal
        override
        returns (SgxVerifier)
    {
        return new InsecureSgxVerifier(_chainId, _owner, _attestation, _registrar, _validityDelay);
    }

    function test_constructor_RevertWhen_ValidityDelayTooLarge() external {
        uint64 tooLarge = uint64(verifier.INSTANCE_EXPIRY()) + 1;
        vm.expectRevert(SgxVerifier.SGX_INVALID_VALIDITY_DELAY.selector);
        new InsecureSgxVerifier(CHAIN_ID, address(this), address(attestation), address(0), tooLarge);
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
