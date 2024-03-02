// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "../test/automata-attestation/common/AttestationBase.t.sol";

contract SetDcapParams is Script, AttestationBase {
    uint256 public ownerPrivateKey = vm.envUint("PRIVATE_KEY"); // Owner of the attestation contract
    address public dcapAttestationAddress = vm.envAddress("ATTESTATION_ADDRESS");
    address public sgxVerifier = vm.envAddress("SGX_VERIFIER_ADDRESS");
    address public pemCertChainLibAddr = vm.envAddress("PEM_CERTCHAIN_ADDRESS");
    // TASK_FLAG: [setMrEnclave,setMrSigner,configQE,configTCB,registerSgxInstanceWithQuote]
    bool[] internal defaultTaskFlags = [true, true, true, true, true];
    bool[] public taskFlags = vm.envOr("TASK_ENABLE", ",", defaultTaskFlags);

    function run() external {
        require(ownerPrivateKey != 0, "PRIVATE_KEY not set");
        require(dcapAttestationAddress != address(0), "ATTESTATION_ADDRESS not set");

        vm.startBroadcast(ownerPrivateKey);
        if (taskFlags[0]) {
            _setMrEnclave();
        }
        if (taskFlags[1]) {
            _setMrSigner();
        }
        if (taskFlags[2]) {
            _configureQeIdentityJson();
        }
        if (taskFlags[3]) {
            _configureTcbInfoJson();
        }
        if (taskFlags[4]) {
            _registerSgxInstanceWithQuoteBytes();
        }

        vm.stopBroadcast();
    }

    function _setMrEnclave() internal {
        mrEnclave = vm.envBytes32("MR_ENCLAVE");
        setMrEnclave(dcapAttestationAddress, mrEnclave);
        console2.log("MR_ENCLAVE set: ", uint256(mrEnclave));
    }

    function _setMrSigner() internal {
        mrSigner = vm.envBytes32("MR_SIGNER");
        setMrSigner(dcapAttestationAddress, mrSigner);
        console2.log("MR_SIGNER set: ", uint256(mrSigner));
    }

    function _configureQeIdentityJson() internal {
        idPath = vm.envString("QEID_PATH");
        string memory enclaveIdJson = vm.readFile(string.concat(vm.projectRoot(), idPath));
        configureQeIdentityJson(dcapAttestationAddress, enclaveIdJson);
        console2.log("QE_IDENTITY_JSON set:");
        console2.logString(enclaveIdJson);
    }

    function _configureTcbInfoJson() internal {
        tcbInfoPath = vm.envString("TCB_INFO_PATH");
        string memory tcbInfoJson = vm.readFile(string.concat(vm.projectRoot(), tcbInfoPath));
        configureTcbInfoJson(dcapAttestationAddress, tcbInfoJson);
        console2.logString("TCB_INFO_JSON set: ");
        console2.logString(tcbInfoJson);
    }

    function _registerSgxInstanceWithQuoteBytes() internal {
        bytes memory v3QuoteBytes = vm.envBytes("V3_QUOTE_BYTES");
        registerSgxInstanceWithQuoteBytes(pemCertChainLibAddr, sgxVerifier, v3QuoteBytes);
    }
}
