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
abstract contract EssentialContract is OwnableUpgradeable, AddressResolver {
    uint8 private constant _NOPE = 1;
    uint8 private constant _YEP = 2;

    uint8 private _reentryStatus; // slot 1
    uint8 private _pauseStatus;

    event Paused(address account);
    event Unpaused(address account);

    error REENTRANT_CALL();
    error INVALID_PAUSE_STATUS();

    modifier nonReentrant() {
        if (_reentryStatus == _YEP) revert REENTRANT_CALL();
        _reentryStatus = _YEP;
        _;
        _reentryStatus = _NOPE;
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
        _pauseStatus = _YEP;
        emit Paused(msg.sender);
    }

    function unpause() external whenPaused onlyOwner {
        _pauseStatus = _NOPE;
        emit Unpaused(msg.sender);
    }

    function paused() public view returns (bool) {
        return _pauseStatus == _YEP;
    }

    /// @notice Initializes the contract with an address manager.
    /// @param _addressManager The address of the address manager.
    function _init(address _addressManager) internal virtual override {
        OwnableUpgradeable.__Ownable_init_unchained();
        AddressResolver._init(_addressManager);

        _reentryStatus = _NOPE;
        _pauseStatus = _NOPE;
    }
}
