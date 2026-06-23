// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { TCBStatus } from "@automata-network/on-chain-pccs/helpers/FmspcTcbHelper.sol";
import "forge-std/src/Test.sol";
import { BaseSgxVerifier } from "src/layer1/verifiers/BaseSgxVerifier.sol";
import { IDcapAttestation } from "src/layer1/verifiers/IDcapAttestation.sol";
import { TestnetSgxVerifier } from "src/layer1/verifiers/TestnetSgxVerifier.sol";

/// @title TestnetSgxVerifierTest
/// @notice Unit tests for the lenient TCB-status acceptance policy of TestnetSgxVerifier. All shared
/// logic is covered by SgxVerifierTest against the MainnetSgxVerifier; this file only asserts the
/// policy delta: the testnet verifier additionally accepts out-of-date and config-and-sw-hardening
/// platforms, while still rejecting the configuration-needed, revoked, and unrecognized statuses.
/// @custom:security-contact security@taiko.xyz
contract TestnetSgxVerifierTest is Test {
    uint64 internal constant CHAIN_ID = 167;
    address internal constant ATTESTATION = address(0xA11CE);

    // Bind the test's TCB codes to Automata's real FmspcTcbHelper.TCBStatus enum (pinned
    // @automata-network/on-chain-pccs) so the lenient policy is exercised against the actual enum
    // values; a dependency bump that reorders the enum breaks these tests instead of silently
    // misclassifying statuses on-chain.
    uint8 internal constant TCB_CONFIG_AND_SW_HARDENING =
        uint8(TCBStatus.TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED);
    uint8 internal constant TCB_CONFIG_NEEDED = uint8(TCBStatus.TCB_CONFIGURATION_NEEDED); // rejected
    uint8 internal constant TCB_OUT_OF_DATE = uint8(TCBStatus.TCB_OUT_OF_DATE);
    uint8 internal constant TCB_OUT_OF_DATE_CONFIG =
        uint8(TCBStatus.TCB_OUT_OF_DATE_CONFIGURATION_NEEDED);
    uint8 internal constant TCB_REVOKED = uint8(TCBStatus.TCB_REVOKED); // rejected
    uint8 internal constant TCB_UNRECOGNIZED = uint8(TCBStatus.TCB_UNRECOGNIZED); // rejected

    TestnetSgxVerifier internal verifier;

    bytes32 internal constant MR_ENCLAVE = bytes32(uint256(0x1111));
    bytes32 internal constant MR_SIGNER = bytes32(uint256(0x2222));

    function setUp() external {
        // owner == address(this) so this test can call the onlyOwner admin functions.
        verifier = new TestnetSgxVerifier(CHAIN_ID, address(this), ATTESTATION, address(0));
        // The MRENCLAVE/MRSIGNER allowlist is enforced by default; trust the standard enclave so
        // registrations turn on the TCB-status check rather than failing on the allowlist.
        verifier.setMrEnclave(MR_ENCLAVE, true);
        verifier.setMrSigner(MR_SIGNER, true);
    }

    // ---------------------------------------------------------------
    // Helpers (mirrors SgxVerifierTest)
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

    // ---------------------------------------------------------------
    // Lenient policy: additionally-accepted statuses succeed
    // ---------------------------------------------------------------

    function test_registerInstance_acceptsLenientTcbStatuses() external {
        uint8[3] memory lenient =
            [TCB_OUT_OF_DATE, TCB_OUT_OF_DATE_CONFIG, TCB_CONFIG_AND_SW_HARDENING];
        for (uint256 i; i < lenient.length; ++i) {
            address instance = address(uint160(0x1000 + i));
            bytes memory quote =
                _mockQuote(false, MR_ENCLAVE, MR_SIGNER, instance, 3, 1, lenient[i]);
            verifier.registerInstance(quote);
            assertTrue(verifier.addressRegistered(instance));
        }
    }

    function test_registerInstance_acceptsTcbOutOfDate() external {
        address instance = address(0xBEEF);
        bytes memory quote =
            _mockQuote(false, MR_ENCLAVE, MR_SIGNER, instance, 3, 1, TCB_OUT_OF_DATE);
        verifier.registerInstance(quote);
        assertTrue(verifier.addressRegistered(instance));
    }

    function test_registerInstance_acceptsTcbOutOfDateConfigNeeded() external {
        address instance = address(0xBEEF);
        bytes memory quote =
            _mockQuote(false, MR_ENCLAVE, MR_SIGNER, instance, 3, 1, TCB_OUT_OF_DATE_CONFIG);
        verifier.registerInstance(quote);
        assertTrue(verifier.addressRegistered(instance));
    }

    function test_registerInstance_acceptsTcbConfigAndSwHardeningNeeded() external {
        address instance = address(0xBEEF);
        bytes memory quote =
            _mockQuote(false, MR_ENCLAVE, MR_SIGNER, instance, 3, 1, TCB_CONFIG_AND_SW_HARDENING);
        verifier.registerInstance(quote);
        assertTrue(verifier.addressRegistered(instance));
    }

    // ---------------------------------------------------------------
    // Lenient policy: still rejects the unsafe statuses
    // ---------------------------------------------------------------

    function test_registerInstance_RevertWhen_TcbConfigNeeded() external {
        bytes memory quote =
            _mockQuote(false, MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 1, TCB_CONFIG_NEEDED);
        vm.expectRevert(BaseSgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_TcbRevoked() external {
        bytes memory quote =
            _mockQuote(false, MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 1, TCB_REVOKED);
        vm.expectRevert(BaseSgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }

    function test_registerInstance_RevertWhen_TcbUnrecognized() external {
        bytes memory quote =
            _mockQuote(false, MR_ENCLAVE, MR_SIGNER, address(0xBEEF), 3, 1, TCB_UNRECOGNIZED);
        vm.expectRevert(BaseSgxVerifier.SGX_INVALID_ATTESTATION.selector);
        verifier.registerInstance(quote);
    }
}
