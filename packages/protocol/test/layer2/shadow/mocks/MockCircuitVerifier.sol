// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ICircuitVerifier} from "../../src/iface/ICircuitVerifier.sol";

contract MockCircuitVerifier is ICircuitVerifier {
    bool public shouldVerify = true;

    function setShouldVerify(bool _shouldVerify) external {
        shouldVerify = _shouldVerify;
    }

    function verifyProof(bytes calldata, uint256[] calldata) external view returns (bool _isValid_) {
        _isValid_ = shouldVerify;
    }
}
