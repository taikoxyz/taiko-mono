// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { OwnableUpgradeable } from
    "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

import { AddressResolver } from "./AddressResolver.sol";

/// @title EssentialContract
/// @notice This contract serves as the base contract for many core components.
/// @dev We didn't use OpenZeppelin's PausableUpgradeable and
/// ReentrancyGuardUpgradeable conract in order to optimize storage reads
abstract contract EssentialContract is OwnableUpgradeable, AddressResolver {
    uint8 private constant _FALSE = 1;
    uint8 private constant _TRUE = 2;

    uint8 private _reentryStatus; // slot 1
    uint8 private _pauseStatus;

    event Paused(address account);
    event Unpaused(address account);

    error REENTRANT_CALL();
    error INVALID_PAUSE_STATUS();

    modifier nonReentrant() {
        if (_reentryStatus == _TRUE) revert REENTRANT_CALL();
        _reentryStatus = _TRUE;
        _;
        _reentryStatus = _FALSE;
    }

    modifier whenPaused() {
        if (!paused()) revert INVALID_PAUSE_STATUS();
        _;
    }

    modifier whenNotPaused() {
        if (paused()) revert INVALID_PAUSE_STATUS();
        _;
    }

    function pause() external whenNotPaused onlyOwner {
        _pauseStatus = _TRUE;
        emit Paused(msg.sender);
    }

    function unpause() external whenPaused onlyOwner {
        _pauseStatus = _FALSE;
        emit Unpaused(msg.sender);
    }

    function paused() public view returns (bool) {
        return _pauseStatus == _TRUE;
    }

    /// @notice Initializes the contract with an address manager.
    /// @param _addressManager The address of the address manager.
    function _init(address _addressManager) internal virtual override {
        OwnableUpgradeable.__Ownable_init_unchained();
        AddressResolver._init(_addressManager);

        _reentryStatus = _FALSE;
        _pauseStatus = _FALSE;
    }
}
