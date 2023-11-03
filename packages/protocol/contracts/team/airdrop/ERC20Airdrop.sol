// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { BaseAirdrop } from "./BaseAirdrop.sol";

import { console2 } from "forge-std/console2.sol";
import { Proxied } from "../../common/Proxied.sol";

/// @dev This shall be implemented by the vaults helping with the airdrop.
interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 value
    )
        external
        returns (bool);
}

/// @title ERC20Airdrop
/// Contract for managing Taiko token airdrop for eligible users
contract ERC20Airdrop is BaseAirdrop {
    struct ERC20InputParams {
        bytes32[] merkleProof; // Format is given (see OZ code)
        uint256 allowance;
    }

    event UserClaimed(address indexed user, uint256 amount);

    /// @notice Claim airdrop
    /// @param inputData Encoded data containing merkle proof and related
    /// variables (amount, contract, etc.)
    function claim(bytes calldata inputData) external virtual override {
        if (merkleRoot == 0x0) {
            revert CLAIM_NOT_STARTED();
        }

        ERC20InputParams memory input =
            abi.decode(inputData, (ERC20InputParams));

        // Create the leafs - a leaf consist of the 2 data encoded (address and
        // allowance). See claimList.ts and buildMerkleTree.ts for more info !
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, input.allowance));
        verifyProof(input.merkleProof, leaf);

        if (!leafClaimed[leaf]) {
            leafClaimed[leaf] = true;
            bool success = IERC20(tokenAddress).transferFrom(
                tokenVaultAddress, msg.sender, input.allowance
            );

            if (!success) {
                revert UNSUCCESSFUL_TRANSFER();
            }

            emit UserClaimed(msg.sender, input.allowance);
            return;
        }
        revert CLAIMED_ALREADY();
    }
}

/// @title ProxiedERC20Airdrop
/// @notice Proxied version of the parent contract.
contract ProxiedERC20Airdrop is Proxied, ERC20Airdrop { }
