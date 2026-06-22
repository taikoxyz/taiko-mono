// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import { IDcapAttestation } from "src/layer1/verifiers/IDcapAttestation.sol";
import { LibPublicInput } from "src/layer1/verifiers/LibPublicInput.sol";
import { SgxVerifier } from "src/layer1/verifiers/SgxVerifier.sol";

/// @title SgxVerifierTest
/// @notice Unit tests for the migrated SgxVerifier: raw-quote registration via the Automata DCAP
/// entrypoint, DEBUG-enclave rejection, TCB-status policy, MRENCLAVE/MRSIGNER allowlist, instance
/// management, and proof verification.
/// @custom:security-contact security@taiko.xyz
contract SgxVerifierTest is Test {
    uint64 internal constant CHAIN_ID = 167;
    address internal constant ATTESTATION = address(0xA11CE);

    // Automata FmspcTcbHelper.TCBStatus codes.
    uint8 internal constant TCB_OK = 0;
    uint8 internal constant TCB_SW_HARDENING = 1;
    uint8 internal constant TCB_CONFIG_AND_SW_HARDENING = 2;
    uint8 internal constant TCB_CONFIG_NEEDED = 3; // rejected
    uint8 internal constant TCB_OUT_OF_DATE = 4;
    uint8 internal constant TCB_OUT_OF_DATE_CONFIG = 5;
    uint8 internal constant TCB_REVOKED = 6; // rejected
    uint8 internal constant TCB_UNRECOGNIZED = 7; // rejected

    SgxVerifier internal verifier;

    bytes32 internal constant MR_ENCLAVE = bytes32(uint256(0x1111));
    bytes32 internal constant MR_SIGNER = bytes32(uint256(0x2222));

    function setUp() external {
        // owner == address(this) so this test can call the onlyOwner admin functions.
        verifier = new SgxVerifier(CHAIN_ID, address(this), ATTESTATION);
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev Builds a 384-byte SGX enclave report with the given fields at their Intel-spec offsets.
    function _report(
        bool debug,
        bytes32 mrEnclave,
        bytes32 mrSigner,
        address instance
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes16 attributes = debug ? bytes16(0x02000000000000000000000000000000) : bytes16(0);
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
        bool debug,
        bytes32 mrEnclave,
        bytes32 mrSigner,
        address instance
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(new bytes(48), _report(debug, mrEnclave, mrSigner, instance));
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
        bool debug,
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
        bytes memory report = _report(debug, mrEnclave, mrSigner, instance);
        quote = abi.encodePacked(new bytes(48), report);
        _mockAttest(true, _output(version, bodyType, tcbStatus, report));
    }

    /// @dev Common valid case: non-debug, trusted MR values, V3/SGX/OK.
    function _mockValidQuote(address instance) internal returns (bytes memory) {
        return _mockQuote(false, MR_ENCLAVE, MR_SIGNER, instance, 3, 1, TCB_OK);
    }

    // ---------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------

    function test_constructor_RevertWhen_ChainIdZero() external {
        vm.expectRevert(SgxVerifier.SGX_INVALID_CHAIN_ID.selector);
        new SgxVerifier(0, address(this), ATTESTATION);
    }

    // ---------------------------------------------------------------
    // registerInstance — happy path
    // ---------------------------------------------------------------

    function test_registerInstance_succeeds() external {
        address instance = address(0xBEEF);
        bytes memory quote = _mockValidQuote(instance);

        vm.expectEmit();
        emit SgxVerifier.InstanceAdded(0, instance, address(0), block.timestamp);
        uint256 id = verifier.registerInstance(quote);

        assertEq(id, 0);
        (address addr, uint64 validSince) = verifier.instances(0);
        assertEq(addr, instance);
        assertEq(validSince, uint64(block.timestamp));
        assertTrue(verifier.addressRegistered(instance));
        assertEq(verifier.nextInstanceId(), 1);
    }

    function test_registerInstance_acceptsAllAllowedTcbStatuses() external {
        uint8[5] memory ok = [
            TCB_OK,
            TCB_SW_HARDENING,
            TCB_CONFIG_AND_SW_HARDENING,
            TCB_OUT_OF_DATE,
            TCB_OUT_OF_DATE_CONFIG
        ];
        for (uint256 i; i < ok.length; ++i) {
            address instance = address(uint160(0x1000 + i));
            bytes memory quote = _mockQuote(false, MR_ENCLAVE, MR_SIGNER, instance, 3, 1, ok[i]);
            verifier.registerInstance(quote);
            assertTrue(verifier.addressRegistered(instance));
        }
    }

    function test_registerInstance_forwardsAttestationFee() external {
        address instance = address(0xBEEF);
        uint256 fee = 1 ether;
        vm.deal(address(this), fee);
        bytes memory quote = _mockValidQuote(instance);

        // msg.value must be forwarded to the entrypoint so a non-zero fee (if ever configured on
        // the entrypoint) is payable rather than bricking every registration.
        vm.expectCall(
            ATTESTATION,
            fee,
            abi.encodeWithSelector(IDcapAttestation.verifyAndAttestOnChain.selector, quote)
        );
        verifier.registerInstance{ value: fee }(quote);
        assertTrue(verifier.addressRegistered(instance));
    }

    // ---------------------------------------------------------------
    // registerInstance — reverts
    // ---------------------------------------------------------------

    function test_registerInstance_RevertWhen_NotVerified() external {
        _mockAttest(false, bytes("some failure reason"));
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(_rawQuote(false, MR_ENCLAVE, MR_SIGNER, address(0xBEEF)));
    }

    function test_registerInstance_RevertWhen_DebugEnclave() external {
        bytes memory quote = _mockQuote(true, MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 1, TCB_OK);
        vm.expectRevert(SgxVerifier.SGX_DEBUG_ENCLAVE.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_TcbRevoked() external {
        bytes memory quote =
            _mockQuote(false, MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 1, TCB_REVOKED);
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_TcbConfigNeeded() external {
        bytes memory quote =
            _mockQuote(false, MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 1, TCB_CONFIG_NEEDED);
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_TcbUnrecognized() external {
        bytes memory quote =
            _mockQuote(false, MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 1, TCB_UNRECOGNIZED);
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_WrongQuoteVersion() external {
        bytes memory quote = _mockQuote(false, MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 4, 1, TCB_OK);
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_WrongBodyType() external {
        bytes memory quote = _mockQuote(false, MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 2, TCB_OK);
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_OutputTooShort() external {
        _mockAttest(true, new bytes(10));
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(_rawQuote(false, MR_ENCLAVE, MR_SIGNER, address(0xBEEF)));
    }

    function test_registerInstance_RevertWhen_VerifiedBodyMismatch() external {
        // Attestation succeeds and the Output header is well-formed (V3/SGX/OK), but its body does
        // not match the raw quote's enclave report — the verified-body binding must reject it.
        bytes memory quote = _rawQuote(false, MR_ENCLAVE, MR_SIGNER, address(0xBEEF));
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
        SgxVerifier dummy = new SgxVerifier(CHAIN_ID, address(this), address(0));
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        dummy.registerInstance(_rawQuote(false, MR_ENCLAVE, MR_SIGNER, address(0xBEEF)));
    }

    function test_registerInstance_RevertWhen_DuplicateInstance() external {
        address instance = address(0xBEEF);
        bytes memory quote = _mockValidQuote(instance);
        verifier.registerInstance(quote);

        vm.expectRevert(SgxVerifier.SGX_ALREADY_ATTESTED.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_InstanceZeroAddress() external {
        // reportData -> instance == address(0); _addInstances rejects it.
        bytes memory quote = _mockQuote(false, MR_ENCLAVE, MR_SIGNER, address(0), 3, 1, TCB_OK);
        vm.expectRevert(SgxVerifier.SGX_INVALID_INSTANCE.selector);
        verifier.registerInstance(quote);
    }

    // ---------------------------------------------------------------
    // registerInstance — MRENCLAVE/MRSIGNER allowlist
    // ---------------------------------------------------------------

    function test_registerInstance_RevertWhen_AllowlistOnAndMrEnclaveUntrusted() external {
        verifier.toggleLocalReportCheck();
        verifier.setMrSigner(MR_SIGNER, true); // signer trusted, enclave not
        bytes memory quote = _mockValidQuote(address(0xBEEF));
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_AllowlistOnAndMrSignerUntrusted() external {
        verifier.toggleLocalReportCheck();
        verifier.setMrEnclave(MR_ENCLAVE, true); // enclave trusted, signer not
        bytes memory quote = _mockValidQuote(address(0xBEEF));
        vm.expectRevert(SgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_WithAllowlist_succeeds() external {
        address instance = address(0xBEEF);
        verifier.toggleLocalReportCheck();
        verifier.setMrEnclave(MR_ENCLAVE, true);
        verifier.setMrSigner(MR_SIGNER, true);
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

    function test_toggleLocalReportCheck_togglesAndEmits() external {
        assertFalse(verifier.checkLocalEnclaveReport());
        vm.expectEmit();
        emit SgxVerifier.LocalReportCheckToggled(true);
        verifier.toggleLocalReportCheck();
        assertTrue(verifier.checkLocalEnclaveReport());
        verifier.toggleLocalReportCheck();
        assertFalse(verifier.checkLocalEnclaveReport());
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

    function test_deleteInstances_succeeds() external {
        address[] memory addrs = new address[](1);
        addrs[0] = address(0xA1);
        verifier.addInstances(addrs);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        vm.expectEmit();
        emit SgxVerifier.InstanceDeleted(0, address(0xA1));
        verifier.deleteInstances(ids);

        (address addr,) = verifier.instances(0);
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
        returns (bytes memory)
    {
        bytes32 h = LibPublicInput.hashPublicInputs(aggHash, address(verifier), instance, CHAIN_ID);
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
}
