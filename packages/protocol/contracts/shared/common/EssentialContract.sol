// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IResolver.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @title EssentialContract
/// @custom:security-contact security@taiko.xyz
abstract contract EssentialContract is UUPSUpgradeable, Ownable2StepUpgradeable {
    // ---------------------------------------------------------------
    // Constants and Immutable Variables
    // ---------------------------------------------------------------
    uint8 internal constant _FALSE = 1;
    uint8 internal constant _TRUE = 2;

    address internal immutable __resolver;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    uint256[50] private __gapFromOldAddressResolver;

    /// @dev Slot 1.
    uint8 internal __reentry;
    uint8 internal __paused;

    uint256[49] private __gap;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when the contract is paused.
    /// @param account The account that paused the contract.
    event Paused(address account);

    /// @notice Emitted when the contract is unpaused.
    /// @param account The account that unpaused the contract.
    event Unpaused(address account);

    error INVALID_PAUSE_STATUS();
    error FUNC_NOT_IMPLEMENTED();
    error REENTRANT_CALL();
    error ACCESS_DENIED();
    error ZERO_ADDRESS();
    error ZERO_VALUE();

    // ---------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------

    /// @dev Modifier that ensures the caller is either the owner or a specified address.
    /// @param _addr The address to check against.
    modifier onlyFromOwnerOr(address _addr) {
        _checkOwnerOr(_addr);
        _;
    }

    /// @dev Modifier that reverts the function call, indicating it is not implemented.
    modifier notImplemented() {
        revert FUNC_NOT_IMPLEMENTED();
        _;
    }

    /// @dev Modifier that prevents reentrant calls to a function.
    modifier nonReentrant() {
        _checkReentrancy();
        _storeReentryLock(_TRUE);
        _;
        _storeReentryLock(_FALSE);
    }

    /// @dev Modifier that allows function execution only when the contract is paused.
    modifier whenPaused() {
        _checkPaused();
        _;
    }

    /// @dev Modifier that allows function execution only when the contract is not paused.
    modifier whenNotPaused() {
        _checkNotPaused();
        _;
    }

    /// @dev Modifier that ensures the provided address is not the zero address.
    /// @param _addr The address to check.
    modifier nonZeroAddr(address _addr) {
        _checkNonZeroAddr(_addr);
        _;
    }

    /// @dev Modifier that ensures the provided value is not zero.
    /// @param _value The value to check.
    modifier nonZeroValue(uint256 _value) {
        _checkNonZeroValue(_value);
        _;
    }

    /// @dev Modifier that ensures the provided bytes32 value is not zero.
    /// @param _value The bytes32 value to check.
    modifier nonZeroBytes32(bytes32 _value) {
        _checkNonZeroBytes32(_value);
        _;
    }

    /// @dev Modifier that ensures the caller is either of the two specified addresses.
    /// @param _addr1 The first address to check against.
    /// @param _addr2 The second address to check against.
    modifier onlyFromEither(address _addr1, address _addr2) {
        _checkFromEither(_addr1, _addr2);
        _;
    }

    /// @dev Modifier that ensures the caller is the specified address.
    /// @param _addr The address to check against.
    modifier onlyFrom(address _addr) {
        _checkFrom(_addr);
        _;
    }

    /// @dev Modifier that ensures the caller is the specified address.
    /// @param _addr The address to check against.
    modifier onlyFromOptional(address _addr) {
        _checkFromOptional(_addr);
        _;
    }

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor() {
        _disableInitializers();
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Pauses the contract.
    function pause() public whenNotPaused {
        _pause();
        emit Paused(msg.sender);
        // We call the authorize function here to avoid:
        // Warning (5740): Unreachable code.
        _authorizePause(msg.sender, true);
    }

    /// @notice Unpauses the contract.
    function unpause() public whenPaused {
        _unpause();
        emit Unpaused(msg.sender);
        // We call the authorize function here to avoid:
        // Warning (5740): Unreachable code.
        _authorizePause(msg.sender, false);
    }

    function impl() public view returns (address) {
        return _getImplementation();
    }

    /// @notice Returns true if the contract is paused, and false otherwise.
    /// @return true if paused, false otherwise.
    function paused() public view virtual returns (bool) {
        return __paused == _TRUE;
    }

    function inNonReentrant() public view returns (bool) {
        return _loadReentryLock() == _TRUE;
    }

    /// @notice Returns the address of this contract.
    /// @return The address of this contract.
    function resolver() public view virtual returns (address) {
        return __resolver;
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function __Essential_init(address _owner) internal virtual onlyInitializing {
        __Context_init();
        _transferOwnership(_owner == address(0) ? msg.sender : _owner);
        __paused = _FALSE;
    }

    function _pause() internal virtual {
        __paused = _TRUE;
    }

    function _unpause() internal virtual {
        __paused = _FALSE;
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner { }

    function _authorizePause(address, bool) internal virtual onlyOwner { }

    // Stores the reentry lock
    function _storeReentryLock(uint8 _reentry) internal virtual {
        __reentry = _reentry;
    }

    // Loads the reentry lock
    function _loadReentryLock() internal view virtual returns (uint8 reentry_) {
        reentry_ = __reentry;
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    function _checkOwnerOr(address _addr) private view {
        require(msg.sender == owner() || msg.sender == _addr, ACCESS_DENIED());
    }

    function _checkReentrancy() private view {
        require(_loadReentryLock() != _TRUE, REENTRANT_CALL());
    }

    function _checkPaused() private view {
        require(paused(), INVALID_PAUSE_STATUS());
    }

    function _checkNotPaused() private view {
        require(!paused(), INVALID_PAUSE_STATUS());
    }

    function _checkNonZeroAddr(address _addr) private pure {
        require(_addr != address(0), ZERO_ADDRESS());
    }

    function _checkNonZeroValue(uint256 _value) private pure {
        require(_value != 0, ZERO_VALUE());
    }

    function _checkNonZeroBytes32(bytes32 _value) private pure {
        require(_value != 0, ZERO_VALUE());
    }

    function _checkFromEither(address _addr1, address _addr2) private view {
        require(msg.sender == _addr1 || msg.sender == _addr2, ACCESS_DENIED());
    }

    function _checkFrom(address _addr) private view {
        require(msg.sender == _addr, ACCESS_DENIED());
    }

    function _checkFromOptional(address _addr) private view {
        require(_addr == address(0) || msg.sender == _addr, ACCESS_DENIED());
    }
}
