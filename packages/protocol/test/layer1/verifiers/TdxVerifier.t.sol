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
    bool internal deriveOutputFromRawQuote;
    bytes internal output;

    function setResult(bool _verified, bytes memory _output) external {
        deriveOutputFromRawQuote = false;
        verified = _verified;
        output = _output;
    }

    function setDeriveOutputFromRawQuote(bool _deriveOutputFromRawQuote) external {
        deriveOutputFromRawQuote = _deriveOutputFromRawQuote;
    }

    function verifyAndAttestOnChain(bytes calldata rawQuote)
        external
        view
        returns (bool, bytes memory)
    {
        if (deriveOutputFromRawQuote) {
            return (verified, _dcapOutputFromRawQuotePrefix(rawQuote));
        }
        return (verified, output);
    }

    function _dcapOutputFromRawQuotePrefix(bytes calldata rawQuote)
        private
        pure
        returns (bytes memory dcapOutput)
    {
        require(rawQuote.length >= 632, "raw quote prefix too short");

        dcapOutput = new bytes(595);

        dcapOutput[0] = rawQuote[1];
        dcapOutput[1] = rawQuote[0];
        dcapOutput[2] = rawQuote[3];
        dcapOutput[3] = rawQuote[2];
        dcapOutput[4] = 0;

        for (uint256 i; i < 6; ++i) {
            dcapOutput[5 + i] = rawQuote[12 + i];
        }
        for (uint256 i; i < 584; ++i) {
            dcapOutput[11 + i] = rawQuote[48 + i];
        }
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

    function test_gcpBootstrapRegistration_AcceptsRealBootstrapQuotePrefix() external {
        bytes memory rawQuotePrefix = _realBootstrapRawQuotePrefix();
        bytes memory userData = _realBootstrapUserData();
        bytes memory nonce = _realBootstrapNonce();
        address instance = address(bytes20(userData));

        assertEq(instance, 0xca1dF2D2685DC35AE07C27dC85319ee735cc8F30);

        gcpVerifier.setTrustedParams(0, _gcpTrustedParamsFromRawQuotePrefix(rawQuotePrefix));
        automata.setDeriveOutputFromRawQuote(true);

        gcpVerifier.registerInstance(0, rawQuotePrefix, userData, nonce);

        assertGt(gcpVerifier.addressValidSince(instance), 0);
        assertTrue(gcpVerifier.isInstanceRegistered(instance));
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

    function _gcpTrustedParamsFromRawQuotePrefix(bytes memory rawQuotePrefix)
        private
        pure
        returns (GcpTdxVerifier.TrustedParams memory params)
    {
        bytes[] memory rtmrs = new bytes[](3);
        rtmrs[0] = _slice(rawQuotePrefix, 376, 48);
        rtmrs[1] = _slice(rawQuotePrefix, 424, 48);
        rtmrs[2] = _slice(rawQuotePrefix, 472, 48);

        params = GcpTdxVerifier.TrustedParams({
            teeTcbSvn: bytes16(_slice(rawQuotePrefix, 48, 16)),
            rtmrMask: 7,
            mrSeam: _slice(rawQuotePrefix, 64, 48),
            mrTd: _slice(rawQuotePrefix, 184, 48),
            rtmrs: rtmrs
        });
    }

    function _realBootstrapRawQuotePrefix() private pure returns (bytes memory) {
        // First 632 bytes of a real reth-tdx /bootstrap RawQuote from a GCP TDX VM.
        return bytes.concat(
            hex"040002008100000000000000939a7233f79c4ca9940a0db3957f0607000000000000000000000000",
            hex"00000000000000000d010800000000000000000000000000489e585f1c54bc5a02066c8c6ec21619",
            hex"ff0334ec6f21e07e2a35202c59183789c8057e7d97dd591bb08314b185819e720000000000000000",
            hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000",
            hex"00000000000000000000001000000000e700060000000000feb7486608382c1ff0e15b4648ddc0ac",
            hex"ea6ca974eb53e3529f4c4bd5ffbaa20bf335cb75965cea65fe473aed9647c1620000000000000000",
            hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000",
            hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000",
            hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000",
            hex"00000000000000000000000000000000625d8cf7e50917681a9fec5da4acef4e66972be2faa2f686",
            hex"73f5cd8a456aa318057fbe4392407c9e2bdf469af93d385a927e27ef8153fdedd2ea483b5c03d99e",
            hex"00b2419ffdd3feda2ea185193b2e63dd211b722d5abd11e34a6a557f7976bec72cbdf1126d270e7f",
            hex"ae622eb3917c2cb625fac10452b79a51b67f73b6db35b6bf1111f55877fbfd29a60efebb16fe703a",
            hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000",
            hex"0000000000000000a048f208599096e3c45b32771cef219c2cf0166404bf296c5c461cd69d17df95",
            hex"0000000000000000000000000000000000000000000000000000000000000000"
        );
    }

    function _realBootstrapUserData() private pure returns (bytes memory) {
        return hex"ca1df2d2685dc35ae07c27dc85319ee735cc8f30000000000000000000000000";
    }

    function _realBootstrapNonce() private pure returns (bytes memory) {
        return hex"0ba32989765f4da1a07053f4f79fc6fc8dfcf9fd7fff3908634ec75b869dec85";
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

    function _slice(
        bytes memory data,
        uint256 offset,
        uint256 size
    )
        private
        pure
        returns (bytes memory out)
    {
        out = new bytes(size);
        for (uint256 i; i < size; ++i) {
            out[i] = data[offset + i];
        }
    }

    function _copy(bytes memory dst, uint256 offset, bytes memory src) private pure {
        for (uint256 i; i < src.length; ++i) {
            dst[offset + i] = src[i];
        }
    }
}
