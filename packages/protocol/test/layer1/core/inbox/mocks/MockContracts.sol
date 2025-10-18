// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/layer1/verifiers/IProofVerifier.sol";

/// @title MockERC20
/// @notice Mock ERC20 token for testing bond mechanics
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title MockProofVerifier
/// @notice Mock proof verifier that always accepts proofs
contract MockProofVerifier is IProofVerifier {
    function verifyProof(uint256, bytes32, bytes calldata) external pure {
        // Always accept
    }
}
