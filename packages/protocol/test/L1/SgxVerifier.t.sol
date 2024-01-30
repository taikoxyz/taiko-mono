// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoL1TestBase.sol";

// For SGX remote attestation
import { AutomataDcapV3Attestation } from
    "../../contracts/thirdparty/automata-attestation/AutomataDcapV3Attestation.sol";
import { P256Verifier } from "../../lib/p256-verifier/src/P256Verifier.sol";
import { SigVerifyLib } from
    "../../contracts/thirdparty/automata-attestation/utils/SigVerifyLib.sol";
import { PEMCertChainLib } from
    "../../contracts/thirdparty/automata-attestation/lib/PEMCertChainLib.sol";

import "../automata-attestation/utils/DcapTestUtils.t.sol";
import "../automata-attestation/utils/V3JsonUtils.t.sol";

contract TestSgxVerifier is TaikoL1TestBase, DcapTestUtils, V3JsonUtils {
    address internal SGX_Y =
        vm.addr(0x9b1bb8cb3bdb539d0d1f03951d27f167f2d5443e7ef0d7ce745cd4ec619d3dd7);
    address internal SGX_Z = randAddress();
    // For SGX remote attestation
    AutomataDcapV3Attestation attestation;
    SigVerifyLib sigVerifyLib;
    P256Verifier p256Verifier;
    PEMCertChainLib pemCertChainLib;
    string internal constant tcbInfoPath = "/test/automata-attestation/assets/0923/tcbInfo.json";
    string internal constant idPath = "/test/automata-attestation/assets/0923/identity.json";
    string internal constant v3QuotePath = "/test/automata-attestation/assets/0923/v3quote.json";
    bytes32 constant mrEnclave = 0x46049af725ec3986eeb788693df7bc5f14d3f2705106a19cd09b9d89237db1a0;
    bytes32 constant mrSigner = 0xef69011f29043f084e99ce420bfebdfa410aee1e132014e7ceff29efa9659bd9;

    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        // Call the TaikoL1TestBase setUp()
        super.setUp();

        vm.warp(1_695_435_682);

        p256Verifier = new P256Verifier();
        sigVerifyLib = new SigVerifyLib(address(p256Verifier));
        pemCertChainLib = new PEMCertChainLib();
        attestation = new AutomataDcapV3Attestation(address(sigVerifyLib), address(pemCertChainLib));
        attestation.setMrEnclave(mrEnclave, true);
        attestation.setMrSigner(mrSigner, true);

        string memory tcbInfoJson = vm.readFile(string.concat(vm.projectRoot(), tcbInfoPath));
        string memory enclaveIdJson = vm.readFile(string.concat(vm.projectRoot(), idPath));

        string memory fmspc = "00606a000000";
        (bool tcbParsedSuccess, TCBInfoStruct.TCBInfo memory parsedTcbInfo) =
            parseTcbInfoJson(tcbInfoJson);
        require(tcbParsedSuccess, "tcb parsed failed");
        attestation.configureTcbInfoJson(fmspc, parsedTcbInfo);

        (bool qeIdParsedSuccess, EnclaveIdStruct.EnclaveId memory parsedEnclaveId) =
            parseEnclaveIdentityJson(enclaveIdJson);
        require(qeIdParsedSuccess, "qeid parsed failed");
        attestation.configureQeIdentityJson(parsedEnclaveId);

        registerAddress("automata_dcap_attestation", address(attestation));
    }

    function test_addInstancesByOwner() external {
        address[] memory _instances = new address[](3);
        _instances[0] = SGX_X_1;
        _instances[1] = SGX_Y;
        _instances[2] = SGX_Z;
        sv.addInstances(_instances);
    }

    function test_addInstancesByOwner_WithoutOwnerRole() external {
        address[] memory _instances = new address[](3);
        _instances[0] = SGX_X_0;
        _instances[1] = SGX_Y;
        _instances[2] = SGX_Z;

        vm.expectRevert();
        vm.prank(Bob, Bob);
        sv.addInstances(_instances);
    }

    function test_registerInstanceWithAttestation() external {
        string memory v3QuoteJsonStr = vm.readFile(string.concat(vm.projectRoot(), v3QuotePath));
        bytes memory v3QuotePacked = vm.parseJson(v3QuoteJsonStr);

        (, V3Struct.ParsedV3QuoteStruct memory v3quote) = parseV3QuoteJson(v3QuotePacked);

        vm.prank(Bob, Bob);
        sv.registerInstance(v3quote);
    }

    function _getSignature(
        address _newInstance,
        address[] memory _instances,
        uint256 privKey
    )
        private
        view
        returns (bytes memory signature)
    {
        bytes32 digest = keccak256(
            abi.encode(
                "ADD_INSTANCES",
                ITaikoL1(L1).getConfig().chainId,
                address(sv),
                _newInstance,
                _instances
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
