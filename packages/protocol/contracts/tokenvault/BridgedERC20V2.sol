// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "./BridgedERC20.sol";

/// @title BridgedERC20V2
/// @notice An upgradeable ERC20 contract that represents tokens bridged from
/// another chain. This implementation adds ERC20Permit support to BridgedERC20.
///
/// Most of the code were copied from OZ's ERC20PermitUpgradeable.sol contract.
///
/// @custom:security-contact security@taiko.xyz
contract BridgedERC20V2 is BridgedERC20, IERC20PermitUpgradeable, EIP712Upgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    mapping(address => CountersUpgradeable.Counter) private _nonces;
    uint256[49] private __gap;

    error BTOKEN_DEADLINE_EXPIRED();
    error BTOKEN_INVALID_SIG();

    /// @inheritdoc IBridgedERC20Initializable
    function init(
        address _owner,
        address _sharedAddressManager,
        address _srcToken,
        uint256 _srcChainId,
        uint8 _decimals,
        string calldata _symbol,
        string calldata _name
    )
        external
        virtual
        override
        initializer
    {
        // Check if provided parameters are valid
        LibBridgedToken.validateInputs(_srcToken, _srcChainId);
        __Essential_init(_owner, _sharedAddressManager);
        __ERC20_init(_name, _symbol);
        __EIP712_init_unchained(_name, "1");

        // Set contract properties
        srcToken = _srcToken;
        srcChainId = _srcChainId;
        __srcDecimals = _decimals;
    }

    /**
     * @inheritdoc IERC20PermitUpgradeable
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        virtual
        override
    {
        if (block.timestamp > deadline) revert BTOKEN_DEADLINE_EXPIRED();

        bytes32 structHash = keccak256(
            abi.encode(_PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline)
        );

        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSAUpgradeable.recover(hash, v, r, s);
        if (signer != owner) revert BTOKEN_INVALID_SIG();

        _approve(owner, spender, value);
    }

    /**
     * @inheritdoc IERC20PermitUpgradeable
     */
    function nonces(address owner) public view virtual override returns (uint256) {
        return _nonces[owner].current();
    }

    /**
     * @inheritdoc IERC20PermitUpgradeable
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev "Consume a nonce": return the current value and increment.
     *
     * _Available since v4.1._
     */
    function _useNonce(address owner) internal virtual returns (uint256 current) {
        CountersUpgradeable.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }
}
