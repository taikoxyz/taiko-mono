// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../common/EssentialContract.sol";
import "./LibTokenGrant.sol";

/// @title TokenGrant
/// @notice Contract for managing Taiko tokens allocated to different roles and
/// individuals.
///
/// Manages Taiko tokens through a three-state lifecycle: "allocated" to
/// "granted, owned, and locked," and finally to "granted, owned, and unlocked."
/// Allocation doesn't transfer ownership unless specified by grant settings.
/// Conditional allocated tokens can be canceled by invoking `void()`, making
/// them available for other uses. Once granted and owned, tokens are
/// irreversible and their unlock schedules are immutable.
///
/// We should deploy multiple instances of this contract for different roles:
/// - investors
/// - team members, advisors, etc.
/// - grant program grantees
/// @custom:security-contact security@taiko.xyz
contract TokenGrant is EssentialContract {
    address public constant TAIKO_TOKEN = address(1);
    address public constant USTC_TOKEN = address(2);
    // TODO
}
