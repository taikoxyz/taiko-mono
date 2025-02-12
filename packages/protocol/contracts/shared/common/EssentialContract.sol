// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "./IResolver.sol";

/// @title EssentialContract
/// @custom:security-contact security@taiko.xyz
abstract contract EssentialContract is UUPSUpgradeable, Ownable2StepUpgradeable {
    uint8 internal constant _FALSE = 1;
    uint8 internal constant _TRUE = 2;

    address private immutable __resolver;
    uint256[50] private __gapFromOldAddressResolver;

    /// @dev Slot 1.
    uint8 internal __reentry;
    uint8 internal __paused;

    uint256[49] private __gap;

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
    error RESOLVER_NOT_FOUND();
    error ZERO_ADDRESS();
    error ZERO_VALUE();

    /// @dev Modifier that ensures the caller is the owner or resolved address of a given name.
    /// @param _name The name to check against.
    modifier onlyFromOwnerOrNamed(bytes32 _name) {
        require(msg.sender == owner() || msg.sender == resolve(_name, true), ACCESS_DENIED());
        _;
    }

    /// @dev Modifier that ensures the caller is either the owner or a specified address.
    /// @param _addr The address to check against.
    modifier onlyFromOwnerOr(address _addr) {
        require(msg.sender == owner() || msg.sender == _addr, ACCESS_DENIED());
        _;
    }

    /// @dev Modifier that reverts the function call, indicating it is not implemented.
    modifier notImplemented() {
        revert FUNC_NOT_IMPLEMENTED();
        _;
    }

    /// @dev Modifier that prevents reentrant calls to a function.
    modifier nonReentrant() {
        require(_loadReentryLock() != _TRUE, REENTRANT_CALL());
        _storeReentryLock(_TRUE);
        _;
        _storeReentryLock(_FALSE);
    }

    /// @dev Modifier that allows function execution only when the contract is paused.
    modifier whenPaused() {
        require(paused(), INVALID_PAUSE_STATUS());
        _;
    }

    /// @dev Modifier that allows function execution only when the contract is not paused.
    modifier whenNotPaused() {
        require(!paused(), INVALID_PAUSE_STATUS());
        _;
    }

    /// @dev Modifier that ensures the provided address is not the zero address.
    /// @param _addr The address to check.
    modifier nonZeroAddr(address _addr) {
        require(_addr != address(0), ZERO_ADDRESS());
        _;
    }

    /// @dev Modifier that ensures the provided value is not zero.
    /// @param _value The value to check.
    modifier nonZeroValue(uint256 _value) {
        require(_value != 0, ZERO_VALUE());
        _;
    }

    /// @dev Modifier that ensures the provided bytes32 value is not zero.
    /// @param _value The bytes32 value to check.
    modifier nonZeroBytes32(bytes32 _value) {
        require(_value != 0, ZERO_VALUE());
        _;
    }

    /// @dev Modifier that ensures the caller is the resolved address of a given
    /// name.
    /// @param _name The name to check against.
    modifier onlyFromNamed(bytes32 _name) {
        require(msg.sender == resolve(_name, true), ACCESS_DENIED());
        _;
    }

    /// @dev Modifier that ensures the caller is the resolved address of a given
    /// name, if the name is set.
    /// @param _name The name to check against.
    modifier onlyFromOptionalNamed(bytes32 _name) {
        address addr = resolve(_name, true);
        require(addr == address(0) || msg.sender == addr, ACCESS_DENIED());
        _;
    }

    /// @dev Modifier that ensures the caller is a resolved address to either _name1 or _name2
    /// name.
    /// @param _name1 The first name to check against.
    /// @param _name2 The second name to check against.
    modifier onlyFromNamedEither(bytes32 _name1, bytes32 _name2) {
        require(
            msg.sender == resolve(_name1, true) || msg.sender == resolve(_name2, true),
            ACCESS_DENIED()
        );
        _;
    }

    /// @dev Modifier that ensures the caller is either of the two specified addresses.
    /// @param _addr1 The first address to check against.
    /// @param _addr2 The second address to check against.
    modifier onlyFromEither(address _addr1, address _addr2) {
        require(msg.sender == _addr1 || msg.sender == _addr2, ACCESS_DENIED());
        _;
    }

    /// @dev Modifier that ensures the caller is the specified address.
    /// @param _addr The address to check against.
    modifier onlyFrom(address _addr) {
        require(msg.sender == _addr, ACCESS_DENIED());
        _;
    }

    /// @dev Modifier that ensures the caller is the specified address.
    /// @param _addr The address to check against.
    modifier onlyFromOptional(address _addr) {
        require(_addr == address(0) || msg.sender == _addr, ACCESS_DENIED());
        _;
    }

    constructor(address _resolver) {
        __resolver = _resolver;
        _disableInitializers();
    }

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

    /// @notice Resolves a name to an address on a specific chain
    /// @param _chainId The chain ID to resolve the name on
    /// @param _name The name to resolve
    /// @param _allowZeroAddress Whether to allow resolving to the zero address
    /// @return The resolved address
    function resolve(
        uint64 _chainId,
        bytes32 _name,
        bool _allowZeroAddress
    )
        internal
        view
        returns (address)
    {
        return IResolver(resolver()).resolve(_chainId, _name, _allowZeroAddress);
    }

    /// @notice Resolves a name to an address on the current chain
    /// @param _name The name to resolve
    /// @param _allowZeroAddress Whether to allow resolving to the zero address
    /// @return The resolved address
    function resolve(bytes32 _name, bool _allowZeroAddress) internal view returns (address) {
        return IResolver(resolver()).resolve(block.chainid, _name, _allowZeroAddress);
    }

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
}
