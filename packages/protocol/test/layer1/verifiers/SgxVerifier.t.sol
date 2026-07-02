// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TCBStatus } from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";
import "forge-std/src/Test.sol";
import { IDcapAttestation } from "src/layer1/verifiers/IDcapAttestation.sol";
import { InsecureSgxVerifier } from "src/layer1/verifiers/InsecureSgxVerifier.sol";
import { LibPublicInput } from "src/layer1/verifiers/LibPublicInput.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";
import { SgxVerifier } from "src/layer1/verifiers/SgxVerifier.sol";

/// @title SgxVerifierTestBase
/// @notice Shared raw-quote test suite exercised against every concrete `SgxVerifier` subclass.
/// It covers the logic that lives in the abstract base: raw-quote registration via the Automata
/// DCAP entrypoint, DEBUG-enclave rejection, the universal forbidden-attribute floor, the
/// MRENCLAVE/MRSIGNER allowlist, registrar gating, instance management and proof verification.
/// Concrete subclasses supply the verifier under test via `_deployVerifier`, so the suite runs
/// against both the strict `SecureSgxVerifier` and the lenient `InsecureSgxVerifier`; per-network
/// TCB-status and ATTRIBUTES-pin behaviour is asserted in the subclasses below.
/// @custom:security-contact security@taiko.xyz
abstract contract SgxVerifierTestBase is Test {
    uint64 internal constant CHAIN_ID = 167;
    address internal constant ATTESTATION = address(0xA11CE);

    // Bind the test's TCB codes to Automata's real FmspcTcbHelper.TCBStatus enum (pinned
    // @automata-network/on-chain-pccs). Every TCB test below therefore exercises the verifier's
    // hardcoded accept/reject policy against the actual enum values, so a future dependency bump
    // that reorders the enum breaks these tests instead of silently misclassifying statuses
    // on-chain. See also test_tcbStatusEnum_matchesExpectedValues.
    uint8 internal constant TCB_OK = uint8(TCBStatus.OK);
    uint8 internal constant TCB_SW_HARDENING = uint8(TCBStatus.TCB_SW_HARDENING_NEEDED);
    uint8 internal constant TCB_CONFIG_AND_SW_HARDENING =
        uint8(TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED);
    uint8 internal constant TCB_CONFIG_NEEDED = uint8(TCBStatus.TCB_CONFIGURATION_NEEDED); // rejected
    uint8 internal constant TCB_OUT_OF_DATE = uint8(TCBStatus.TCB_OUT_OF_DATE);
    uint8 internal constant TCB_OUT_OF_DATE_CONFIG =
        uint8(TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED);
    uint8 internal constant TCB_REVOKED = uint8(TCBStatus.TCB_REVOKED); // rejected
    uint8 internal constant TCB_UNRECOGNIZED = uint8(TCBStatus.TCB_UNRECOGNIZED); // rejected

    bytes32 internal constant MR_ENCLAVE = bytes32(uint256(0x1111));
    bytes32 internal constant MR_SIGNER = bytes32(uint256(0x2222));
    /// @dev The universal forbidden-attribute floor (DEBUG | PROVISION_KEY | EINITTOKEN_KEY),
    /// mirroring `SgxVerifier.SGX_FORBIDDEN_ATTRIBUTE_MASK`.
    bytes16 internal constant FORBIDDEN_FLOOR = bytes16(0x32000000000000000000000000000000);
    /// @dev DEBUG bit (bit 1) of the little-endian SGX ATTRIBUTES flags.
    bytes16 internal constant ATTR_DEBUG = bytes16(0x02000000000000000000000000000000);
    /// @dev A nominal positive validity delay; SecureSgxVerifier requires a positive delay. Owner
    /// registrations skip it, so it does not perturb the owner-driven shared tests.
    uint64 internal constant VALIDITY_DELAY = 1 hours;
    /// @dev A non-owner caller: the validity delay applies only to non-owner registrations.
    address internal constant NON_OWNER = address(0xBEEF11);

    SgxVerifier internal verifier;

    function setUp() external {
        // owner == address(this) so this test can call the onlyOwner admin functions.
        verifier = _deployVerifier(CHAIN_ID, address(this), ATTESTATION, address(0));
    }

    // ---------------------------------------------------------------
    // Subclass hooks
    // ---------------------------------------------------------------

    /// @dev Deploys the concrete `SgxVerifier` subclass under test, already configured so that a
    /// quote built with `_mockValidQuote` (MRENCLAVE == MR_ENCLAVE, zero ATTRIBUTES) passes the
    /// subclass's per-MRENCLAVE ATTRIBUTES policy. The MRENCLAVE/MRSIGNER allowlist is left
    /// unconfigured (enforced by default) so each test trusts exactly what it needs.
    function _deployVerifier(
        uint64 _chainId,
        address _owner,
        address _attestation,
        address _registrar
    )
        internal
        virtual
        returns (SgxVerifier);

    // ---------------------------------------------------------------
    // Raw-quote helpers
    // ---------------------------------------------------------------

    /// @dev Builds a 384-byte SGX enclave report with the given fields at their Intel-spec offsets.
    function _report(
        bytes16 attributes,
        bytes32 mrEnclave,
        bytes32 mrSigner,
        address instance
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory reportData = abi.encodePacked(bytes20(instance), new bytes(44)); // 64 bytes
        return abi.encodePacked(
            new bytes(48), // cpuSvn(16)+miscSelect(4)+reserved1(28)        [0:48]
            attributes, //                                                  [48:64]
            mrEnclave, //                                                   [64:96]
            bytes32(0), // reserved2                                        [96:128]
            mrSigner, //                                                    [128:160]
            new bytes(96), // reserved3                                     [160:256]
            new bytes(64), // isvProdId(2)+isvSvn(2)+reserved4(60)          [256:320]
            reportData //                                                   [320:384]
        );
    }

    /// @dev Builds a 432-byte raw quote (48-byte header + 384-byte SGX enclave report).
    function _rawQuote(
        bytes16 attributes,
        bytes32 mrEnclave,
        bytes32 mrSigner,
        address instance
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(new bytes(48), _report(attributes, mrEnclave, mrSigner, instance));
    }

    /// @dev Builds the serialized Automata `Output`: version(2,BE) | bodyType(2,BE) | tcbStatus(1)
    /// | fmspc(6) | quoteBody(384). The body must equal the raw quote's enclave report for the
    /// on-chain verified-body binding to pass.
    function _output(
        uint16 version,
        uint16 bodyType,
        uint8 tcbStatus,
        bytes memory report
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(version, bodyType, tcbStatus, bytes6(0), report);
    }

    function _mockAttest(bool verified, bytes memory output) internal {
        vm.mockCall(
            ATTESTATION,
            abi.encodeWithSelector(IDcapAttestation.verifyAndAttestOnChain.selector),
            abi.encode(verified, output)
        );
    }

    /// @dev Builds a raw quote and mocks the entrypoint to return a *matching* verified Output
    /// (body == the quote's enclave report, so the verified-body binding passes). Returns the quote.
    function _mockQuote(
        bytes16 attributes,
        bytes32 mrEnclave,
        bytes32 mrSigner,
        address instance,
        uint16 version,
        uint16 bodyType,
        uint8 tcbStatus
    )
        internal
        returns (bytes memory quote)
    {
        bytes memory report = _report(attributes, mrEnclave, mrSigner, instance);
        quote = abi.encodePacked(new bytes(48), report);
        _mockAttest(true, _output(version, bodyType, tcbStatus, report));
    }

    /// @dev Common valid case: non-debug, trusted MR values, V3/SGX/OK.
    function _mockValidQuote(address instance) internal returns (bytes memory) {
        return _mockQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, instance, 3, 1, TCB_OK);
    }

    /// @dev Trusts the standard MRENCLAVE/MRSIGNER on `verifier` so registrations pass the
    /// allowlist, which is enforced by default (checkLocalEnclaveReport == true).
    function _trustStandardEnclave() internal {
        _trustEnclaveOn(verifier);
    }

    /// @dev Trusts the standard MRENCLAVE/MRSIGNER on an arbitrary verifier instance.
    function _trustEnclaveOn(SgxVerifier _v) internal {
        _v.setMrEnclave(MR_ENCLAVE, true);
        _v.setMrSigner(MR_SIGNER, true);
    }

    // ---------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------

    function test_constructor_enablesLocalReportCheckByDefault() external view {
        assertTrue(verifier.checkLocalEnclaveReport());
    }

    // ---------------------------------------------------------------
    // registerInstance — happy path
    // ---------------------------------------------------------------

    function test_registerInstance_succeeds() external {
        _trustStandardEnclave();
        address instance = address(0xBEEF);
        bytes memory quote = _mockValidQuote(instance);

        // Owner registration is as trusted as addInstances, so it is immediately valid.
        vm.expectEmit();
        emit SgxVerifier.InstanceAdded(0, instance, address(0), block.timestamp);
        uint256 id = verifier.registerInstance(quote);

        assertEq(id, 0);
        (address addr, uint64 validSince,,,) = verifier.instances(0);
        assertEq(addr, instance);
        assertEq(validSince, uint64(block.timestamp));
        assertTrue(verifier.addressRegistered(instance));
        assertEq(verifier.nextInstanceId(), 1);
    }

    function test_registerInstance_acceptsAllAllowedTcbStatuses() external {
        _trustStandardEnclave();
        uint8[3] memory ok = [TCB_OK, TCB_SW_HARDENING, TCB_CONFIG_AND_SW_HARDENING];
        for (uint256 i; i < ok.length; ++i) {
            address instance = address(uint160(0x1000 + i));
            bytes memory quote =
                _mockQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, instance, 3, 1, ok[i]);
            verifier.registerInstance(quote);
            assertTrue(verifier.addressRegistered(instance));
        }
    }

    /// @notice Guards against silent TCB-status drift: pins Automata's TCBStatus enum to the exact
    /// numeric values the verifier's accept/reject policy is built on. If a future dependency bump
    /// reorders the enum, this fails loudly so the on-chain policy can be re-reviewed.
    function test_tcbStatusEnum_matchesExpectedValues() external pure {
        assertEq(uint256(uint8(TCBStatus.OK)), 0);
        assertEq(uint256(uint8(TCBStatus.TCB_SW_HARDENING_NEEDED)), 1);
        assertEq(uint256(uint8(TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED)), 2);
        assertEq(uint256(uint8(TCBStatus.TCB_CONFIGURATION_NEEDED)), 3);
        assertEq(uint256(uint8(TCBStatus.TCB_OUT_OF_DATE)), 4);
        assertEq(uint256(uint8(TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED)), 5);
        assertEq(uint256(uint8(TCBStatus.TCB_REVOKED)), 6);
        assertEq(uint256(uint8(TCBStatus.TCB_UNRECOGNIZED)), 7);
    }

    function test_registerInstance_doesNotForwardValue() external {
        _trustStandardEnclave();
        address instance = address(0xBEEF);
        bytes memory quote = _mockValidQuote(instance);

        // The entrypoint must be called with zero value: it runs feeless and registerInstance is
        // non-payable, so no ETH is ever forwarded.
        vm.expectCall(
            ATTESTATION,
            0,
            abi.encodeWithSelector(IDcapAttestation.verifyAndAttestOnChain.selector, quote)
        );
        verifier.registerInstance(quote);
        assertTrue(verifier.addressRegistered(instance));
    }

    // ---------------------------------------------------------------
    // registerInstance — registrar gating
    // ---------------------------------------------------------------

    function test_registerInstance_AllowsRegistrarWhenSet() external {
        address registrar = address(0x5151);
        SgxVerifier gated = _deployVerifier(CHAIN_ID, address(this), ATTESTATION, registrar);
        _trustEnclaveOn(gated);

        address instance = address(0xC0FFEE);
        bytes memory quote = _mockValidQuote(instance);

        // `validSince` (non-indexed) differs by subclass — a non-owner registration is delayed on
        // SecureSgxVerifier but immediate on InsecureSgxVerifier — so only check the indexed topics.
        vm.expectEmit(true, true, true, false);
        emit SgxVerifier.InstanceAdded(0, instance, address(0), block.timestamp);

        vm.prank(registrar);
        uint256 id = gated.registerInstance(quote);
        assertEq(id, 0);
        assertTrue(gated.addressRegistered(instance));
    }

    function test_registerInstance_RevertWhen_CallerNotRegistrar() external {
        address registrar = address(0x5151);
        SgxVerifier gated = _deployVerifier(CHAIN_ID, address(this), ATTESTATION, registrar);

        // The registrar gate reverts before any attestation work, so no entrypoint mock is needed.
        bytes memory quote = _rawQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, address(0xC0FFEE));
        vm.expectRevert(SgxVerifier.SGX_NOT_REGISTRAR.selector);
        vm.prank(address(0xBAD));
        gated.registerInstance(quote);
    }

    // ---------------------------------------------------------------
    // registerInstance — reverts
    // ---------------------------------------------------------------

    function test_registerInstance_RevertWhen_NotVerified() external {
        _mockAttest(false, bytes("some failure reason"));
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(_rawQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, address(0xBEEF)));
    }

    function test_registerInstance_RevertWhen_DebugEnclave() external {
        bytes memory quote =
            _mockQuote(ATTR_DEBUG, MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 1, TCB_OK);
        vm.expectRevert(SgxVerifier.SGX_DEBUG_ENCLAVE.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_ProvisionKeyEnabled() external {
        // PROVISION_KEY(0x10) is not DEBUG, so it passes the dedicated DEBUG guard and is caught by
        // the universal forbidden-attribute floor.
        bytes16 provisionKey = bytes16(0x10000000000000000000000000000000);
        bytes memory quote =
            _mockQuote(provisionKey, MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 1, TCB_OK);
        vm.expectRevert(SgxVerifier.SGX_FORBIDDEN_ATTRIBUTES.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_LaunchKeyEnabled() external {
        // EINITTOKEN_KEY(0x20) (launch-token key) is rejected by the universal forbidden floor.
        bytes16 launchKey = bytes16(0x20000000000000000000000000000000);
        bytes memory quote =
            _mockQuote(launchKey, MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 1, TCB_OK);
        vm.expectRevert(SgxVerifier.SGX_FORBIDDEN_ATTRIBUTES.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_AllowsDebugBitOutsideFlagsByte() external {
        // A 0x02 bit outside the FLAGS byte (here in byte 1) is not the DEBUG flag and must not be
        // rejected by the forbidden floor (which only checks byte 0).
        _trustStandardEnclave();
        bytes16 attributes = bytes16(0x00020000000000000000000000000000);
        bytes memory quote =
            _mockQuote(attributes, MR_ENCLAVE, MR_SIGNER, address(0xC0FFEE), 3, 1, TCB_OK);
        uint256 id = verifier.registerInstance(quote);
        assertEq(id, 0);
    }

    function test_registerInstance_RevertWhen_TcbRevoked() external {
        bytes memory quote =
            _mockQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 1, TCB_REVOKED);
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_TcbConfigNeeded() external {
        bytes memory quote =
            _mockQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 1, TCB_CONFIG_NEEDED);
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_TcbUnrecognized() external {
        bytes memory quote =
            _mockQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 1, TCB_UNRECOGNIZED);
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_WrongQuoteVersion() external {
        bytes memory quote =
            _mockQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 4, 1, TCB_OK);
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_WrongBodyType() external {
        bytes memory quote =
            _mockQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 2, TCB_OK);
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_OutputTooShort() external {
        _mockAttest(true, new bytes(10));
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(_rawQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, address(0xBEEF)));
    }

    function test_registerInstance_RevertWhen_VerifiedBodyMismatch() external {
        // Attestation succeeds and the Output header is well-formed (V3/SGX/OK), but its body does
        // not match the raw quote's enclave report — the verified-body binding must reject it.
        bytes memory quote = _rawQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, address(0xBEEF));
        _mockAttest(true, _output(3, 1, TCB_OK, new bytes(384))); // zero body != quote body
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_RawQuoteTooShort() external {
        _mockAttest(true, _output(3, 1, TCB_OK, new bytes(384)));
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(new bytes(100)); // < 432
    }

    function test_registerInstance_RevertWhen_NoAttestationEntrypoint() external {
        // A verifier deployed without an attestation entrypoint (e.g. a dummy deployment).
        SgxVerifier dummy = _deployVerifier(CHAIN_ID, address(this), address(0), address(0));
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        dummy.registerInstance(_rawQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, address(0xBEEF)));
    }

    function test_registerInstance_RevertWhen_DuplicateInstance() external {
        _trustStandardEnclave();
        address instance = address(0xBEEF);
        bytes memory quote = _mockValidQuote(instance);
        verifier.registerInstance(quote);

        vm.expectRevert(SgxVerifier.SGX_ALREADY_ATTESTED.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_InstanceZeroAddress() external {
        _trustStandardEnclave();
        // reportData -> instance == address(0); _addInstances rejects it.
        bytes memory quote = _mockQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, address(0), 3, 1, TCB_OK);
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.registerInstance(quote);
    }

    // ---------------------------------------------------------------
    // registerInstance — MRENCLAVE/MRSIGNER allowlist
    // ---------------------------------------------------------------

    function test_registerInstance_RevertWhen_AllowlistOnAndMrEnclaveUntrusted() external {
        // Allowlist is enforced by default; trust only the signer, not the enclave.
        verifier.setMrSigner(MR_SIGNER, true);
        bytes memory quote = _mockValidQuote(address(0xBEEF));
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_AllowlistOnAndMrSignerUntrusted() external {
        // Allowlist is enforced by default; trust only the enclave, not the signer.
        verifier.setMrEnclave(MR_ENCLAVE, true);
        bytes memory quote = _mockValidQuote(address(0xBEEF));
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_WithAllowlist_succeeds() external {
        // Allowlist is enforced by default; registration succeeds once both MR values are trusted.
        address instance = address(0xBEEF);
        _trustStandardEnclave();
        bytes memory quote = _mockValidQuote(instance);
        verifier.registerInstance(quote);
        assertTrue(verifier.addressRegistered(instance));
    }

    // ---------------------------------------------------------------
    // admin: setMrEnclave / setMrSigner / toggleLocalReportCheck
    // ---------------------------------------------------------------

    function test_setMrEnclave_setsAndEmits() external {
        vm.expectEmit();
        emit SgxVerifier.MrEnclaveUpdated(MR_ENCLAVE, true);
        verifier.setMrEnclave(MR_ENCLAVE, true);
        assertTrue(verifier.trustedUserMrEnclave(MR_ENCLAVE));
    }

    function test_setMrEnclave_RevertWhen_NotOwner() external {
        vm.prank(address(0xD00D));
        vm.expectRevert();
        verifier.setMrEnclave(MR_ENCLAVE, true);
    }

    function test_setMrSigner_setsAndEmits() external {
        vm.expectEmit();
        emit SgxVerifier.MrSignerUpdated(MR_SIGNER, true);
        verifier.setMrSigner(MR_SIGNER, true);
        assertTrue(verifier.trustedUserMrSigner(MR_SIGNER));
    }

    function test_setMrSigner_RevertWhen_NotOwner() external {
        vm.prank(address(0xD00D));
        vm.expectRevert();
        verifier.setMrSigner(MR_SIGNER, true);
    }

    /// @dev Untrusting a trusted MRENCLAVE is permanent: it is recorded as revoked and can never be
    /// re-trusted, so instances revoked by the removal can never be silently revived.
    function test_setMrEnclave_RevertWhen_ReTrustAfterUntrust() external {
        verifier.setMrEnclave(MR_ENCLAVE, true);
        verifier.setMrEnclave(MR_ENCLAVE, false);
        assertTrue(verifier.revokedMrEnclave(MR_ENCLAVE));

        vm.expectRevert(SgxVerifier.SGX_MR_ENCLAVE_REVOKED.selector);
        verifier.setMrEnclave(MR_ENCLAVE, true);
    }

    function test_setMrSigner_RevertWhen_ReTrustAfterUntrust() external {
        verifier.setMrSigner(MR_SIGNER, true);
        verifier.setMrSigner(MR_SIGNER, false);
        assertTrue(verifier.revokedMrSigner(MR_SIGNER));

        vm.expectRevert(SgxVerifier.SGX_MR_SIGNER_REVOKED.selector);
        verifier.setMrSigner(MR_SIGNER, true);
    }

    /// @dev Untrusting a value that was never trusted is a no-op: it does not poison the value, so it
    /// can still be trusted afterwards (revocation is armed only by a trusted -> untrusted change).
    function test_setMrEnclave_UntrustWhenNeverTrustedDoesNotRevoke() external {
        verifier.setMrEnclave(MR_ENCLAVE, false);
        assertFalse(verifier.revokedMrEnclave(MR_ENCLAVE));

        verifier.setMrEnclave(MR_ENCLAVE, true); // still allowed
        assertTrue(verifier.trustedUserMrEnclave(MR_ENCLAVE));
    }

    /// @dev End-to-end: an instance revoked by untrusting its MRENCLAVE cannot be revived, because
    /// the measurement can never be re-trusted.
    function test_verifyProof_RevokedInstanceCannotBeRevived() external {
        _trustStandardEnclave();
        uint256 key = 0xA11CE;
        address instance = vm.addr(key);
        uint256 id = verifier.registerInstance(_mockValidQuote(instance));
        bytes32 aggHash = bytes32(uint256(0x1234));
        bytes memory proof = _proof(uint32(id), instance, _sign(key, aggHash, instance));

        verifier.verifyProof(0, aggHash, proof); // valid

        // Untrust the MRENCLAVE: the instance is revoked at proof time.
        verifier.setMrEnclave(MR_ENCLAVE, false);
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggHash, proof);

        // Re-trusting the same measurement is impossible, so the instance can never come back.
        vm.expectRevert(SgxVerifier.SGX_MR_ENCLAVE_REVOKED.selector);
        verifier.setMrEnclave(MR_ENCLAVE, true);
    }

    function test_toggleLocalReportCheck_togglesAndEmits() external {
        // Enforced by default; first toggle disables it.
        assertTrue(verifier.checkLocalEnclaveReport());
        vm.expectEmit();
        emit SgxVerifier.LocalReportCheckToggled(false);
        verifier.toggleLocalReportCheck();
        assertFalse(verifier.checkLocalEnclaveReport());
        verifier.toggleLocalReportCheck();
        assertTrue(verifier.checkLocalEnclaveReport());
    }

    function test_toggleLocalReportCheck_RevertWhen_NotOwner() external {
        vm.prank(address(0xD00D));
        vm.expectRevert();
        verifier.toggleLocalReportCheck();
    }

    // ---------------------------------------------------------------
    // admin: addInstances / deleteInstances
    // ---------------------------------------------------------------

    function test_addInstances_succeeds() external {
        address[] memory addrs = new address[](2);
        addrs[0] = address(0xA1);
        addrs[1] = address(0xA2);
        uint256[] memory ids = verifier.addInstances(addrs);
        assertEq(ids[0], 0);
        assertEq(ids[1], 1);
        assertTrue(verifier.addressRegistered(address(0xA1)));
        assertTrue(verifier.addressRegistered(address(0xA2)));
    }

    function test_addInstances_RevertWhen_NotOwner() external {
        address[] memory addrs = new address[](1);
        addrs[0] = address(0xA1);
        vm.prank(address(0xD00D));
        vm.expectRevert();
        verifier.addInstances(addrs);
    }

    function test_addInstances_RevertWhen_ZeroAddress() external {
        address[] memory addrs = new address[](1);
        addrs[0] = address(0);
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.addInstances(addrs);
    }

    function test_addInstances_RevertWhen_DuplicateAddress() external {
        address[] memory addrs = new address[](1);
        addrs[0] = address(0xA1);
        verifier.addInstances(addrs);

        vm.expectRevert(SgxVerifier.SGX_ALREADY_ATTESTED.selector);
        verifier.addInstances(addrs);
    }

    function test_deleteInstances_succeeds() external {
        address[] memory addrs = new address[](1);
        addrs[0] = address(0xA1);
        verifier.addInstances(addrs);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        vm.expectEmit();
        emit SgxVerifier.InstanceDeleted(0, address(0xA1));
        verifier.deleteInstances(ids);

        (address addr,,,,) = verifier.instances(0);
        assertEq(addr, address(0));
    }

    function test_deleteInstances_RevertWhen_NotOwner() external {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        vm.prank(address(0xD00D));
        vm.expectRevert();
        verifier.deleteInstances(ids);
    }

    function test_deleteInstances_RevertWhen_InvalidInstance() external {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 42; // never added
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.deleteInstances(ids);
    }

    // ---------------------------------------------------------------
    // verifyProof
    // ---------------------------------------------------------------

    function _proof(
        uint32 id,
        address instance,
        bytes memory sig
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(id, bytes20(instance), sig);
    }

    function _sign(
        uint256 pk,
        bytes32 aggHash,
        address instance
    )
        internal
        view
        returns (bytes memory)
    {
        return _signFor(address(verifier), pk, aggHash, instance);
    }

    /// @dev Like `_sign`, but binds the signature to an arbitrary verifier address (for proofs
    /// against a separately-deployed verifier, e.g. the registrar-configured one).
    function _signFor(
        address verifierAddr,
        uint256 pk,
        bytes32 aggHash,
        address instance
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 h = LibPublicInput.hashPublicInputs(aggHash, verifierAddr, instance, CHAIN_ID);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, h);
        return abi.encodePacked(r, s, v);
    }

    function test_verifyProof_succeeds() external {
        uint256 pk = 0xA11CE5;
        address instance = vm.addr(pk);
        address[] memory addrs = new address[](1);
        addrs[0] = instance;
        verifier.addInstances(addrs);

        bytes32 aggHash = bytes32(uint256(0xABCD));
        bytes memory proof = _proof(0, instance, _sign(pk, aggHash, instance));
        verifier.verifyProof(0, aggHash, proof); // must not revert
    }

    function test_verifyProof_RevertWhen_WrongLength() external {
        vm.expectRevert(SgxVerifier.SGX_INVALID_PROOF.selector);
        verifier.verifyProof(0, bytes32(uint256(1)), new bytes(88));
    }

    function test_verifyProof_RevertWhen_InstanceMismatch() external {
        uint256 pk = 0xA11CE5;
        address instance = vm.addr(pk);
        address[] memory addrs = new address[](1);
        addrs[0] = instance;
        verifier.addInstances(addrs);

        bytes32 aggHash = bytes32(uint256(0xABCD));
        // id 0 holds `instance`, but the proof claims a different instance address.
        bytes memory proof = _proof(0, address(0xDEAD), _sign(pk, aggHash, address(0xDEAD)));
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggHash, proof);
    }

    function test_verifyProof_RevertWhen_BadSignature() external {
        uint256 pk = 0xA11CE5;
        address instance = vm.addr(pk);
        address[] memory addrs = new address[](1);
        addrs[0] = instance;
        verifier.addInstances(addrs);

        bytes32 aggHash = bytes32(uint256(0xABCD));
        // Sign with the wrong key.
        bytes memory proof = _proof(0, instance, _sign(0xBADBAD, aggHash, instance));
        vm.expectRevert(SgxVerifier.SGX_INVALID_PROOF.selector);
        verifier.verifyProof(0, aggHash, proof);
    }

    function test_verifyProof_RevertWhen_Expired() external {
        uint256 pk = 0xA11CE5;
        address instance = vm.addr(pk);
        address[] memory addrs = new address[](1);
        addrs[0] = instance;
        verifier.addInstances(addrs);

        bytes32 aggHash = bytes32(uint256(0xABCD));
        bytes memory proof = _proof(0, instance, _sign(pk, aggHash, instance));

        vm.warp(block.timestamp + verifier.INSTANCE_EXPIRY() + 1);
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggHash, proof);
    }

    function test_verifyProof_RevertWhen_InstanceZero() external {
        bytes32 aggHash = bytes32(uint256(0xABCD));
        bytes memory proof = _proof(0, address(0), new bytes(65));
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggHash, proof);
    }

    function test_verifyProof_RevertWhen_AggregatedHashZero() external {
        uint256 pk = 0xA11CE5;
        address instance = vm.addr(pk);
        address[] memory addrs = new address[](1);
        addrs[0] = instance;
        verifier.addInstances(addrs);

        bytes memory proof = _proof(0, instance, _sign(pk, bytes32(uint256(0xABCD)), instance));
        vm.expectRevert(LibPublicInput.InvalidAggregatedProvingHash.selector);
        verifier.verifyProof(0, bytes32(0), proof);
    }

    // ---------------------------------------------------------------
    // verifyProof — current-policy re-check (revocation, not just deletion)
    // ---------------------------------------------------------------

    /// @dev A registered instance records the MRENCLAVE it attested with, so the verifier can
    /// re-check the current enclave policy at proof time.
    function test_registerInstance_RecordsMrEnclave() external {
        _trustStandardEnclave();
        address instance = address(0xBEEF);
        bytes memory quote = _mockValidQuote(instance);

        uint256 id = verifier.registerInstance(quote);
        (,,, bytes32 mrEnclave, bytes32 mrSigner) = verifier.instances(id);
        assertEq(mrEnclave, MR_ENCLAVE);
        assertEq(mrSigner, MR_SIGNER);
    }

    /// @dev Owner-added instances (`addInstances`) carry no attested MRENCLAVE, so they record the
    /// zero measurement and are exempt from the proof-time enclave-policy re-check.
    function test_addInstances_RecordsNoMrEnclave() external {
        address[] memory addrs = new address[](1);
        addrs[0] = address(0xA1);
        verifier.addInstances(addrs);

        (,, uint32 policyVersion, bytes32 mrEnclave,) = verifier.instances(0);
        assertEq(mrEnclave, bytes32(0));
        assertEq(policyVersion, 0);
    }

    /// @dev Untrusting an instance's MRENCLAVE in the allowlist revokes it at proof time, even though
    /// the instance record itself is untouched — the core fix: revocation now reaches verifyProof.
    function test_verifyProof_RevertWhen_MrEnclaveUntrustedAfterRegistration() external {
        _trustStandardEnclave();
        uint256 key = 0xA11CE;
        address instance = vm.addr(key);
        bytes memory quote = _mockValidQuote(instance);

        // Owner registration is immediately valid (skips any validity delay).
        uint256 id = verifier.registerInstance(quote);
        bytes32 aggHash = bytes32(uint256(0x1234));
        bytes memory proof = _proof(uint32(id), instance, _sign(key, aggHash, instance));

        // Valid now.
        verifier.verifyProof(0, aggHash, proof);

        // Revoking trust in the MRENCLAVE stops the already-registered instance from verifying.
        verifier.setMrEnclave(MR_ENCLAVE, false);
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggHash, proof);
    }

    /// @dev Untrusting an instance's MRSIGNER in the allowlist also revokes it at proof time (the
    /// allowlist re-check is symmetric: registration requires both MRENCLAVE and MRSIGNER trust).
    function test_verifyProof_RevertWhen_MrSignerUntrustedAfterRegistration() external {
        _trustStandardEnclave();
        uint256 key = 0xA11CE;
        address instance = vm.addr(key);
        bytes memory quote = _mockValidQuote(instance);

        uint256 id = verifier.registerInstance(quote);
        bytes32 aggHash = bytes32(uint256(0x1234));
        bytes memory proof = _proof(uint32(id), instance, _sign(key, aggHash, instance));

        // Valid now.
        verifier.verifyProof(0, aggHash, proof);

        // Revoking trust in the MRSIGNER stops the already-registered instance from verifying.
        verifier.setMrSigner(MR_SIGNER, false);
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggHash, proof);
    }

    /// @dev With the allowlist disabled, neither MRENCLAVE nor MRSIGNER trust is re-checked, so an
    /// instance keeps verifying even after its measurement/signer is untrusted (matches registration,
    /// which skips the allowlist when `checkLocalEnclaveReport` is off).
    function test_verifyProof_AllowlistDisabledSkipsReCheck() external {
        _trustStandardEnclave();
        uint256 key = 0xA11CE;
        address instance = vm.addr(key);
        uint256 id = verifier.registerInstance(_mockValidQuote(instance));
        bytes32 aggHash = bytes32(uint256(0x1234));
        bytes memory proof = _proof(uint32(id), instance, _sign(key, aggHash, instance));

        // Disable the allowlist, then untrust both MR values: the instance is unaffected.
        verifier.toggleLocalReportCheck();
        verifier.setMrEnclave(MR_ENCLAVE, false);
        verifier.setMrSigner(MR_SIGNER, false);
        verifier.verifyProof(0, aggHash, proof); // still valid
    }

    /// @dev Owner-added instances are not subject to the MRENCLAVE allowlist re-check: they remain
    /// valid regardless of allowlist changes (the owner revokes them via `deleteInstances`).
    function test_verifyProof_OwnerAddedInstanceIgnoresAllowlistChanges() external {
        uint256 key = 0xA11CE;
        address instance = vm.addr(key);
        address[] memory addrs = new address[](1);
        addrs[0] = instance;
        verifier.addInstances(addrs);

        bytes32 aggHash = bytes32(uint256(0x1234));
        bytes memory proof = _proof(0, instance, _sign(key, aggHash, instance));
        verifier.verifyProof(0, aggHash, proof);

        // Even untrusting some MRENCLAVE does not affect an owner-added (measurement-less) instance.
        verifier.setMrEnclave(MR_ENCLAVE, false);
        verifier.verifyProof(0, aggHash, proof); // still valid
    }
}

/// @title SecureSgxVerifierTest
/// @notice Runs the shared suite against the strict mainnet `SecureSgxVerifier`, plus its
/// strict-only behaviour: out-of-date TCB rejection, the fail-closed per-MRENCLAVE ATTRIBUTES pin,
/// the registrar pin-removal role, and the instance-validity delay.
/// @custom:security-contact security@taiko.xyz
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
        address _registrar
    )
        internal
        override
        returns (SgxVerifier)
    {
        SecureSgxVerifier secureVerifier =
            new SecureSgxVerifier(_chainId, _owner, _attestation, _registrar, VALIDITY_DELAY);
        // Permissive-but-configured pin for the shared suite's MRENCLAVE: check only the forbidden
        // floor (expected 0), so a zero-ATTRIBUTES quote passes and the shared tests exercise the
        // floor exactly. The dedicated tests below pin tighter against STRICT_MR. `_owner` owns the
        // verifier, so impersonate it to configure.
        vm.prank(_owner);
        secureVerifier.setEnclaveAttributePolicy(MR_ENCLAVE, FORBIDDEN_FLOOR, bytes16(0));
        return secureVerifier;
    }

    /// @dev Convenience accessor for the verifier under test as its concrete type.
    function _secure() private view returns (SecureSgxVerifier) {
        return SecureSgxVerifier(address(verifier));
    }

    // ---------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------

    function test_constructor_RevertWhen_ChainIdZero() external {
        vm.expectRevert(SgxVerifier.SGX_INVALID_CHAIN_ID.selector);
        new SecureSgxVerifier(0, address(this), ATTESTATION, address(0), VALIDITY_DELAY);
    }

    // ---------------------------------------------------------------
    // Strict TCB-status policy
    // ---------------------------------------------------------------

    function test_registerInstance_RevertWhen_TcbOutOfDate() external {
        // The strict mainnet policy rejects out-of-date platforms.
        bytes memory quote =
            _mockQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, address(0xC0FFEE), 3, 1, TCB_OUT_OF_DATE);
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_TcbOutOfDateConfigNeeded() external {
        bytes memory quote = _mockQuote(
            bytes16(0), MR_ENCLAVE, MR_SIGNER, address(0xC0FFEE), 3, 1, TCB_OUT_OF_DATE_CONFIG
        );
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_isTcbStatusAccepted_StrictPolicy() external view {
        assertTrue(verifier.isTcbStatusAccepted(TCB_OK));
        assertTrue(verifier.isTcbStatusAccepted(TCB_SW_HARDENING));
        assertTrue(verifier.isTcbStatusAccepted(TCB_CONFIG_AND_SW_HARDENING));
        assertFalse(verifier.isTcbStatusAccepted(TCB_OUT_OF_DATE));
        assertFalse(verifier.isTcbStatusAccepted(TCB_OUT_OF_DATE_CONFIG));
        assertFalse(verifier.isTcbStatusAccepted(TCB_CONFIG_NEEDED));
        assertFalse(verifier.isTcbStatusAccepted(TCB_REVOKED));
        assertFalse(verifier.isTcbStatusAccepted(TCB_UNRECOGNIZED));
    }

    /// @dev Exhaustively check all 256 status bytes: exactly {OK, SW_HARDENING_NEEDED,
    /// CONFIGURATION_AND_SW_HARDENING_NEEDED} are accepted; every other value (the out-of-date
    /// statuses and any out-of-enum byte) is rejected - exact, never over-scoped.
    function test_isTcbStatusAccepted_StrictPolicyIsExact() external view {
        for (uint256 s; s <= type(uint8).max; ++s) {
            bool expected = s == TCB_OK || s == TCB_SW_HARDENING || s == TCB_CONFIG_AND_SW_HARDENING;
            assertEq(verifier.isTcbStatusAccepted(uint8(s)), expected);
        }
    }

    // ---------------------------------------------------------------
    // Per-MRENCLAVE ATTRIBUTES pin
    // ---------------------------------------------------------------

    function test_registerInstance_RevertWhen_EnclaveAttributesNotConfigured() external {
        // Fail closed: an MRENCLAVE with no configured pin cannot register, even with otherwise
        // valid production attributes. Reverts at the pin, before the allowlist check.
        bytes16 production = bytes16(0x05000000000000000000000000000000);
        bytes memory quote = _mockQuote(
            production, bytes32(uint256(0xDEADBEEF)), MR_SIGNER, address(0xC0FFEE), 3, 1, TCB_OK
        );
        vm.expectRevert(SecureSgxVerifier.SGX_ATTRIBUTE_POLICY_NOT_SET.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_AttributesViolateStrictPolicy() external {
        _secure().setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);
        // A bit set outside FLAGS byte 0 - allowed by the global deny-mask, but rejected by the pin
        // (it also fails to assert the required INIT|MODE64BIT). Reverts before the allowlist check.
        bytes16 attributes = bytes16(0x00020000000000000000000000000000);
        bytes memory quote =
            _mockQuote(attributes, STRICT_MR, MR_SIGNER, address(0xC0FFEE), 3, 1, TCB_OK);
        vm.expectRevert(SecureSgxVerifier.SGX_ATTRIBUTE_MISMATCH.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_SucceedsWhen_AttributesMatchStrictPolicy() external {
        _secure().setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);
        verifier.setMrEnclave(STRICT_MR, true);
        verifier.setMrSigner(MR_SIGNER, true);

        address instance = address(0xC0FFEE);
        // INIT|MODE64BIT in FLAGS; AVX bits in XFRM (XFRM is not checked by STRICT_MASK).
        bytes16 attributes = bytes16(0x05000000000000000700000000000000);
        bytes memory quote = _mockQuote(attributes, STRICT_MR, MR_SIGNER, instance, 3, 1, TCB_OK);

        vm.expectEmit();
        emit SgxVerifier.InstanceAdded(0, instance, address(0), block.timestamp);
        uint256 id = verifier.registerInstance(quote);
        assertEq(id, 0);
    }

    function test_setEnclaveAttributePolicy_RevertWhen_NotOwner() external {
        vm.prank(address(0xBAD));
        vm.expectRevert(); // Ownable2Step: caller is not the owner.
        _secure().setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);
    }

    function test_setEnclaveAttributePolicy_RevertWhen_ExpectedOutsideMask() external {
        bytes16 mask = bytes16(0xff000000000000000000000000000000); // checks byte 0 only
        bytes16 expected = bytes16(0x00010000000000000000000000000000); // asserts a byte-1 bit
        vm.expectRevert(SecureSgxVerifier.SGX_INVALID_ATTRIBUTE_POLICY.selector);
        _secure().setEnclaveAttributePolicy(STRICT_MR, mask, expected);
    }

    function test_setEnclaveAttributePolicy_RevertWhen_MaskMissesForbiddenBit() external {
        bytes16 mask = bytes16(0x01000000000000000000000000000000); // checks INIT, not the floor
        vm.expectRevert(SecureSgxVerifier.SGX_INVALID_ATTRIBUTE_POLICY.selector);
        _secure().setEnclaveAttributePolicy(STRICT_MR, mask, bytes16(0));
    }

    function test_setEnclaveAttributePolicy_RevertWhen_ExpectedHasForbiddenBit() external {
        // A pin that would *expect* DEBUG to be set must be rejected.
        bytes16 mask = bytes16(0xff000000000000000000000000000000);
        bytes16 expected = bytes16(0x02000000000000000000000000000000); // DEBUG
        vm.expectRevert(SecureSgxVerifier.SGX_INVALID_ATTRIBUTE_POLICY.selector);
        _secure().setEnclaveAttributePolicy(STRICT_MR, mask, expected);
    }

    function test_setEnclaveAttributePolicy_SetsAndEmits() external {
        // STRICT_MR has no prior pin, so the first set lands on version 1.
        vm.expectEmit();
        emit SecureSgxVerifier.EnclaveAttributePolicySet(STRICT_MR, STRICT_MASK, STRICT_EXPECTED, 1);
        _secure().setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);

        (bytes16 mask, bytes16 expected) = _secure().enclaveAttributePolicy(STRICT_MR);
        assertEq(bytes32(mask), bytes32(STRICT_MASK));
        assertEq(bytes32(expected), bytes32(STRICT_EXPECTED));
        assertEq(_secure().enclaveAttributePolicyVersion(STRICT_MR), 1);
    }

    function test_setEnclaveAttributePolicy_BumpsVersionOnEverySet() external {
        // Each set — even an in-place edit with identical values — advances the monotonic version.
        _secure().setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);
        assertEq(_secure().enclaveAttributePolicyVersion(STRICT_MR), 1);

        _secure().setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);
        assertEq(_secure().enclaveAttributePolicyVersion(STRICT_MR), 2);

        // Removal also advances the counter (so a single version compare in verifyProof rejects
        // revoked instances) and never resets it; a re-add then gets yet another fresh version.
        _secure().removeEnclaveAttributePolicy(STRICT_MR);
        assertEq(_secure().enclaveAttributePolicyVersion(STRICT_MR), 3);

        _secure().setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);
        assertEq(_secure().enclaveAttributePolicyVersion(STRICT_MR), 4);
    }

    function test_removeEnclaveAttributePolicy_FailsClosedAfterRemoval() external {
        _secure().setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);

        vm.expectEmit();
        emit SecureSgxVerifier.EnclaveAttributePolicyRemoved(STRICT_MR);
        _secure().removeEnclaveAttributePolicy(STRICT_MR);

        (bytes16 mask,) = _secure().enclaveAttributePolicy(STRICT_MR);
        assertEq(bytes32(mask), bytes32(0));

        bytes16 attributes = bytes16(0x05000000000000000000000000000000);
        bytes memory quote =
            _mockQuote(attributes, STRICT_MR, MR_SIGNER, address(0xC0FFEE), 3, 1, TCB_OK);
        vm.expectRevert(SecureSgxVerifier.SGX_ATTRIBUTE_POLICY_NOT_SET.selector);
        verifier.registerInstance(quote);
    }

    // ---------------------------------------------------------------
    // Registrar pin-removal role
    // ---------------------------------------------------------------

    /// @dev Deploys a SecureSgxVerifier owned by this test with `REGISTRAR` set, which besides the
    /// owner may remove pins.
    function _deployWithRegistrar() private returns (SecureSgxVerifier secure_) {
        secure_ =
            new SecureSgxVerifier(CHAIN_ID, address(this), ATTESTATION, REGISTRAR, VALIDITY_DELAY);
        assertEq(secure_.registrar(), REGISTRAR);
    }

    function test_removeEnclaveAttributePolicy_ByRegistrar() external {
        SecureSgxVerifier secure = _deployWithRegistrar();
        secure.setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);

        // The registrar, not the owner, removes the pin.
        vm.expectEmit();
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
        _secure().setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);

        vm.prank(address(0xBAD));
        vm.expectRevert(SecureSgxVerifier.SGX_NOT_AUTHORIZED.selector);
        _secure().removeEnclaveAttributePolicy(STRICT_MR);
    }

    /// @dev The registrar can only remove pins, never set them: setting stays owner-only.
    function test_setEnclaveAttributePolicy_RevertWhen_CalledByRegistrar() external {
        SecureSgxVerifier secure = _deployWithRegistrar();

        vm.prank(REGISTRAR);
        vm.expectRevert(); // Ownable2Step: caller is not the owner.
        secure.setEnclaveAttributePolicy(STRICT_MR, STRICT_MASK, STRICT_EXPECTED);
    }

    // ---------------------------------------------------------------
    // Instance-validity delay
    // ---------------------------------------------------------------

    function test_constructor_RevertWhen_ValidityDelayTooLarge() external {
        uint64 tooLarge = uint64(verifier.INSTANCE_EXPIRY()) + 1;
        vm.expectRevert(SecureSgxVerifier.SGX_INVALID_VALIDITY_DELAY.selector);
        new SecureSgxVerifier(CHAIN_ID, address(this), ATTESTATION, address(0), tooLarge);
    }

    function test_constructor_RevertWhen_ValidityDelayZero() external {
        vm.expectRevert(SecureSgxVerifier.SGX_INVALID_VALIDITY_DELAY.selector);
        new SecureSgxVerifier(CHAIN_ID, address(this), ATTESTATION, address(0), 0);
    }

    function test_registerInstance_AppliesValidityDelay() external {
        _trustStandardEnclave();
        address instance = address(0xC0FFEE);
        bytes memory quote = _mockValidQuote(instance);

        // A non-owner self-registration is delayed.
        vm.prank(NON_OWNER);
        uint256 id = verifier.registerInstance(quote);
        (, uint64 validSince,,,) = verifier.instances(id);
        assertEq(validSince, uint64(block.timestamp) + VALIDITY_DELAY);
    }

    function test_registerInstance_OwnerSkipsValidityDelay() external {
        _trustStandardEnclave();
        address instance = address(0xC0FFEE);
        bytes memory quote = _mockValidQuote(instance);

        // The owner (this test) is as trusted as addInstances, so registerInstance skips the delay.
        uint256 id = verifier.registerInstance(quote);
        (, uint64 validSince,,,) = verifier.instances(id);
        assertEq(validSince, uint64(block.timestamp));
    }

    function test_addInstances_IgnoresValidityDelay() external {
        address[] memory instances = new address[](1);
        instances[0] = address(0xA11CE);
        verifier.addInstances(instances);

        // Owner registrations are trusted and take effect immediately, ignoring the delay.
        (, uint64 validSince,,,) = verifier.instances(0);
        assertEq(validSince, uint64(block.timestamp));
    }

    function test_verifyProof_RevertWhen_WithinValidityDelay() external {
        _trustStandardEnclave();
        uint256 key = 0xA11CE;
        address instance = vm.addr(key);
        bytes memory quote = _mockValidQuote(instance);

        vm.prank(NON_OWNER);
        uint256 id = verifier.registerInstance(quote);

        bytes32 aggHash = bytes32(uint256(0x1234));
        bytes memory proof = _proof(uint32(id), instance, _sign(key, aggHash, instance));

        // Still inside the validity delay: the self-registered instance cannot prove yet.
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggHash, proof);

        // After the delay elapses, the same proof is accepted.
        vm.warp(block.timestamp + VALIDITY_DELAY);
        verifier.verifyProof(0, aggHash, proof);
    }

    // ---------------------------------------------------------------
    // Policy removal / change revokes existing instances (versioned)
    // ---------------------------------------------------------------

    /// @dev The instance records the policy version in force when it registered. `_deployVerifier`
    /// sets the MR_ENCLAVE pin once, so registrations bind to version 1.
    function test_registerInstance_RecordsPolicyVersion() external {
        _trustStandardEnclave();
        assertEq(_secure().enclaveAttributePolicyVersion(MR_ENCLAVE), 1);

        address instance = address(0xBEEF);
        uint256 id = verifier.registerInstance(_mockValidQuote(instance));

        (,, uint32 policyVersion, bytes32 mrEnclave,) = verifier.instances(id);
        assertEq(policyVersion, 1);
        assertEq(mrEnclave, MR_ENCLAVE);
    }

    /// @dev Audit finding test #1: a non-owner instance registered under a pin that is removed during
    /// its validity delay is revoked — it cannot prove even once the delay elapses.
    function test_verifyProof_RevertWhen_PolicyRemovedBeforeDelayElapses() external {
        _trustStandardEnclave();
        uint256 key = 0xA11CE;
        address instance = vm.addr(key);
        bytes memory quote = _mockValidQuote(instance);

        // Non-owner self-registration → subject to the validity delay.
        vm.prank(NON_OWNER);
        uint256 id = verifier.registerInstance(quote);

        bytes32 aggHash = bytes32(uint256(0x1234));
        bytes memory proof = _proof(uint32(id), instance, _sign(key, aggHash, instance));

        // Remove the enclave's pin while the instance is still inside its validity delay.
        _secure().removeEnclaveAttributePolicy(MR_ENCLAVE);

        // Even once the delay elapses, the revoked instance cannot prove.
        vm.warp(block.timestamp + VALIDITY_DELAY);
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggHash, proof);
    }

    /// @dev Audit finding test #2: an already-valid instance is revoked once its MRENCLAVE pin is
    /// removed (invalidated, not deleted — the record is untouched).
    function test_verifyProof_RevertWhen_PolicyRemovedForValidInstance() external {
        _trustStandardEnclave();
        uint256 key = 0xA11CE;
        address instance = vm.addr(key);
        bytes memory quote = _mockValidQuote(instance);

        // Owner registration → immediately valid.
        uint256 id = verifier.registerInstance(quote);
        bytes32 aggHash = bytes32(uint256(0x1234));
        bytes memory proof = _proof(uint32(id), instance, _sign(key, aggHash, instance));
        verifier.verifyProof(0, aggHash, proof); // valid before removal

        // Removing the pin revokes the already-valid instance.
        _secure().removeEnclaveAttributePolicy(MR_ENCLAVE);
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggHash, proof);

        // The instance record itself is untouched (invalidated, not deleted).
        (address addr,,,,) = verifier.instances(id);
        assertEq(addr, instance);
    }

    /// @dev Version requirement: removing then re-adding the SAME pin must NOT re-enable instances
    /// registered under the previous version — the monotonic version advances (1 -> remove 2 -> 3).
    function test_verifyProof_RevertWhen_PolicyRemovedThenReAdded() external {
        _trustStandardEnclave();
        uint256 key = 0xA11CE;
        address instance = vm.addr(key);
        bytes memory quote = _mockValidQuote(instance);

        uint256 id = verifier.registerInstance(quote); // owner → valid, bound to version 1
        bytes32 aggHash = bytes32(uint256(0x1234));
        bytes memory proof = _proof(uint32(id), instance, _sign(key, aggHash, instance));
        verifier.verifyProof(0, aggHash, proof);

        _secure().removeEnclaveAttributePolicy(MR_ENCLAVE); // version 1 -> 2
        _secure().setEnclaveAttributePolicy(MR_ENCLAVE, FORBIDDEN_FLOOR, bytes16(0)); // 2 -> 3
        assertEq(_secure().enclaveAttributePolicyVersion(MR_ENCLAVE), 3);

        // The old instance is pinned to version 1 and stays revoked under version 3.
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggHash, proof);
    }

    /// @dev An in-place pin edit (same MRENCLAVE) bumps the version and revokes prior instances.
    function test_verifyProof_RevertWhen_PolicyEditedInPlace() external {
        _trustStandardEnclave();
        uint256 key = 0xA11CE;
        address instance = vm.addr(key);
        bytes memory quote = _mockValidQuote(instance);

        uint256 id = verifier.registerInstance(quote);
        bytes32 aggHash = bytes32(uint256(0x1234));
        bytes memory proof = _proof(uint32(id), instance, _sign(key, aggHash, instance));
        verifier.verifyProof(0, aggHash, proof);

        _secure().setEnclaveAttributePolicy(MR_ENCLAVE, FORBIDDEN_FLOOR, bytes16(0));
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggHash, proof);
    }

    /// @dev Audit finding test #3: registrar-triggered pin removal also closes the proof path — the
    /// registrar can fail-close a compromised enclave even though it cannot delete instances.
    function test_verifyProof_RevertWhen_RegistrarRemovesPolicy() external {
        SecureSgxVerifier secure = _deployWithRegistrar();
        secure.setEnclaveAttributePolicy(MR_ENCLAVE, FORBIDDEN_FLOOR, bytes16(0));
        _trustEnclaveOn(secure);

        uint256 key = 0xA11CE;
        address instance = vm.addr(key);
        bytes memory quote = _mockValidQuote(instance);

        // Registrar registers a (delayed) instance.
        vm.prank(REGISTRAR);
        uint256 id = secure.registerInstance(quote);

        bytes32 aggHash = bytes32(uint256(0x1234));
        bytes memory proof =
            _proof(uint32(id), instance, _signFor(address(secure), key, aggHash, instance));

        // The registrar fail-closes the enclave by removing the pin, revoking the instance.
        vm.prank(REGISTRAR);
        secure.removeEnclaveAttributePolicy(MR_ENCLAVE);

        // Past the delay, the revocation (not the delay) is what rejects the proof.
        vm.warp(block.timestamp + VALIDITY_DELAY);
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        secure.verifyProof(0, aggHash, proof);
    }

    /// @dev After re-authorization (re-add the pin), a freshly registered instance binds to the new
    /// version and verifies, while an instance registered under the old version stays revoked.
    function test_verifyProof_SucceedsForNewInstanceAfterReauthorization() external {
        _trustStandardEnclave();

        // instance1 registers under version 1.
        uint256 key1 = 0xA11CE;
        address instance1 = vm.addr(key1);
        verifier.registerInstance(_mockValidQuote(instance1)); // id 0

        // Remove and re-add the pin (version 1 -> remove 2 -> re-add 3).
        _secure().removeEnclaveAttributePolicy(MR_ENCLAVE);
        _secure().setEnclaveAttributePolicy(MR_ENCLAVE, FORBIDDEN_FLOOR, bytes16(0));

        // instance2 registers under the fresh version 3.
        uint256 key2 = 0xB0B;
        address instance2 = vm.addr(key2);
        uint256 id2 = verifier.registerInstance(_mockValidQuote(instance2)); // id 1
        (,, uint32 policyVersion,,) = verifier.instances(id2);
        assertEq(policyVersion, 3);

        bytes32 aggHash = bytes32(uint256(0x1234));

        // The new instance verifies under the current version.
        bytes memory proof2 = _proof(uint32(id2), instance2, _sign(key2, aggHash, instance2));
        verifier.verifyProof(0, aggHash, proof2);

        // The old instance (version 1) remains revoked.
        bytes memory proof1 = _proof(0, instance1, _sign(key1, aggHash, instance1));
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.verifyProof(0, aggHash, proof1);
    }
}

/// @title InsecureSgxVerifierTest
/// @notice Runs the shared suite against the lenient devnet `InsecureSgxVerifier`, plus its
/// lenient-only behaviour: acceptance of out-of-date TCB statuses. It enforces no per-MRENCLAVE
/// ATTRIBUTES pin and no instance-validity delay.
/// @custom:security-contact security@taiko.xyz
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
        // InsecureSgxVerifier has no ATTRIBUTES pin (the base hook is a no-op) and no validity delay.
        return new InsecureSgxVerifier(_chainId, _owner, _attestation, _registrar);
    }

    function test_constructor_RevertWhen_ChainIdZero() external {
        vm.expectRevert(SgxVerifier.SGX_INVALID_CHAIN_ID.selector);
        new InsecureSgxVerifier(0, address(this), ATTESTATION, address(0));
    }

    function test_registerInstance_AcceptsOutOfDateTcb() external {
        // The lenient policy accepts out-of-date platforms for dev-hardware liveness.
        _trustStandardEnclave();
        address instance = address(0xC0FFEE);
        bytes memory quote =
            _mockQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, instance, 3, 1, TCB_OUT_OF_DATE);
        uint256 id = verifier.registerInstance(quote);
        assertEq(id, 0);
        assertTrue(verifier.addressRegistered(instance));
    }

    function test_registerInstance_AcceptsOutOfDateConfigTcb() external {
        _trustStandardEnclave();
        address instance = address(0xC0FFEE);
        bytes memory quote =
            _mockQuote(bytes16(0), MR_ENCLAVE, MR_SIGNER, instance, 3, 1, TCB_OUT_OF_DATE_CONFIG);
        uint256 id = verifier.registerInstance(quote);
        assertEq(id, 0);
        assertTrue(verifier.addressRegistered(instance));
    }

    function test_registerInstance_AcceptsProductionAttributesWithoutPin() external {
        // With no per-MRENCLAVE pin, the lenient verifier admits any non-forbidden ATTRIBUTES once
        // the MR allowlist is satisfied.
        _trustStandardEnclave();
        address instance = address(0xC0FFEE);
        bytes16 production = bytes16(0x05000000000000000700000000000000);
        bytes memory quote = _mockQuote(production, MR_ENCLAVE, MR_SIGNER, instance, 3, 1, TCB_OK);
        uint256 id = verifier.registerInstance(quote);
        assertEq(id, 0);
    }

    function test_isTcbStatusAccepted_LenientPolicy() external view {
        assertTrue(verifier.isTcbStatusAccepted(TCB_OK));
        assertTrue(verifier.isTcbStatusAccepted(TCB_SW_HARDENING));
        assertTrue(verifier.isTcbStatusAccepted(TCB_CONFIG_AND_SW_HARDENING));
        assertTrue(verifier.isTcbStatusAccepted(TCB_OUT_OF_DATE));
        assertTrue(verifier.isTcbStatusAccepted(TCB_OUT_OF_DATE_CONFIG));
        assertFalse(verifier.isTcbStatusAccepted(TCB_CONFIG_NEEDED));
        assertFalse(verifier.isTcbStatusAccepted(TCB_REVOKED));
        assertFalse(verifier.isTcbStatusAccepted(TCB_UNRECOGNIZED));
    }

    /// @dev Exhaustively check all 256 status bytes: the lenient policy accepts exactly the
    /// up-to-date statuses plus the out-of-date statuses, and rejects everything else
    /// (config-needed, revoked, unrecognized, and any out-of-enum byte).
    function test_isTcbStatusAccepted_LenientPolicyIsExact() external view {
        for (uint256 s; s <= type(uint8).max; ++s) {
            bool expected = s == TCB_OK || s == TCB_SW_HARDENING || s == TCB_CONFIG_AND_SW_HARDENING
                || s == TCB_OUT_OF_DATE || s == TCB_OUT_OF_DATE_CONFIG;
            assertEq(verifier.isTcbStatusAccepted(uint8(s)), expected);
        }
    }
}
