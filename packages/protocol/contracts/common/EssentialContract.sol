// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "./AddressResolver.sol";

/// @title EssentialContract
/// @custom:security-contact security@taiko.xyz
abstract contract EssentialContract is UUPSUpgradeable, Ownable2StepUpgradeable, AddressResolver {
    uint8 private constant _FALSE = 1;
    uint8 private constant _TRUE = 2;

    // The slot in transient storage of the reentry lock
    // This is the keccak256 hash of "ownerUUPS.reentry_slot"
    bytes32 private constant _REENTRY_SLOT =
        0xa5054f728453d3dbe953bdc43e4d0cb97e662ea32d7958190f3dc2da31d9721a;

    uint8 private _reentry; // slot 1
    uint8 private _paused;
    uint256[49] private __gap;

    event Paused(address account);
    event Unpaused(address account);

    error REENTRANT_CALL();
    error INVALID_PAUSE_STATUS();
    error ZERO_ADDR_MANAGER();

    /// @dev Modifier that ensures the caller is the owner or resolved address of a given name.
    /// @param _name The name to check against.
    modifier onlyFromOwnerOrNamed(bytes32 _name) {
        if (msg.sender != owner() && msg.sender != resolve(_name, true)) revert RESOLVER_DENIED();
        _;
    }

    modifier nonReentrant() {
        if (_loadReentryLock() == _TRUE) revert REENTRANT_CALL();
        _storeReentryLock(_TRUE);
        _;
        _storeReentryLock(_FALSE);
    }

    modifier whenPaused() {
        if (!paused()) revert INVALID_PAUSE_STATUS();
        _;
    }

    modifier whenNotPaused() {
        if (paused()) revert INVALID_PAUSE_STATUS();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function pause() public virtual whenNotPaused {
        _paused = _TRUE;
        emit Paused(msg.sender);
        _authorizePause(msg.sender);
    }

    function unpause() public virtual whenPaused {
        _paused = _FALSE;
        emit Unpaused(msg.sender);
        _authorizePause(msg.sender);
    }

    function paused() public view returns (bool) {
        return _paused == _TRUE;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    // solhint-disable-next-line func-name-mixedcase
    function __Essential_init(
        address _owner,
        address _addressManager
    )
        internal
        virtual
        onlyInitializing
    {
        __Essential_init(_owner);

        if (_addressManager == address(0)) revert ZERO_ADDR_MANAGER();
        __AddressResolver_init(_addressManager);
    }

    // solhint-disable-next-line func-name-mixedcase
    function __Essential_init(address _owner) internal virtual {
        _transferOwnership(_owner == address(0) ? msg.sender : _owner);
        _paused = _FALSE;
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
    function _authorizePause(address) internal virtual onlyOwner { }

    // Stores the reentry lock
    function _storeReentryLock(uint8 reentry) internal virtual {
        if (block.chainid == 1) {
            assembly {
                tstore(_REENTRY_SLOT, reentry)
            }
        } else {
            _reentry = reentry;
        }
    }

    // Loads the reentry lock
    function _loadReentryLock() internal view virtual returns (uint8 reentry_) {
        if (block.chainid == 1) {
            assembly {
                reentry_ := tload(_REENTRY_SLOT)
            }
        } else {
            reentry_ = _reentry;
        }
    }

    function _inNonReentrant() internal view returns (bool) {
        return _loadReentryLock() == _TRUE;
    }
}
