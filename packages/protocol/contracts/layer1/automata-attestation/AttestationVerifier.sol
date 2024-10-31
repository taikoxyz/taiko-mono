//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../shared/common/EssentialContract.sol";
import "./interfaces/IAttestationV2.sol";
import "./interfaces/IAttestationVerifier.sol";

/// @title AttestationVerifier
contract AttestationVerifier is IAttestationVerifier, EssentialContract {
    IAttestationV2 public automataDcapAttestation; // slot 1
    mapping(bytes32 pcr10 => bool trusted) public trustedPcr10; // slot 2
    bool checkPcr10; // slot3

    uint256[47] private __gap;

    function init(
        address _owner,
        address _automataDcapAttestation,
        bool _checkPcr10
    )
        external
        initializer
    {
        __Essential_init(_owner);
        automataDcapAttestation = IAttestationV2(_automataDcapAttestation);
        checkPcr10 = _checkPcr10;
    }

    function setCheckPcr10(bool _check) external onlyOwner {
        checkPcr10 = _check;
    }

    function setImagePcr10(bytes32 _pcr10, bool _trusted) external onlyOwner {
        trustedPcr10[_pcr10] = _trusted;
    }

    function verifyAttestation(
        bytes calldata _report,
        bytes32 _userData,
        bytes calldata _ext
    ) 
        external
    {
        if (address(automataDcapAttestation) == address(0)) return;

        (bool succ, bytes memory output) = automataDcapAttestation
            .verifyAndAttestOnChain(_report);
        if (!succ) revert INVALID_REPORT();

        if (output.length < 32) revert INVALID_REPORT_DATA();

        bytes32 quoteBodyLast32;
        assembly {
            quoteBodyLast32 := mload(
                add(add(output, 0x20), sub(mload(output), 32))
            )
        }

        ExtTpmInfo memory info = abi.decode(_ext, (ExtTpmInfo));

        bytes32 dataWithNonce = sha256(abi.encodePacked(info.akDer, _userData));
        if (quoteBodyLast32 != dataWithNonce) revert REPORT_DATA_MISMATCH(quoteBodyLast32, dataWithNonce);
        // TODO: verify tpm info

        if (checkPcr10 && !trustedPcr10[info.pcr10]) revert INVALID_PRC10(info.pcr10);
    }
}