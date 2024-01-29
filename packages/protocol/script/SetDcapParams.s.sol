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
import "../test/onchainRA/utils/DcapTestUtils.t.sol";

contract SetAddress is Script, DcapTestUtils {
    //@todo: Wand Yue -> after deployed with DeployOnL1, you have the parameters, fill in the proper
    // .env vars the the parameter files, and run this script.
    uint256 public ownerPrivateKey = vm.envUint("PRIVATE_KEY"); // Owner of the attestation contract
    address public dcapAttestationAddress = vm.envAddress("ATTESTATION_ADDRESS");
    string public tcbInfoPath = vm.envString("TCB_INFO_PATH");
    string public idPath = vm.envString("TCB_ID_PATH");
    string public v3QuotePath = vm.envString("V3_QUOTE_PATH");
    bytes32 public mrEnclave = vm.envBytes32("MR_ENCLAVE");
    bytes32 public mrSigner = vm.envBytes32("MR_SIGNER");

    function run() external {
        require(ownerPrivateKey != 0, "PRIVATE_KEY not set");
        require(dcapAttestationAddress != address(0), "ATTESTATION_ADDRESS not set");

        vm.startBroadcast(ownerPrivateKey);

        AutomataDcapV3Attestation(dcapAttestationAddress).setMrEnclave(mrEnclave, true);
        AutomataDcapV3Attestation(dcapAttestationAddress).setMrSigner(mrSigner, true);

        string memory tcbInfoJson = vm.readFile(string.concat(vm.projectRoot(), tcbInfoPath));
        string memory enclaveIdJson = vm.readFile(string.concat(vm.projectRoot(), idPath));

        string memory fmspc = "00606a000000";
        (bool tcbParsedSuccess, TCBInfoStruct.TCBInfo memory parsedTcbInfo) =
            parseTcbInfoJson(tcbInfoJson);
        require(tcbParsedSuccess, "tcb parsed failed");
        AutomataDcapV3Attestation(dcapAttestationAddress).configureTcbInfoJson(fmspc, parsedTcbInfo);

        (bool qeIdParsedSuccess, EnclaveIdStruct.EnclaveId memory parsedEnclaveId) =
            parseEnclaveIdentityJson(enclaveIdJson);
        require(qeIdParsedSuccess, "qeid parsed failed");
        AutomataDcapV3Attestation(dcapAttestationAddress).configureQeIdentityJson(parsedEnclaveId);

        vm.stopBroadcast();
    }
}
