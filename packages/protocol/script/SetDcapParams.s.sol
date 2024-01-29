// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../contracts/thirdparty/onchainRA/AutomataDcapV3Attestation.sol";
import "../contracts/L1/verifiers/SgxVerifier.sol";
import "../test/onchainRA/utils/DcapTestUtils.t.sol";
import "../test/onchainRA/utils/V3JsonUtils.t.sol";

contract SetDcapParams is Script, DcapTestUtils, V3JsonUtils {
    //@todo: Wand Yue -> after deployed with DeployOnL1, you have the parameters, fill in the proper
    // .env vars the the parameter files, and run this script.
    uint256 public ownerPrivateKey = vm.envUint("PRIVATE_KEY"); // Owner of the attestation contract
    address public dcapAttestationAddress = vm.envAddress("ATTESTATION_ADDRESS");
    address public sgxVerifier = vm.envAddress("SGX_VERIFIER_ADDRESS");
    string public tcbInfoPath = vm.envString("TCB_INFO_PATH");
    string public idPath = vm.envString("QEID_PATH");
    string public v3QuotePath = vm.envString("V3_QUOTE_PATH");
    bytes32 public mrEnclave = vm.envBytes32("MR_ENCLAVE");
    bytes32 public mrSigner = vm.envBytes32("MR_SIGNER");

    function run() external {
        require(ownerPrivateKey != 0, "PRIVATE_KEY not set");
        require(dcapAttestationAddress != address(0), "ATTESTATION_ADDRESS not set");

        vm.startBroadcast(ownerPrivateKey);

        // all in one
        setMrEnclave();
        setMrSigner();
        configureQeIdentityJson();
        configureTcbInfoJson();
        registerSgxInstanceWithQuote();

        vm.stopBroadcast();
    }

    function setMrEnclave() internal {
        AutomataDcapV3Attestation(dcapAttestationAddress).setMrEnclave(mrEnclave, true);
    }

    function setMrSigner() internal {
        AutomataDcapV3Attestation(dcapAttestationAddress).setMrSigner(mrSigner, true);
    }

    function configureQeIdentityJson() internal {
        string memory enclaveIdJson = vm.readFile(string.concat(vm.projectRoot(), idPath));
        (bool qeIdParsedSuccess, EnclaveIdStruct.EnclaveId memory parsedEnclaveId) =
            parseEnclaveIdentityJson(enclaveIdJson);
        AutomataDcapV3Attestation(dcapAttestationAddress).configureQeIdentityJson(parsedEnclaveId);
        console.log("qeIdParsedSuccess: %s", qeIdParsedSuccess);
    }

    function configureTcbInfoJson() internal {
        string memory tcbInfoJson = vm.readFile(string.concat(vm.projectRoot(), tcbInfoPath));
        (bool tcbParsedSuccess, TCBInfoStruct.TCBInfo memory parsedTcbInfo) =
            parseTcbInfoJson(tcbInfoJson);
        // string memory fmspc = "00606a000000";
        string memory fmspc = parsedTcbInfo.fmspc;
        AutomataDcapV3Attestation(dcapAttestationAddress).configureTcbInfoJson(fmspc, parsedTcbInfo);
        console.log("tcbParsedSuccess: %s", tcbParsedSuccess);
    }

    function registerSgxInstanceWithQuote() internal {
        string memory v3QuoteJsonStr = vm.readFile(string.concat(vm.projectRoot(), v3QuotePath));
        console.log("[LOG] v3QuoteJsonStr: %s", v3QuoteJsonStr);
        bytes memory v3QuotePacked = vm.parseJson(v3QuoteJsonStr);
        console.logBytes(v3QuotePacked);

        (, V3Struct.ParsedV3QuoteStruct memory v3quote) = parseV3QuoteJson(v3QuotePacked);
        console.log("v3quote.header.userData = %s", address(v3quote.header.userData));
        console.logBytes(v3quote.localEnclaveReport.reportData);
        uint256 ret = SgxVerifier(sgxVerifier).registerInstance(v3quote);
        console.log("SGX register instance Id: %s", ret);
    }
}
