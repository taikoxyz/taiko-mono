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

pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../test/automata-attestation/common/AttestationBase.t.sol";

contract SetDcapParams is Script, AttestationBase {
    uint256 public ownerPrivateKey = vm.envUint("PRIVATE_KEY"); // Owner of the attestation contract
    address public dcapAttestationAddress = vm.envAddress("ATTESTATION_ADDRESS");
    address public sgxVerifier = vm.envAddress("SGX_VERIFIER_ADDRESS");

    function run() external {
        tcbInfoPath = vm.envString("TCB_INFO_PATH");
        idPath = vm.envString("QEID_PATH");
        v3QuotePath = vm.envString("V3_QUOTE_PATH");
        mrEnclave = vm.envBytes32("MR_ENCLAVE");
        mrSigner = vm.envBytes32("MR_SIGNER");

        require(ownerPrivateKey != 0, "PRIVATE_KEY not set");
        require(dcapAttestationAddress != address(0), "ATTESTATION_ADDRESS not set");

        vm.startBroadcast(ownerPrivateKey);

        setMrEnclave(dcapAttestationAddress, mrEnclave);
        setMrSigner(dcapAttestationAddress, mrSigner);

        string memory enclaveIdJson = vm.readFile(string.concat(vm.projectRoot(), idPath));
        configureQeIdentityJson(dcapAttestationAddress, enclaveIdJson);

        string memory tcbInfoJson = vm.readFile(string.concat(vm.projectRoot(), tcbInfoPath));
        configureTcbInfoJson(dcapAttestationAddress, tcbInfoJson);

        string memory v3QuoteJsonStr = vm.readFile(string.concat(vm.projectRoot(), v3QuotePath));
        registerSgxInstanceWithQuote(sgxVerifier, v3QuoteJsonStr);

        vm.stopBroadcast();
    }
}
