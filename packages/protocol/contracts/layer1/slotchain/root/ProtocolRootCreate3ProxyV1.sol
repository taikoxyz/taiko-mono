// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title One-shot protocol root CREATE3 proxy
/// @notice Deploys exactly one child with CREATE nonce one for its constructor-time factory.
/// @dev The factory occupies raw storage slot zero and the used flag occupies raw slot one. The
///      runtime has no immutable or constructor-argument patch, so every factory uses identical
///      proxy creation and runtime bytecode.
/// @custom:security-contact security@taiko.xyz
contract ProtocolRootCreate3ProxyV1 {
    uint256 private constant _MAX_INIT_CODE_LENGTH = 49_152;

    uint256 private _factorySlot;
    uint256 private _usedSlot;

    constructor() {
        assembly ("memory-safe") {
            sstore(_factorySlot.slot, caller())
        }
    }

    /// @notice Deploys the proxy's only child from canonical nonempty init code.
    /// @param _initCode The exact manifest-committed child init code.
    /// @return component_ The nonzero CREATE nonce-one child address.
    function deployV1(bytes calldata _initCode) external returns (address component_) {
        if (msg.sender != address(uint160(_factorySlot))) revert UnauthorizedFactory();
        if (_usedSlot != 0) revert ProxyAlreadyUsed();
        _requireCanonicalBytesCalldata(_initCode);

        // Set before CREATE. A failed child construction reverts this write with the call frame.
        _usedSlot = 1;
        assembly ("memory-safe") {
            let pointer := mload(0x40)
            calldatacopy(pointer, _initCode.offset, _initCode.length)
            component_ := create(0, pointer, _initCode.length)
            mstore(0x40, and(add(add(pointer, _initCode.length), 31), not(31)))
        }
        if (component_ == address(0)) revert ComponentDeploymentFailed();
    }

    /// @dev Rejects every ABI-equivalent dynamic encoding except offset 0x20, a contiguous tail,
    ///      the minimal padded total length, and zero final-word padding.
    function _requireCanonicalBytesCalldata(bytes calldata _initCode) private pure {
        uint256 encodedOffset;
        uint256 encodedLength;
        assembly ("memory-safe") {
            encodedOffset := calldataload(4)
            encodedLength := calldataload(36)
        }
        if (
            encodedOffset != 32 || encodedLength == 0 || encodedLength > _MAX_INIT_CODE_LENGTH
                || encodedLength != _initCode.length
        ) {
            revert NonCanonicalInitCode();
        }

        uint256 paddedLength = (encodedLength + 31) & ~uint256(31);
        if (msg.data.length != 68 + paddedLength) revert NonCanonicalInitCode();

        uint256 remainder = encodedLength & 31;
        if (remainder != 0) {
            uint256 finalWord;
            assembly ("memory-safe") {
                finalWord := calldataload(add(68, sub(encodedLength, remainder)))
            }
            uint256 paddingBits = (32 - remainder) * 8;
            if ((finalWord & ((uint256(1) << paddingBits) - 1)) != 0) {
                revert NonCanonicalInitCode();
            }
        }
    }

    error ComponentDeploymentFailed();
    error NonCanonicalInitCode();
    error ProxyAlreadyUsed();
    error UnauthorizedFactory();
}
