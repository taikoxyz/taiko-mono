// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/layer1/automata-attestation/AttestationBase.sol";
import "script/BaseScript.sol";

contract SetDcapParams is BaseScript, AttestationBase {
    address public dcapAttestationAddress = vm.envAddress("ATTESTATION_ADDRESS");
    address public sgxVerifier = vm.envAddress("SGX_VERIFIER_ADDRESS");
    address public pemCertChainLibAddr = vm.envAddress("PEM_CERTCHAIN_ADDRESS");
    // TASK_FLAG:
    // [setMrEnclave,setMrSigner,configQE,configTCB,enableMrCheck,registerSgxInstanceWithQuote]
    uint256[] internal defaultTaskFlags = [1, 1, 1, 1, 1, 1];
    uint256[] public taskFlags = vm.envOr("TASK_ENABLE", ",", defaultTaskFlags);

    function run() external broadcast {
        require(dcapAttestationAddress != address(0), "ATTESTATION_ADDRESS not set");
        require(sgxVerifier != address(0), "SGX_VERIFIER_ADDRESS not set");
        require(pemCertChainLibAddr != address(0), "PEM_CERTCHAIN_ADDRESS not set");

        if (taskFlags[0] != 0) {
            bool enable = (taskFlags[0] == 1);
            _setMrEnclave(enable);
        }
        if (taskFlags[1] != 0) {
            bool enable = (taskFlags[1] == 1);
            _setMrSigner(enable);
        }
        if (taskFlags[2] != 0) {
            _configureQeIdentityJson();
        }
        if (taskFlags[3] != 0) {
            _configureTcbInfoJson();
        }
        if (taskFlags[4] != 0) {
            toggleCheckQuoteValidity(dcapAttestationAddress);
        }
        if (taskFlags[5] != 0) {
            _registerSgxInstanceWithQuoteBytes();
        }
    }

    function _setMrEnclave(bool enable) internal {
        mrEnclave = vm.envBytes32("MR_ENCLAVE");
        console2.log("_setMrEnclave set: ", uint256(mrEnclave));
        setMrEnclave(dcapAttestationAddress, mrEnclave, enable);
        console2.log("MR_ENCLAVE set: ", uint256(mrEnclave));
    }

    function _setMrSigner(bool enable) internal {
        mrSigner = vm.envBytes32("MR_SIGNER");
        setMrSigner(dcapAttestationAddress, mrSigner, enable);
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
        string memory tcbInfoPath = vm.envString("TCB_INFO_PATH");
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
