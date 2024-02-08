// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../contracts/thirdparty/optimism/Bytes.sol";

/// @author Kirk Baird <kirk@sigmaprime.io>
contract MockPlonkVerifier {
    bool public _shouldRevert;

    // Mock verifier that just returns what is sent in the proof after the first 64 bytes
    fallback(bytes calldata input) external returns (bytes memory) {
        require(!_shouldRevert, "We're going to revert here for fun :)");

        return Bytes.slice(input, 64, input.length - 64);
    }

    function setShouldRevert(bool shouldRevert) public {
        _shouldRevert = shouldRevert;
    }
}
