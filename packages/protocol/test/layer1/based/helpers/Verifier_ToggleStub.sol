// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/verifiers/IVerifier.sol";

contract Verifier_ToggleStub is IVerifier {
    bool private _paused;

    function verifyProof(Context[] calldata, bytes calldata) external view {
        require(!_paused, "IVerifier failure");
    }

    function pause() public override {
        _paused = true;
    }

    function unpause() public override {
        _paused = false;
    }

    function paused() external view returns (bool) {
        return _paused;
    }
}
