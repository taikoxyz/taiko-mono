// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../L1/ITaikoL1.sol";
import "../common/EssentialContract.sol";

contract NitroVerifier is EssentialContract {
    using ECDSA for bytes32;

    // The address of the L1 contract that this verifier is used with.
    address public immutable l1Contract;
}
